"use strict";

/* eslint-disable require-jsdoc */

const crypto = require("node:crypto");

// Public, comparable performance fields only. All *Ms values are milliseconds;
// ranks, misses, and percentages are dimensionless.
const METRIC_FIELDS = [
  "skiTimeMs", "netSkiTimeMs", "rangeTimeMs", "shootingTimeMs",
  "penaltyTimeMs", "proneTimeMs", "standingTimeMs", "missesTotal",
  "proneMisses", "standingMisses", "skiRank", "netSkiRank",
  "rangeRank", "shootRank", "penaltyRank",
];
const SPLIT_FIELDS = ["cumMs", "legMs", "cumRank", "legRank"];
const PASS_FIELDS = [
  "misses", "rangeMs", "penaltyMs", "rangeRank", "rangeExitMs",
  "approachCumMs", "inCumMs", "shootingCumMs", "outCumMs",
  "rangeExitCumMs", "cumulativeMisses",
];
const LAP_FIELDS = ["skiMs", "startCumMs", "endCumMs"];
const isFiniteNumber = (value) =>
  typeof value === "number" && Number.isFinite(value);
const nonFinish = (status) => {
  const text = String(status || "");
  return /\b(?:DNS|DNF|DSQ|DQ)\b|DID NOT|IKKE STARTET|STARTET IKKE/i
      .test(text) || /BRUTT|IKKE FULLF|DISQUAL/i.test(text);
};

function positive(value) {
  return isFiniteNumber(value) && value > 0;
}

function add(target, field, value, valid = isFiniteNumber) {
  if (!valid(value)) return;
  const current = target[field] || {sum: 0, count: 0};
  current.sum += value;
  current.count++;
  target[field] = current;
}

function means(values) {
  return Object.fromEntries(Object.entries(values).map(([field, value]) =>
    [field, {mean: value.sum / value.count, count: value.count}]));
}

function hitPercent(passes, expectedCount, position) {
  if (!expectedCount || passes.length !== expectedCount ||
      new Set(passes.map((pass) => pass.index)).size !== expectedCount ||
      passes.some((pass) => !Number.isInteger(pass.index) ||
        pass.index < 1 || pass.index > expectedCount ||
        !Number.isInteger(pass.misses) || pass.misses < 0 ||
        pass.misses > 5)) return null;
  if (position && passes.some((pass) =>
    !["prone", "standing"].includes(pass.position))) return null;
  const selected = position ?
    passes.filter((pass) => pass.position === position) : passes;
  if (!selected.length) return null;
  const missed = selected.reduce((sum, pass) => sum + pass.misses, 0);
  return (1 - missed / (5 * selected.length)) * 100;
}

function sortedPasses(result) {
  const source = result.analysisSummary?.biathlon?.passes || {};
  return Object.entries(source).map(([key, value]) => {
    const index = Number(value?.index || /^shoot(\d+)$/.exec(key)?.[1]);
    const position = String(value?.position || "").toLowerCase();
    return {...value, index, position};
  }).filter((pass) => Number.isInteger(pass.index) && pass.index > 0);
}

function buildOne(kind, finishers, cohort, splitDefs, expectedShootingCount) {
  const metricValues = {};
  const splits = {};
  const shootingPasses = {};
  const laps = {};
  for (const result of cohort) {
    const analysis = result.analysisSummary?.biathlon || {};
    const metrics = analysis.metrics || {};
    add(metricValues, "finishTimeMs", result.totalMs, positive);
    add(metricValues, "finishRank", result.finishRank);
    for (const field of METRIC_FIELDS) {
      const valid = ["skiTimeMs", "netSkiTimeMs", "rangeTimeMs",
        "shootingTimeMs", "proneTimeMs", "standingTimeMs"].includes(field) ?
        positive : isFiniteNumber;
      add(metricValues, field, metrics[field], valid);
    }
    const passes = sortedPasses(result);
    add(metricValues, "totalHitPercent",
        hitPercent(passes, expectedShootingCount));
    add(metricValues, "proneHitPercent",
        hitPercent(passes, expectedShootingCount, "prone"));
    add(metricValues, "standingHitPercent",
        hitPercent(passes, expectedShootingCount, "standing"));
    for (const point of result.timingPoints || []) {
      const id = String(point?.setupUid || "");
      const def = splitDefs[id];
      if (!id || !def || (point.code && def.code &&
        String(point.code) !== String(def.code))) continue;
      const entry = splits[id] || (splits[id] = {
        code: def.code, sort: def.sort, label: def.label || def.code,
        values: {},
      });
      for (const field of SPLIT_FIELDS) {
        add(entry.values, field, point[field], field.endsWith("Ms") ?
          (value) => isFiniteNumber(value) && value >= 0 : isFiniteNumber);
      }
    }
    for (const pass of passes) {
      const key = `shoot${pass.index}-${pass.position || "unknown"}`;
      const entry = shootingPasses[key] || (shootingPasses[key] = {
        index: pass.index, position: pass.position || "unknown", values: {},
      });
      for (const field of PASS_FIELDS) {
        add(entry.values, field, pass[field]);
      }
    }
    for (const [key, lap] of Object.entries(analysis.laps || {})) {
      const index = Number(lap.index || /^lap(\d+)$/.exec(key)?.[1]);
      if (!Number.isInteger(index) || index < 1) continue;
      const boundary = lap.beforeShooting == null ? "finish" :
        `shoot${lap.beforeShooting}`;
      const startCode = String(lap.startCode || "");
      const endCode = String(lap.endCode || "");
      const codeKey = startCode || endCode ? `-${crypto.createHash("sha256")
          .update(JSON.stringify([startCode, endCode])).digest("hex")
          .slice(0, 12)}` : "";
      const stableKey = `lap${index}-${boundary}${codeKey}`;
      const entry = laps[stableKey] || (laps[stableKey] = {
        index, beforeShooting: lap.beforeShooting ?? null,
        startCode, endCode, values: {},
      });
      for (const field of LAP_FIELDS) add(entry.values, field, lap[field]);
    }
  }
  for (const section of [splits, shootingPasses, laps]) {
    for (const entry of Object.values(section)) {
      entry.values = means(entry.values);
    }
  }
  return {schemaVersion: 1, kind, finishersCount: finishers.length,
    cohortCount: cohort.length, metrics: means(metricValues),
    timingPoints: splits, shootingPasses, laps};
}

function buildBiathlonAggregates(results, splitDefs = {}) {
  const finishers = results.filter((row) => row.isBiathlon === true &&
      row.isRelay !== true && row.entrant?.kind !== "team" &&
      !nonFinish(row.status) && positive(row.totalMs))
      .slice().sort((left, right) => left.totalMs - right.totalMs ||
        String(left.id).localeCompare(String(right.id)));
  if (!finishers.length) return null;
  let expectedShootingCount = 0;
  for (const row of finishers) {
    const declared = Number(row.analysisSummary?.biathlon?.metrics
        ?.shootingCount);
    if (Number.isInteger(declared) && declared > expectedShootingCount) {
      expectedShootingCount = declared;
    }
    for (const pass of sortedPasses(row)) {
      expectedShootingCount = Math.max(expectedShootingCount, pass.index);
    }
  }
  return {
    all: buildOne("biathlon-all", finishers, finishers, splitDefs,
        expectedShootingCount),
    topHalf: buildOne("biathlon-top-half", finishers,
        finishers.slice(0, Math.ceil(finishers.length / 2)), splitDefs,
        expectedShootingCount),
  };
}

function compatibilityTopHalf(profile) {
  if (!profile) return null;
  const names = ["finishTimeMs", "skiTimeMs", "shootingTimeMs",
    "proneHitPercent", "standingHitPercent", "totalHitPercent"];
  return {version: 1, finishersCount: profile.finishersCount,
    cohortCount: profile.cohortCount,
    metrics: Object.fromEntries(names.filter((name) => profile.metrics[name])
        .map((name) => [name, profile.metrics[name]]))};
}

module.exports = {buildBiathlonAggregates, compatibilityTopHalf};
