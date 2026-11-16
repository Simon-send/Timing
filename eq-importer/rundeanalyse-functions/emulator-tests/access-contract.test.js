"use strict";
const {test, after} = require("node:test");
const assert = require("node:assert/strict");
// Fail before loading an SDK unless all traffic is explicitly local/demo.
if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || "") ||
    process.env.GCLOUD_PROJECT !== "demo-eq-results") {
  throw new Error("Access contract requires loopback Firestore and demo-eq-results.");
}
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {RundeanalyseAccessService} = require("../access_service");
const app = initializeApp({projectId: "demo-eq-results"}, "starter-contract");
const db = getFirestore(app);
const now = Date.UTC(2026, 10, 16);
const service = new RundeanalyseAccessService({db, auth: {getUser: async (uid) => ({uid})},
  codePepper: "synthetic-contract-pepper-not-for-production", nowMs: () => now});
function request(uid, data = {}, admin = false) {
  return {auth: {uid, token: {email_verified: true, rundeanalyseAdmin: admin, firebase: {sign_in_provider: "custom"}}}, data};
}
after(async () => {
  await db.terminate();
  await deleteApp(app);
});
test("real shared-code and starter transactions preserve last-credit/idempotency rules", async () => {
  await db.collection("rundeanalyseConfig").doc("default").set({freeAnalysisLimit: 15, freePeriodDays: 1});
  const code = "SYNTHETIC-CLUB-2026";
  const created = await service.createCode(request("synthetic-admin", {code, label: code, credits: 1, reason: "Local integration contract"}, true));
  const first = request("synthetic-code-a", {code: "syntheticclub2026", idempotencyKey: "shared-credit-first-001"});
  const second = request("synthetic-code-b", {code, idempotencyKey: "shared-credit-second-001"});
  const results = await Promise.all([service.consumeAnalysis(first), service.consumeAnalysis(second)]);
  assert.equal(results.filter((r) => r.allowed).length, 1);
  const winner = results[0].allowed ? first : second;
  assert.deepEqual(await service.consumeAnalysis(winner), results.find((r) => r.allowed));
  const stored = (await db.collection("rundeanalyseCodes").doc(created.codeId).get()).data();
  assert.equal(stored.remainingAnalyses, 0);
  assert.equal(stored.usedAnalyses, 1);
  await assert.rejects(service.createCode(request("synthetic-admin", {code: "syntheticclub2026", credits: 1, reason: "Duplicate"}, true)), {code: "already-exists"});

  await db.collection("rundeanalyseUsers").doc("synthetic-starter").set({freePeriodStartedAtMs: now - 400 * 86400000, freeAnalysesUsed: 14});
  const a = request("synthetic-starter", {idempotencyKey: "starter-last-credit-a", useFreeAllowance: true});
  const b = request("synthetic-starter", {idempotencyKey: "starter-last-credit-b", useFreeAllowance: true});
  const starter = await Promise.all([service.consumeAnalysis(a), service.consumeAnalysis(b)]);
  assert.equal(starter.filter((r) => r.allowed).length, 1);
  assert.equal((await db.collection("rundeanalyseUsers").doc("synthetic-starter").get()).data().freeAnalysesUsed, 15);
  const status = await service.getAccessStatus(request("synthetic-starter"));
  assert.equal(status.access.freeRemainingAnalyses, 0);
  assert.equal(status.access.freeAllowanceExpires, false);
  assert.equal(status.access.freePeriodEndsAtMs, null);
});
