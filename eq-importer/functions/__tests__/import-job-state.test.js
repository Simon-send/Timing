"use strict";

const {claimDecision, ownsLease} = require("../import-job-state");

const request = {eventId: 83302, classCount: 1, classIndex: 59, runId: "new"};
const queued = {
  eventId: 83302, classCount: 1, nextClassIndex: 59,
  status: "queued", runId: "new",
};

test("old tasks cannot claim a new run", () => {
  expect(claimDecision(queued, {...request, runId: "old"}, 100))
      .toBe("obsolete");
  expect(claimDecision(queued, {...request, runId: undefined}, 100))
      .toBe("obsolete");
});

test("duplicate deliveries of completed work are acknowledged", () => {
  expect(claimDecision(queued, {...request, classIndex: 58}, 100))
      .toBe("complete");
});

test("a lock is recoverable only after its expiry", () => {
  const running = {...queued, status: "running", activeClassIndex: 59,
    leaseExpiresAtMs: 200};
  expect(claimDecision(running, request, 199)).toBe("busy");
  expect(claimDecision(running, request, 200)).toBe("claim");
  expect(claimDecision({...running, leaseExpiresAtMs: undefined}, request, 300))
      .toBe("legacy-lock");
});

test("a queued legacy job can proceed but a future chunk cannot", () => {
  expect(claimDecision({...queued, runId: undefined}, request, 100))
      .toBe("claim");
  expect(claimDecision(queued, {...request, classIndex: 60}, 100))
      .toBe("out-of-order");
});

test("only the current owner in the same run can finish or report failure", () => {
  const job = {...queued, leaseOwner: "owner-2"};
  expect(ownsLease(job, "owner-1", "new")).toBe(false);
  expect(ownsLease(job, "owner-2", "old")).toBe(false);
  expect(ownsLease(job, "owner-2", "new")).toBe(true);
});
