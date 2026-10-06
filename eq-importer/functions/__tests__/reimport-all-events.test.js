"use strict";

/* eslint-disable require-jsdoc */

const {parseArgs, listEventIds, idChecksum, checkJobs, verifyCompletedTargets,
  runImports} = require("../scripts/reimport-all-events");

function makeDb(ids, jobs = {}) {
  return {
    collection: () => ({select: () => ({get: async () => ({
      docs: ids.map((id) => ({id: String(id)})),
    })})}),
    doc(path) {
      const id = Number(path.split("event-")[1]);
      return {
        get: async () => ({exists: !!jobs[id], data: () => jobs[id]}),
        collection: () => ({doc: () => ({collection: () => ({
          get: async () => ({size: 1, docs: [{data: () => ({status: "done"})}]}),
        })})}),
      };
    },
  };
}

test("bulk import defaults to read-only and requires explicit confirmation", () => {
  expect(parseArgs(["--project=time-plotting"]).run).toBe(false);
  expect(() => parseArgs(["--run", "--project=time-plotting"]))
      .toThrow(/confirm-count/);
  expect(() => parseArgs(["--run", "--project=time-plotting",
    "--confirm-count=0"])).toThrow(/confirm-count/);
  expect(() => parseArgs(["--run", "--project=time-plotting",
    "--confirm-count=2"])).toThrow(/confirm-ids/);
  expect(parseArgs(["--run", "--project=time-plotting",
    "--confirm-count=2", `--confirm-ids=${idChecksum([2, 3])}`]))
      .toMatchObject({confirmCount: 2, confirmIds: idChecksum([2, 3])});
});

test("event inventory is numeric and sorted", async () => {
  await expect(listEventIds(makeDb([9, 2]))).resolves.toEqual([2, 9]);
  await expect(listEventIds(makeDb(["test"]))).rejects.toThrow(/Unsafe/);
});

test("active jobs stop the whole batch", async () => {
  await expect(checkJobs(makeDb([2], {2: {status: "queued"}}), [2]))
      .rejects.toThrow(/active import/);
});

test("completion requires persisted run and fully done manifest", async () => {
  const job = {runId: "run", status: "done", done: true,
    manifestVersion: 1, targetCount: 1, completedTargetCount: 1,
    failedTargetCount: 0};
  await expect(verifyCompletedTargets(makeDb([2]), 2, "run", job))
      .resolves.toBe(1);
  await expect(verifyCompletedTargets(makeDb([2]), 2, "other", job))
      .rejects.toThrow(/incomplete/);
});

test("count mismatch stops before access probe or imports", async () => {
  const verifyAccess = jest.fn();
  const startImport = jest.fn();
  await expect(runImports(makeDb([2]), [2], {
    project: "time-plotting", confirmCount: 3, confirmIds: idChecksum([2]),
  }, {verifyAccess, startImport})).rejects.toThrow(/list changed/);
  expect(verifyAccess).not.toHaveBeenCalled();
  expect(startImport).not.toHaveBeenCalled();
});

test("changed IDs with the same count also stop before import", async () => {
  const startImport = jest.fn();
  await expect(runImports(makeDb([2, 4]), [2, 4], {
    project: "time-plotting", confirmCount: 2,
    confirmIds: idChecksum([2, 3]),
  }, {startImport})).rejects.toThrow(/list changed/);
  expect(startImport).not.toHaveBeenCalled();
});

test("imports run sequentially and stop at the first failed coverage", async () => {
  const startImport = jest.fn(async () => "run");
  const waitForRun = jest.fn(async () => ({runId: "run", status: "done",
    done: true, manifestVersion: 1, targetCount: 1,
    completedTargetCount: 1, failedTargetCount: 0}));
  await runImports(makeDb([2, 3]), [2, 3], {project: "time-plotting",
    confirmCount: 2, confirmIds: idChecksum([2, 3])},
  {assertQueueRunning: () => {},
    verifyAccess: async () => {}, startImport, waitForRun});
  expect(startImport.mock.calls.map((call) => call[1])).toEqual([2, 3]);
});
