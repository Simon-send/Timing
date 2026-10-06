"use strict";

/* eslint-disable require-jsdoc */

const {execFileSync} = require("node:child_process");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {buildBiathlonAggregates} = require("../biathlon-aggregate");

const EVENT_IDS = [
  74316, 79094, 79097, 79181, 79182, 79179, 80088, 80089, 79480,
  80090, 81702, 80091, 81703, 81337, 80093, 80094, 80114, 83291, 83309,
];
const ACTIVE_STATUSES = new Set(["initializing", "queued", "running"]);
const RUN_ID_PATTERN = new RegExp(
    "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-" +
    "[0-9a-f]{4}-[0-9a-f]{12}$", "i");
const REGION = "europe-west1";
const QUEUE = "imports";

function parseArgs(argv) {
  const options = {run: false, project: null, from: null, pollSeconds: 20,
    timeoutMinutes: 120};
  for (const arg of argv) {
    if (arg === "--run") options.run = true;
    else if (arg === "--help") options.help = true;
    else if (arg.startsWith("--project=")) options.project = arg.slice(10);
    else if (arg.startsWith("--from=")) options.from = Number(arg.slice(7));
    else if (arg.startsWith("--poll-seconds=")) {
      options.pollSeconds = Number(arg.slice(15));
    } else if (arg.startsWith("--timeout-minutes=")) {
      options.timeoutMinutes = Number(arg.slice(18));
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  if (options.project != null &&
      !/^[a-z][a-z0-9-]{4,62}$/.test(options.project)) {
    throw new Error("Invalid --project");
  }
  if (options.run && !options.project) {
    throw new Error("--run requires an explicit --project=<id>");
  }
  if (options.from != null && !EVENT_IDS.includes(options.from)) {
    throw new Error("--from must be one of the listed event IDs");
  }
  if (!Number.isInteger(options.pollSeconds) || options.pollSeconds < 5 ||
      options.pollSeconds > 300) {
    throw new Error("--poll-seconds must be between 5 and 300");
  }
  if (!Number.isInteger(options.timeoutMinutes) ||
      options.timeoutMinutes < 10 || options.timeoutMinutes > 1440) {
    throw new Error("--timeout-minutes must be between 10 and 1440");
  }
  return options;
}

function selectedEvents(options) {
  const start = options.from == null ? 0 : EVENT_IDS.indexOf(options.from);
  return EVENT_IDS.slice(start);
}

function gcloud(args) {
  return execFileSync("gcloud", args, {
    encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function validateAggregate(actual, expected, kind) {
  if (!actual || actual.schemaVersion !== 1 || actual.kind !== kind ||
      actual.finishersCount !== expected.finishersCount ||
      actual.cohortCount !== expected.cohortCount) return false;
  for (const [field, value] of Object.entries(expected.metrics)) {
    const stored = actual.metrics && actual.metrics[field];
    if (stored?.count !== value.count ||
        typeof stored.mean !== "number" ||
        Math.abs(stored.mean - value.mean) > 0.000001) return false;
  }
  return true;
}

async function verifyProfiles(db, eventId, runId, expectedTargetCount) {
  const jobRef = db.doc(`importJobs/event-${eventId}`);
  const targets = await jobRef.collection("runs").doc(runId)
      .collection("targets").get();
  if (targets.size !== expectedTargetCount || targets.docs.some((target) =>
    target.data().status !== "done")) {
    throw new Error(`Event ${eventId}: target manifest is not fully done`);
  }
  let verifiedClasses = 0;
  let expectedProfiles = 0;
  for (const target of targets.docs) {
    const {stageId, classId} = target.data();
    if (!stageId || !classId) {
      throw new Error(`Event ${eventId}: invalid manifest target`);
    }
    const classRef = db.doc(
        `events/${eventId}/stages/${stageId}/classes/${classId}`);
    const classSnapshot = await classRef.get();
    if (!classSnapshot.exists) {
      throw new Error(
          `Event ${eventId}: missing stage class ${stageId}/${classId}`);
    }
    const cls = classSnapshot.data();
    if (cls.isRelay === true || cls.isBiathlon !== true) continue;
    verifiedClasses++;
    const results = await classRef.collection("results").get();
    const profiles = buildBiathlonAggregates(results.docs.map((row) =>
      ({...row.data(), id: row.id})));
    const [all, top] = await Promise.all([
      classRef.collection("aggregateProfiles").doc("biathlon-all").get(),
      classRef.collection("aggregateProfiles").doc("biathlon-top-half").get(),
    ]);
    if (profiles == null) {
      if (all.exists || top.exists) {
        throw new Error(
            `Event ${eventId}: stale profiles at ${stageId}/${classId}`);
      }
      continue;
    }
    expectedProfiles += 2;
    if (!validateAggregate(all.data(), profiles.all, "biathlon-all") ||
        !validateAggregate(top.data(), profiles.topHalf, "biathlon-top-half")) {
      throw new Error(
          `Event ${eventId}: missing or outdated profiles at ` +
          `${stageId}/${classId}`);
    }
  }
  if (!expectedProfiles) {
    throw new Error(`Event ${eventId}: no individual aggregate profiles`);
  }
  return {targetCount: targets.size, verifiedClasses, expectedProfiles};
}

function parseStartImportResponse(output) {
  let value = JSON.parse(output);
  for (let depth = 0; depth < 5; depth++) {
    if (typeof value === "string") {
      value = JSON.parse(value);
    } else if (value && typeof value === "object" &&
        !Array.isArray(value) && !Object.hasOwn(value, "jobId")) {
      const nested = value.result ?? value.response ?? value.body;
      if (nested == null) break;
      value = nested;
    } else {
      break;
    }
  }
  return value;
}

async function jobStateHint(db, eventId) {
  try {
    const snapshot = await db.doc(`importJobs/event-${eventId}`).get();
    if (!snapshot.exists) return "no job document";
    const job = snapshot.data();
    return `status=${job.status || "unknown"}, runId=${job.runId || "none"}`;
  } catch {
    return "job status could not be read";
  }
}

async function startImport(db, eventId, project, previousRunId,
    invoke = gcloud) {
  let response;
  try {
    const output = invoke([
      "functions", "call", "startImportEvent", "--gen2",
      `--region=${REGION}`, `--project=${project}`,
      `--data=${JSON.stringify({eventId, classCount: 1})}`,
      "--format=json", "--quiet",
    ]);
    response = parseStartImportResponse(output);
  } catch {
    const state = await jobStateHint(db, eventId);
    throw new Error(`Event ${eventId}: start response failed; ${state}. ` +
      "Inspect this job before retrying; it may have started.");
  }
  const runId = response && response.runId;
  if (response?.ok !== true || response.jobId !== `event-${eventId}` ||
      (response.eventId != null &&
        String(response.eventId) !== String(eventId)) ||
      typeof runId !== "string" ||
      !RUN_ID_PATTERN.test(runId) ||
      runId === previousRunId) {
    const state = await jobStateHint(db, eventId);
    throw new Error(`Event ${eventId}: unexpected start response; ${state}. ` +
      "Inspect this job before retrying; it may have started.");
  }
  const snapshot = await db.doc(`importJobs/event-${eventId}`).get();
  const job = snapshot.data();
  if (!snapshot.exists || job.runId !== runId ||
      job.jobId !== `event-${eventId}` || job.eventId !== eventId ||
      job.classCount !== 1 || job.manifestVersion !== 1 ||
      !Number.isInteger(job.targetCount) || job.targetCount < 1) {
    throw new Error(`Event ${eventId}: start response does not match ` +
      "the persisted import job. Inspect it before retrying.");
  }
  return runId;
}

async function verifiedExistingRun(db, eventId, job) {
  if (!job || job.status !== "done" || job.done !== true ||
      job.manifestVersion !== 1 || !job.runId ||
      !Number.isInteger(job.targetCount) || job.targetCount < 1 ||
      job.completedTargetCount !== job.targetCount ||
      (job.failedTargetCount || 0) !== 0) return null;
  try {
    return await verifyProfiles(db, eventId, job.runId, job.targetCount);
  } catch (error) {
    const incomplete = ["target manifest is not fully done",
      "missing or outdated profiles", "no individual aggregate profiles",
      "stale profiles"].some((message) => error.message.includes(message));
    if (incomplete) {
      return null;
    }
    throw error;
  }
}

async function waitForRun(db, eventId, runId, options) {
  const jobRef = db.doc(`importJobs/event-${eventId}`);
  const deadline = Date.now() + options.timeoutMinutes * 60000;
  let lastProgress = "";
  while (Date.now() < deadline) {
    const snapshot = await jobRef.get();
    const job = snapshot.data();
    if (!job || job.runId !== runId) {
      throw new Error(
          `Event ${eventId}: import run changed; inspect manually`);
    }
    const progress = `${job.status} ` +
      `${job.completedTargetCount || 0}/${job.targetCount || 0}`;
    if (progress !== lastProgress) {
      console.log(`Event ${eventId}: ${progress}`);
      lastProgress = progress;
    }
    if (job.status === "done") {
      if (job.done !== true || job.manifestVersion !== 1 ||
          !Number.isInteger(job.targetCount) || job.targetCount < 1 ||
          job.completedTargetCount !== job.targetCount ||
          (job.failedTargetCount || 0) !== 0) {
        throw new Error(`Event ${eventId}: done without verified coverage`);
      }
      return job;
    }
    if (["partial", "blocked", "error"].includes(job.status)) {
      throw new Error(
          `Event ${eventId}: import stopped as ${job.status}; ` +
          "inspect this run before continuing");
    }
    await new Promise((resolve) =>
      setTimeout(resolve, options.pollSeconds * 1000));
  }
  throw new Error(
      `Event ${eventId}: wait timed out; import may still be running`);
}

async function preflight(db, ids, project) {
  const queueState = gcloud([
    "tasks", "queues", "describe", QUEUE, `--location=${REGION}`,
    `--project=${project}`, "--format=value(state)",
  ]);
  if (queueState !== "RUNNING") {
    throw new Error(`Cloud Tasks queue ${QUEUE} is not RUNNING`);
  }
  for (const id of ids) {
    const [event, job] = await Promise.all([
      db.doc(`events/${id}`).get(),
      db.doc(`importJobs/event-${id}`).get(),
    ]);
    if (!event.exists) throw new Error(`Event ${id} is missing`);
    if (job.exists && ACTIVE_STATUSES.has(job.data().status)) {
      throw new Error(
          `Event ${id} already has an active import; stop first`);
    }
  }
  await require("./verify-import-access").verify(project);
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log("Usage: node scripts/reimport-biathlon-aggregates.js " +
      "[--run --project=time-plotting] [--from=EVENT_ID]");
    console.log("Default is read-only. --run imports sequentially " +
      "and verifies each event.");
    return;
  }
  const ids = selectedEvents(options);
  console.log(`Events (${ids.length}): ${ids.join(", ")}`);
  if (!options.run) {
    console.log("Dry run only. Add --run --project=time-plotting to start.");
    return;
  }
  initializeApp({projectId: options.project});
  const db = getFirestore();
  await preflight(db, ids, options.project);
  for (const [index, id] of ids.entries()) {
    const prior = await db.doc(`importJobs/event-${id}`).get();
    const previous = prior.data();
    if (prior.exists && ACTIVE_STATUSES.has(previous.status)) {
      throw new Error(`Event ${id} became active before start`);
    }
    const verified = await verifiedExistingRun(db, id, previous);
    if (verified) {
      console.log(JSON.stringify({eventId: id, runId: previous.runId,
        status: "already verified", ...verified}));
      continue;
    }
    console.log(`Starting ${index + 1}/${ids.length}: ${id}`);
    const runId = await startImport(db, id, options.project, previous?.runId);
    const job = await waitForRun(db, id, runId, options);
    const verification = await verifyProfiles(
        db, id, runId, job.targetCount);
    console.log(JSON.stringify({eventId: id, runId, status: "verified",
      ...verification}));
  }
  console.log("All requested events were reimported and verified.");
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {EVENT_IDS, parseArgs, selectedEvents, validateAggregate,
  verifyProfiles, waitForRun, parseStartImportResponse, startImport,
  verifiedExistingRun};
