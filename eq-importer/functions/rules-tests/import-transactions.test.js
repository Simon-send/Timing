"use strict";

const {Firestore} = require("@google-cloud/firestore");
const {execution, assertWriteLease} = require("../import-execution");
const {claimDecision, LEASE_MS} = require("../import-job-state");
const {recoveryDecision, canFinalizeInitialization} = require("../import-recovery");

let db;
let jobRef;
let resultRef;

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("This test requires the Firestore emulator");
  }
  db = new Firestore({projectId: "demo-eq-results"});
  jobRef = db.doc("importJobs/transaction-test");
  resultRef = db.doc("events/transaction-test");
});

beforeEach(async () => {
  await jobRef.set({eventId: 1, classCount: 1, nextClassIndex: 0,
    runId: "run", status: "queued"});
  await resultRef.delete();
});

afterAll(async () => {
  if (db) {
    await jobRef.delete();
    await resultRef.delete();
    await db.terminate();
  }
});

test("concurrent claims have exactly one winner", async () => {
  const request = {eventId: 1, classCount: 1, classIndex: 0, runId: "run"};
  const claim = (owner) => db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (claimDecision(snapshot.data(), request, Date.now()) !== "claim") {
      return false;
    }
    transaction.set(jobRef, {status: "running", activeClassIndex: 0,
      leaseOwner: owner, leaseExpiresAtMs: Date.now() + LEASE_MS}, {merge: true});
    return true;
  });
  const outcomes = await Promise.all([claim("one"), claim("two")]);
  expect(outcomes.filter(Boolean)).toHaveLength(1);
});

test("replaced worker cannot overwrite a result", async () => {
  await jobRef.set({leaseOwner: "new", leaseExpiresAtMs: Date.now() + LEASE_MS},
      {merge: true});
  const write = (owner) => execution.run({jobRef, owner, runId: "run"}, () =>
    db.runTransaction(async (transaction) => {
      await assertWriteLease(transaction);
      transaction.set(resultRef, {writer: owner});
    }));
  await write("new");
  await expect(write("old")).rejects.toThrow("IMPORT_LEASE_LOST");
  expect((await resultRef.get()).data()).toEqual({writer: "new"});
});

test("expired initialization cannot finalize while recovery blocks it", async () => {
  const now = Date.now();
  await jobRef.set({eventId: 1, runId: "run", status: "initializing",
    initializationExpiresAtMs: now - 1, initialized: false});
  const finalize = () => db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (!canFinalizeInitialization(snapshot.data(), "run", now)) return false;
    transaction.set(jobRef, {status: "queued", initialized: true}, {merge: true});
    return true;
  });
  const recover = () => db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (recoveryDecision(snapshot.data(), now) !== "block-initialization") return false;
    transaction.set(jobRef, {status: "blocked", initialized: false}, {merge: true});
    return true;
  });
  const [finalized, blocked] = await Promise.all([finalize(), recover()]);
  expect(finalized).toBe(false);
  expect(blocked).toBe(true);
  expect((await jobRef.get()).data()).toMatchObject({status: "blocked", initialized: false});
});

test("old initializer cannot complete a replacement run", async () => {
  await jobRef.set({eventId: 1, runId: "replacement", status: "initializing",
    initializationExpiresAtMs: Date.now() + 300000});
  const oldInitializer = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(jobRef);
    if (!canFinalizeInitialization(snapshot.data(), "run", Date.now())) return false;
    transaction.set(jobRef, {status: "queued"}, {merge: true});
    return true;
  });
  expect(oldInitializer).toBe(false);
  expect((await jobRef.get()).data()).toMatchObject({runId: "replacement", status: "initializing"});
});
