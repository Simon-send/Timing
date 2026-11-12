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


function prologOnlySource() {
  const source = sprintSource();
  source.sprintPrologOnly = true;
  source.stages = [source.stages[0]];
  source.classes[0].official = source.stages[0].classes[0].rows.map((row) => ({...row}));
  return source;
}

test("cancelled heats keep an official timed prolog as the primary sprint stage", () => {
  const input = prologOnlySource();
  const live = input.stages[0].classes[0].rows;
  live[0].rank = 9;
  live[0].totalMs = 131000;
  live[1].status = "DNF";
  const bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(true);
  expect(bundle.report.event.resultProfile).toBe("sprint");
  expect(bundle.docs.find(({path}) => path.endsWith(`/classes/${klass}`) &&
    !path.includes("/stages/")).data.primaryStageId).toBe("prolog");
  expect(bundle.docs.find(({path}) => path.endsWith("/stages/prolog")).data.name)
      .toBe("Prolog (heat avlyst)");
  expect(result(bundle, "prolog", "Løper D").data).toMatchObject({
    rank: 1, totalMs: 130000, resultAuthority: "official", finishConfirmed: true,
  });
  expect(result(bundle, "prolog", "Løper C").data).toMatchObject({
    rank: 2, status: "", totalMs: 151000, resultAuthority: "official",
  });
  expect(bundle.docs.some(({path}) => path.includes("sprint-overall"))).toBe(false);
  expect(JSON.stringify(bundle.docs)).not.toContain("sprintPodium");
});

test("prolog-only requires complete official timed results for each selected class", () => {
  const noOfficial = prologOnlySource();
  delete noOfficial.classes[0].official;
  expect(prepareNsfImport(noOfficial).report.ready).toBe(false);
  const incomplete = prologOnlySource();
  incomplete.classes[0].official.pop();
  expect(prepareNsfImport(incomplete).report.ready).toBe(false);
  const noTimes = prologOnlySource();
  delete noTimes.classes[0].official[0].totalMs;
  expect(prepareNsfImport(noTimes).report.ready).toBe(false);
  const laterPhases = sprintSource();
  laterPhases.sprintPrologOnly = true;
  expect(prepareNsfImport(laterPhases).report.ready).toBe(false);
});

test("a complete stage-scoped official prolog also authorizes the prolog-only import", () => {
  const source = prologOnlySource();
  source.stages[0].classes[0].official = source.classes[0].official;
  delete source.classes[0].official;
  const bundle = prepareNsfImport(source);
  expect(bundle.report.ready).toBe(true);
  expect(result(bundle, "prolog", "Løper D").data.resultAuthority).toBe("official");
});

test("an official list does not hide the absence of an independent participant total", () => {
  const input = sprintSource();
  delete input.classes[0].expectedCount;
  const bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(true);
  expect(bundle.report.issues).toContainEqual(expect.objectContaining({
    severity: "warning", message: expect.stringMatching(/uavhengig bekreftet deltakerantall/),
  }));
});

function categorySource() {
  return {
    schemaVersion: 1,
    event: {id: 2446, name: "Felles felt", date: "2026-03-28", place: "Teststed"},
    classes: [
      {id: "parent", name: "Senior", expectedCount: 3},
      {id: "u20", name: "U20", expectedCount: 2, categoryOf: "parent"},
    ],
    stages: [{id: "distance", name: "10 km", phase: "distance", classes: [
      {classId: "parent", points: [split, finish], rows: [
        timed("Løper A", 1, 10000, 20000),
        timed("Løper B", 2, 11000, 21000),
        entrant("Løper C", null, {status: "DNS"}),
      ]},
      {classId: "u20", points: [split, finish], rows: [
        timed("Løper B", 1, 11000, 21000),
        entrant("Løper C", null, {status: "DNS"}),
      ]},
    ]}],
  };
}

test("explicit verified category membership is counted once while both class views remain", () => {
  const input = categorySource();
  const bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(true);
  expect(bundle.report.event.participantCount).toBe(3);
  expect(bundle.report.classes.map((item) => item.participants)).toEqual([3, 2]);
  expect(bundle.docs.filter((doc) => doc.path.includes("/results/"))).toHaveLength(5);
});

test("matching names in independent classes are not implicitly deduplicated", () => {
  const input = categorySource();
  delete input.classes[1].categoryOf;
  expect(prepareNsfImport(input).report.event.participantCount).toBe(5);
});

test.each([
  ["unknown parent", (source) => source.classes[1].categoryOf = "missing"],
  ["self parent", (source) => source.classes[1].categoryOf = "u20"],
  ["projection chain", (source) => source.classes[0].categoryOf = "u20"],
  ["unknown member", (source) => source.stages[0].classes[1].rows[0].name = "Ukjent løper"],
  ["ambiguous member", (source) => {
    source.stages[0].classes[0].rows[0].name = "Løper B";
    source.stages[0].classes[0].rows[0].club = "Annen klubb";
    delete source.stages[0].classes[1].rows[0].club;
  }],
  ["different finish", (source) => source.stages[0].classes[1].rows[0].totalMs++],
  ["different status", (source) => source.stages[0].classes[1].rows[1].status = "DNF"],
  ["different split", (source) => source.stages[0].classes[1].rows[0].points.km12.cumMs++],
  ["different stage", (source) => {
    const child = source.stages[0].classes.pop();
    source.stages.push({id: "other", name: "Annet løp", phase: "distance", classes: [child]});
  }],
])("category totals reject %s instead of hiding unrelated participants", (_, change) => {
  const input = categorySource();
  change(input);
  const bundle = prepareNsfImport(input);
  expect(bundle.report.ready).toBe(false);
  expect(bundle.report.issues).toContainEqual(expect.objectContaining({
    severity: "error", message: expect.stringMatching(/kategori/i),
  }));
});
