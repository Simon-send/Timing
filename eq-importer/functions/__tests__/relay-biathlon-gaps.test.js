"use strict";
/* eslint-disable require-jsdoc */
jest.mock("firebase-functions/v2/https", () => ({
  onRequest: jest.fn((options, handler) => handler),
}));
jest.mock("firebase-functions/v2/scheduler", () => ({
  onSchedule: jest.fn((options, handler) => handler),
}));
jest.mock("firebase-admin", () => ({
  initializeApp: jest.fn(() => {
    throw new Error("No Firebase in pure test");
  }),
}));
jest.mock("firebase-admin/firestore", () => ({FieldValue: {}}));
jest.mock("axios", () => ({get: jest.fn(() => {
  throw new Error("No network in pure test");
})}));
jest.mock("@google-cloud/tasks", () => ({CloudTasksClient: jest.fn(() => {
  throw new Error("No Cloud Tasks in pure test");
})}));

const {buildRelayLegBiathlon, sanitizeForFirestore} = require("../index")._test;
const clientFixture = require("../../../results/test/fixtures/relay_biathlon_unknown_start.json");

function leg(number, sort, inMs, outMs, endMs) {
  return {
    [`l${number}-in`]: {code: "INS1", kind: "rangeIn", sort,
      legNumber: number, cumMs: inMs, legMs: 12000, additionParts: [1]},
    [`l${number}-out`]: {code: "UTS1", kind: "rangeOut", sort: sort + 1,
      legNumber: number, cumMs: outMs, additionParts: [1, 2]},
    [`l${number}-finish`]: {code: "Veksling", kind: "finish", sort: sort + 2,
      legNumber: number, cumMs: endMs, additionParts: [1, 2]},
  };
}
const first = leg(1, 1, 10000, 15000, 30000);
const second = leg(2, 4, 100000, 106000, 130000);
const third = leg(3, 7, 190000, 196000, 210000);
const fourth = leg(4, 10, 250000, 256000, 280000);
const withoutSecondFinish = {...second};
delete withoutSecondFinish["l2-finish"];

function unknownWholeLeg(result) {
  expect(result.totalMs).toBeNull();
  expect(result.biathlon.metrics).toMatchObject({
    courseTimeMs: null, skiTimeMs: null, netSkiTimeMs: null,
    shootingTimeMs: 6000, missesTotal: 2,
  });
  expect(result.biathlon.passes.shoot1).toMatchObject({rangeMs: 6000, misses: 2});
}

test("complete numbered relay keeps full leg and shooting durations", () => {
  const result = buildRelayLegBiathlon({...first, ...second, ...third})[2];
  expect(result).toMatchObject({legNumber: 3, totalMs: 80000,
    biathlon: {metrics: {courseTimeMs: 80000, skiTimeMs: 74000,
      netSkiTimeMs: 74000, shootingTimeMs: 6000, missesTotal: 2}}});
});

test.each([
  ["absent immediate leg", {...first, ...third}],
  ["untimed immediate leg", {...first, ...third,
    "l2-finish": {code: "Veksling", kind: "finish", legNumber: 2, cumMs: null}}],
  ["first represented leg above one", third],
  ["missing exchange despite timed shooting", {...first, ...withoutSecondFinish, ...third}],
])("%s cannot create whole-leg analysis across a gap", (name, splits) => {
  const result = buildRelayLegBiathlon(splits).find((entry) => entry.legNumber === 3);
  unknownWholeLeg(result);
  expect(result.biathlon.laps.lap1).toBeUndefined();
  expect(result.biathlon.laps.lap2).toMatchObject({skiMs: 14000,
    startCode: "UTS1", endCode: "Veksling"});
  expect(result.biathlon.passes.shoot1.inCumMs).toBeNull();
  expect(result.biathlon.laps.lap2.startCumMs).toBeNull();
});

test("missing own finish preserves measured range but not partial whole-leg time", () => {
  const result = buildRelayLegBiathlon({...first, ...withoutSecondFinish})[1];
  unknownWholeLeg(result);
  expect(result.biathlon.laps.lap1).toMatchObject({skiMs: 70000});
  expect(result.biathlon.laps.lap2).toBeUndefined();
});

test("a known endpoint after a gap restores the next adjacent leg", () => {
  const results = buildRelayLegBiathlon({...first, ...third, ...fourth});
  unknownWholeLeg(results[1]);
  expect(results[2]).toMatchObject({legNumber: 4, totalMs: 70000,
    biathlon: {metrics: {skiTimeMs: 64000, netSkiTimeMs: 64000}}});
});

test("a numeric zero exchange is valid", () => {
  const result = buildRelayLegBiathlon({
    "l1-finish": {code: "Veksling", kind: "finish", legNumber: 1, cumMs: 0},
    ...leg(2, 4, 10000, 16000, 30000),
  })[1];
  expect(result.totalMs).toBe(30000);
  expect(result.biathlon.metrics.skiTimeMs).toBe(24000);
});

test.each([
  {code: "1. Veksling", kind: "split"},
  {code: "Veksling 1", kind: "split"},
  {code: "Station 9", kind: "split", isStop: true},
  {code: "Maal"},
])("a genuine exchange marker is accepted: %j", (marker) => {
  const splits = {...first, ...second};
  splits["l1-finish"] = {...splits["l1-finish"], ...marker};
  if (marker.kind === undefined) delete splits["l1-finish"].kind;
  const result = buildRelayLegBiathlon(splits)[1];
  expect(result.totalMs).toBe(100000);
});

test("unknown relay start uses the shared sparse client contract", () => {
  const result = buildRelayLegBiathlon({...first, ...third})[1];
  const persisted = sanitizeForFirestore(result);
  expect(persisted).toMatchObject(clientFixture.team.legs[0]);
  for (const key of ["courseTimeMs", "netSkiTimeMs", "skiTimeMs"]) {
    expect(persisted.biathlon.metrics).not.toHaveProperty(key);
  }
  expect(persisted.biathlon.passes.shoot1).not.toHaveProperty("inCumMs");
  expect(third["l3-in"].legMs).toBe(12000);
});

test.each(["Før veksling", "Pre-exchange"])(
    "a mid-course marker %s cannot establish an exchange", (code) => {
      const splits = {...first, ...second};
      splits["l1-finish"] = {...splits["l1-finish"], code, kind: "split"};
      const results = buildRelayLegBiathlon(splits);
      expect(results[0].totalMs).toBeNull();
      unknownWholeLeg(results[1]);
    },
);

test.each([Infinity, NaN])("non-finite endpoint %s cannot establish a time", (cumMs) => {
  const splits = {...first, ...second, ...third};
  splits["l2-finish"] = {...splits["l2-finish"], cumMs};
  const results = buildRelayLegBiathlon(splits);
  unknownWholeLeg(results[1]);
  unknownWholeLeg(results[2]);
  expect(results[1].biathlon.laps.lap2).toBeUndefined();
});

test("negative adjacent leg cannot provide a later leg baseline", () => {
  const splits = {...first, ...second, ...third};
  splits["l2-finish"] = {...splits["l2-finish"], cumMs: 20000};
  const results = buildRelayLegBiathlon(splits);
  expect(results.find((result) => result.legNumber === 2)).toBeUndefined();
  unknownWholeLeg(results.find((result) => result.legNumber === 3));
});

test("negative absolute finish with unknown start cannot anchor the next leg", () => {
  const splits = {...third, ...fourth};
  splits["l3-finish"] = {...splits["l3-finish"], cumMs: -100};
  const results = buildRelayLegBiathlon(splits);
  unknownWholeLeg(results[0]);
  unknownWholeLeg(results[1]);
});

test("negative without-addition finish cannot become a corrected-time baseline", () => {
  const splits = {...first, ...second};
  splits["l1-finish"] = {...splits["l1-finish"], cumMsWithoutAddition: -100};
  for (const key of ["l2-in", "l2-out", "l2-finish"]) {
    splits[key] = {...splits[key], cumMsWithoutAddition: splits[key].cumMs - 80000};
  }
  const baseline = buildRelayLegBiathlon({...first, ...second})[1];
  const result = buildRelayLegBiathlon(splits)[1];
  expect(result.totalMs).toBe(100000);
  expect(result.biathlon.metrics).toEqual(baseline.biathlon.metrics);
});
