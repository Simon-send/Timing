"use strict";

const crypto = require("node:crypto");

const COLLECTIONS = Object.freeze({
  config: "rundeanalyseConfig",
  users: "rundeanalyseUsers",
  codes: "rundeanalyseCodes",
  events: "rundeanalyseEvents",
  eventStats: "rundeanalyseEventStats",
  usage: "rundeanalyseUsage",
  idempotency: "rundeanalyseIdempotency",
  guestSessions: "rundeanalyseGuestSessions",
  stats: "rundeanalyseStats",
  adminAudit: "rundeanalyseAdminAudit",
});

const DEFAULT_CONFIG = Object.freeze({
  freeAnalysisLimit: 5,
  freePeriodDays: 35,
  offerEnabled: true,
});

const MAX_FREE_ANALYSES = 1000;
const MAX_FREE_PERIOD_DAYS = 3650;
const MAX_CODE_CREDITS = 1000000;
const MAX_LINKED_CODES_PER_USER = 20;
const MAX_ADMIN_LIST_LIMIT = 100;
const DAY_MS = 24 * 60 * 60 * 1000;
const GUEST_SESSION_DURATION_MS = 8 * 60 * 60 * 1000;

class AccessError extends Error {
  constructor(code, message, details) {
    super(message);
    this.name = "AccessError";
    this.code = code;
    this.details = details;
  }
}

function requireObject(value, fieldName) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new AccessError("invalid-argument", `${fieldName} must be an object.`);
  }
  return value;
}

function optionalTrimmedString(value, fieldName, maxLength) {
  if (value == null) return undefined;
  if (typeof value !== "string") {
    throw new AccessError("invalid-argument", `${fieldName} must be text.`);
  }
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) {
    throw new AccessError("invalid-argument", `${fieldName} must contain 1–${maxLength} characters.`);
  }
  return trimmed;
}

function requiredReason(value) {
  const reason = optionalTrimmedString(value, "reason", 500);
  if (!reason) throw new AccessError("invalid-argument", "reason must contain 1–500 characters.");
  return reason;
}

function requiredInteger(value, fieldName, minimum, maximum) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new AccessError(
      "invalid-argument",
      `${fieldName} must be a whole number between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

function requiredFiniteNumber(value, fieldName, minimum, maximum) {
  if (!Number.isFinite(value) || value < minimum || value > maximum) {
    throw new AccessError(
      "invalid-argument",
      `${fieldName} must be a number between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

function optionalFutureMillis(value, fieldName, nowMs) {
  if (value == null) return undefined;
  const milliseconds = requiredInteger(value, fieldName, 1, Number.MAX_SAFE_INTEGER);
  if (milliseconds <= nowMs) {
    throw new AccessError("invalid-argument", `${fieldName} must be in the future.`);
  }
  return milliseconds;
}

function normaliseCode(rawCode) {
  const text = optionalTrimmedString(rawCode, "code", 128);
  const normalized = text.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (normalized.length < 6 || normalized.length > 64) {
    throw new AccessError("invalid-argument", "code must contain 6–64 letters or digits.");
  }
  return normalized;
}

function codeIdFor(normalizedCode, pepper = process.env.RUNDEANALYSE_CODE_PEPPER) {
  if (typeof pepper !== "string" || pepper.length < 16) {
    throw new AccessError(
      "failed-precondition",
      "Rundeanalyse code protection is not configured.",
    );
  }
  return crypto.createHmac("sha256", pepper).update(normalizedCode).digest("hex");
}

function randomCode() {
  const value = crypto.randomBytes(9).toString("hex").toUpperCase();
  return `RA-${value.slice(0, 6)}-${value.slice(6, 12)}-${value.slice(12, 18)}`;
}

function requireId(value, fieldName) {
  const id = optionalTrimmedString(value, fieldName, 128);
  if (!/^[A-Za-z0-9_-]+$/.test(id)) {
    throw new AccessError("invalid-argument", `${fieldName} may only use letters, numbers, _ and -.`);
  }
  return id;
}

function requireIdempotencyKey(value) {
  const key = optionalTrimmedString(value, "idempotencyKey", 128);
  if (!/^[A-Za-z0-9_-]{12,128}$/.test(key)) {
    throw new AccessError(
      "invalid-argument",
      "idempotencyKey must contain 12–128 letters, numbers, _ or -.",
    );
  }
  return key;
}

function safeData(snapshot) {
  return snapshot && snapshot.exists ? snapshot.data() || {} : {};
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function uniqueStrings(values) {
  return [...new Set(asArray(values).filter((value) => typeof value === "string"))];
}

function sourceCounts(data) {
  const counts = data && typeof data === "object" ? data : {};
  return {
    annual: Number.isInteger(counts.annual) ? counts.annual : 0,
    bonus: Number.isInteger(counts.bonus) ? counts.bonus : 0,
    code: Number.isInteger(counts.code) ? counts.code : 0,
    event: Number.isInteger(counts.event) ? counts.event : 0,
    free: Number.isInteger(counts.free) ? counts.free : 0,
  };
}

function incrementSourceCounts(existing, source) {
  const next = sourceCounts(existing);
  next[source] = (Number.isInteger(next[source]) ? next[source] : 0) + 1;
  return next;
}

function dateKeyFor(nowMs) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Oslo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date(nowMs));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function haversineMeters(latitudeA, longitudeA, latitudeB, longitudeB) {
  const earthRadiusMeters = 6371008.8;
  const toRadians = (degrees) => degrees * Math.PI / 180;
  const latitudeDelta = toRadians(latitudeB - latitudeA);
  const longitudeDelta = toRadians(longitudeB - longitudeA);
  const startLatitude = toRadians(latitudeA);
  const endLatitude = toRadians(latitudeB);
  const a = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(startLatitude) * Math.cos(endLatitude) * Math.sin(longitudeDelta / 2) ** 2;
  return 2 * earthRadiusMeters * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function publicEvent(eventId, event) {
  const result = {
    id: eventId,
    name: event.name,
    startAtMs: event.startAtMs,
    endAtMs: event.endAtMs,
    goalLatitude: event.goalLatitude,
    goalLongitude: event.goalLongitude,
    radiusMeters: event.radiusMeters,
  };
  if (typeof event.description === "string" && event.description.trim()) {
    result.description = event.description.trim();
  }
  return result;
}

function codeSummary(codeId, code, nowMs) {
  const active = code.active !== false;
  const expired = Number.isInteger(code.expiresAtMs) && code.expiresAtMs <= nowMs;
  const remainingAnalyses = Number.isInteger(code.remainingAnalyses) ? code.remainingAnalyses : 0;
  return {
    id: codeId,
    label: typeof code.label === "string" ? code.label : "Analysekode",
    remainingAnalyses,
    active,
    expiresAtMs: Number.isInteger(code.expiresAtMs) ? code.expiresAtMs : null,
    usable: active && !expired && remainingAnalyses > 0,
  };
}

function accessStatusForUser(config, user, accountCreatedAtMs, nowMs) {
  const freePeriodStartedAtMs = Number.isInteger(user.freePeriodStartedAtMs) ?
    user.freePeriodStartedAtMs : accountCreatedAtMs;
  const freeAnalysesUsed = Number.isInteger(user.freeAnalysesUsed) ? user.freeAnalysesUsed : 0;
  const freePeriodEndsAtMs = freePeriodStartedAtMs + config.freePeriodDays * DAY_MS;
  const freePeriodActive = nowMs < freePeriodEndsAtMs;
  const freeRemainingAnalyses = freePeriodActive ?
    Math.max(0, config.freeAnalysisLimit - freeAnalysesUsed) : 0;
  const annualAccessUntilMs = Number.isInteger(user.annualAccessUntilMs) ? user.annualAccessUntilMs : null;
  const bonusAnalysesRemaining = Number.isInteger(user.bonusAnalysesRemaining) ?
    Math.max(0, user.bonusAnalysesRemaining) : 0;

  return {
    annualAccessUntilMs,
    annualActive: annualAccessUntilMs != null && annualAccessUntilMs > nowMs,
    bonusAnalysesRemaining,
    freeAnalysisLimit: config.freeAnalysisLimit,
    freeAnalysesUsed,
    freeRemainingAnalyses,
    freePeriodStartsAtMs: freePeriodStartedAtMs,
    freePeriodEndsAtMs,
    freePeriodActive,
    offerActive: config.offerEnabled && freePeriodActive && freeRemainingAnalyses > 0,
  };
}

function normaliseConfig(data) {
  const candidate = Object.assign({}, DEFAULT_CONFIG, data || {});
  return {
    freeAnalysisLimit: requiredInteger(
      candidate.freeAnalysisLimit,
      "freeAnalysisLimit",
      0,
      MAX_FREE_ANALYSES,
    ),
    freePeriodDays: requiredInteger(
      candidate.freePeriodDays,
      "freePeriodDays",
      0,
      MAX_FREE_PERIOD_DAYS,
    ),
    offerEnabled: candidate.offerEnabled !== false,
  };
}

function requestActor(request) {
  if (!request || !request.auth || typeof request.auth.uid !== "string" || !request.auth.uid) {
    return null;
  }
  const token = request.auth.token || {};
  return {
    uid: request.auth.uid,
    email: typeof token.email === "string" ? token.email : undefined,
    displayName: typeof token.name === "string" ? token.name : undefined,
    token,
  };
}

function isVerifiedRundeanalyseAccount(actor) {
  if (!actor || actor.token.email_verified !== true) return false;
  const provider = actor.token.firebase && actor.token.firebase.sign_in_provider;
  return provider !== "anonymous";
}

function fingerprintFor({actor, explicitCodeId, guestSessionCodeId, linkedCodeId, eventCandidate, useFreeAllowance}) {
  const payload = {
    actorUid: actor ? actor.uid : "guest",
    explicitCodeId: explicitCodeId || null,
    guestSessionCodeId: guestSessionCodeId || null,
    linkedCodeId: linkedCodeId || null,
    // A replay must be byte-for-byte equivalent to the original access
    // choice. Including the full validated candidate prevents a caller from
    // reusing a key with a different event time or location.
    eventCandidate: eventCandidate ? {
      eventId: eventCandidate.eventId,
      capturedAtMs: eventCandidate.capturedAtMs,
      latitude: eventCandidate.latitude,
      longitude: eventCandidate.longitude,
    } : null,
    useFreeAllowance: useFreeAllowance === true,
  };
  return crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

class RundeanalyseAccessService {
  constructor({db, auth, codePepper, nowMs = () => Date.now()}) {
    if (!db || typeof db.collection !== "function" || typeof db.runTransaction !== "function") {
      throw new Error("RundeanalyseAccessService requires a Firestore-compatible database.");
    }
    this.db = db;
    this.auth = auth;
    this.codePepper = codePepper;
    this.nowMs = nowMs;
  }

  _configRef() {
    return this.db.collection(COLLECTIONS.config).doc("default");
  }

  _userRef(uid) {
    return this.db.collection(COLLECTIONS.users).doc(uid);
  }

  _codeRef(codeId) {
    return this.db.collection(COLLECTIONS.codes).doc(codeId);
  }

  _guestSessionRef(token) {
    return this.db.collection(COLLECTIONS.guestSessions).doc(
      crypto.createHmac("sha256", this.codePepper)
        .update(`guest-session:${token}`)
        .digest("hex"),
    );
  }

  _eventRef(eventId) {
    return this.db.collection(COLLECTIONS.events).doc(eventId);
  }

  _eventStatsRef(eventId) {
    return this.db.collection(COLLECTIONS.eventStats).doc(eventId);
  }

  _codeId(rawCode) {
    return codeIdFor(normaliseCode(rawCode), this.codePepper);
  }

  _statsRef(id) {
    return this.db.collection(COLLECTIONS.stats).doc(id);
  }

  _adminAuditRef(id) {
    return this.db.collection(COLLECTIONS.adminAudit).doc(id);
  }

  // The browser keeps only an opaque random token in an HTTP-only cookie.
  // Neither the raw analysis code nor the raw cookie token is persisted.
  async codeIdForGuestSession(token) {
    if (typeof token !== "string" || !/^[A-Za-z0-9_-]{32,128}$/.test(token)) {
      return undefined;
    }
    const snapshot = await this._guestSessionRef(token).get();
    const session = safeData(snapshot);
    if (!snapshot.exists || !Number.isInteger(session.expiresAtMs) ||
        session.expiresAtMs <= this.nowMs() || typeof session.codeId !== "string") {
      return undefined;
    }
    return session.codeId;
  }

  async createGuestSession({token, codeId}) {
    if (typeof token !== "string" || !/^[A-Za-z0-9_-]{32,128}$/.test(token)) {
      throw new AccessError("invalid-argument", "The guest session token is invalid.");
    }
    requireId(codeId, "codeId");
    const nowMs = this.nowMs();
    await this._guestSessionRef(token).set({
      codeId,
      createdAtMs: nowMs,
      expiresAtMs: nowMs + GUEST_SESSION_DURATION_MS,
    });
  }

  _requireAuthenticated(request) {
    const actor = requestActor(request);
    if (!actor) throw new AccessError("unauthenticated", "You must be signed in.");
    return actor;
  }

  _requireVerifiedAccount(request) {
    const actor = this._requireAuthenticated(request);
    if (!isVerifiedRundeanalyseAccount(actor)) {
      throw new AccessError("failed-precondition", "A verified Rundeanalyse account is required.");
    }
    return actor;
  }

  _requireAdmin(request) {
    const actor = this._requireVerifiedAccount(request);
    if (actor.token.rundeanalyseAdmin !== true) {
      throw new AccessError("permission-denied", "Rundeanalyse administrator access is required.");
    }
    return actor;
  }

  _buildUserDocument(existing, actor, accountCreatedAtMs, nowMs) {
    const current = existing || {};
    const user = {
      createdAtMs: Number.isInteger(current.createdAtMs) ? current.createdAtMs : nowMs,
      freePeriodStartedAtMs: Number.isInteger(current.freePeriodStartedAtMs) ?
        current.freePeriodStartedAtMs : accountCreatedAtMs,
      freeAnalysesUsed: Number.isInteger(current.freeAnalysesUsed) ? current.freeAnalysesUsed : 0,
      linkedCodeIds: uniqueStrings(current.linkedCodeIds),
      totalAnalyses: Number.isInteger(current.totalAnalyses) ? current.totalAnalyses : 0,
      usageBySource: sourceCounts(current.usageBySource),
      bonusAnalysesRemaining: Number.isInteger(current.bonusAnalysesRemaining) ?
        Math.max(0, current.bonusAnalysesRemaining) : 0,
      updatedAtMs: nowMs,
    };
    if (Number.isInteger(current.annualAccessUntilMs)) user.annualAccessUntilMs = current.annualAccessUntilMs;
    if (typeof actor.email === "string") user.email = actor.email;
    if (typeof actor.displayName === "string") user.displayName = actor.displayName;
    return user;
  }

  _isEventMatch(event, candidate) {
    if (!event || event.active === false) return false;
    if (!candidate) return false;
    if (candidate.capturedAtMs < event.startAtMs || candidate.capturedAtMs > event.endAtMs) return false;
    const distance = haversineMeters(
      candidate.latitude,
      candidate.longitude,
      event.goalLatitude,
      event.goalLongitude,
    );
    return distance <= event.radiusMeters;
  }

  _parseEventCandidate(value) {
    if (value == null) return undefined;
    const candidate = requireObject(value, "eventCandidate");
    return {
      eventId: requireId(candidate.eventId, "eventCandidate.eventId"),
      capturedAtMs: requiredInteger(
        candidate.capturedAtMs,
        "eventCandidate.capturedAtMs",
        1,
        Number.MAX_SAFE_INTEGER,
      ),
      latitude: requiredFiniteNumber(candidate.latitude, "eventCandidate.latitude", -90, 90),
      longitude: requiredFiniteNumber(candidate.longitude, "eventCandidate.longitude", -180, 180),
    };
  }

  async getAccessStatus(request) {
    const nowMs = this.nowMs();
    const actor = requestActor(request);
    const configSnapshot = await this._configRef().get();
    const config = normaliseConfig(safeData(configSnapshot));
    const eventSnapshot = await this.db.collection(COLLECTIONS.events).get();
    const availableEvents = eventSnapshot.docs
      .filter((snapshot) => {
        const event = safeData(snapshot);
        // A GPX may be imported long after the race has finished. The file's
        // final timestamp—not today's date—is the event eligibility rule, so
        // keep an event available until an administrator deactivates it.
        return event.active !== false;
      })
      .map((snapshot) => publicEvent(snapshot.id, safeData(snapshot)))
      .sort((left, right) => left.startAtMs - right.startAtMs);

    if (!isVerifiedRundeanalyseAccount(actor)) {
      return {
        signedIn: false,
        isAdmin: false,
        access: null,
        linkedCodes: [],
        availableEvents,
        nextStep: "sign-in-or-code",
      };
    }

    const userRef = this._userRef(actor.uid);
    const user = await this.db.runTransaction(async (transaction) => {
      const userSnapshot = await transaction.get(userRef);
      if (userSnapshot.exists) return safeData(userSnapshot);
      const enrolledUser = this._buildUserDocument({}, actor, nowMs, nowMs);
      transaction.set(userRef, enrolledUser);
      return enrolledUser;
    });
    const linkedCodeIds = uniqueStrings(user.linkedCodeIds);
    const linkedCodeSnapshots = linkedCodeIds.length && typeof this.db.getAll === "function" ?
      await this.db.getAll(...linkedCodeIds.map((codeId) => this._codeRef(codeId))) : [];
    const linkedCodes = linkedCodeSnapshots
      .filter((snapshot) => snapshot.exists)
      .map((snapshot) => codeSummary(snapshot.id, safeData(snapshot), nowMs));

    return {
      signedIn: true,
      isAdmin: actor.token.rundeanalyseAdmin === true,
      access: accessStatusForUser(config, user, nowMs, nowMs),
      linkedCodes,
      availableEvents,
      nextStep: "ready",
    };
  }

  async consumeAnalysis(request) {
    const data = requireObject(request && request.data || {}, "data");
    const caller = requestActor(request);
    const actor = isVerifiedRundeanalyseAccount(caller) ? caller : null;
    const nowMs = this.nowMs();
    const idempotencyKey = requireIdempotencyKey(data.idempotencyKey);
    const eventCandidate = this._parseEventCandidate(data.eventCandidate);
    const explicitCodeId = data.code == null ? undefined : this._codeId(data.code);
    // Only the HTTPS wrapper can populate this property after validating the
    // HTTP-only cookie. It is intentionally not read from request.data.
    const guestSessionCodeId = typeof request.guestSessionCodeId === "string" ?
      request.guestSessionCodeId : undefined;
    const linkedCodeId = data.linkedCodeId == null ? undefined : requireId(data.linkedCodeId, "linkedCodeId");
    const useFreeAllowance = data.useFreeAllowance === true;

    if ((explicitCodeId && linkedCodeId) ||
        (useFreeAllowance && (explicitCodeId || linkedCodeId))) {
      throw new AccessError(
        "invalid-argument",
        "Provide only one of code, linkedCodeId or useFreeAllowance.",
      );
    }
    if (linkedCodeId && !actor) {
      throw new AccessError("unauthenticated", "A linked code requires a signed-in user.");
    }

    const requestFingerprint = fingerprintFor({
      actor: caller,
      explicitCodeId,
      guestSessionCodeId,
      linkedCodeId,
      eventCandidate,
      useFreeAllowance,
    });
    const idempotencyRef = this.db.collection(COLLECTIONS.idempotency).doc(idempotencyKey);

    return this.db.runTransaction(async (transaction) => {
      const existingRequest = await transaction.get(idempotencyRef);
      if (existingRequest.exists) {
        const stored = safeData(existingRequest);
        const storedActorUid = typeof stored.actorUid === "string" ? stored.actorUid : "guest";
        const currentActorUid = caller ? caller.uid : "guest";
        if (storedActorUid !== currentActorUid || stored.requestFingerprint !== requestFingerprint) {
          throw new AccessError(
            "already-exists",
            "This idempotencyKey was already used for a different request.",
          );
        }
        return stored.response;
      }

      const usageRef = this.db.collection(COLLECTIONS.usage).doc(`usage_${idempotencyKey}`);
      const reject = (reason, nextStep, extra) => {
        const response = Object.assign({allowed: false, reason, nextStep}, extra || {});
        const usage = {idempotencyKey, source: "none", result: "denied", reason, createdAtMs: nowMs};
        if (actor) usage.uid = actor.uid;
        transaction.set(usageRef, usage);
        transaction.set(idempotencyRef, {
          actorUid: caller ? caller.uid : "guest", requestFingerprint, response,
          usageId: usageRef.id, createdAtMs: nowMs,
        });
        transaction.set(this._adminAuditRef(`usage_${usageRef.id}`), {
          action: "analysis-denied", actorUid: actor ? actor.uid : null,
          usageId: usageRef.id, reason, occurredAtMs: nowMs,
        });
        return response;
      };

      const configRef = this._configRef();
      const userRef = actor ? this._userRef(actor.uid) : undefined;
      const eventRef = eventCandidate ? this._eventRef(eventCandidate.eventId) : undefined;
      const eventStatsRef = eventCandidate ? this._eventStatsRef(eventCandidate.eventId) : undefined;
      const requestedCodeId = explicitCodeId || guestSessionCodeId;
      const explicitCodeRef = requestedCodeId ? this._codeRef(requestedCodeId) : undefined;
      const [configSnapshot, userSnapshot, eventSnapshot, eventStatsSnapshot, explicitCodeSnapshot] = await Promise.all([
        transaction.get(configRef),
        userRef ? transaction.get(userRef) : Promise.resolve(undefined),
        eventRef ? transaction.get(eventRef) : Promise.resolve(undefined),
        eventStatsRef ? transaction.get(eventStatsRef) : Promise.resolve(undefined),
        explicitCodeRef ? transaction.get(explicitCodeRef) : Promise.resolve(undefined),
      ]);
      const config = normaliseConfig(safeData(configSnapshot));
      const userData = safeData(userSnapshot);
      const user = actor ? this._buildUserDocument(userData, actor, nowMs, nowMs) : undefined;
      const event = safeData(eventSnapshot);
      const eventStats = safeData(eventStatsSnapshot);
      const linkedIds = user ? uniqueStrings(user.linkedCodeIds) : [];
      const linkedIdsToRead = linkedCodeId ? [linkedCodeId] : linkedIds;
      const linkedCodeSnapshots = await Promise.all(linkedIdsToRead.map((codeId) =>
        transaction.get(this._codeRef(codeId))));
      const linkedCodeById = new Map(linkedCodeSnapshots.map((snapshot) => [snapshot.id, snapshot]));

      let decision;
      if (eventCandidate && this._isEventMatch(event, eventCandidate)) {
        decision = {
          source: "event",
          eventId: eventCandidate.eventId,
          eventName: event.name,
        };
      } else if (user) {
        const status = accessStatusForUser(config, user, nowMs, nowMs);
        if (status.annualActive) {
          decision = {
            source: "annual",
            annualAccessUntilMs: status.annualAccessUntilMs,
          };
        } else if (status.bonusAnalysesRemaining > 0) {
          decision = {
            source: "bonus",
            bonusAnalysesRemaining: status.bonusAnalysesRemaining - 1,
          };
        }
      }

      if (!decision && requestedCodeId) {
        const summary = explicitCodeSnapshot && explicitCodeSnapshot.exists ?
          codeSummary(requestedCodeId, safeData(explicitCodeSnapshot), nowMs) : undefined;
        if (!summary || !summary.usable) {
          return reject(summary ? "code-unavailable" : "code-invalid", "enter-a-different-code");
        }
        decision = {
          source: "code",
          codeId: requestedCodeId,
          codeLabel: summary.label,
          codeRef: explicitCodeRef,
          codeData: safeData(explicitCodeSnapshot),
        };
      }

      if (!decision && linkedCodeId) {
        if (!user || !linkedIds.includes(linkedCodeId)) {
          return reject("linked-code-unavailable", "select-another-access-method");
        }
        const snapshot = linkedCodeById.get(linkedCodeId);
        const summary = snapshot && snapshot.exists ? codeSummary(linkedCodeId, safeData(snapshot), nowMs) : undefined;
        if (!summary || !summary.usable) {
          return reject("linked-code-unavailable", "select-another-access-method");
        }
        decision = {
          source: "code",
          codeId: linkedCodeId,
          codeLabel: summary.label,
          codeRef: this._codeRef(linkedCodeId),
          codeData: safeData(snapshot),
        };
      }

      if (!decision && user && !explicitCodeId && !linkedCodeId && !useFreeAllowance) {
        const linkedCodes = linkedIds
          .map((candidateCodeId) => linkedCodeById.get(candidateCodeId))
          .filter((snapshot) => snapshot && snapshot.exists)
          .map((snapshot) => codeSummary(snapshot.id, safeData(snapshot), nowMs))
          .filter((summary) => summary.usable);
        if (linkedCodes.length) {
          return reject("CHOOSE_CODE", "choose-linked-code", {linkedCodes});
        }
      }

      if (!decision && user) {
        const status = accessStatusForUser(config, user, nowMs, nowMs);
        if (status.freeRemainingAnalyses > 0) {
          decision = {
            source: "free",
            freeRemainingAnalyses: status.freeRemainingAnalyses - 1,
          };
        }
      }

      if (!decision) {
        return reject(
          actor ? "no-analysis-access" : "sign-in-or-code-required",
          actor ? "buy-or-use-code" : "sign-in-or-code",
        );
      }

      const statsOverviewRef = this._statsRef("overview");
      const statsDayRef = this._statsRef(`day_${dateKeyFor(nowMs)}`);
      const [statsOverviewSnapshot, statsDaySnapshot] = await Promise.all([
        transaction.get(statsOverviewRef),
        transaction.get(statsDayRef),
      ]);

      let explicitCodeLinked = false;
      if (user) {
        user.totalAnalyses += 1;
        user.usageBySource = incrementSourceCounts(user.usageBySource, decision.source);
        user.lastAnalysisAtMs = nowMs;
        if (decision.source === "free") user.freeAnalysesUsed += 1;
        if (decision.source === "bonus") user.bonusAnalysesRemaining -= 1;
        if (decision.source === "code" && explicitCodeId && !user.linkedCodeIds.includes(explicitCodeId)) {
          if (user.linkedCodeIds.length < MAX_LINKED_CODES_PER_USER) {
            user.linkedCodeIds.push(explicitCodeId);
            explicitCodeLinked = true;
          }
        }
        transaction.set(userRef, user, {merge: true});
      }

      if (decision.source === "code") {
        const code = Object.assign({}, decision.codeData, {
          remainingAnalyses: decision.codeData.remainingAnalyses - 1,
          usedAnalyses: (Number.isInteger(decision.codeData.usedAnalyses) ? decision.codeData.usedAnalyses : 0) + 1,
          lastUsedAtMs: nowMs,
          updatedAtMs: nowMs,
        });
        if (explicitCodeLinked) {
          code.linkedUsersCount = (Number.isInteger(decision.codeData.linkedUsersCount) ?
            decision.codeData.linkedUsersCount : 0) + 1;
        }
        transaction.set(decision.codeRef, code, {merge: true});
        decision.remainingAnalyses = code.remainingAnalyses;
      }

      if (decision.source === "event") {
        transaction.set(eventStatsRef, {
          usedAnalyses: (Number.isInteger(eventStats.usedAnalyses) ? eventStats.usedAnalyses : 0) + 1,
          lastUsedAtMs: nowMs,
          updatedAtMs: nowMs,
        }, {merge: true});
      }

      const overview = safeData(statsOverviewSnapshot);
      const day = safeData(statsDaySnapshot);
      transaction.set(statsOverviewRef, {
        totalAnalyses: (Number.isInteger(overview.totalAnalyses) ? overview.totalAnalyses : 0) + 1,
        usageBySource: incrementSourceCounts(overview.usageBySource, decision.source),
        updatedAtMs: nowMs,
      }, {merge: true});
      transaction.set(statsDayRef, {
        dateKey: dateKeyFor(nowMs),
        totalAnalyses: (Number.isInteger(day.totalAnalyses) ? day.totalAnalyses : 0) + 1,
        usageBySource: incrementSourceCounts(day.usageBySource, decision.source),
        updatedAtMs: nowMs,
      }, {merge: true});

      const response = {
        allowed: true,
        idempotencyKey,
        analysisAccessId: usageRef.id,
        access: {
          source: decision.source,
        },
      };
      if (decision.eventId) {
        response.access.eventId = decision.eventId;
        response.access.eventName = decision.eventName;
      }
      if (decision.codeId) {
        response.access.codeId = decision.codeId;
        response.access.codeLabel = decision.codeLabel;
        response.access.remainingAnalyses = decision.remainingAnalyses;
      }
      if (decision.annualAccessUntilMs) response.access.annualAccessUntilMs = decision.annualAccessUntilMs;
      if (decision.freeRemainingAnalyses != null) {
        response.access.freeRemainingAnalyses = decision.freeRemainingAnalyses;
      }

      const usage = {
        idempotencyKey,
        source: decision.source,
        result: "approved",
        createdAtMs: nowMs,
      };
      if (actor) usage.uid = actor.uid;
      if (decision.codeId) usage.codeId = decision.codeId;
      if (decision.eventId) usage.eventId = decision.eventId;
      transaction.set(usageRef, usage);
      transaction.set(this._adminAuditRef(`usage_${usageRef.id}`), {
        action: "analysis-approved",
        actorUid: actor ? actor.uid : null,
        usageId: usageRef.id,
        source: decision.source,
        codeId: decision.codeId || null,
        eventId: decision.eventId || null,
        occurredAtMs: nowMs,
      });
      transaction.set(idempotencyRef, {
        actorUid: caller ? caller.uid : "guest",
        requestFingerprint,
        response,
        usageId: usageRef.id,
        createdAtMs: nowMs,
      });
      return response;
    });
  }

  async linkCode(request) {
    const actor = this._requireVerifiedAccount(request);
    const data = requireObject(request && request.data || {}, "data");
    const codeId = this._codeId(data.code);
    const nowMs = this.nowMs();
    const userRef = this._userRef(actor.uid);
    const codeRef = this._codeRef(codeId);

    return this.db.runTransaction(async (transaction) => {
      const [userSnapshot, codeSnapshot] = await Promise.all([
        transaction.get(userRef),
        transaction.get(codeRef),
      ]);
      if (!codeSnapshot.exists) {
        throw new AccessError("not-found", "The analysis code was not found.");
      }
      const code = safeData(codeSnapshot);
      const summary = codeSummary(codeId, code, nowMs);
      if (!summary.usable) {
        throw new AccessError("failed-precondition", "The analysis code is not available.");
      }

      const user = this._buildUserDocument(safeData(userSnapshot), actor, nowMs, nowMs);
      const alreadyLinked = user.linkedCodeIds.includes(codeId);
      if (!alreadyLinked && user.linkedCodeIds.length >= MAX_LINKED_CODES_PER_USER) {
        throw new AccessError(
          "resource-exhausted",
          `A user may link at most ${MAX_LINKED_CODES_PER_USER} analysis codes.`,
        );
      }
      if (!alreadyLinked) {
        user.linkedCodeIds.push(codeId);
        transaction.set(codeRef, {
          linkedUsersCount: (Number.isInteger(code.linkedUsersCount) ? code.linkedUsersCount : 0) + 1,
          updatedAtMs: nowMs,
        }, {merge: true});
      }
      transaction.set(userRef, user, {merge: true});
      return {
        linked: true,
        alreadyLinked,
        code: summary,
      };
    });
  }

  async createCode(request) {
    const actor = this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const nowMs = this.nowMs();
    const reason = requiredReason(data.reason);
    const credits = requiredInteger(data.credits, "credits", 1, MAX_CODE_CREDITS);
    const label = data.label == null ? "Analysekode" : optionalTrimmedString(data.label, "label", 120);
    const expiresAtMs = optionalFutureMillis(data.expiresAtMs, "expiresAtMs", nowMs);
    if (data.active != null && typeof data.active !== "boolean") {
      throw new AccessError("invalid-argument", "active must be true or false.");
    }
    const active = data.active !== false;
    const rawCode = data.code == null ? randomCode() : optionalTrimmedString(data.code, "code", 128);
    const normalizedCode = normaliseCode(rawCode);
    const codeId = codeIdFor(normalizedCode, this.codePepper);
    const codeRef = this._codeRef(codeId);

    return this.db.runTransaction(async (transaction) => {
      const existing = await transaction.get(codeRef);
      if (existing.exists) {
        throw new AccessError("already-exists", "This analysis code already exists.");
      }
      const code = {
        label,
        initialAnalyses: credits,
        remainingAnalyses: credits,
        usedAnalyses: 0,
        linkedUsersCount: 0,
        active,
        createdAtMs: nowMs,
        createdByUid: actor.uid,
        updatedAtMs: nowMs,
      };
      if (expiresAtMs != null) code.expiresAtMs = expiresAtMs;
      transaction.set(codeRef, code);
      transaction.set(this._adminAuditRef(`code_created_${codeId}_${nowMs}`), {
        action: "code-created",
        actorUid: actor.uid,
        codeId,
        after: {label, credits, active, expiresAtMs: expiresAtMs || null},
        reason: reason || null,
        occurredAtMs: nowMs,
      });
      return {
        code: rawCode,
        codeId,
        label,
        initialAnalyses: credits,
        remainingAnalyses: credits,
        active,
        expiresAtMs: expiresAtMs || null,
      };
    });
  }

  async setConfig(request) {
    const actor = this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const nowMs = this.nowMs();
    const reason = requiredReason(data.reason);
    const configRef = this._configRef();
    const requestedFields = ["freeAnalysisLimit", "freePeriodDays", "offerEnabled"];
    if (!requestedFields.some((field) => Object.prototype.hasOwnProperty.call(data, field))) {
      throw new AccessError("invalid-argument", "Provide at least one configuration field.");
    }
    if (Object.prototype.hasOwnProperty.call(data, "offerEnabled") &&
      typeof data.offerEnabled !== "boolean") {
      throw new AccessError("invalid-argument", "offerEnabled must be true or false.");
    }

    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(configRef);
      const candidate = Object.assign({}, safeData(snapshot));
      const before = normaliseConfig(candidate);
      for (const field of requestedFields) {
        if (Object.prototype.hasOwnProperty.call(data, field)) candidate[field] = data[field];
      }
      const config = normaliseConfig(candidate);
      transaction.set(configRef, Object.assign({}, config, {
        updatedAtMs: nowMs,
        updatedByUid: actor.uid,
      }), {merge: true});
      transaction.set(this._adminAuditRef(`config_${nowMs}`), {
        action: "config-updated",
        actorUid: actor.uid,
        before,
        after: config,
        reason: reason || null,
        occurredAtMs: nowMs,
      });
      return {config};
    });
  }

  async upsertEvent(request) {
    const actor = this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const nowMs = this.nowMs();
    const reason = requiredReason(data.reason);
    const eventId = data.eventId == null ? `event_${crypto.randomUUID()}` : requireId(data.eventId, "eventId");
    const eventRef = this._eventRef(eventId);
    const name = optionalTrimmedString(data.name, "name", 160);
    const description = optionalTrimmedString(data.description, "description", 500);
    const startAtMs = requiredInteger(data.startAtMs, "startAtMs", 1, Number.MAX_SAFE_INTEGER);
    const endAtMs = requiredInteger(data.endAtMs, "endAtMs", 1, Number.MAX_SAFE_INTEGER);
    if (endAtMs <= startAtMs) {
      throw new AccessError("invalid-argument", "endAtMs must be after startAtMs.");
    }
    const goalLatitude = requiredFiniteNumber(data.goalLatitude, "goalLatitude", -90, 90);
    const goalLongitude = requiredFiniteNumber(data.goalLongitude, "goalLongitude", -180, 180);
    const radiusMeters = requiredInteger(data.radiusMeters, "radiusMeters", 1, 50000);
    if (data.active != null && typeof data.active !== "boolean") {
      throw new AccessError("invalid-argument", "active must be true or false.");
    }

    return this.db.runTransaction(async (transaction) => {
      const existing = await transaction.get(eventRef);
      const current = safeData(existing);
      const event = {
        name,
        description: description || null,
        startAtMs,
        endAtMs,
        goalLatitude,
        goalLongitude,
        radiusMeters,
        active: data.active == null ? current.active !== false : data.active === true,
        createdAtMs: Number.isInteger(current.createdAtMs) ? current.createdAtMs : nowMs,
        updatedAtMs: nowMs,
      };
      transaction.set(eventRef, event, {merge: true});
      transaction.set(this.db.collection(COLLECTIONS.adminAudit).doc(`event_${eventId}_${nowMs}`), {
        action: existing.exists ? "event-updated" : "event-created",
        actorUid: actor.uid,
        eventId,
        before: current,
        after: event,
        reason: reason || null,
        occurredAtMs: nowMs,
      });
      return {
        event: Object.assign({id: eventId}, publicEvent(eventId, event), {
          active: event.active,
          usedAnalyses: 0,
        }),
      };
    });
  }

  async grantAnnualAccess(request) {
    const actor = this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const nowMs = this.nowMs();
    const revoke = data.revoke === true;
    const accessUntilMs = revoke ? null : optionalFutureMillis(data.accessUntilMs, "accessUntilMs", nowMs);
    const reason = requiredReason(data.reason);
    const targetUid = data.uid == null ? undefined : requireId(data.uid, "uid");
    const targetEmail = data.email == null ? undefined : optionalTrimmedString(data.email, "email", 320);
    if ((targetUid && targetEmail) || (!targetUid && !targetEmail)) {
      throw new AccessError("invalid-argument", "Provide exactly one of uid or email.");
    }
    if (!this.auth || typeof this.auth.getUser !== "function" || typeof this.auth.getUserByEmail !== "function") {
      throw new AccessError("failed-precondition", "Firebase Authentication is unavailable.");
    }

    const target = targetUid ?
      await this.auth.getUser(targetUid) :
      await this.auth.getUserByEmail(targetEmail);
    const targetActor = {
      uid: target.uid,
      email: typeof target.email === "string" ? target.email : undefined,
      displayName: typeof target.displayName === "string" ? target.displayName : undefined,
      token: {},
    };
    const userRef = this._userRef(target.uid);

    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      const user = this._buildUserDocument(safeData(snapshot), targetActor, nowMs, nowMs);
      const before = Number.isInteger(user.annualAccessUntilMs) ? user.annualAccessUntilMs : null;
      user.annualAccessUntilMs = accessUntilMs;
      user.annualAccessGrantedAtMs = nowMs;
      user.annualAccessGrantedByUid = actor.uid;
      transaction.set(userRef, user, {merge: true});
      transaction.set(this._adminAuditRef(`annual_${target.uid}_${nowMs}`), {
        action: revoke ? "annual-access-revoked" : "annual-access-granted",
        actorUid: actor.uid,
        targetUid: target.uid,
        before: {annualAccessUntilMs: before},
        after: {annualAccessUntilMs: accessUntilMs},
        reason: reason || null,
        occurredAtMs: nowMs,
      });
      return {
        uid: target.uid,
        email: user.email || null,
        annualAccessUntilMs: accessUntilMs,
      };
    });
  }

  async grantBonusAnalyses(request) {
    const actor = this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const nowMs = this.nowMs();
    const creditsDelta = requiredInteger(data.creditsDelta, "creditsDelta", -MAX_CODE_CREDITS, MAX_CODE_CREDITS);
    if (creditsDelta === 0) throw new AccessError("invalid-argument", "creditsDelta may not be zero.");
    const reason = requiredReason(data.reason);
    const targetUid = data.uid == null ? undefined : requireId(data.uid, "uid");
    const targetEmail = data.email == null ? undefined : optionalTrimmedString(data.email, "email", 320);
    if ((targetUid && targetEmail) || (!targetUid && !targetEmail)) {
      throw new AccessError("invalid-argument", "Provide exactly one of uid or email.");
    }
    const target = targetUid ? await this.auth.getUser(targetUid) : await this.auth.getUserByEmail(targetEmail);
    const targetActor = {uid: target.uid, email: target.email, displayName: target.displayName, token: {}};
    const userRef = this._userRef(target.uid);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      const user = this._buildUserDocument(safeData(snapshot), targetActor, nowMs, nowMs);
      const before = user.bonusAnalysesRemaining;
      user.bonusAnalysesRemaining = Math.max(0, before + creditsDelta);
      transaction.set(userRef, user, {merge: true});
      transaction.set(this._adminAuditRef(`bonus_${target.uid}_${nowMs}`), {
        action: "bonus-analyses-adjusted",
        actorUid: actor.uid,
        targetUid: target.uid,
        before: {bonusAnalysesRemaining: before},
        after: {bonusAnalysesRemaining: user.bonusAnalysesRemaining},
        reason: reason || null,
        occurredAtMs: nowMs,
      });
      return {uid: target.uid, email: user.email || null, bonusAnalysesRemaining: user.bonusAnalysesRemaining};
    });
  }

  async updateCode(request) {
    const actor = this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const nowMs = this.nowMs();
    const codeId = requireId(data.codeId, "codeId");
    const reason = optionalTrimmedString(data.reason, "reason", 500);
    if (data.active != null && typeof data.active !== "boolean") {
      throw new AccessError("invalid-argument", "active must be true or false.");
    }
    const creditsDelta = data.creditsDelta == null ? 0 :
      requiredInteger(data.creditsDelta, "creditsDelta", -MAX_CODE_CREDITS, MAX_CODE_CREDITS);
    const expiresAtMs = Object.prototype.hasOwnProperty.call(data, "expiresAtMs") ?
      (data.expiresAtMs == null ? null : optionalFutureMillis(data.expiresAtMs, "expiresAtMs", nowMs)) : undefined;
    const codeRef = this._codeRef(codeId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(codeRef);
      if (!snapshot.exists) throw new AccessError("not-found", "The analysis code was not found.");
      const before = safeData(snapshot);
      const after = Object.assign({}, before, {updatedAtMs: nowMs});
      if (data.active != null) after.active = data.active;
      if (creditsDelta !== 0) {
        after.remainingAnalyses = Math.max(0, (Number.isInteger(before.remainingAnalyses) ? before.remainingAnalyses : 0) + creditsDelta);
        after.initialAnalyses = Math.max(after.remainingAnalyses, (Number.isInteger(before.initialAnalyses) ? before.initialAnalyses : 0) + Math.max(0, creditsDelta));
      }
      if (expiresAtMs !== undefined) {
        if (expiresAtMs === null) delete after.expiresAtMs;
        else after.expiresAtMs = expiresAtMs;
      }
      transaction.set(codeRef, after);
      transaction.set(this._adminAuditRef(`code_updated_${codeId}_${nowMs}`), {
        action: "code-updated", actorUid: actor.uid, codeId,
        before: {active: before.active !== false, remainingAnalyses: before.remainingAnalyses || 0, expiresAtMs: before.expiresAtMs || null},
        after: {active: after.active !== false, remainingAnalyses: after.remainingAnalyses || 0, expiresAtMs: after.expiresAtMs || null},
        reason: reason || null, occurredAtMs: nowMs,
      });
      return Object.assign({id: codeId}, codeSummary(codeId, after, nowMs), {
        initialAnalyses: after.initialAnalyses || 0,
        usedAnalyses: after.usedAnalyses || 0,
        linkedUsersCount: after.linkedUsersCount || 0,
      });
    });
  }

  async getAdminUsage(request) {
    this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const limit = data.limit == null ? 50 : requiredInteger(data.limit, "limit", 1, MAX_ADMIN_LIST_LIMIT);
    const fromAtMs = data.fromAtMs == null ? 0 : requiredInteger(data.fromAtMs, "fromAtMs", 0, Number.MAX_SAFE_INTEGER);
    const toAtMs = data.toAtMs == null ? Number.MAX_SAFE_INTEGER : requiredInteger(data.toAtMs, "toAtMs", fromAtMs, Number.MAX_SAFE_INTEGER);
    const filterType = data.filterType == null ? undefined : optionalTrimmedString(data.filterType, "filterType", 20);
    const filterId = data.filterId == null ? undefined : requireId(data.filterId, "filterId");
    const cursorAtMs = data.cursorAtMs == null ? undefined : requiredInteger(data.cursorAtMs, "cursorAtMs", 1, Number.MAX_SAFE_INTEGER);
    const cursorId = data.cursorId == null ? undefined : requireId(data.cursorId, "cursorId");
    if (filterType && (!["user", "code", "event"].includes(filterType) || !filterId)) {
      throw new AccessError("invalid-argument", "Provide a valid history filter and ID.");
    }
    let query = this.db.collection(COLLECTIONS.usage);
    query = query.where("createdAtMs", ">=", fromAtMs)
      .where("createdAtMs", "<=", toAtMs);
    if (filterType) {
      query = query.where(filterType === "user" ? "uid" : `${filterType}Id`, "==", filterId);
    }
    query = query.orderBy("createdAtMs", "desc");
    if (cursorId) {
      const cursor = await this.db.collection(COLLECTIONS.usage).doc(cursorId).get();
      if (!cursor.exists) throw new AccessError("invalid-argument", "History cursor no longer exists.");
      query = query.startAfter(cursor);
    } else if (cursorAtMs) {
      query = query.where("createdAtMs", "<", cursorAtMs);
    }
    query = query.limit(limit + 1);
    const snapshot = await query.get();
    const rows = snapshot.docs.map((doc) => Object.assign({id: doc.id}, safeData(doc)))
      .filter((row) => Number.isInteger(row.createdAtMs) && row.createdAtMs >= fromAtMs && row.createdAtMs <= toAtMs)
      .filter((row) => cursorId || !cursorAtMs || row.createdAtMs < cursorAtMs)
      .filter((row) => {
        if (!filterType) return true;
        const field = filterType === "user" ? "uid" : `${filterType}Id`;
        return row[field] === filterId;
      })
      .sort((left, right) => right.createdAtMs - left.createdAtMs)
      .slice(0, limit);
    const hasNextPage = snapshot.docs.length > limit && rows.length > 0;
    const userIds = uniqueStrings(rows.map((row) => row.uid));
    const codeIds = uniqueStrings(rows.map((row) => row.codeId));
    const eventIds = uniqueStrings(rows.map((row) => row.eventId));
    const [users, codes, events] = await Promise.all([
      userIds.length ? this.db.getAll(...userIds.map((id) => this._userRef(id))) : [],
      codeIds.length ? this.db.getAll(...codeIds.map((id) => this._codeRef(id))) : [],
      eventIds.length ? this.db.getAll(...eventIds.map((id) => this._eventRef(id))) : [],
    ]);
    const userById = new Map(users.map((doc) => [doc.id, safeData(doc)]));
    const codeById = new Map(codes.map((doc) => [doc.id, safeData(doc)]));
    const eventById = new Map(events.map((doc) => [doc.id, safeData(doc)]));
    return {
      entries: rows.map((row) => ({
        id: row.id, createdAtMs: row.createdAtMs, source: row.source,
        result: row.result || "approved", uid: row.uid || null,
        userLabel: row.uid ? (userById.get(row.uid).displayName || userById.get(row.uid).email || row.uid) : "Anonym gjest",
        codeId: row.codeId || null, codeLabel: row.codeId ? (codeById.get(row.codeId).label || "Analysekode") : null,
        eventId: row.eventId || null, eventName: row.eventId ? (eventById.get(row.eventId).name || "Arrangement") : null,
      })),
      nextCursorAtMs: hasNextPage ? rows.at(-1).createdAtMs : null,
      nextCursorId: hasNextPage ? rows.at(-1).id : null,
    };
  }

  async getAdminAudit(request) {
    this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const limit = data.limit == null ? 50 : requiredInteger(data.limit, "limit", 1, MAX_ADMIN_LIST_LIMIT);
    let query = this.db.collection(COLLECTIONS.adminAudit);
    if (typeof query.orderBy === "function") query = query.orderBy("occurredAtMs", "desc");
    if (typeof query.limit === "function") query = query.limit(limit);
    const snapshot = await query.get();
    return {entries: snapshot.docs.map((doc) => Object.assign({id: doc.id}, safeData(doc)))};
  }

  async getAdminOverview(request) {
    this._requireAdmin(request);
    const data = requireObject(request && request.data || {}, "data");
    const limit = data.limit == null ? 25 : requiredInteger(data.limit, "limit", 1, MAX_ADMIN_LIST_LIMIT);
    const nowMs = this.nowMs();
    const getRecent = async (collection, orderField) => {
      let query = this.db.collection(collection);
      if (typeof query.orderBy === "function") query = query.orderBy(orderField, "desc");
      if (typeof query.limit === "function") query = query.limit(limit);
      return query.get();
    };
    const [configSnapshot, overviewSnapshot, daySnapshot, codeSnapshot, eventSnapshot, userSnapshot] = await Promise.all([
      this._configRef().get(),
      this._statsRef("overview").get(),
      this._statsRef(`day_${dateKeyFor(nowMs)}`).get(),
      getRecent(COLLECTIONS.codes, "updatedAtMs"),
      getRecent(COLLECTIONS.events, "updatedAtMs"),
      getRecent(COLLECTIONS.users, "updatedAtMs"),
    ]);
    const codes = codeSnapshot.docs.map((snapshot) => Object.assign(
      {id: snapshot.id},
      codeSummary(snapshot.id, safeData(snapshot), nowMs),
      {
        initialAnalyses: safeData(snapshot).initialAnalyses || 0,
        usedAnalyses: safeData(snapshot).usedAnalyses || 0,
        linkedUsersCount: safeData(snapshot).linkedUsersCount || 0,
      },
    ));
    const eventStatsSnapshots = eventSnapshot.docs.length && typeof this.db.getAll === "function" ?
      await this.db.getAll(...eventSnapshot.docs.map((snapshot) => this._eventStatsRef(snapshot.id))) : [];
    const eventStatsById = new Map(eventStatsSnapshots.map((snapshot) => [snapshot.id, safeData(snapshot)]));
    const events = eventSnapshot.docs.map((snapshot) => {
      const event = safeData(snapshot);
      const eventStats = eventStatsById.get(snapshot.id) || {};
      return Object.assign({id: snapshot.id}, publicEvent(snapshot.id, event), {
        active: event.active !== false,
        usedAnalyses: Number.isInteger(eventStats.usedAnalyses) ? eventStats.usedAnalyses : 0,
      });
    });
    const users = userSnapshot.docs.map((snapshot) => {
      const user = safeData(snapshot);
      return {
        uid: snapshot.id,
        email: typeof user.email === "string" ? user.email : null,
        displayName: typeof user.displayName === "string" ? user.displayName : null,
        totalAnalyses: Number.isInteger(user.totalAnalyses) ? user.totalAnalyses : 0,
        usageBySource: sourceCounts(user.usageBySource),
        freeAnalysesUsed: Number.isInteger(user.freeAnalysesUsed) ? user.freeAnalysesUsed : 0,
        annualAccessUntilMs: Number.isInteger(user.annualAccessUntilMs) ? user.annualAccessUntilMs : null,
        bonusAnalysesRemaining: Number.isInteger(user.bonusAnalysesRemaining) ? user.bonusAnalysesRemaining : 0,
        lastAnalysisAtMs: Number.isInteger(user.lastAnalysisAtMs) ? user.lastAnalysisAtMs : null,
      };
    });
    return {
      generatedAtMs: nowMs,
      config: normaliseConfig(safeData(configSnapshot)),
      overview: {
        totalAnalyses: Number.isInteger(safeData(overviewSnapshot).totalAnalyses) ?
          safeData(overviewSnapshot).totalAnalyses : 0,
        usageBySource: sourceCounts(safeData(overviewSnapshot).usageBySource),
        today: {
          dateKey: dateKeyFor(nowMs),
          totalAnalyses: Number.isInteger(safeData(daySnapshot).totalAnalyses) ?
            safeData(daySnapshot).totalAnalyses : 0,
          usageBySource: sourceCounts(safeData(daySnapshot).usageBySource),
        },
      },
      codes,
      events,
      users,
    };
  }
}

module.exports = {
  AccessError,
  COLLECTIONS,
  DEFAULT_CONFIG,
  RundeanalyseAccessService,
  codeIdFor,
  dateKeyFor,
  haversineMeters,
  normaliseCode,
};
