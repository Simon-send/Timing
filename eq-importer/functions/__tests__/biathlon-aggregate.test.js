"use strict";

/* eslint-disable require-jsdoc */

const {buildBiathlonAggregates, compatibilityTopHalf} =
  require("../biathlon-aggregate");

const defs = {
  a: {code: "INS1", label: "Inn skyting 1", sort: 1},
  b: {code: "MAL", label: "Mål", sort: 2},
};

function result(id, totalMs, overrides = {}) {
  return {
    id, totalMs, status: "", isBiathlon: true, isRelay: false,
    entrant: {kind: "athlete"},
    timingPoints: [
      {setupUid: "a", code: "INS1", cumMs: 300, legMs: 300, cumRank: 1},
      {setupUid: "b", code: "MAL", cumMs: totalMs, legMs: 300},
    ],
    analysisSummary: {biathlon: {
      metrics: {skiTimeMs: 400, shootingTimeMs: 50, shootingCount: 2},
      passes: {
        shoot1: {index: 1, position: "prone", misses: 0,
          rangeMs: 20, penaltyMs: 0},
        shoot2: {index: 2, position: "standing", misses: 1,
          rangeMs: 30, penaltyMs: 5},
      },
      laps: {lap1: {index: 1, skiMs: 300, startCumMs: 0,
        endCumMs: 300, beforeShooting: 1}},
    }},
    ...overrides,
  };
}

test("odd and even cohorts use finish time and stable ID tie-break", () => {
  const rows = [result("z", 1000), result("b", 900), result("a", 900),
    result("c", 1200), result("d", 1300)];
  const profiles = buildBiathlonAggregates(rows, defs);
  expect(profiles.all.cohortCount).toBe(5);
  expect(profiles.topHalf.cohortCount).toBe(3);
  expect(profiles.topHalf.metrics.finishTimeMs).toEqual({mean: 2800 / 3,
    count: 3});
  expect(buildBiathlonAggregates(rows.slice(0, 4), defs)
      .topHalf.cohortCount).toBe(2);
  expect(compatibilityTopHalf(profiles.topHalf)).toMatchObject({
    version: 1, finishersCount: 5, cohortCount: 3,
    metrics: {finishTimeMs: profiles.topHalf.metrics.finishTimeMs,
      skiTimeMs: profiles.topHalf.metrics.skiTimeMs},
  });
});

test("finish placement is averaged without treating display order as a rank", () => {
  const rows = [result("a", 800, {finishRank: 1, displayOrder: 99}),
    result("b", 900, {finishRank: 2, displayOrder: 3})];
  const metrics = buildBiathlonAggregates(rows, defs).all.metrics;
  expect(metrics.finishRank).toEqual({mean: 1.5, count: 2});
  expect(metrics.displayOrder).toBeUndefined();
});

test("invalid statuses and teams never enter the cohort", () => {
  const rows = [result("ok", 1000), result("dns", 0, {status: "DNS"}),
    result("dnf", 300, {status: "DNF"}),
    result("dsq", 200, {status: "DSQ"}),
    result("dq", 100, {status: "DQ"}),
    result("team", 50, {isRelay: true})];
  expect(buildBiathlonAggregates(rows, defs).all.finishersCount).toBe(1);
  expect(buildBiathlonAggregates(rows.slice(1), defs)).toBeNull();
});

test("missing metrics and splits reduce counts without becoming zero", () => {
  const second = result("b", 900);
  delete second.analysisSummary.biathlon.metrics.skiTimeMs;
  delete second.analysisSummary.biathlon.metrics.shootingTimeMs;
  second.timingPoints = [{setupUid: "x", code: "INS1", cumMs: 99}];
  const all = buildBiathlonAggregates([result("a", 800), second], defs).all;
  expect(all.metrics.skiTimeMs).toEqual({mean: 400, count: 1});
  expect(all.metrics.shootingTimeMs.count).toBe(1);
  expect(all.timingPoints.a.values.cumMs).toEqual({mean: 300, count: 1});
  expect(all.timingPoints.x).toBeUndefined();
  expect(all.laps["lap1-shoot1"].values.startCumMs)
      .toEqual({mean: 0, count: 2});
});

test("a measured zero split, penalty or miss remains a valid sample", () => {
  const row = result("a", 800);
  row.timingPoints[0].cumMs = 0;
  const profile = buildBiathlonAggregates([row], defs).all;
  expect(profile.timingPoints.a.values.cumMs).toEqual({mean: 0, count: 1});
  expect(profile.shootingPasses["shoot1-prone"].values.misses)
      .toEqual({mean: 0, count: 1});
  expect(profile.shootingPasses["shoot1-prone"].values.penaltyMs)
      .toEqual({mean: 0, count: 1});
});

test("passes stay separate by index and position with decimal misses", () => {
  const first = result("a", 800);
  const second = result("b", 900);
  second.analysisSummary.biathlon.passes.shoot1.misses = 1;
  second.analysisSummary.biathlon.passes.shoot2.misses = 2;
  second.analysisSummary.biathlon.passes.shoot2.position = "prone";
  const all = buildBiathlonAggregates([first, second], defs).all;
  expect(all.shootingPasses["shoot1-prone"].values.misses)
      .toEqual({mean: 0.5, count: 2});
  expect(all.shootingPasses["shoot2-prone"].values.misses)
      .toEqual({mean: 2, count: 1});
  expect(all.shootingPasses["shoot2-standing"].values.misses)
      .toEqual({mean: 1, count: 1});
  expect(all.metrics.totalHitPercent).toEqual({mean: 80, count: 2});
});

test("four shooting rounds retain independent fractional miss averages", () => {
  const rows = Array.from({length: 10}, (_, athlete) => {
    const row = result(String(athlete), 1000 + athlete);
    const misses = [athlete < 5 ? 1 : 0, athlete < 2 ? 2 : 1,
      athlete < 3 ? 2 : 1, 2];
    row.analysisSummary.biathlon.metrics.shootingCount = 4;
    row.analysisSummary.biathlon.passes = Object.fromEntries(misses.map(
        (value, index) => [`shoot${index + 1}`, {index: index + 1,
          position: index < 2 ? "prone" : "standing", misses: value}]));
    return row;
  });
  const passes = buildBiathlonAggregates(rows, defs).all.shootingPasses;
  expect(["shoot1-prone", "shoot2-prone", "shoot3-standing",
    "shoot4-standing"].map((key) => passes[key].values.misses))
      .toEqual([0.5, 1.2, 1.3, 2].map((mean) => ({mean, count: 10})));
});

test("incomplete series excludes hit percentages but keeps individual misses", () => {
  const incomplete = result("b", 900);
  delete incomplete.analysisSummary.biathlon.passes.shoot2;
  const unknown = result("c", 1000);
  unknown.analysisSummary.biathlon.passes.shoot2.position = "unknown";
  const all = buildBiathlonAggregates([
    result("a", 800), incomplete, unknown], defs).all;
  expect(all.metrics.totalHitPercent.count).toBe(2);
  expect(all.metrics.proneHitPercent.count).toBe(1);
  expect(all.shootingPasses["shoot1-prone"].values.misses.count).toBe(3);
  expect(all.shootingPasses["shoot2-standing"].values.misses.count).toBe(1);
});

test("different stages and reimported data produce distinct, fresh profiles", () => {
  const before = buildBiathlonAggregates([result("a", 800)], defs).all;
  const after = buildBiathlonAggregates([result("a", 1000)], defs).all;
  expect(before.metrics.finishTimeMs.mean).toBe(800);
  expect(after.metrics.finishTimeMs.mean).toBe(1000);
  expect(buildBiathlonAggregates([result("other", 2000)], defs)
      .all.metrics.finishTimeMs.mean).toBe(2000);
});

test("laps with different timing boundaries are not averaged together", () => {
  const first = result("a", 800);
  const second = result("b", 900);
  first.analysisSummary.biathlon.laps.lap1.startCode = "US1";
  first.analysisSummary.biathlon.laps.lap1.endCode = "INS2";
  second.analysisSummary.biathlon.laps.lap1.startCode = "UTS1";
  second.analysisSummary.biathlon.laps.lap1.endCode = "INS2";
  const laps = buildBiathlonAggregates([first, second], defs).all.laps;
  expect(Object.keys(laps)).toHaveLength(2);
  expect(Object.values(laps).map((lap) => lap.values.skiMs.count))
      .toEqual([1, 1]);
});
