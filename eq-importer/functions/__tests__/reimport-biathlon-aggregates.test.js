"use strict";

/* eslint-disable require-jsdoc */

const {buildBiathlonAggregates} = require("../biathlon-aggregate");
const {EVENT_IDS, parseArgs, selectedEvents, validateAggregate,
  verifyProfiles, parseStartImportResponse, startImport, verifiedExistingRun} =
  require("../scripts/reimport-biathlon-aggregates");

const RUN_ID = "d6650811-5aa5-4bfb-a463-90c460b6d5a5";

function startDb(overrides = {}) {
  const job = {jobId: "event-79182", eventId: 79182, runId: RUN_ID,
    classCount: 1, manifestVersion: 1, targetCount: 12, status: "queued",
    ...overrides};
  return {doc: () => ({get: async () => ({exists: true,
    data: () => job})})};
}

test("start response accepts gcloud envelopes and JSON strings", () => {
  const response = {ok: true, jobId: "event-79182", eventId: "79182",
    runId: RUN_ID};
  expect(parseStartImportResponse(JSON.stringify({result:
    JSON.stringify(response)}))).toEqual(response);
  expect(parseStartImportResponse(JSON.stringify({response:
    JSON.stringify(JSON.stringify(response))}))).toEqual(response);
});

test("start confirms the persisted run before following it", async () => {
  const invoke = jest.fn(() => JSON.stringify({result: JSON.stringify({
    ok: true, jobId: "event-79182", eventId: "79182", runId: RUN_ID,
  })}));
  await expect(startImport(startDb(), 79182, "time-plotting", null,
      invoke)).resolves.toBe(RUN_ID);
  expect(invoke).toHaveBeenCalledTimes(1);
  expect(invoke.mock.calls[0][0]).toContain("--project=time-plotting");
  await expect(startImport(startDb({runId: "different"}), 79182,
      "time-plotting", null, invoke)).rejects.toThrow(/does not match/);
  await expect(startImport(startDb(), 79182, "time-plotting", RUN_ID,
      invoke)).rejects.toThrow(/unexpected start response/);
});

test("ambiguous start response fails closed without leaking raw output", async () => {
  const output = "secret-body";
  await expect(startImport(startDb(), 79182, "time-plotting", null,
      () => output)).rejects.toThrow(/may have started/);
  try {
    await startImport(startDb(), 79182, "time-plotting", null,
        () => output);
  } catch (error) {
    expect(error.message).not.toContain(output);
  }
});

test("existing run is not skipped unless profiles are verified", async () => {
  const job = {status: "done", done: true, manifestVersion: 1,
    runId: RUN_ID, targetCount: 1, completedTargetCount: 1,
    failedTargetCount: 0};
  await expect(verifiedExistingRun(startDb(), 79182, {...job,
    completedTargetCount: 0})).resolves.toBeNull();
});

test("the reviewed event list includes 79181, not 97181", () => {
  expect(EVENT_IDS).toHaveLength(19);
  expect(new Set(EVENT_IDS).size).toBe(EVENT_IDS.length);
  expect(EVENT_IDS).toContain(79181);
  expect(EVENT_IDS).not.toContain(97181);
});

test("dry run is default and production needs an explicit project", () => {
  expect(parseArgs([]).run).toBe(false);
  expect(() => parseArgs(["--run"])).toThrow(/explicit --project/);
  expect(parseArgs(["--run", "--project=time-plotting"])).toMatchObject({
    run: true, project: "time-plotting",
  });
  expect(() => parseArgs(["--from=97181"])).toThrow(/--from/);
  expect(selectedEvents(parseArgs(["--from=80114"])))
      .toEqual([80114, 83291, 83309]);
});

test("aggregate verifier rejects missing, stale and changed values", () => {
  const expected = {finishersCount: 3, cohortCount: 2,
    metrics: {finishTimeMs: {mean: 900, count: 2},
      skiTimeMs: {mean: 700, count: 1}}};
  const actual = {schemaVersion: 1, kind: "biathlon-top-half",
    finishersCount: 3, cohortCount: 2,
    metrics: {finishTimeMs: {mean: 900, count: 2},
      skiTimeMs: {mean: 700, count: 1}}};
  expect(validateAggregate(actual, expected, "biathlon-top-half")).toBe(true);
  expect(validateAggregate(null, expected, "biathlon-top-half")).toBe(false);
  expect(validateAggregate({...actual, cohortCount: 3}, expected,
      "biathlon-top-half")).toBe(false);
  expect(validateAggregate({...actual, metrics: {
    ...actual.metrics, skiTimeMs: {mean: 701, count: 1},
  }}, expected, "biathlon-top-half")).toBe(false);
});

test("event verification requires every target and both profiles", async () => {
  const row = {id: "a", isBiathlon: true, isRelay: false,
    totalMs: 1000, status: "TIME", analysisSummary: {biathlon: {
      metrics: {skiTimeMs: 800},
    }}};
  const profiles = buildBiathlonAggregates([row]);
  const classPath = "events/123/stages/456/classes/789";
  const makeDb = (topExists) => ({
    doc(path) {
      if (path === "importJobs/event-123") {
        return {
        collection: () => ({doc: () => ({collection: () => ({
          get: async () => ({size: 1, docs: [{
            data: () => ({stageId: "456", classId: "789", status: "done"}),
          }]}),
        })})}),
        };
      }
      if (path !== classPath) {
        throw new Error("Unexpected path");
      }
      return {
        get: async () => ({exists: true, data: () => ({
          isBiathlon: true, isRelay: false,
        })}),
        collection(name) {
          if (name === "results") {
            return {get: async () => ({
              docs: [{id: row.id, data: () => row}],
            })};
          }
          if (name === "aggregateProfiles") {
            return {doc: (id) => ({
            get: async () => {
              const exists = id === "biathlon-all" || topExists;
              return {exists, data: () => exists ?
                (id === "biathlon-all" ? profiles.all : profiles.topHalf) :
                undefined};
            },
            })};
          }
          throw new Error("Unexpected collection");
        },
      };
    },
  });
  await expect(verifyProfiles(makeDb(true), 123, "run", 1))
      .resolves.toMatchObject({expectedProfiles: 2, verifiedClasses: 1});
  await expect(verifyProfiles(makeDb(false), 123, "run", 1))
      .rejects.toThrow(/missing or outdated profiles/);
  await expect(verifyProfiles(makeDb(true), 123, "run", 2))
      .rejects.toThrow(/target manifest/);
});
