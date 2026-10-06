"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {buildResultUpdate} = require("../scripts/scrub-public-sensitive-fields");

let testEnvironment;

test("scrub and merge-reimport remove raw IDs without losing public entrant data", async () => {
  const paths = ["events/1/classes/1/results/101",
    "events/1/stages/1/classes/1/results/101"];
  const original = {participantUid: 101, etappeDeltakerUid: 9001,
    totalMs: 120000, entrant: {participantUid: 101, name: "Ada",
      athleteId: "athlete:1001", bib: "7"}};
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const path of paths) {
      const ref = doc(db, path);
      await setDoc(ref, original);
      await updateDoc(ref, buildResultUpdate(original, deleteField()));
    }
    // Firestore set(merge:true) has nested deletion semantics as well.
    const ref = doc(db, paths[1]);
    await setDoc(ref, original);
    await setDoc(ref, {participantUid: deleteField(),
      etappeDeltakerUid: deleteField(),
      entrant: {participantUid: deleteField(), name: "Ada"}}, {merge: true});
  });
  const db = testEnvironment.unauthenticatedContext().firestore();
  for (const path of paths) {
    const data = (await assertSucceeds(getDoc(doc(db, path)))).data();
    expect(data.participantUid).toBeUndefined();
    expect(data.etappeDeltakerUid).toBeUndefined();
    expect(data.entrant).toEqual({name: "Ada", athleteId: "athlete:1001", bib: "7"});
    expect(data.totalMs).toBe(120000);
  }
});

test("import manifests, source caches and probes remain server-only", async () => {
  const paths = [
    "importJobs/event-1",
    "importJobs/event-1/runs/run/targets/stage_class",
    "importJobs/event-1/runs/run/sourcePages/page",
    "importJobs/event-1/runs/run/sourcePages/page/sourceFragments/0",
    "importJobs/event-1/runs/run/writeReceipts/batch",
    "importProbes/probe",
  ];
  for (const context of [testEnvironment.unauthenticatedContext(),
    testEnvironment.authenticatedContext("operator", {email_verified: true})]) {
    for (const path of paths) {
      const reference = doc(context.firestore(), path);
      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, {status: "done"}));
    }
  }
});

test("only named public biathlon aggregates are readable", async () => {
  const stageBase = "events/1/stages/1/classes/1";
  const legacyBase = "events/1/classes/1";
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const base of [stageBase, legacyBase]) {
      await setDoc(doc(db, `${base}/aggregateProfiles/biathlon-all`), {
        schemaVersion: 1, cohortCount: 2,
      });
      await setDoc(doc(db,
        `${base}/aggregateProfiles/biathlon-top-half/sections/laps-0`), {
        field: "laps",
      });
      await setDoc(doc(db, `${base}/aggregateProfiles/biathlon-top-half`), {
        schemaVersion: 1, sections: {laps: ["laps-0"]},
      });
      await setDoc(doc(db,
        `${base}/aggregateProfiles/biathlon-top-half/sections/laps-old`), {
        field: "laps",
      });
      await setDoc(doc(db, `${base}/aggregateProfiles/private-data`), {
        internal: true,
      });
    }
  });
  for (const context of [testEnvironment.unauthenticatedContext(),
    testEnvironment.authenticatedContext("member", {email_verified: true})]) {
    const db = context.firestore();
    for (const base of [stageBase, legacyBase]) {
      const aggregate = doc(db, `${base}/aggregateProfiles/biathlon-all`);
      await assertSucceeds(getDoc(aggregate));
      await assertSucceeds(getDoc(doc(db,
        `${base}/aggregateProfiles/biathlon-top-half/sections/laps-0`)));
      await assertFails(getDoc(doc(db,
        `${base}/aggregateProfiles/biathlon-top-half/sections/laps-old`)));
      await assertFails(setDoc(aggregate, {cohortCount: 99}));
      await assertFails(getDoc(doc(db,
        `${base}/aggregateProfiles/private-data`)));
    }
    await assertFails(getDoc(doc(db,
      `${stageBase}/results/1/privateAnalysis/current`)));
  }
});

beforeAll(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: "demo-eq-results",
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8",
      ),
    },
  });
});

afterAll(async () => {
  await testEnvironment.cleanup();
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "events/1"), {name: "Testevent"});
    await setDoc(doc(db, "events/1/stages/1/classes/1/results/1"), {
      name: "Testutøver",
    });
    await setDoc(doc(
      db,
      "events/1/stages/1/classes/1/results/1/privateAnalysis/current",
    ), {analysis: {pacing: true}});
    await setDoc(doc(db, "rundeanalyseEvents/open"), {
      active: true,
      name: "Rundeanalyse test arrangement",
    });
    await setDoc(doc(db, "rundeanalyseConfig/default"), {
      freeAnalysisLimit: 5,
    });
    await setDoc(doc(db, "rundeanalyseUsers/test-user"), {
      totalAnalyses: 1,
    });
    await setDoc(doc(db, "rundeanalyseCodes/test-code"), {
      remainingAnalyses: 50,
    });
    await setDoc(doc(db, "rundeanalyseUsage/test-usage"), {
      source: "free",
    });
    await setDoc(doc(db, "rundeanalyseIdempotency/test-request"), {
      usageId: "test-usage",
    });
    await setDoc(doc(db, "rundeanalyseStats/overview"), {
      totalAnalyses: 1,
    });
    await setDoc(doc(db, "rundeanalyseEventStats/open"), {
      usedAnalyses: 1,
    });
    await setDoc(doc(db, "rundeanalyseAdminAudit/test-entry"), {
      operation: "create-code",
    });
    await setDoc(doc(db, "rundeanalyseAdminGrants/test-user"), {
      grantedAtMs: Date.now(),
    });
  });
});

test("official event and result data is public but client writes are denied", async () => {
  const db = testEnvironment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(db, "events/1")));
  await assertSucceeds(getDoc(doc(
    db,
    "events/1/stages/1/classes/1/results/1",
  )));
  await assertFails(setDoc(doc(db, "events/1"), {name: "Endret"}));
});

test("detailed result analysis is not publicly readable", async () => {
  const db = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(
    db,
    "events/1/stages/1/classes/1/results/1/privateAnalysis/current",
  )));
});

test("only the verified user can access personal settings", async () => {
  const owner = testEnvironment.authenticatedContext("owner", {
    email_verified: true,
  }).firestore();
  const other = testEnvironment.authenticatedContext("other", {
    email_verified: true,
  }).firestore();
  const unverified = testEnvironment.authenticatedContext("owner", {
    email_verified: false,
  }).firestore();
  const settings = doc(owner, "users/owner/settings/app");

  await assertSucceeds(setDoc(settings, {
    localeCode: "nb",
    defaultEventId: null,
    defaultClassId: null,
    preferredSplitId: null,
    tableDensity: "comfortable",
    themeVariant: "nordicDark",
  }));
  await assertSucceeds(getDoc(settings));
  await assertFails(getDoc(doc(other, "users/owner/settings/app")));
  await assertFails(setDoc(
    doc(unverified, "users/owner/settings/app"),
    {
      localeCode: "en",
      defaultEventId: null,
      defaultClassId: null,
      preferredSplitId: null,
      tableDensity: "comfortable",
      themeVariant: "nordicDark",
    },
  ));
});

test("verified settings creation needs a complete known base before patch updates", async () => {
  const owner = testEnvironment.authenticatedContext("settings-owner", {
    email_verified: true,
  }).firestore();
  const settings = doc(owner, "users/settings-owner/settings/app");

  // A locale-only first write is not a valid settings document.
  await assertFails(setDoc(settings, {localeCode: "en"}, {merge: true}));
  expect((await assertSucceeds(getDoc(settings))).exists()).toBe(false);
  await assertSucceeds(setDoc(settings, {
    localeCode: "en",
    defaultEventId: "event-a",
    defaultClassId: "class-a",
    preferredSplitId: "finish",
    tableDensity: "comfortable",
    themeVariant: "nordicDark",
  }, {merge: true}));
  await assertSucceeds(setDoc(settings, {localeCode: "de"}, {merge: true}));
  expect((await assertSucceeds(getDoc(settings))).data()).toEqual({
    localeCode: "de",
    defaultEventId: "event-a",
    defaultClassId: "class-a",
    preferredSplitId: "finish",
    tableDensity: "comfortable",
    themeVariant: "nordicDark",
  });
});

test("settings merge patches preserve other fields and allow explicit null clears", async () => {
  const owner = testEnvironment.authenticatedContext("settings-owner", {
    email_verified: true,
  }).firestore();
  const settings = doc(owner, "users/settings-owner/settings/app");
  await assertSucceeds(setDoc(settings, {
    localeCode: "sv",
    defaultEventId: "server-event",
    defaultClassId: "server-class",
    preferredSplitId: "server-split",
    tableDensity: "compact",
    themeVariant: "graphite",
  }));
  await assertSucceeds(setDoc(settings, {
    defaultEventId: null,
    defaultClassId: null,
    preferredSplitId: null,
  }, {merge: true}));
  expect((await assertSucceeds(getDoc(settings))).data()).toEqual({
    localeCode: "sv",
    defaultEventId: null,
    defaultClassId: null,
    preferredSplitId: null,
    tableDensity: "compact",
    themeVariant: "graphite",
  });
  const unverified = testEnvironment.authenticatedContext("settings-owner", {
    email_verified: false,
  }).firestore();
  await assertFails(setDoc(doc(unverified, "users/settings-owner/settings/app"), {
    localeCode: "en",
  }, {merge: true}));
});

test("personal documents reject unknown fields and allow favorite deletion", async () => {
  const db = testEnvironment.authenticatedContext("owner", {
    email_verified: true,
  }).firestore();

  await assertFails(setDoc(doc(db, "users/owner/settings/app"), {
    localeCode: "nb",
    tableDensity: "comfortable",
    themeVariant: "nordicDark",
    unexpectedSecret: "should not be stored",
  }));
  await assertSucceeds(setDoc(doc(db, "users/owner/profile/main"), {
    athleteId: "athlete:1",
    athleteName: "Test Utøver",
    athleteLinkOnboardingCompleted: true,
    updatedAt: new Date(),
  }));
  await assertFails(setDoc(doc(db, "users/owner/profile/main"), {
    athleteId: "athlete:1",
    athleteName: "Test Utøver",
    athleteLinkOnboardingCompleted: true,
    updatedAt: new Date(),
    internalNote: "should not be stored",
  }));
  const favorite = doc(db, "users/owner/favoriteAthletes/athlete:1");
  await assertFails(setDoc(favorite, {
    athleteId: "athlete:other", athleteName: "Test", updatedAt: new Date(),
  }));
  await assertFails(setDoc(favorite, {
    athleteId: "athlete:1", athleteName: 123, updatedAt: new Date(),
  }));
  await assertFails(setDoc(favorite, {
    athleteId: "athlete:1", athleteName: "Test", updatedAt: new Date(), extra: true,
  }));
  for (const context of [
    testEnvironment.authenticatedContext("other", {email_verified: true}),
    testEnvironment.authenticatedContext("owner", {email_verified: false}),
    testEnvironment.unauthenticatedContext(),
  ]) {
    const foreign = doc(context.firestore(), "users/owner/favoriteAthletes/athlete:1");
    await assertFails(setDoc(foreign, {
      athleteId: "athlete:1", athleteName: "Test", updatedAt: new Date(),
    }));
    await assertFails(getDoc(foreign));
  }
  await assertSucceeds(setDoc(favorite, {
    athleteId: "athlete:1",
    athleteName: "Test Utøver",
    updatedAt: new Date(),
  }));
  await assertSucceeds(deleteDoc(favorite));
});

test("Rundeanalyse collections are only available through callable Functions", async () => {
  const guest = testEnvironment.unauthenticatedContext().firestore();
  const signedIn = testEnvironment.authenticatedContext("runde-user", {
    email_verified: true,
  }).firestore();
  const serverOnlyPaths = [
    ["rundeanalyseConfig", "default"],
    ["rundeanalyseUsers", "test-user"],
    ["rundeanalyseCodes", "test-code"],
    ["rundeanalyseEvents", "open"],
    ["rundeanalyseEventStats", "open"],
    ["rundeanalyseUsage", "test-usage"],
    ["rundeanalyseIdempotency", "test-request"],
    ["rundeanalyseStats", "overview"],
    ["rundeanalyseAdminAudit", "test-entry"],
    ["rundeanalyseAdminGrants", "test-user"],
  ];

  for (const [collectionId, documentId] of serverOnlyPaths) {
    await assertFails(getDoc(doc(guest, collectionId, documentId)));
    await assertFails(getDoc(doc(signedIn, collectionId, documentId)));
    await assertFails(setDoc(
      doc(signedIn, collectionId, documentId),
      {clientWrite: true},
    ));
  }
  await assertFails(getDocs(collection(guest, "rundeanalyseEvents")));
});
