"use strict";

/* eslint-disable require-jsdoc */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {execFileSync} = require("node:child_process");
const {createHash} = require("node:crypto");
const {startImport, waitForRun} = require("./reimport-biathlon-aggregates");

const ACTIVE = new Set(["initializing", "queued", "running"]);

function parseArgs(argv) {
  const options = {run: false, project: null, confirmCount: null,
    confirmIds: null, from: null,
    pollSeconds: 20, timeoutMinutes: 120};
  for (const arg of argv) {
    if (arg === "--run") options.run = true;
    else if (arg === "--help") options.help = true;
    else if (arg.startsWith("--project=")) options.project = arg.slice(10);
    else if (arg.startsWith("--confirm-ids=")) {
      options.confirmIds = arg.slice(14);
    } else if (arg.startsWith("--from=")) {
      options.from = Number(arg.slice(7));
    } else if (arg.startsWith("--confirm-count=")) {
      options.confirmCount = Number(arg.slice(16));
    } else if (arg.startsWith("--poll-seconds=")) {
      options.pollSeconds = Number(arg.slice(15));
    } else if (arg.startsWith("--timeout-minutes=")) {
      options.timeoutMinutes = Number(arg.slice(18));
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!options.help && !/^[a-z][a-z0-9-]{4,62}$/.test(options.project || "")) {
    throw new Error("Specify --project=<valid project ID>");
  }
  if (options.run && (!Number.isSafeInteger(options.confirmCount) ||
      options.confirmCount < 1)) {
    throw new Error("--run requires --confirm-count=<dry-run count>");
  }
  if (options.run && !/^[0-9a-f]{64}$/.test(options.confirmIds || "")) {
    throw new Error("--run requires --confirm-ids=<dry-run checksum>");
  }
  if (options.from != null && (!Number.isSafeInteger(options.from) ||
      options.from <= 0)) throw new Error("Invalid --from event ID");
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

async function listEventIds(db) {
  const snapshot = await db.collection("events").select().get();
  const ids = snapshot.docs.map((doc) => {
    const id = Number(doc.id);
    if (!Number.isSafeInteger(id) || id <= 0 || String(id) !== doc.id) {
      throw new Error(`Unsafe event document ID: ${doc.id}`);
    }
    return id;
  });
  return ids.sort((a, b) => a - b);
}

function idChecksum(ids) {
  return createHash("sha256").update(ids.join(",")).digest("hex");
}

async function checkJobs(db, ids) {
  const jobs = new Map();
  for (const id of ids) {
    const snapshot = await db.doc(`importJobs/event-${id}`).get();
    const job = snapshot.exists ? snapshot.data() : null;
    if (job && ACTIVE.has(job.status)) {
      throw new Error(`Event ${id} already has an active import`);
    }
    jobs.set(id, job);
  }
  return jobs;
}

async function verifyCompletedTargets(db, eventId, runId, job) {
  if (job.runId !== runId || job.status !== "done" || job.done !== true ||
      job.manifestVersion !== 1 ||
      !Number.isSafeInteger(job.targetCount) || job.targetCount < 1 ||
      job.completedTargetCount !== job.targetCount ||
      (job.failedTargetCount || 0) !== 0) {
    throw new Error(`Event ${eventId}: incomplete import coverage`);
  }
  const targets = await db.doc(`importJobs/event-${eventId}`)
      .collection("runs").doc(runId).collection("targets").get();
  if (targets.size !== job.targetCount ||
      targets.docs.some((doc) => doc.data().status !== "done")) {
    throw new Error(`Event ${eventId}: incomplete target manifest`);
  }
  return targets.size;
}

function assertQueueRunning(project) {
  const state = execFileSync("gcloud", ["tasks", "queues", "describe",
    "imports", "--location=europe-west1", `--project=${project}`,
    "--format=value(state)"], {
    encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
  }).trim();
  if (state !== "RUNNING") throw new Error("Import queue is not RUNNING");
}

async function runImports(db, ids, options, dependencies = {}) {
  if (ids.length !== options.confirmCount ||
      idChecksum(ids) !== options.confirmIds) {
    throw new Error("Event list changed since dry run; inspect again");
  }
  const fromIndex = options.from == null ? 0 : ids.indexOf(options.from);
  if (fromIndex < 0) throw new Error("--from ID is not in the event list");
  const selected = ids.slice(fromIndex);
  const jobs = await checkJobs(db, selected);
  (dependencies.assertQueueRunning || assertQueueRunning)(options.project);
  await (dependencies.verifyAccess ||
    require("./verify-import-access").verify)(options.project);
  for (const [index, id] of selected.entries()) {
    const latest = await db.doc(`importJobs/event-${id}`).get();
    if (latest.exists && ACTIVE.has(latest.data().status)) {
      throw new Error(`Event ${id} became active before start`);
    }
    const oldRunId = latest.exists ? latest.data().runId : jobs.get(id)?.runId;
    console.log(`Starting ${index + 1}/${selected.length}: ${id}`);
    const runId = await (dependencies.startImport || startImport)(
        db, id, options.project, oldRunId);
    const job = await (dependencies.waitForRun || waitForRun)(
        db, id, runId, options);
    const count = await verifyCompletedTargets(db, id, runId, job);
    console.log(JSON.stringify({eventId: id, runId, status: "verified",
      targetCount: count}));
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log("Usage: node scripts/reimport-all-events.js " +
      "--project=time-plotting " +
      "[--run --confirm-count=N --confirm-ids=SHA256] [--from=EVENT_ID]");
    console.log("Default: read-only list. --run reimports sequentially.");
    return;
  }
  initializeApp({projectId: options.project});
  const db = getFirestore();
  const ids = await listEventIds(db);
  console.log(`Existing events (${ids.length}): ${ids.join(", ")}`);
  console.log(`ID checksum: ${idChecksum(ids)}`);
  if (!options.run) {
    console.log("Dry run only. No imports started.");
    return;
  }
  await runImports(db, ids, options);
  console.log("All existing events reimported and manifest-verified.");
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {parseArgs, listEventIds, idChecksum, checkJobs,
  verifyCompletedTargets, runImports};
