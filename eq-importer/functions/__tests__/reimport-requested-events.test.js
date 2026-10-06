"use strict";

const {
  EVENT_IDS,
  parseFunctionCallOutput,
  parseArgs,
} = require("../scripts/reimport-requested-events");

describe("requested reimport script", () => {
  test("keeps the requested event IDs and defaults to a dry run", () => {
    expect(EVENT_IDS).toEqual([
      79178,
      79179,
      80090,
      80091,
      80093,
      80114,
      81337,
    ]);
    expect(parseArgs([]).enqueue).toBe(false);
    expect(parseArgs(["--enqueue"]).enqueue).toBe(true);
    expect(parseArgs([]).projectId).toBe("time-plotting");
  });

  test("reads the result returned by gcloud functions call", () => {
    expect(parseFunctionCallOutput(JSON.stringify({
      executionId: "execution",
      result: JSON.stringify({ok: true, jobId: "event-79178", status: "queued"}),
    }))).toEqual({ok: true, jobId: "event-79178", status: "queued"});
  });
});
