"use strict";

const {
  buildAthleteUpdate,
  buildResultUpdate,
  isOfficialResultPath,
  parseArgs,
} = require("../scripts/scrub-public-sensitive-fields");

describe("public sensitive field cleanup", () => {
  const deleted = Symbol("deleted");

  test("is a dry run by default and requires exact apply confirmation", () => {
    expect(parseArgs([])).toMatchObject({
      apply: false,
      projectId: "time-plotting",
    });
    expect(() => parseArgs([
      "--apply",
      "--project=time-plotting",
    ])).toThrow("--confirm-project");
    expect(parseArgs([
      "--apply",
      "--project=time-plotting",
      "--confirm-project=time-plotting",
    ]).apply).toBe(true);
  });

  test("deletes only sensitive athlete fields", () => {
    expect(buildAthleteUpdate({
      displayName: "Ada Lovelace",
      source: {provider: "eqtiming"},
      gender: "F",
      birthYear: 1815,
      age: 17,
    }, deleted)).toEqual({
      source: deleted,
      gender: deleted,
      birthYear: deleted,
      age: deleted,
    });
  });

  test("deletes result registration data and nested relay source ids", () => {
    expect(buildResultUpdate({
      name: "Oslo lag 1",
      registration: {paid: true},
      timingIds: [123],
      team: {
        members: [
          {name: "Ada", athleteId: "athlete:1", athleteSourceUid: 1},
          {name: "Grace", athleteId: "athlete:2"},
        ],
      },
    }, deleted)).toEqual({
      "registration": deleted,
      "timingIds": deleted,
      "team.members": [
        {name: "Ada", athleteId: "athlete:1"},
        {name: "Grace", athleteId: "athlete:2"},
      ],
    });
  });

  test("only accepts official v2 and v3 event result paths", () => {
    expect(isOfficialResultPath(
        "events/1/classes/2/results/3",
    )).toBe(true);
    expect(isOfficialResultPath(
        "events/1/stages/2/classes/3/results/4",
    )).toBe(true);
    expect(isOfficialResultPath(
        "users/1/archive/2/classes/3/results/4",
    )).toBe(false);
  });
});
