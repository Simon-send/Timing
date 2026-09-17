"use strict";

/* eslint-disable require-jsdoc */
const STALLED_MS = 15 * 60 * 1000;
const MAX_RECOVERIES = 3;

function recoveryDecision(job, now) {
  if (!job.runId || !job.initialized || job.done ||
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

module.exports = {recoveryDecision, STALLED_MS, MAX_RECOVERIES};
