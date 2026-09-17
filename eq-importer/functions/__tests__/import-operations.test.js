"use strict";
const {parseArgs, resumeRequest} = require("../scripts/import-operations");

test("inspection is read only by default", () => {
  expect(parseArgs(["--event=83302"]).resume).toBe(false);
  expect(() => parseArgs(["--event=83302", "--resume"])).toThrow("--run");
});

test("resumption requires the exact terminal run", () => {
  const options = {eventId: 83302, runId: "run"};
  const job = {eventId: 83302, runId: "run", manifestVersion: 1,
    status: "partial"};
  expect(resumeRequest(options, job)).toEqual({eventId: 83302,
    resumeRunId: "run", classCount: 1});
  expect(() => resumeRequest(options, {...job, status: "running"})).toThrow();
  expect(() => resumeRequest(options, {...job, runId: "new"})).toThrow();
});
