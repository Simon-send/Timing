"use strict";

/* eslint-disable require-jsdoc */
const {execFileSync} = require("node:child_process");

function parseArgs(argv) {
  const options = {project: "time-plotting", resume: false};
  for (const argument of argv) {
    if (argument === "--resume") options.resume = true;
    else if (argument.startsWith("--event=")) {
      options.eventId = Number(argument.slice(8));
    } else if (argument.startsWith("--project=")) {
      options.project = argument.slice(10);
    } else if (argument.startsWith("--run=")) options.runId = argument.slice(6);
    else throw new Error(`Unknown argument: ${argument}`);
  }
  if (!Number.isSafeInteger(options.eventId) || options.eventId <= 0) {
    throw new Error("Specify --event=<positive event ID>");
  }
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(options.project)) {
    throw new Error("Invalid project ID");
  }
  if (options.resume && !options.runId) {
    throw new Error("Resumption requires the inspected --run=<run ID>");
  }
  return options;
}

function resumeRequest(options, job) {
  if (job.eventId !== options.eventId || job.runId !== options.runId ||
      job.manifestVersion !== 1 ||
      !["partial", "blocked", "error"].includes(job.status)) {
    throw new Error("Run changed, still active, or not resumable");
  }
  return {eventId: options.eventId, resumeRunId: job.runId, classCount: 1};
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const token = execFileSync("gcloud", ["auth", "print-identity-token"], {
    encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
  }).trim();
  const base = `https://europe-west1-${options.project}.cloudfunctions.net`;
  const call = async (path, body) => {
    const response = await fetch(`${base}/${path}`, {
      method: body ? "POST" : "GET",
      headers: {"Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"},
      ...(body ? {body: JSON.stringify(body)} : {}),
      signal: AbortSignal.timeout(60000),
    });
    if (!response.ok) {
      throw new Error(`Import API returned HTTP ${response.status}`);
    }
    return response.json();
  };
  const path = `getImportStatus?jobId=event-${options.eventId}` +
    "&includeTargets=true";
  let job = await call(path);
  const targets = [...(job.targets || [])];
  const firstRun = job.runId;
  while (job.nextOffset != null) {
    job = await call(`${path}&offset=${job.nextOffset}`);
    if (job.runId !== firstRun) {
      throw new Error("Run changed during inspection");
    }
    targets.push(...job.targets);
  }
  const unresolved = targets.filter((target) => target.status !== "done");
  console.log(JSON.stringify({eventId: job.eventId, runId: job.runId,
    status: job.status, done: job.done, targetCount: job.targetCount,
    completedTargetCount: job.completedTargetCount,
    failedTargetCount: job.failedTargetCount, unresolved}, null, 2));
  if (!options.resume) {
    console.log("Read-only inspection. To resume, specify --resume and --run.");
    return;
  }
  const request = resumeRequest(options, job);
  console.log(JSON.stringify(await call("startImportEvent", request), null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {parseArgs, resumeRequest};
