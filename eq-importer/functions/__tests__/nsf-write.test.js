"use strict";

/* eslint-disable require-jsdoc */

const {assertCoverage, writeNsfImport} = require("../nsf-write");
const {prepareNsfImport} = require("../nsf-normalize");

function source() {
  return {
    schemaVersion: 1,
    event: {id: 2290, name: "Testløp", date: "2026-03-08", place: "Teststed"},
    classes: [{id: "senior", name: "Senior", expectedCount: 2}],
    stages: [{id: "distance", name: "Distanse", phase: "distance",
      classes: [{classId: "senior", points: [
        {id: "p1", label: "1 km", km: 1, kind: "split"},
      ], rows: [
        {name: "Utøver A", rank: 1, totalMs: 100000, points: {p1: {cumMs: 75000}}},
        {name: "Utøver B", rank: 2, totalMs: 110000, points: {p1: {cumMs: 78000}}},
      ]}]}],
  };
}

function memoryDb() {
  const store = new Map();
  return {
    store,
    doc: (path) => path,
    collection: (path) => ({doc: (id) => `${path}/${id}`}),
    async runTransaction(body) {
      const next = new Map(store);
      const result = await body({
        get: async (ref) => ({data: () => store.get(ref)}),
        set: (ref, data) => next.set(ref, data),
        update: (ref, patch) => next.set(ref, {...next.get(ref), ...patch}),
      });
      for (const [key, value] of next) store.set(key, value);
      return result;
    },
  };
}

test("only imports a checked snapshot and does not duplicate documents", async () => {
  const db = memoryDb();
  const bundle = prepareNsfImport(source());
  const {checksum} = bundle.report;
  await expect(writeNsfImport(db, bundle, {checksum: "invalid"})).rejects.toThrow();
  expect(db.store.size).toBe(0);
  await expect(writeNsfImport(db, bundle, {checksum}))
      .resolves.toMatchObject({unchanged: false, written: bundle.docs.length});
  await expect(writeNsfImport(db, bundle, {checksum}))
      .resolves.toMatchObject({unchanged: true, written: 0});
  expect(db.store.size).toBe(bundle.docs.length + 1);
  expect(db.store.get("events/nsf-2290").source).toBe("nsf");
});

test("a weaker or tampered snapshot cannot overwrite a complete import", async () => {
  const db = memoryDb();
  const original = prepareNsfImport(source());
  await writeNsfImport(db, original, {checksum: original.report.checksum});
  const before = [...db.store.entries()];
  const weaker = source();
  delete weaker.stages[0].classes[0].rows[0].points.p1;
  const bundle = prepareNsfImport(weaker);
  await expect(writeNsfImport(db, bundle, {checksum: bundle.report.checksum}))
      .rejects.toThrow(/mangler tidligere/);
  original.docs[0].data.name = "Endret uten forhåndsvisning";
  await expect(writeNsfImport(db, original, {checksum: original.report.checksum}))
      .rejects.toThrow(/kontrollsum/);
  expect([...db.store.entries()]).toEqual(before);
  expect(() => assertCoverage({oldRow: []}, {})).toThrow();
});

test("an interrupted import must resume the exact snapshot", async () => {
  const db = memoryDb();
  const bundle = prepareNsfImport(source());
  const {checksum} = bundle.report;
  db.store.set("nsfImportReceipts/nsf-2290", {state: "writing",
    runId: "interrupted", pendingChecksum: checksum, coverage: {}});
  await expect(writeNsfImport(db, bundle, {checksum})).rejects.toThrow(/--resume/);
  await expect(writeNsfImport(db, bundle, {checksum, resume: true}))
      .resolves.toMatchObject({written: bundle.docs.length});
});

test("an interrupted reimport preserves the public snapshot and resumes atomically", async () => {
  const input = source();
  const group = input.stages[0].classes[0];
  group.rows = Array.from({length: 400}, (_, index) => ({
    name: `Testløper ${index + 1}`, rank: index + 1,
    totalMs: 100000 + index, points: {p1: {cumMs: 75000 + index}},
  }));
  input.classes[0].expectedCount = group.rows.length;
  const db = memoryDb();
  const original = prepareNsfImport(input);
  await writeNsfImport(db, original, {checksum: original.report.checksum});
  const publicBefore = [...db.store].filter(([path]) => path.startsWith("events/"));
  for (const row of group.rows) row.totalMs += 1000;
  const bundle = prepareNsfImport(input);
  const {checksum} = bundle.report;
  const transact = db.runTransaction.bind(db);
  let calls = 0;
  db.runTransaction = (body) => transact(async (tx) => {
    const result = await body(tx);
    if (++calls === 2) throw new Error("Simulated disconnect");
    return result;
  });
  await expect(writeNsfImport(db, bundle, {checksum}))
      .rejects.toThrow("Simulated disconnect");
  expect([...db.store].filter(([path]) => path.startsWith("events/"))).toEqual(publicBefore);
  expect(db.store.get("nsfImportReceipts/nsf-2290"))
      .toMatchObject({state: "failed", pendingChecksum: checksum});

  const partial = [...db.store.entries()];
  group.rows[0].totalMs += 10;
  const different = prepareNsfImport(input);
  await expect(writeNsfImport(db, different, {
    checksum: different.report.checksum, resume: true,
  })).rejects.toThrow(/samme forhåndsvisning/);
  expect([...db.store.entries()]).toEqual(partial);
  await writeNsfImport(db, bundle, {checksum, resume: true});
  expect(db.store.size).toBe(bundle.docs.length + 1);
  for (const {path, data} of bundle.docs) expect(db.store.get(path)).toEqual(data);
  expect(db.store.get("nsfImportReceipts/nsf-2290"))
      .toMatchObject({state: "complete", checksum});
});

test("official corrections cannot be replaced by live-only times or ranks", async () => {
  const db = memoryDb();
  const input = source();
  input.classes[0].official = input.stages[0].classes[0].rows
      .map((row) => ({...row, totalMs: row.totalMs + 1000}));
  const official = prepareNsfImport(input);
  await writeNsfImport(db, official, {checksum: official.report.checksum});
  const before = [...db.store];
  const live = prepareNsfImport(source());
  await expect(writeNsfImport(db, live, {checksum: live.report.checksum}))
      .rejects.toThrow(/offisiell resultatliste/);
  expect([...db.store]).toEqual(before);
});

test("missing finish or checkpoint ranks cannot erase existing placements", async () => {
  const db = memoryDb();
  const input = source();
  input.stages[0].classes[0].rows[0].points.p1.rank = 1;
  const initial = prepareNsfImport(input);
  await writeNsfImport(db, initial, {checksum: initial.report.checksum});
  const before = [...db.store];
  for (const missing of ["rank", "checkpointRank"]) {
    const weaker = structuredClone(input);
    const row = weaker.stages[0].classes[0].rows[0];
    if (missing === "rank") delete row.rank;
    else delete row.points.p1.rank;
    const bundle = prepareNsfImport(weaker);
    expect(bundle.report.ready).toBe(true);
    await expect(writeNsfImport(db, bundle, {checksum: bundle.report.checksum}))
        .rejects.toThrow(/plasseringer/);
    expect([...db.store]).toEqual(before);
  }
});

test("an official DNF may remove the finish but must retain intermediate measurements", async () => {
  const db = memoryDb();
  const input = source();
  input.classes[0].official = structuredClone(input.stages[0].classes[0].rows);
  const initial = prepareNsfImport(input);
  await writeNsfImport(db, initial, {checksum: initial.report.checksum});
  const before = [...db.store];
  input.classes[0].official[0] = {name: "Utøver A", status: "DNF"};
  const weaker = structuredClone(input);
  delete weaker.stages[0].classes[0].rows[0].points.p1;
  const incomplete = prepareNsfImport(weaker);
  await expect(writeNsfImport(db, incomplete, {checksum: incomplete.report.checksum}))
      .rejects.toThrow(/mangler tidligere/);
  expect([...db.store]).toEqual(before);
  const corrected = prepareNsfImport(input);
  await writeNsfImport(db, corrected, {checksum: corrected.report.checksum});
  const result = corrected.docs.find(({data}) => data.entrant?.name === "Utøver A").data;
  expect(result).toMatchObject({status: "DNF", officialStatus: true});
  expect(result).not.toHaveProperty("totalMs");
  expect(result).not.toHaveProperty("finishRank");
  expect(result.timingPoints.map((point) => point.setupUid)).toEqual(["p1"]);
});

test("an official sprint classification can be corrected to DSQ", async () => {
  const input = source();
  const prolog = input.stages[0];
  prolog.id = "prolog";
  prolog.phase = "prolog";
  prolog.classes[0].rows.push({name: "Utøver C", rank: 3, totalMs: 120000});
  input.classes[0].expectedCount = 3;
  input.classes[0].official = structuredClone(prolog.classes[0].rows);
  input.stages.push({...structuredClone(prolog), id: "final", phase: "final"});
  const db = memoryDb();
  const initial = prepareNsfImport(input);
  await writeNsfImport(db, initial, {checksum: initial.report.checksum});
  input.classes[0].official[2] = {name: "Utøver C", status: "DSQ"};
  const updated = prepareNsfImport(input);
  expect(updated.report.ready).toBe(true);
  await writeNsfImport(db, updated, {checksum: updated.report.checksum});
  const classification = updated.docs.find(({path, data}) =>
    path.includes("/stages/sprint-overall/") && data.entrant?.name === "Utøver C");
  expect(db.store.get(classification.path)).toMatchObject({status: "DSQ", officialStatus: true});
  expect(db.store.get(classification.path)).not.toHaveProperty("rank");
});
