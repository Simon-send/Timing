"use strict";
/* eslint-disable require-jsdoc */
jest.mock("node:child_process", () => ({execFileSync: jest.fn()}));
const {execFileSync} = require("node:child_process");
const {parseArgs, resumeRequest, buildInspectionReport, inspectionHelp, main} =
  require("../scripts/import-operations");

test("inspection is read only by default", () => {
  expect(parseArgs(["--event=83302"]).resume).toBe(false);
  expect(() => parseArgs(["--event=83302", "--resume"])).toThrow("--run");
});

test("resumption requires the exact terminal run", () => {
  const options = {eventId: 83302, runId: "run"};
  const job = {eventId: 83302, runId: "run", manifestVersion: 1, initialized: true,
    status: "partial"};
  expect(resumeRequest(options, job)).toEqual({eventId: 83302,
    resumeRunId: "run", classCount: 1});
  expect(() => resumeRequest(options, {...job, status: "running"})).toThrow();
  expect(() => resumeRequest(options, {...job, runId: "new"})).toThrow();
});

async function inspectFixture(job) {
  const originalFetch = global.fetch;
  const log = jest.spyOn(console, "log").mockImplementation(() => {});
  const request = jest.fn().mockResolvedValue({
    ok: true, json: async () => job,
  });
  global.fetch = request;
  execFileSync.mockReturnValue("local-test-token");
  try {
    await main(["--event=83302"]);
    expect(request).toHaveBeenCalledTimes(1);
    expect(request).toHaveBeenCalledWith(
      expect.stringContaining("getImportStatus?jobId=event-83302"),
      expect.objectContaining({method: "GET"}),
    );
    return {report: JSON.parse(log.mock.calls[0][0]),
      help: log.mock.calls[1][0]};
  } finally {
    global.fetch = originalFetch;
    log.mockRestore();
    execFileSync.mockReset();
  }
}

test.each(["queued", "done"])(
  "legacy %s CLI output preserves recovery fields and warns about coverage",
  async (status) => {
    const job = {eventId: 83302, status, done: status === "done",
      nextClassIndex: 0, classCount: 1, lastError: "Local legacy error"};
    const {report, help} = await inspectFixture(job);
    expect(report).toMatchObject({...job, coverageVerified: false,
      unresolved: []});
    expect(help).toContain("coverage is unverified");
    expect(help).toContain("Resume is unsupported");
    expect(help).toContain("nextClassIndex and queue state");
    expect(help).not.toContain("--resume");
  },
);

test.each([
  {manifestVersion: 1},
  {manifestVersion: 1, runId: ""},
  {runId: "run"},
  {manifestVersion: 2, runId: "run"},
])("unsupported manifest/run cannot imply verified coverage: %j", (fields) => {
  const job = {eventId: 83302, status: "partial", ...fields};
  expect(buildInspectionReport(job, [])).toMatchObject({
    coverageVerified: false, unresolved: [],
  });
  expect(inspectionHelp(job)).toContain("Resume is unsupported");
  expect(inspectionHelp(job)).not.toContain("--resume");
});

test.each(["partial", "blocked", "error"])(
  "manifest %s inspection preserves targets and valid resume help",
  async (status) => {
    const job = {eventId: 83302, runId: "run", manifestVersion: 1, initialized: true,
      status, done: false, targetCount: 2, completedTargetCount: 1,
      failedTargetCount: 1, targets: [{id: "done", status: "done"},
        {id: "failed", status: "failed"}]};
    const {report, help} = await inspectFixture(job);
    expect(report).toEqual({eventId: 83302, runId: "run", status,
      done: false, targetCount: 2, completedTargetCount: 1,
      failedTargetCount: 1, unresolved: [{id: "failed", status: "failed"}]});
    expect(report).not.toHaveProperty("coverageVerified");
    expect(help).toContain("--resume and --run");
  },
);

test.each(["initializing", "queued", "running", "done"])(
  "manifest %s inspection does not advertise resumption", (status) => {
    const help = inspectionHelp({manifestVersion: 1, runId: "run", status});
    expect(help).toContain("not currently resumable");
    expect(help).not.toContain("--resume");
  },
);


test("incomplete initialization cannot resume even with a complete target list", () => {
  const job = {eventId: 83302, runId: "run", manifestVersion: 1,
    status: "blocked", initialized: false, targetCount: 1};
  expect(() => resumeRequest({eventId: 83302, runId: "run"}, job)).toThrow();
  expect(inspectionHelp(job)).toContain("Initialization is incomplete");
  expect(inspectionHelp(job)).not.toContain("--resume");
});

test("CLI rejects repeated offsets instead of looping on a partial manifest", async () => {
  const originalFetch = global.fetch;
  const log = jest.spyOn(console, "log").mockImplementation(() => {});
  const job = {eventId: 83302, runId: "run", manifestVersion: 1,
    status: "blocked", initialized: false, targetCount: 2, nextOffset: 1};
  const request = jest.fn().mockResolvedValueOnce({ok: true, json: async () => ({
    ...job, targets: [{id: "one", status: "queued"}],
  })}).mockResolvedValueOnce({ok: true, json: async () => ({...job, targets: []})});
  global.fetch = request;
  execFileSync.mockReturnValue("local-test-token");
  try {
    await expect(main(["--event=83302"])).rejects.toThrow("did not advance");
    expect(request).toHaveBeenCalledTimes(2);
  } finally {
    global.fetch = originalFetch;
    log.mockRestore();
    execFileSync.mockReset();
  }
});

test("incomplete manifest inspection reports missing coverage", async () => {
  const job = {eventId: 83302, runId: "run", manifestVersion: 1,
    status: "blocked", initialized: false, targetCount: 2,
    targets: [{id: "one", status: "queued"}], nextOffset: null};
  const {report, help} = await inspectFixture(job);
  expect(report).toMatchObject({coverageVerified: false, observedTargetCount: 1});
  expect(help).toContain("Initialization is incomplete");
});
