"use strict";

/* eslint-disable require-jsdoc */

const {prepareNsfImport} = require("../nsf-normalize");

const klass = "senior";
const finish = {id: "finish", label: "Mål", kind: "finish"};
const split = {id: "km12", label: "1,2 km", km: 1.2, kind: "split"};

function entrant(name, rank, extras = {}) {
  return {name, rank, bib: rank, club: "Testklubb", ...extras};
}

function timed(name, rank, cumMs, totalMs, extras = {}) {
  return entrant(name, rank, {totalMs, points: cumMs == null ? {} : {
    km12: {cumMs, rank},
  }, ...extras});
}

function stage(id, phase, rows, courseKey = "course-a") {
  return {id, name: id, phase, courseKey, distanceKm: 1.4,
    classes: [{classId: klass, points: [split, finish], rows}]};
}

function sprintSource() {
  return {
    schemaVersion: 1,
    event: {id: 2279, name: "Syntetisk sprint", date: "2026-03-07", place: "Teststed"},
    classes: [{id: klass, name: "Senior", expectedCount: 4, official: [
      entrant("Løper A", 1, {athleteId: "source-private-A", birthDate: "2000-01-01"}),
      entrant("Løper B", 2), entrant("Løper C", 3), entrant("Løper D", 4),
    ]}],
    stages: [
      stage("prolog", "prolog", [
        timed("Løper D", 1, 100000, 130000),
        timed("Løper C", 2, 120000, 151000),
        timed("Løper B", 3, 125000, 153000),
        timed("Løper A", 4, 130000, 161000, {bib: 48}),
      ]),
      stage("quarter-1", "quarterfinal", [
        timed("Løper A", 1, 147000, 190000, {bib: 2}),
        timed("Løper D", 2, 149000, 192000),
      ]),
      stage("quarter-2", "quarterfinal", [
        timed("Løper B", 1, 150000, 193000, {bib: 7}),
        timed("Løper C", 2, null, 196000, {bib: 8}),
      ]),
      stage("final", "final", [
        timed("Løper A", 1, 140000, 190000), timed("Løper B", 2, 145000, 195000),
        timed("Løper C", 3, 150000, 200000), timed("Løper D", 4, 151000, 201000),
      ]),
    ],
  };
}

function raceClass(bundle, stageId) {
  return bundle.docs.find(({path}) =>
    path === `events/${bundle.eventId}/stages/${stageId}/classes/${klass}`).data;
}

function result(bundle, stageId, name) {
  return bundle.docs.find(({path, data}) =>
    path.includes(`/stages/${stageId}/classes/${klass}/results/`) &&
    data.entrant.name === name);
}

test("sprint keeps one official cohort across prolog and different heats", () => {
  const input = sprintSource();
  const bundle = prepareNsfImport(input);
  expect(bundle.report.issues).toEqual([]);
  expect(bundle.report.ready).toBe(true);
  const q1 = raceClass(bundle, "quarter-1").sprintPodium;
  expect(q1).toEqual({phase: "quarterfinal", points: {
    km12: {cumMeanMs: 148500, cumCount: 2, legMeanMs: 148500, legCount: 2},
    finish: {cumMeanMs: 193000, cumCount: 3, legMeanMs: 43000, legCount: 2},
  }});
  expect(raceClass(bundle, "quarter-2").sprintPodium).toEqual(q1);
  expect(raceClass(bundle, "prolog").sprintPodium.points.km12.cumMeanMs).toBe(125000);
  expect(result(bundle, "prolog", "Løper A").data.entrant.bib).toBe("48");
  expect(result(bundle, "quarter-1", "Løper A").data.entrant.bib).toBe("2");
  expect(result(bundle, "prolog", "Løper A").path.split("/").at(-1))
      .toBe(result(bundle, "quarter-1", "Løper A").path.split("/").at(-1));
  expect(result(bundle, "sprint-overall", "Løper B").data).toMatchObject({
    resultKind: "classification", rank: 2, displayOrder: 1,
  });
  expect(result(bundle, "sprint-overall", "Løper B").data).not.toHaveProperty("totalMs");
  expect(JSON.stringify(bundle.docs)).not.toMatch(/source-private-A|birthDate|2000-01-01/);
  expect(prepareNsfImport(input).report.checksum).toBe(bundle.report.checksum);
});

test("keeps unrelated courses separate and recalculates the reference on a correction", () => {
  const input = sprintSource();
  input.stages[2].courseKey = "course-b";
  let bundle = prepareNsfImport(input);
  expect(raceClass(bundle, "quarter-1").sprintPodium.points.km12.cumCount).toBe(1);
  expect(raceClass(bundle, "quarter-2").sprintPodium.points.finish.cumCount).toBe(2);
  input.classes[0].official[2].rank = 4;
  input.classes[0].official[3].rank = 3;
  bundle = prepareNsfImport(input);
  expect(raceClass(bundle, "quarter-1").sprintPodium.points.km12)
      .toMatchObject({cumMeanMs: 148000, cumCount: 2});
});

test("blocks missing official sprint results, missing class counts and ambiguous people", () => {
  const input = sprintSource();
  delete input.classes[0].official;
  expect(prepareNsfImport(input).report.ready).toBe(false);
  const ambiguous = sprintSource();
  ambiguous.classes[0].official[3].name = "Løper C";
  expect(prepareNsfImport(ambiguous).report.ready).toBe(false);
  const missing = sprintSource();
  missing.classes[0].official.pop();
  expect(prepareNsfImport(missing).report.issues.some((item) =>
    /Offisielt antall/.test(item.message))).toBe(true);
});

test("distance stores integer milliseconds and never invents a missing segment", () => {
  const source = {
    schemaVersion: 1,
    event: {id: 2290, name: "Syntetisk distanse", date: "2026-03-08", place: "Teststed"},
    classes: [{id: klass, name: "Senior", expectedCount: 3}],
    stages: [{id: "distance", name: "30 km", phase: "distance", distanceKm: 30,
      classes: [{classId: klass, points: [
        {id: "p1", label: "3,3 km", km: 3.3, kind: "split"},
        {id: "p2", label: "3,6 km", km: 3.6, kind: "split"},
        finish,
      ], rows: [
        entrant("Løper A", 1, {totalMs: 3964900, points: {
          p1: {cumMs: 427800}, p2: {cumMs: 453900},
        }}),
        entrant("Løper B", 2, {totalMs: 3990000, points: {p2: {cumMs: 460000}}}),
        entrant("Løper C", null, {status: "DFQ", totalMs: 3900000}),
      ]}],
    }],
  };
  const bundle = prepareNsfImport(source);
  expect(bundle.report.ready).toBe(true);
  expect(result(bundle, "distance", "Løper A").data.timingPoints[1])
      .toMatchObject({cumMs: 453900, legMs: 26100});
  expect(result(bundle, "distance", "Løper B").data.timingPoints[0])
      .not.toHaveProperty("legMs");
  expect(result(bundle, "distance", "Løper B").data.splitLegsAuthoritative).toBe(true);
  expect(result(bundle, "distance", "Løper C").data)
      .toMatchObject({status: "DSQ", finishConfirmed: false, displayOrder: 2});
  expect(result(bundle, "distance", "Løper C").data).not.toHaveProperty("totalMs");
  source.stages[0].classes[0].rows[0].points.p2.cumMs = 1;
  expect(prepareNsfImport(source).report.ready).toBe(false);
});

test("status corrections keep official ranking and nonfinishers out of podium stats", () => {
  const input = sprintSource();
  input.stages[0].classes[0].rows[3].status = "DNF";
  const bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(true);
  expect(raceClass(bundle, "prolog").sprintPodium.points.km12)
      .toMatchObject({cumMeanMs: 122500, cumCount: 2});
});

test("an official prolog correction restores the finish and the podium reference", () => {
  const input = sprintSource();
  const prolog = input.stages[0].classes[0];
  prolog.rows[3].status = "DNF";
  delete prolog.rows[3].totalMs;
  prolog.official = [entrant("Løper A", 4, {totalMs: 161000})];
  const bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(true);
  expect(bundle.report.issues).toEqual([expect.objectContaining({
    severity: "warning", message: expect.stringMatching(/går foran live i prolog/),
  })]);
  expect(result(bundle, "prolog", "Løper A").data).toMatchObject({
    status: "", finishConfirmed: true, rank: 4, totalMs: 161000,
  });
  expect(raceClass(bundle, "prolog").sprintPodium.points.km12)
      .toMatchObject({cumMeanMs: 125000, cumCount: 3});
});

test("rank-only official distance rows cannot authorize weaker live finish times", () => {
  const input = sprintSource();
  input.stages = [{...input.stages[0], id: "distance", phase: "distance"}];
  let bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(false);
  expect(bundle.report.issues).toContainEqual(expect.objectContaining({
    severity: "error", message: expect.stringMatching(/både plassering og sluttid/),
  }));
  for (const row of input.classes[0].official) {
    row.totalMs = input.stages[0].classes[0].rows.find((entry) => entry.name === row.name).totalMs;
  }
  bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(true);
});
