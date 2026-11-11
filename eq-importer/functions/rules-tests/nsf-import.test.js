"use strict";

/* eslint-disable require-jsdoc */

const fs = require("node:fs");
const path = require("node:path");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {assertFails, assertSucceeds, initializeTestEnvironment} =
  require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {prepareNsfImport} = require("../nsf-normalize");
const {writeNsfImport} = require("../nsf-write");

const projectId = "demo-nsf-import-tests";
let environment;
let app;

beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("This test requires the Firestore emulator.");
  }
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8")},
  });
  await environment.clearFirestore();
  app = initializeApp({projectId}, "nsf-emulator-test");
});

afterAll(async () => {
  if (app) await deleteApp(app);
  if (environment) await environment.cleanup();
});

function sample() {
  const rows = [1, 2, 3, 4].map((rank) => ({
    name: `Testløper ${rank}`, rank, bib: rank,
    totalMs: 120000 + 1000 * rank, athleteId: `internal-${rank}`,
    birthDate: "2000-01-01", points: {p1: {cumMs: 90000 + 1000 * rank}},
  }));
  const classes = [{classId: "senior", rows, points: [
    {id: "p1", kind: "split", label: "1,2 km", km: 1.2},
  ]}];
  return {
    schemaVersion: 1,
    event: {id: 2279, date: "2026-03-07", name: "Test sprint", place: "Teststed"},
    classes: [{id: "senior", name: "Senior", official: rows, expectedCount: rows.length}],
    stages: [
      {id: "prolog", name: "Prolog", phase: "prolog", classes},
      {id: "final", name: "Finale", phase: "final", classes},
    ],
  };
}

test("NSF uses the public v3 contract, fences incomplete reimport and hides receipts", async () => {
  const admin = getFirestore(app);
  const initial = prepareNsfImport(sample());
  const {checksum} = initial.report;
  await admin.doc("events/2279").set({name: "Existing EQ race"});
  await expect(writeNsfImport(admin, initial, {checksum})).resolves
      .toMatchObject({eventId: "nsf-2279", written: initial.docs.length});
  await expect(writeNsfImport(admin, initial, {checksum})).resolves
      .toMatchObject({unchanged: true, written: 0});

  const publicDb = environment.unauthenticatedContext().firestore();
  const event = "events/nsf-2279";
  const stageClass = `${event}/stages/prolog/classes/senior`;
  const stageRef = doc(publicDb, stageClass);
  const original = (await assertSucceeds(getDoc(stageRef))).data();
  expect(original.sprintPodium.points.p1).toMatchObject({cumMeanMs: 92000, cumCount: 3});
  const result = initial.docs.find(({path}) => path.startsWith(`${stageClass}/results/`));
  const resultData = (await assertSucceeds(getDoc(doc(publicDb, result.path)))).data();
  expect(JSON.stringify(resultData)).not.toMatch(/internal-|birthDate/);
  const root = (await assertSucceeds(getDoc(doc(publicDb, `${event}/classes/senior`)))).data();
  expect(root.primaryStageId).toBe("sprint-overall");
  expect((await admin.doc("events/2279").get()).data().name).toBe("Existing EQ race");
  await assertFails(setDoc(stageRef, {sprintPodium: {}}));
  await assertFails(getDoc(doc(publicDb, "nsfImportReceipts/nsf-2279")));

  const weaker = sample();
  delete weaker.stages[0].classes[0].rows[0].points.p1;
  const incomplete = prepareNsfImport(weaker);
  await expect(writeNsfImport(admin, incomplete, {checksum: incomplete.report.checksum}))
      .rejects.toThrow(/mangler tidligere/);
  expect((await getDoc(stageRef)).data()).toEqual(original);

  const corrected = sample();
  const official = corrected.classes[0].official.map((row) => ({...row}));
  official[2].rank = 4;
  official[3].rank = 3;
  corrected.classes[0].official = official;
  const updated = prepareNsfImport(corrected);
  await writeNsfImport(admin, updated, {checksum: updated.report.checksum});
  expect((await getDoc(stageRef)).data().sprintPodium.points.p1.cumMeanMs).toBe(92333);
});

test("a large reimport publishes atomically and keeps old results on interruption", async () => {
  const admin = getFirestore(app);
  const input = sample();
  input.event.id = 99001;
  const rows = Array.from({length: 600}, (_, index) => ({
    name: `Atomic Test ${index + 1}`, bib: index + 1, rank: index + 1,
    totalMs: 120000 + index, points: {p1: {cumMs: 90000 + index}},
  }));
  input.classes[0].official = rows;
  input.classes[0].expectedCount = rows.length;
  for (const stage of input.stages) stage.classes[0].rows = rows;
  const first = prepareNsfImport(input);
  expect(first.docs.length).toBeGreaterThan(500);
  await writeNsfImport(admin, first, {checksum: first.report.checksum});
  const checked = first.docs.find(({path}) => path.includes("/stages/prolog/") &&
    path.includes("/results/"));
  const before = (await admin.doc(checked.path).get()).data();
  rows.forEach((row) => row.totalMs += 1000);
  const next = prepareNsfImport(input);
  let calls = 0;
  const interrupted = {
    doc: admin.doc.bind(admin), collection: admin.collection.bind(admin),
    runTransaction: (body) => admin.runTransaction(async (tx) => {
      const result = await body(tx);
      if (++calls === 2) throw new Error("Simulated commit interruption");
      return result;
    }),
  };
  await expect(writeNsfImport(interrupted, next, {checksum: next.report.checksum}))
      .rejects.toThrow("Simulated commit interruption");
  expect((await admin.doc(checked.path).get()).data()).toEqual(before);
  await writeNsfImport(admin, next, {checksum: next.report.checksum, resume: true});
  expect((await admin.doc(checked.path).get()).data().totalMs).toBe(before.totalMs + 1000);
});
