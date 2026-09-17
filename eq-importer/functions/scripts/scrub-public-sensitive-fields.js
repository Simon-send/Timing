"use strict";

/* eslint-disable require-jsdoc */

const admin = require("firebase-admin");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

const DEFAULT_PROJECT_ID = "time-plotting";
const MAX_BATCH_WRITES = 400;
const ATHLETE_FIELDS = ["source", "gender", "birthYear", "age"];
const RESULT_FIELDS = [
  "arrangementUid",
  "athleteSourceUid",
  "gender",
  "birthYear",
  "age",
  "timingIds",
  "registration",
];
const RELAY_MEMBER_FIELDS = [
  "athleteSourceUid",
  "gender",
  "birthYear",
  "age",
  "timingIds",
  "registration",
];

function parseArgs(argv) {
  const options = {
    apply: false,
    confirmProject: "",
    json: false,
    projectId: process.env.GCLOUD_PROJECT || DEFAULT_PROJECT_ID,
  };
  for (const argument of argv) {
    if (argument === "--apply") {
      options.apply = true;
    } else if (argument === "--json") {
      options.json = true;
    } else if (argument.startsWith("--project=")) {
      options.projectId = argument.slice("--project=".length).trim();
    } else if (argument.startsWith("--confirm-project=")) {
      options.confirmProject = argument
          .slice("--confirm-project=".length)
          .trim();
    } else if (argument === "--help") {
      options.help = true;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }
  if (!options.projectId) throw new Error("Missing Firebase project id");
  if (options.apply && options.confirmProject !== options.projectId) {
    throw new Error(
        "--apply requires --confirm-project to exactly match --project",
    );
  }
  return options;
}

function hasOwn(data, field) {
  return Object.prototype.hasOwnProperty.call(data || {}, field);
}

function buildTopLevelDeletes(data, fields, deleteValue) {
  const update = {};
  for (const field of fields) {
    if (hasOwn(data, field)) update[field] = deleteValue;
  }
  return update;
}

function cleanRelayMembers(team) {
  if (!team || !Array.isArray(team.members)) {
    return {changed: false, members: null};
  }
  let changed = false;
  const members = team.members.map((member) => {
    if (!member || typeof member !== "object" || Array.isArray(member)) {
      return member;
    }
    const cleanMember = Object.assign({}, member);
    for (const field of RELAY_MEMBER_FIELDS) {
      if (hasOwn(cleanMember, field)) {
        delete cleanMember[field];
        changed = true;
      }
    }
    return cleanMember;
  });
  return {changed, members};
}

function buildAthleteUpdate(data, deleteValue) {
  return buildTopLevelDeletes(data, ATHLETE_FIELDS, deleteValue);
}

function buildResultUpdate(data, deleteValue) {
  const update = buildTopLevelDeletes(data, RESULT_FIELDS, deleteValue);
  const relayMembers = cleanRelayMembers(data && data.team);
  if (relayMembers.changed) update["team.members"] = relayMembers.members;
  return update;
}

function isOfficialResultPath(path) {
  const parts = String(path || "").split("/");
  return (parts.length === 6 &&
      parts[0] === "events" && parts[2] === "classes" &&
      parts[4] === "results") ||
    (parts.length === 8 &&
      parts[0] === "events" && parts[2] === "stages" &&
      parts[4] === "classes" && parts[6] === "results");
}

async function findCleanupWrites(db) {
  const [athletes, results] = await Promise.all([
    db.collection("athletes").select(...ATHLETE_FIELDS).get(),
    db.collectionGroup("results").select(...RESULT_FIELDS, "team").get(),
  ]);
  const writes = [];
  let athleteDocuments = 0;
  let resultDocuments = 0;

  for (const document of athletes.docs) {
    const update = buildAthleteUpdate(document.data(), FieldValue.delete());
    if (Object.keys(update).length > 0) {
      writes.push({ref: document.ref, update});
      athleteDocuments++;
    }
  }
  for (const document of results.docs) {
    if (!isOfficialResultPath(document.ref.path)) continue;
    const update = buildResultUpdate(document.data(), FieldValue.delete());
    if (Object.keys(update).length > 0) {
      writes.push({ref: document.ref, update});
      resultDocuments++;
    }
  }
  return {athleteDocuments, resultDocuments, writes};
}

async function applyCleanupWrites(db, writes) {
  for (let start = 0; start < writes.length; start += MAX_BATCH_WRITES) {
    const batch = db.batch();
    for (const write of writes.slice(start, start + MAX_BATCH_WRITES)) {
      batch.update(write.ref, write.update);
    }
    await batch.commit();
  }
}

function printReport(report, options) {
  const output = {
    applied: options.apply,
    athleteDocuments: report.athleteDocuments,
    projectId: options.projectId,
    resultDocuments: report.resultDocuments,
    totalDocuments: report.writes.length,
  };
  if (options.json) {
    console.log(JSON.stringify(output, null, 2));
    return;
  }
  console.log(`Project: ${output.projectId}`);
  console.log(`Athlete documents needing cleanup: ${output.athleteDocuments}`);
  console.log(`Result documents needing cleanup: ${output.resultDocuments}`);
  console.log(options.apply ?
    `Cleaned ${output.totalDocuments} public documents.` :
    "Dry run only. No documents were changed.");
}

function printHelp() {
  console.log("Usage: npm run security:scrub-public -- [options]");
  console.log(
      "  --project=<id>          Firebase project (default: time-plotting)",
  );
  console.log("  --json                  Print the report as JSON");
  console.log("  --apply                 Delete sensitive public fields");
  console.log("  --confirm-project=<id>  Required with --apply");
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }
  admin.initializeApp({projectId: options.projectId});
  const db = getFirestore();
  const report = await findCleanupWrites(db);
  if (options.apply) await applyCleanupWrites(db, report.writes);
  printReport(report, options);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {
  buildAthleteUpdate,
  buildResultUpdate,
  cleanRelayMembers,
  isOfficialResultPath,
  parseArgs,
};
