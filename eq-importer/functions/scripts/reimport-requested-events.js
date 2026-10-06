"use strict";

/* eslint-disable require-jsdoc */

const {execFileSync} = require("node:child_process");

const EVENT_IDS = [79178, 79179, 80090, 80091, 80093, 80114, 81337];
const DEFAULT_PROJECT_ID = "time-plotting";
const FUNCTION_NAME = "startImportEvent";
const FUNCTION_REGION = "europe-west1";

function parseArgs(argv) {
  const options = {
    classCount: 1,
    enqueue: false,
    projectId: DEFAULT_PROJECT_ID,
  };
  for (const argument of argv) {
    if (argument === "--enqueue") {
      options.enqueue = true;
    } else if (argument.startsWith("--class-count=")) {
      options.classCount = Number(argument.slice("--class-count=".length));
    } else if (argument.startsWith("--project=")) {
      options.projectId = argument.slice("--project=".length).trim();
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
  if (!options.projectId) throw new Error("Missing Google Cloud project id");
  return options;
}

async function enqueueEvents(eventIds, options) {
  const jobs = [];
  for (const eventId of eventIds) {
    const output = execFileSync(
        "gcloud",
        [
          "functions",
          "call",
          FUNCTION_NAME,
          "--gen2",
          `--region=${FUNCTION_REGION}`,
          `--project=${options.projectId}`,
          `--data=${JSON.stringify({eventId, classCount: options.classCount})}`,
          "--format=json",
          "--quiet",
        ],
        {encoding: "utf8"},
    );
    const body = parseFunctionCallOutput(output);
    jobs.push({
      eventId,
      jobId: body.jobId || null,
      status: body.status || null,
    });
  }
  return jobs;
}

function parseFunctionCallOutput(output) {
  const outer = JSON.parse(output);
  if (typeof outer.result !== "string") return outer.result || outer;
  return JSON.parse(outer.result);
}

function printHelp() {
  console.log("Usage: npm run reimport:requested -- [options]");
  console.log("  --enqueue              Queue the requested events");
  console.log("  --class-count=<1-20>   Import chunk size (default: 1)");
  console.log(
      "  --project=<id>         Google Cloud project (default: time-plotting)",
  );
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }
  console.log("Requested event IDs: " + EVENT_IDS.join(", "));
  if (!options.enqueue) {
    console.log("No import started. Add --enqueue to queue these events.");
    return;
  }
  const jobs = await enqueueEvents(EVENT_IDS, options);
  console.log(JSON.stringify({queuedJobs: jobs}, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {EVENT_IDS, parseArgs, parseFunctionCallOutput};
