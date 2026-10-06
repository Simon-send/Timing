"use strict";

/* eslint-disable require-jsdoc */
const STALLED_MS = 15 * 60 * 1000;
const MAX_RECOVERIES = 3;
// Longer than startImportEvent's 60-second HTTP timeout.
const INITIALIZATION_TIMEOUT_MS = 5 * 60 * 1000;

function initializationExpiresAtMs(job) {
  if (Number.isFinite(job.initializationExpiresAtMs)) {
    return job.initializationExpiresAtMs;
  }
  // Existing reservations predate explicit deadlines.
  const created = job.createdAt;
  const createdMs = created && typeof created.toMillis === "function" ?
    created.toMillis() : typeof created === "number" ? created : NaN;
  return Number.isFinite(createdMs) ?
    createdMs + INITIALIZATION_TIMEOUT_MS : null;
}

function canFinalizeInitialization(job, runId, now) {
  const expires = initializationExpiresAtMs(job);
  return job.runId === runId && job.status === "initializing" &&
    !job.done && expires != null && expires > now;
}

function recoveryDecision(job, now) {
  if (!job.runId || job.done) return "ignore";
  if (job.status === "initializing") {
    const expires = initializationExpiresAtMs(job);
    return expires != null && expires <= now ?
      "block-initialization" : "ignore";
  }
  if (!job.initialized ||
      !["queued", "running", "error"].includes(job.status)) return "ignore";
  if (job.status === "running" && job.activeClassIndex != null) {
    if (!Number.isFinite(job.leaseExpiresAtMs) ||
        job.leaseExpiresAtMs > now) return "ignore";
  } else if (job.pendingDispatch) {
    return (job.dispatchFailureCount || 0) >= MAX_RECOVERIES ?
      "block" : "dispatch";
  } else if (job.status !== "error" &&
      now - (job.lastDispatchAtMs || job.lastProgressAtMs || now) <
      STALLED_MS) {
    return "ignore";
  }
  return (job.recoveryCount || 0) >= MAX_RECOVERIES ? "block" : "recover";
}

module.exports = {recoveryDecision, STALLED_MS, MAX_RECOVERIES,
  INITIALIZATION_TIMEOUT_MS, initializationExpiresAtMs,
  canFinalizeInitialization};
