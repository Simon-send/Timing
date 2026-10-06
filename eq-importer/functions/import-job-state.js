"use strict";

/* eslint-disable require-jsdoc */

const LEASE_MS = 11 * 60 * 1000;

function claimDecision(job, request, now) {
  if (job.runId && job.runId !== request.runId) return "obsolete";
  if (job.runId && (job.dispatchGeneration || 0) !==
      (request.dispatchGeneration || 0)) return "obsolete";
  if (job.status === "blocked" || job.status === "partial" ||
      job.status === "initializing") return "complete";
  if (Number(job.eventId) !== request.eventId ||
      Number(job.classCount) !== request.classCount) return "mismatch";
  if (job.done || job.status === "done") return "complete";
  const next = Number(job.nextClassIndex);
  if (!Number.isInteger(next)) return "mismatch";
  if (request.classIndex < next) return "complete";
  if (request.classIndex !== next) return "out-of-order";
  if (job.status === "running" && job.activeClassIndex != null) {
    // Missing expiry belongs to a legacy worker; never steal its lock.
    if (!Number.isFinite(job.leaseExpiresAtMs)) return "legacy-lock";
    if (now < job.leaseExpiresAtMs) return "busy";
  }
  return "claim";
}

function ownsLease(job, owner, runId) {
  return job.leaseOwner === owner && (job.runId || null) === (runId || null);
}

module.exports = {LEASE_MS, claimDecision, ownsLease};
