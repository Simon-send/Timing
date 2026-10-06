"use strict";

const {
  AccessError,
  RundeanalyseAccessService,
  codeIdFor,
  dateKeyFor,
  normaliseCode,
} = require("../access_service");

const NOW_MS = Date.UTC(2026, 8, 9, 12, 0, 0);
const PEPPER = "test-code-pepper-with-at-least-thirty-two-characters";
const DAY_MS = 24 * 60 * 60 * 1000;

function clone(value) {
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

class FakeDocumentSnapshot {
  constructor(ref, data) {
    this.id = ref.id;
    this.ref = ref;
    this.exists = data !== undefined;
    this._data = clone(data);
  }

  data() {
    return clone(this._data);
  }
}

class FakeDocumentReference {
  constructor(database, path) {
    this.database = database;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  get() {
    return Promise.resolve(new FakeDocumentSnapshot(this, this.database.documents.get(this.path)));
  }

  set(data, options) {
    this.database.set(this, data, options);
    return Promise.resolve();
  }
}

class FakeCollectionReference {
  constructor(database, path, order, limitValue, filters = [], cursor) {
    this.database = database;
    this.path = path;
    this.order = order;
    this.limitValue = limitValue;
    this.filters = filters;
    this.cursor = cursor;
  }

  doc(id) {
    return new FakeDocumentReference(this.database, `${this.path}/${id}`);
  }

  orderBy(field, direction) {
    return new FakeCollectionReference(this.database, this.path, {field, direction}, this.limitValue, this.filters, this.cursor);
  }

  limit(value) {
    return new FakeCollectionReference(this.database, this.path, this.order, value, this.filters, this.cursor);
  }

  where(field, operator, value) {
    return new FakeCollectionReference(this.database, this.path, this.order, this.limitValue,
      [...this.filters, {field, operator, value}], this.cursor);
  }

  startAfter(snapshot) {
    return new FakeCollectionReference(this.database, this.path, this.order, this.limitValue, this.filters, snapshot);
  }

  get() {
    const prefix = `${this.path}/`;
    let documents = [...this.database.documents.entries()]
      .filter(([path]) => path.startsWith(prefix) && !path.slice(prefix.length).includes("/"))
      .map(([path, data]) => new FakeDocumentSnapshot(
        new FakeDocumentReference(this.database, path),
        data,
      ));
    if (this.order) {
      const {field, direction} = this.order;
      const multiplier = direction === "desc" ? -1 : 1;
      documents = documents.sort((left, right) => {
        const leftValue = left.data()[field] || 0;
        const rightValue = right.data()[field] || 0;
        return leftValue === rightValue ? left.id.localeCompare(right.id) * multiplier : (leftValue < rightValue ? -1 : 1) * multiplier;
      });
    }
    if (this.cursor) documents = documents.slice(documents.findIndex((doc) => doc.id === this.cursor.id) + 1);
    documents = documents.filter((doc) => this.filters.every(({field, operator, value}) => {
      const actual = doc.data()[field];
      if (operator === "==") return actual === value;
      if (operator === ">=") return actual >= value;
      if (operator === "<=") return actual <= value;
      if (operator === "<") return actual < value;
      throw new Error(`Unsupported operator: ${operator}`);
    }));
    if (this.limitValue != null) documents = documents.slice(0, this.limitValue);
    return Promise.resolve({docs: documents});
  }
}

class FakeFirestore {
  constructor(seed = {}) {
    this.documents = new Map(Object.entries(clone(seed)));
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  getAll(...references) {
    return Promise.all(references.map((reference) => reference.get()));
  }

  runTransaction(callback) {
    const transaction = {
      get: (reference) => reference.get(),
      set: (reference, data, options) => {
        this.set(reference, data, options);
      },
    };
    return callback(transaction);
  }

  set(reference, data, options) {
    const previous = this.documents.get(reference.path) || {};
    const next = options && options.merge ? Object.assign({}, previous, clone(data)) : clone(data);
    this.documents.set(reference.path, next);
  }

  data(path) {
    return clone(this.documents.get(path));
  }
}

function verifiedRequest(uid = "athlete-1", data = {}, token = {}) {
  return {
    auth: {
      uid,
      token: Object.assign({
        email: `${uid}@example.com`,
        email_verified: true,
        firebase: {sign_in_provider: "google.com"},
      }, token),
    },
    data,
  };
}

function adminRequest(data = {}) {
  return verifiedRequest("admin-1", data, {rundeanalyseAdmin: true});
}

function makeService(seed = {}, authOverrides = {}) {
  const db = new FakeFirestore(seed);
  const auth = Object.assign({
    getUser: jest.fn(async (uid) => ({
      uid,
      email: `${uid}@example.com`,
      displayName: "Example athlete",
    })),
    getUserByEmail: jest.fn(async (email) => ({
      uid: "target-1",
      email,
      displayName: "Target athlete",
    })),
  }, authOverrides);
  return {
    db,
    auth,
    service: new RundeanalyseAccessService({
      db,
      auth,
      codePepper: PEPPER,
      nowMs: () => NOW_MS,
    }),
  };
}

function codeDocumentPath(code) {
  return `rundeanalyseCodes/${codeIdFor(normaliseCode(code), PEPPER)}`;
}

describe("RundeanalyseAccessService", () => {
  test("history finds older filtered rows and paginates equal timestamps without losses", async () => {
    const seed = {};
    for (let i = 0; i < 1200; i++) {
      seed[`rundeanalyseUsage/new-${i}`] = {createdAtMs: NOW_MS + i, uid: "other"};
    }
    for (const id of ["a", "b", "c"]) {
      seed[`rundeanalyseUsage/${id}`] = {createdAtMs: NOW_MS - 100, uid: "target", source: "free"};
    }
    const {service} = makeService(seed);
    const first = await service.getAdminUsage(adminRequest({filterType: "user", filterId: "target", limit: 2}));
    expect(first.entries.map((row) => row.id)).toEqual(["c", "b"]);
    const second = await service.getAdminUsage(adminRequest({filterType: "user", filterId: "target", limit: 2, cursorId: first.nextCursorId}));
    expect(second.entries.map((row) => row.id)).toEqual(["a"]);
    expect(second.nextCursorId).toBeNull();
  });
  test("starts the free window on first Rundeanalyse status and consumes exactly once", async () => {
    const {db, service} = makeService();
    const status = await service.getAccessStatus(verifiedRequest());

    expect(status).toMatchObject({
      signedIn: true,
      isAdmin: false,
      access: {
        freeAnalysisLimit: 5,
        freeRemainingAnalyses: 5,
        freePeriodStartsAtMs: NOW_MS,
      },
    });
    expect(db.data("rundeanalyseUsers/athlete-1").freePeriodStartedAtMs).toBe(NOW_MS);

    const request = verifiedRequest("athlete-1", {idempotencyKey: "free-analysis-0001"});
    const first = await service.consumeAnalysis(request);
    const replay = await service.consumeAnalysis(request);

    expect(first).toEqual(replay);
    expect(first).toMatchObject({allowed: true, access: {source: "free"}});
    expect(db.data("rundeanalyseUsers/athlete-1").freeAnalysesUsed).toBe(1);
    expect(db.data("rundeanalyseStats/overview").totalAnalyses).toBe(1);
    expect([...db.documents.keys()].filter((path) => path.startsWith("rundeanalyseUsage/"))).toHaveLength(1);
  });

  test("uses a matching event for a guest and persists no candidate coordinates", async () => {
    const {db, service} = makeService({
      "rundeanalyseEvents/race-1": {
        name: "Høstløpet",
        startAtMs: NOW_MS - 1000,
        endAtMs: NOW_MS + 1000,
        goalLatitude: 63.4305,
        goalLongitude: 10.3951,
        radiusMeters: 50,
        active: true,
      },
    });

    const result = await service.consumeAnalysis({
      data: {
        idempotencyKey: "event-analysis-0001",
        eventCandidate: {
          eventId: "race-1",
          capturedAtMs: NOW_MS,
          latitude: 63.43054321,
          longitude: 10.3951,
        },
      },
    });

    expect(result).toMatchObject({
      allowed: true,
      access: {source: "event", eventId: "race-1", eventName: "Høstløpet"},
    });
    expect(db.data("rundeanalyseUsage/usage_event-analysis-0001")).toEqual(expect.objectContaining({
      eventId: "race-1",
      source: "event",
    }));
    expect(JSON.stringify(Object.fromEntries(db.documents))).not.toContain("63.43054321");
  });

  test("rejects an idempotency replay whose event proof differs", async () => {
    const {service} = makeService({
      "rundeanalyseEvents/race-replay": {
        name: "Replay test",
        startAtMs: NOW_MS - 1000,
        endAtMs: NOW_MS + 1000,
        goalLatitude: 63.4305,
        goalLongitude: 10.3951,
        radiusMeters: 50,
        active: true,
      },
    });
    const idempotencyKey = "event-replay-proof-0001";
    await service.consumeAnalysis({
      data: {
        idempotencyKey,
        eventCandidate: {
          eventId: "race-replay",
          capturedAtMs: NOW_MS,
          latitude: 63.4305,
          longitude: 10.3951,
        },
      },
    });

    await expect(service.consumeAnalysis({
      data: {
        idempotencyKey,
        eventCandidate: {
          eventId: "race-replay",
          capturedAtMs: NOW_MS - 1,
          latitude: 63.4305,
          longitude: 10.3951,
        },
      },
    })).rejects.toMatchObject({code: "already-exists"});
  });

  test("keeps an active past arrangement available for a later GPX import", async () => {
    const {service} = makeService({
      "rundeanalyseEvents/race-previous": {
        name: "Forrige løp",
        startAtMs: NOW_MS - 10 * DAY_MS,
        endAtMs: NOW_MS - 9 * DAY_MS,
        goalLatitude: 63.4305,
        goalLongitude: 10.3951,
        radiusMeters: 50,
        active: true,
      },
    });

    const status = await service.getAccessStatus({data: {}});

    expect(status.availableEvents).toEqual([
      expect.objectContaining({id: "race-previous", name: "Forrige løp"}),
    ]);
  });

  test("annual access wins before an explicitly entered code", async () => {
    const code = "RA-ANNUAL-TEST-001";
    const codePath = codeDocumentPath(code);
    const {db, service} = makeService({
      "rundeanalyseUsers/athlete-1": {
        freePeriodStartedAtMs: NOW_MS,
        freeAnalysesUsed: 0,
        annualAccessUntilMs: NOW_MS + 1000,
      },
      [codePath]: {
        label: "Klubb",
        active: true,
        remainingAnalyses: 3,
        usedAnalyses: 0,
      },
    });

    const result = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "annual-analysis-0001",
      code,
    }));

    expect(result).toMatchObject({allowed: true, access: {source: "annual"}});
    expect(db.data(codePath).remainingAnalyses).toBe(3);
  });

  test("an explicit code links to the account, while an unselected linked code prompts the user", async () => {
    const code = "RA-LINKED-TEST-001";
    const codePath = codeDocumentPath(code);
    const codeId = codePath.split("/")[1];
    const {db, service} = makeService({
      [codePath]: {
        label: "Klubbkode",
        active: true,
        remainingAnalyses: 3,
        usedAnalyses: 0,
        linkedUsersCount: 0,
      },
    });

    const explicit = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "linked-analysis-0001",
      code,
    }));
    expect(explicit).toMatchObject({
      allowed: true,
      access: {source: "code", codeId, remainingAnalyses: 2},
    });
    expect(db.data("rundeanalyseUsers/athlete-1").linkedCodeIds).toEqual([codeId]);
    expect(db.data(codePath).linkedUsersCount).toBe(1);

    const status = await service.getAccessStatus(verifiedRequest());
    expect(status.linkedCodes).toEqual([expect.objectContaining({id: codeId, remainingAnalyses: 2})]);

    const choose = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "linked-analysis-0002",
    }));
    expect(choose).toEqual(expect.objectContaining({
      allowed: false,
      reason: "CHOOSE_CODE",
      linkedCodes: [expect.objectContaining({id: codeId})],
    }));
    expect(db.data(codePath).remainingAnalyses).toBe(2);

    const free = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "linked-analysis-free-0004",
      useFreeAllowance: true,
    }));
    expect(free).toMatchObject({allowed: true, access: {source: "free"}});
    expect(db.data("rundeanalyseUsers/athlete-1").freeAnalysesUsed).toBe(1);

    const selected = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "linked-analysis-0005",
      linkedCodeId: codeId,
    }));
    expect(selected).toMatchObject({allowed: true, access: {source: "code", remainingAnalyses: 1}});
  });

  test("an invalid explicit code never falls through to the free allowance", async () => {
    const {db, service} = makeService();
    const result = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "invalid-code-0001",
      code: "RA-MISSING-TEST-001",
    }));

    expect(result).toEqual({
      allowed: false,
      reason: "code-invalid",
      nextStep: "enter-a-different-code",
    });
    expect(db.data("rundeanalyseUsers/athlete-1")).toBeUndefined();
  });

  test("an opaque guest session can consume a code without retaining its raw value", async () => {
    const code = "RA-GUEST-SESSION-001";
    const codePath = codeDocumentPath(code);
    const token = "gYzR0BB7qD5SvM2yJ8NqH4LwK9xC6pVaT1eF3uIoZkQ";
    const {db, service} = makeService({
      [codePath]: {label: "Gjest", active: true, remainingAnalyses: 2, usedAnalyses: 0},
    });

    const codeId = codePath.split("/")[1];
    await service.createGuestSession({token, codeId});
    expect(await service.codeIdForGuestSession(token)).toBe(codeId);
    expect(JSON.stringify(Object.fromEntries(db.documents))).not.toContain(token);
    expect(JSON.stringify(Object.fromEntries(db.documents))).not.toContain(code);

    const result = await service.consumeAnalysis({
      guestSessionCodeId: await service.codeIdForGuestSession(token),
      data: {idempotencyKey: "guest-session-analysis-0001"},
    });
    expect(result).toMatchObject({allowed: true, access: {source: "code", codeId}});
    expect(db.data(codePath).remainingAnalyses).toBe(1);
  });

  test("a shared final code credit is consumed once", async () => {
    const code = "RA-FINAL-CREDIT-001";
    const codePath = codeDocumentPath(code);
    const {db, service} = makeService({
      [codePath]: {
        label: "One left",
        active: true,
        remainingAnalyses: 1,
        usedAnalyses: 0,
      },
    });

    const first = await service.consumeAnalysis({data: {idempotencyKey: "final-credit-0001", code}});
    const second = await service.consumeAnalysis({data: {idempotencyKey: "final-credit-0002", code}});

    expect(first.allowed).toBe(true);
    expect(second).toEqual({
      allowed: false,
      reason: "code-unavailable",
      nextStep: "enter-a-different-code",
    });
    expect(db.data(codePath)).toEqual(expect.objectContaining({remainingAnalyses: 0, usedAnalyses: 1}));
  });

  test("requires verified accounts to link a code and admins to change configuration", async () => {
    const code = "RA-VERIFY-TEST-001";
    const codePath = codeDocumentPath(code);
    const {db, service} = makeService({
      [codePath]: {label: "Test", active: true, remainingAnalyses: 1},
    });
    const anonymous = verifiedRequest("anonymous-1", {code}, {
      email_verified: false,
      firebase: {sign_in_provider: "anonymous"},
    });

    await expect(service.linkCode(anonymous)).rejects.toMatchObject({code: "failed-precondition"});
    const linked = await service.linkCode(verifiedRequest("athlete-1", {code}));
    expect(linked).toMatchObject({linked: true, alreadyLinked: false});
    expect(db.data("rundeanalyseUsers/athlete-1").linkedCodeIds).toHaveLength(1);
    await expect(service.setConfig(verifiedRequest("athlete-1", {freeAnalysisLimit: 8})))
      .rejects.toMatchObject({code: "permission-denied"});

    const result = await service.setConfig(adminRequest({freeAnalysisLimit: 8, freePeriodDays: 21, reason: "Test"}));
    expect(result).toEqual({config: {freeAnalysisLimit: 8, freePeriodDays: 21, offerEnabled: true}});
  });

  test("creates protected code records and validates event management", async () => {
    const {db, service} = makeService();
    const code = "RA-PRIVATE-CODE-001";
    const created = await service.createCode(adminRequest({
      code,
      label: "Klubb",
      credits: 50,
      reason: "Test",
    }));

    expect(created).toMatchObject({code, initialAnalyses: 50, remainingAnalyses: 50});
    expect(JSON.stringify(db.data(`rundeanalyseCodes/${created.codeId}`))).not.toContain(code);

    await expect(service.upsertEvent(adminRequest({
      name: "Ugyldig",
      startAtMs: NOW_MS,
      endAtMs: NOW_MS,
      goalLatitude: 63,
      goalLongitude: 10,
      radiusMeters: 30,
      reason: "Test",
    }))).rejects.toMatchObject({code: "invalid-argument"});

    const event = await service.upsertEvent(adminRequest({
      eventId: "race-2",
      name: "Løpet",
      startAtMs: NOW_MS,
      endAtMs: NOW_MS + 1000,
      goalLatitude: 63,
      goalLongitude: 10,
      radiusMeters: 30,
      description: "Gratis analyse for deltakere.",
      reason: "Test",
    }));
    expect(event.event).toMatchObject({
      id: "race-2",
      active: true,
      usedAnalyses: 0,
      description: "Gratis analyse for deltakere.",
    });
    const publicStatus = await service.getAccessStatus({data: {}});
    expect(publicStatus.availableEvents).toEqual([
      expect.objectContaining({id: "race-2", description: "Gratis analyse for deltakere."}),
    ]);
  });

  test("grants annual access and returns an admin overview without raw code values", async () => {
    const {db, service} = makeService();
    const grant = await service.grantAnnualAccess(adminRequest({
      email: "target@example.com",
      accessUntilMs: NOW_MS + 365 * 24 * 60 * 60 * 1000,
      reason: "Test",
    }));
    expect(grant).toMatchObject({uid: "target-1", email: "target@example.com"});
    expect(db.data("rundeanalyseUsers/target-1").annualAccessUntilMs).toBe(grant.annualAccessUntilMs);

    await service.createCode(adminRequest({code: "RA-OVERVIEW-TEST-01", credits: 2, reason: "Test"}));
    const overview = await service.getAdminOverview(adminRequest({limit: 10}));

    expect(overview).toEqual(expect.objectContaining({
      config: expect.objectContaining({freeAnalysisLimit: 5, freePeriodDays: 35}),
      codes: [expect.objectContaining({remainingAnalyses: 2})],
      users: [expect.objectContaining({uid: "target-1"})],
    }));
    expect(JSON.stringify(overview)).not.toContain("RA-OVERVIEW-TEST-01");
  });

  test("uses personal bonus before codes and records a privacy-minimal usage audit", async () => {
    const {db, service} = makeService({
      "rundeanalyseUsers/athlete-1": {
        createdAtMs: NOW_MS,
        freePeriodStartedAtMs: NOW_MS,
        bonusAnalysesRemaining: 2,
      },
    });
    const result = await service.consumeAnalysis(verifiedRequest("athlete-1", {
      idempotencyKey: "bonus-analysis-0001",
    }));
    expect(result).toMatchObject({allowed: true, access: {source: "bonus"}});
    expect(db.data("rundeanalyseUsers/athlete-1").bonusAnalysesRemaining).toBe(1);
    const usage = db.data("rundeanalyseUsage/usage_bonus-analysis-0001");
    expect(usage).toMatchObject({source: "bonus", result: "approved", uid: "athlete-1"});
    expect(JSON.stringify(usage)).not.toContain("latitude");
    const page = await service.getAdminUsage(adminRequest({filterType: "user", filterId: "athlete-1"}));
    expect(page.entries).toEqual([expect.objectContaining({userLabel: "athlete-1@example.com", source: "bonus"})]);
  });

  test("updates a code and records the administrator reason", async () => {
    const {db, service} = makeService();
    const created = await service.createCode(adminRequest({code: "RA-UPDATE-TEST-01", credits: 3, reason: "Test"}));
    const updated = await service.updateCode(adminRequest({
      codeId: created.codeId,
      creditsDelta: 4,
      active: false,
      reason: "Supportsak 42",
    }));
    expect(updated).toMatchObject({remainingAnalyses: 7, active: false});
    const audit = [...db.documents.entries()].find(([path]) => path.startsWith("rundeanalyseAdminAudit/code_updated_"));
    expect(audit[1]).toMatchObject({action: "code-updated", reason: "Supportsak 42"});
  });

  test("uses a keyed HMAC identifier rather than a plain SHA code hash", () => {
    const normalized = normaliseCode("RA-SECRET-123456");
    expect(codeIdFor(normalized, PEPPER)).not.toEqual(codeIdFor(normalized, `${PEPPER}-other`));
    expect(() => codeIdFor(normalized, "short")).toThrow(AccessError);
  });

  test("uses the Norwegian calendar date for dashboard day statistics", () => {
    expect(dateKeyFor(Date.UTC(2026, 0, 1, 23, 30))).toBe("2026-01-02");
  });
});
