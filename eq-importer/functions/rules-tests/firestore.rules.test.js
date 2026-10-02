"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {deleteDoc, doc, getDoc, setDoc} = require("firebase/firestore");

let environment;

beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Rule tests require the local Firestore emulator");
  }
  environment = await initializeTestEnvironment({
    projectId: "demo-eq-results",
    firestore: {
      rules: fs.readFileSync(
          path.resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

afterAll(async () => {
  if (environment) await environment.cleanup();
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "events/event"), {name: "Test event"});
    await setDoc(doc(db,
        "events/event/stages/stage/classes/class/results/result"), {
      name: "Test athlete", timeMs: 1000,
    });
    await setDoc(doc(db, "importJobs/event-event"), {status: "running"});
  });
});

test("published event and stage results are readable but not writable", async () => {
  const db = environment.unauthenticatedContext().firestore();
  for (const location of ["events/event",
    "events/event/stages/stage/classes/class/results/result"]) {
    const reference = doc(db, location);
    await assertSucceeds(getDoc(reference));
    await assertFails(setDoc(reference, {name: "Changed"}));
    await assertFails(deleteDoc(reference));
  }
});

test("only the verified owner can use personal settings and profile", async () => {
  const owner = environment.authenticatedContext("owner", {
    email_verified: true,
  }).firestore();
  const other = environment.authenticatedContext("other", {
    email_verified: true,
  }).firestore();
  const unverified = environment.authenticatedContext("owner", {
    email_verified: false,
  }).firestore();
  const anonymous = environment.unauthenticatedContext().firestore();
  for (const location of ["users/owner/settings/app",
    "users/owner/profile/main", "users/owner/favoriteAthletes/athlete"]) {
    const reference = doc(owner, location);
    await assertSucceeds(setDoc(reference, {name: "Test"}));
    await assertSucceeds(getDoc(reference));
    for (const db of [other, unverified, anonymous]) {
      await assertFails(getDoc(doc(db, location)));
      await assertFails(setDoc(doc(db, location), {name: "Changed"}));
      await assertFails(deleteDoc(doc(db, location)));
    }
    await assertSucceeds(deleteDoc(reference));
  }
});

test("import jobs and internal result analysis are server-only", async () => {
  for (const context of [environment.unauthenticatedContext(),
    environment.authenticatedContext("owner", {email_verified: true})]) {
    const db = context.firestore();
    for (const location of ["importJobs/event-event",
      "events/event/stages/stage/classes/class/results/result/privateAnalysis/current"]) {
      const reference = doc(db, location);
      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, {internal: true}));
    }
  }
});
