"use strict";

const {recoveryDecision, STALLED_MS, INITIALIZATION_TIMEOUT_MS,
  canFinalizeInitialization} = require("../import-recovery");
const {claimDecision} = require("../import-job-state");
const queued = {runId: "run", initialized: true, status: "queued",
  lastDispatchAtMs: 1};

test("repairs missing dispatch but leaves active work alone", () => {
  expect(recoveryDecision({...queued, pendingDispatch: {}}, 10)).toBe("dispatch");
  expect(recoveryDecision(queued, 10)).toBe("ignore");
  expect(recoveryDecision(queued, STALLED_MS + 2)).toBe("recover");
  expect(recoveryDecision({...queued, status: "running", activeClassIndex: 0,
    leaseExpiresAtMs: 100}, 99)).toBe("ignore");
  expect(recoveryDecision({...queued, status: "running", activeClassIndex: 0,
    leaseExpiresAtMs: 100}, 100)).toBe("recover");
});

test("stops automatic retries and does not upgrade legacy jobs", () => {
  expect(recoveryDecision({...queued, pendingDispatch: {},
    dispatchFailureCount: 3}, 10)).toBe("block");
  expect(recoveryDecision({...queued, recoveryCount: 3}, STALLED_MS + 2))
      .toBe("block");
  expect(recoveryDecision({...queued, runId: undefined}, STALLED_MS + 2))
      .toBe("ignore");
  expect(recoveryDecision({...queued, status: "partial"}, STALLED_MS + 2))
      .toBe("ignore");
});

test("tasks superseded by recovery cannot run", () => {
  const job = {...queued, dispatchGeneration: 2, eventId: 1,
    classCount: 1, nextClassIndex: 0};
  expect(claimDecision(job, {runId: "run", dispatchGeneration: 1,
    eventId: 1, classCount: 1, classIndex: 0}, 100)).toBe("obsolete");
});

test("initialization expires without ever dispatching a partial manifest", () => {
  const job = {runId: "run", status: "initializing", done: false,
    initialized: false, initializationExpiresAtMs: 100};
  expect(recoveryDecision(job, 99)).toBe("ignore");
  expect(recoveryDecision(job, 100)).toBe("block-initialization");
  expect(canFinalizeInitialization(job, "run", 99)).toBe(true);
  expect(canFinalizeInitialization(job, "run", 100)).toBe(false);
  expect(canFinalizeInitialization({...job, status: "blocked"}, "run", 99))
      .toBe(false);
  expect(canFinalizeInitialization(job, "old-run", 99)).toBe(false);
});

test("older initializing jobs use their stored creation time", () => {
  const job = {runId: "run", status: "initializing",
    createdAt: {toMillis: () => 0}};
  expect(recoveryDecision(job, INITIALIZATION_TIMEOUT_MS - 1)).toBe("ignore");
  expect(recoveryDecision(job, INITIALIZATION_TIMEOUT_MS))
      .toBe("block-initialization");
  expect(recoveryDecision({...job, createdAt: undefined}, Infinity))
      .toBe("ignore");
  expect(recoveryDecision({...job, done: true}, INITIALIZATION_TIMEOUT_MS))
      .toBe("ignore");
});
