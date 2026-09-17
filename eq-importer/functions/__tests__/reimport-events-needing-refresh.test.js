"use strict";

const {
  classAthleteCount,
  missingBiathlonRanks,
  selectPrimaryStage,
} = require("../scripts/reimport-events-needing-refresh");

describe("reimport event scanner", () => {
  test("selects the highest participant count with stable stage priority", () => {
    const stages = [
      {
        stage: {id: "late", data: {level: 2, order: 1}},
        classData: {participantCount: 12, resultCount: 12},
      },
      {
        stage: {id: "first", data: {level: 1, order: 0}},
        classData: {participantCount: 12, resultCount: 12},
      },
      {
        stage: {id: "small", data: {level: 1, order: 0}},
        classData: {participantCount: 4, resultCount: 20},
      },
    ];

    expect(selectPrimaryStage(stages).stage.id).toBe("first");
    expect(classAthleteCount(stages[2].classData)).toBe(4);
  });

  test("flags only finished biathlon results missing persisted ranks", () => {
    expect(missingBiathlonRanks({
      status: "TIME",
      analysisSummary: {
        biathlon: {
          metrics: {skiTimeMs: 500000, skiRank: 1},
          passes: {shoot1: {rangeMs: 30000, rangeRank: 1}},
        },
      },
    })).toEqual([]);

    expect(missingBiathlonRanks({
      status: "TIME",
      analysisSummary: {
        biathlon: {
          metrics: {skiTimeMs: 500000},
          passes: {shoot1: {rangeMs: 30000}},
        },
      },
    })).toEqual(["skiRank", "rangeRank"]);

    expect(missingBiathlonRanks({
      status: "DNF",
      analysisSummary: {
        biathlon: {
          metrics: {skiTimeMs: 500000},
          passes: {shoot1: {rangeMs: 30000}},
        },
      },
    })).toEqual([]);
  });
});
