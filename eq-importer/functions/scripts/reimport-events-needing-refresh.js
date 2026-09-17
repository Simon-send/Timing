"use strict";

/* eslint-disable require-jsdoc */

const {execFileSync} = require("node:child_process");
const admin = require("firebase-admin");
const {getFirestore} = require("firebase-admin/firestore");

const DEFAULT_PROJECT_ID = "time-plotting";
const DEFAULT_IMPORT_URI =
  "https://europe-west1-time-plotting.cloudfunctions.net/startImportEvent";

function parseArgs(argv) {
  const options = {
    classCount: 1,
    enqueue: false,
    json: false,
    projectId: process.env.GCLOUD_PROJECT || DEFAULT_PROJECT_ID,
    uri: DEFAULT_IMPORT_URI,
  };
  for (const argument of argv) {
    if (argument === "--enqueue") {
      options.enqueue = true;
    } else if (argument === "--json") {
      options.json = true;
    } else if (argument.startsWith("--project=")) {
      options.projectId = argument.slice("--project=".length).trim();
    } else if (argument.startsWith("--uri=")) {
      options.uri = argument.slice("--uri=".length).trim();
    } else if (argument.startsWith("--class-count=")) {
      options.classCount = Number(argument.slice("--class-count=".length));
    } else if (argument === "--help") {
      options.help = true;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  if (!Number.isInteger(options.classCount) ||
      options.classCount <= 0 || options.classCount > 20) {
    throw new Error("--class-count must be an integer between 1 and 20");
  }
  if (!options.projectId) throw new Error("Missing Firebase project id");
  if (!options.uri) throw new Error("Missing startImportEvent URI");
  return options;
}

function classAthleteCount(data) {
  const participantCount = numberOrNull(data && data.participantCount);
  if (participantCount != null && participantCount > 0) {
    return participantCount;
  }
  const resultCount = numberOrNull(data && data.resultCount);
  return resultCount != null && resultCount > 0 ? resultCount : 0;
}

function numberOrNull(value) {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

function stagePriority(stage) {
  const level = numberOrNull(stage.data.level);
  const order = numberOrNull(stage.data.order);
  return [
    level === 1 ? -1 : (level == null ? 1000 : level),
    order == null ? 1000 : order,
    stage.id,
  ];
}

function compareStagePriority(left, right) {
  const leftPriority = stagePriority(left);
  const rightPriority = stagePriority(right);
  for (let index = 0; index < leftPriority.length; index++) {
    if (leftPriority[index] < rightPriority[index]) return -1;
    if (leftPriority[index] > rightPriority[index]) return 1;
  }
  return 0;
}

function selectPrimaryStage(stageClasses) {
  const candidates = stageClasses.slice();
  candidates.sort((left, right) => {
    const countDifference = classAthleteCount(right.classData) -
      classAthleteCount(left.classData);
    return countDifference || compareStagePriority(left.stage, right.stage);
  });
  return candidates.length ? candidates[0] : null;
}

function isBiathlonStage(stageData) {
  return stageData.isBiathlon === true ||
    String(stageData.resultProfile || "").toLowerCase() === "biathlon";
}

function isFinishedStatus(status) {
  return !/^(dnf|dns|dsq|dq|disk|disq|utg)/i.test(String(status || ""));
}

function objectValues(value) {
  return value && typeof value === "object" && !Array.isArray(value) ?
    Object.values(value) : [];
}

function hasPositiveNumber(value) {
  const number = numberOrNull(value);
  return number != null && number > 0;
}

function missingBiathlonRanks(resultData) {
  if (!isFinishedStatus(resultData.status)) return [];
  const summary = resultData.analysisSummary || resultData.analysis;
  const biathlon = summary && summary.biathlon;
  const metrics = biathlon && biathlon.metrics;
  if (!metrics || typeof metrics !== "object") return [];

  const missing = [];
  if (hasPositiveNumber(metrics.skiTimeMs) &&
      !hasPositiveNumber(metrics.skiRank)) {
    missing.push("skiRank");
  }
  for (const pass of objectValues(biathlon.passes)) {
    const rangeMs = pass && (pass.rangeMs || pass.rangeTimeMs ||
      pass.shootingTimeMs);
    if (hasPositiveNumber(rangeMs) && !hasPositiveNumber(pass.rangeRank)) {
      missing.push("rangeRank");
      break;
    }
  }
  return missing;
}

async function scanEvent(eventSnapshot) {
  const eventRef = eventSnapshot.ref;
  const eventData = eventSnapshot.data();
  const [rootClasses, stages] = await Promise.all([
    eventRef.collection("classes").get(),
    eventRef.collection("stages").get(),
  ]);
  const stageEntries = await Promise.all(stages.docs.map(async (stageDoc) => ({
    id: stageDoc.id,
    data: stageDoc.data(),
    classDocs: await stageDoc.ref.collection("classes").get(),
  })));
  const rootClassData = new Map(
      rootClasses.docs.map((classDoc) => [classDoc.id, classDoc.data()]),
  );
  const stageClassesById = new Map();
  for (const stage of stageEntries) {
    for (const classDoc of stage.classDocs.docs) {
      const classes = stageClassesById.get(classDoc.id) || [];
      classes.push({stage, classData: classDoc.data(), ref: classDoc.ref});
      stageClassesById.set(classDoc.id, classes);
    }
  }

  const summaryIssues = [];
  for (const [classId, stageClasses] of stageClassesById.entries()) {
    if (stageClasses.length < 2) continue;
    const expected = selectPrimaryStage(stageClasses);
    const rootData = rootClassData.get(classId);
    const expectedCount = classAthleteCount(expected.classData);
    if (!rootData || rootData.primaryStageId !== expected.stage.id ||
        classAthleteCount(rootData) !== expectedCount) {
      summaryIssues.push({
        classId,
        expectedAthleteCount: expectedCount,
        expectedPrimaryStageId: expected.stage.id,
        storedAthleteCount: rootData ? classAthleteCount(rootData) : null,
        storedPrimaryStageId: rootData ? rootData.primaryStageId || null : null,
      });
    }
  }

  const rankIssues = [];
  for (const stage of stageEntries) {
    if (!isBiathlonStage(stage.data)) continue;
    for (const classDoc of stage.classDocs.docs) {
      const resultSnapshot = await classDoc.ref.collection("results")
          .select("status", "analysis", "analysisSummary")
          .get();
      let missingSkiRankResults = 0;
      let missingRangeRankResults = 0;
      for (const resultDoc of resultSnapshot.docs) {
        const missing = missingBiathlonRanks(resultDoc.data());
        if (missing.includes("skiRank")) missingSkiRankResults++;
        if (missing.includes("rangeRank")) missingRangeRankResults++;
      }
      if (missingSkiRankResults > 0 || missingRangeRankResults > 0) {
        rankIssues.push({
          classId: classDoc.id,
          missingRangeRankResults,
          missingSkiRankResults,
          stageId: stage.id,
        });
      }
    }
  }

  return {
    eventId: eventSnapshot.id,
    eventName: eventData.name || eventData.Navn || "",
    needsReimport: summaryIssues.length > 0 || rankIssues.length > 0,
    rankIssues,
    summaryIssues,
  };
}

async function scanEvents(db) {
  const events = await db.collection("events").get();
  const reports = [];
  for (const eventSnapshot of events.docs) {
    reports.push(await scanEvent(eventSnapshot));
  }
  reports.sort((left, right) => left.eventId.localeCompare(right.eventId));
  return reports;
}

function printReport(reports, json) {
  const needingReimport = reports.filter((report) => report.needsReimport);
  if (json) {
    console.log(JSON.stringify({
      eventIds: needingReimport.map((report) => report.eventId),
      events: needingReimport,
      scannedEventCount: reports.length,
    }, null, 2));
    return;
  }
  console.log(`Scanned ${reports.length} events.`);
  if (needingReimport.length === 0) {
    console.log("No events need a reimport for the current migration checks.");
    return;
  }
  console.log("Events needing reimport:");
  for (const report of needingReimport) {
    const reasons = [
      report.summaryIssues.length ?
        `${report.summaryIssues.length} class summary issue(s)` : null,
      report.rankIssues.length ?
        `${report.rankIssues.length} biathlon rank issue(s)` : null,
    ].filter(Boolean).join(", ");
    console.log(`- ${report.eventId} ${report.eventName}: ${reasons}`);
  }
  console.log("Event IDs: " +
    needingReimport.map((report) => report.eventId).join(", "));
}

function identityToken(uri) {
  return execFileSync(
      "gcloud",
      ["auth", "print-identity-token", `--audiences=${uri}`],
      {encoding: "utf8"},
  ).trim();
}

async function enqueueReimports(reports, options) {
  const eventIds = reports
      .filter((report) => report.needsReimport)
      .map((report) => report.eventId);
  if (eventIds.length === 0) return [];
  const token = identityToken(options.uri);
  if (!token) throw new Error("Could not obtain a Google identity token");
  const jobs = [];
  for (const eventId of eventIds) {
    const response = await fetch(options.uri, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        eventId: Number(eventId),
        classCount: options.classCount,
      }),
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(
          `Could not start ${eventId}: ${body.error || response.status}`,
      );
    }
    jobs.push({
      eventId,
      jobId: body.jobId || null,
      status: body.status || null,
    });
  }
  return jobs;
}

function printHelp() {
  console.log(
      "Usage: node scripts/reimport-events-needing-refresh.js [options]",
  );
  console.log("  --json                 Print the scan report as JSON");
  console.log("  --enqueue              Queue every event found by the scan");
  console.log("  --class-count=<1-20>   Import chunk size (default: 1)");
  console.log(
      "  --project=<id>         Firebase project (default: time-plotting)",
  );
  console.log("  --uri=<url>            startImportEvent endpoint");
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }
  admin.initializeApp({projectId: options.projectId});
  const reports = await scanEvents(getFirestore());
  printReport(reports, options.json);
  if (!options.enqueue) return;
  const jobs = await enqueueReimports(reports, options);
  console.log(JSON.stringify({queuedJobs: jobs}, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {
  classAthleteCount,
  missingBiathlonRanks,
  selectPrimaryStage,
};
