const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const firestoreModule = require("firebase-admin/firestore");
const axios = require("axios");
const crypto = require("node:crypto");
const {normalizeParticipants, timingPage, sourceError} = require("./import-source");
const {LEASE_MS, claimDecision, ownsLease} = require("./import-job-state");
const {execution, assertWriteLease, assertExecutionBudget} = require("./import-execution");
const {cachedSource} = require("./import-source-cache");
const {recoveryDecision, INITIALIZATION_TIMEOUT_MS,
  canFinalizeInitialization} = require("./import-recovery");
const {verifyChunk} = require("./import-completeness");
const {buildBiathlonAggregates, compatibilityTopHalf} =
  require("./biathlon-aggregate");

const FUNCTION_REGION = "europe-west1";
const PROJECT_ID = process.env.GCLOUD_PROJECT ||
  process.env.GCP_PROJECT ||
  (process.env.NODE_ENV === "test" ? undefined : "time-plotting");
const RUNTIME_SERVICE_ACCOUNT = process.env.FUNCTIONS_RUNTIME_SERVICE_ACCOUNT ||
  `eq-import-runtime@${PROJECT_ID}.iam.gserviceaccount.com`;
const TASKS_SERVICE_ACCOUNT = process.env.TASKS_SERVICE_ACCOUNT_EMAIL ||
  `import-tasks@${PROJECT_ID}.iam.gserviceaccount.com`;
const MAX_EXTERNAL_RESPONSE_BYTES = 12 * 1024 * 1024;
const MAX_STATION_PAGES = 100;
const MAX_STATION_ITEMS = 100000;
const FieldValue = admin.firestore && admin.firestore.FieldValue ||
  firestoreModule.FieldValue;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.name = "HttpError";
    this.status = status;
  }
}

function sendHandlerError(res, error, context) {
  if (error instanceof HttpError) {
    res.status(error.status).json({error: error.message});
    return;
  }

  console.error(context, error && error.stack || error && error.message || String(error));
  res.status(500).json({error: "Internal server error"});
}

let appInitialized = false;
let db = null;

function ensureInitialized() {
  if (appInitialized) return;
  admin.initializeApp();
  appInitialized = true;
}

function getDb() {
  ensureInitialized();
  if (!db) {
    db = typeof admin.firestore === "function" ?
      admin.firestore() : firestoreModule.getFirestore();
  }
  return db;
}

function sanitizeForFirestore(value) {
  if (value == null) return undefined;
  if (typeof value === "string" && value.trim() === "") return undefined;
  if (typeof value === "object" && value &&
    (value._methodName || value.constructor && value.constructor.name === "FieldValue")) {
    return value;
  }
  if (Array.isArray(value)) {
    const values = value
      .map(sanitizeForFirestore)
      .filter((item) => item !== undefined);
    return values.length ? values : undefined;
  }
  if (typeof value === "object" &&
    !(value instanceof Date) &&
    !(value && typeof value.isEqual === "function")) {
    const entries = Object.entries(value)
      .map(([key, item]) => [key, sanitizeForFirestore(item)])
      .filter(([, item]) => item !== undefined);
    return entries.length ? Object.fromEntries(entries) : undefined;
  }
  return value;
}

function resultProfileOverrides() {
  const raw = process.env.RESULT_PROFILE_OVERRIDES;
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (error) {
    console.warn(
      "Ignoring invalid RESULT_PROFILE_OVERRIDES JSON",
      error && error.message || String(error),
    );
    return {};
  }
}

function isBiathlonEvent(event) {
  const sport = event && event.Gren ? event.Gren : {};
  const discipline = event && event.Disiplin ? event.Disiplin : {};
  const parent = sport.Parent && typeof sport.Parent === "object" ? sport.Parent : {};
  const identifiers = [
    sport.Kode,
    sport.Code,
    sport.Navn,
    sport.Name,
    parent.Kode,
    parent.Code,
    parent.Navn,
    parent.Name,
    discipline.Navn,
    discipline.Name,
  ].filter((value) => value != null).map((value) => String(value).trim().toLowerCase());
  if (identifiers.some((value) =>
    value === "bt" || value === "bia" || value.includes("skiskyt") || value.includes("biathlon"))) {
    return true;
  }

  return Object.values(event && event.Stasjoner || {}).some((station) => {
    if (!station || typeof station !== "object") return false;
    if (station.ErSkyting === true || station.IsShooting === true) return true;
    const setups = station.StasjonsOppsett || station.stationSetups || {};
    return Object.values(setups).some((setup) => {
      if (!setup || typeof setup !== "object") return false;
      if (setup.ErSkyting === true || setup.IsShooting === true) return true;
      const code = String(firstDefined(setup.Navn, setup.Name, setup.Kode, setup.Code, "")).trim();
      return /^(?:INS|UTS)0*\d+$/i.test(code);
    });
  });
}

function isRelayStage(event, etappe) {
  const discipline = event && event.Disiplin ? event.Disiplin : {};
  const disciplineCode = String(discipline.Kode || "").toUpperCase();
  const disciplineName = String(discipline.Navn || "").toLowerCase();
  const stageType = String(etappe && etappe.Type || "").toLowerCase();
  return disciplineCode === "RL" ||
    disciplineName.includes("relay") ||
    disciplineName.includes("stafett") ||
    stageType.includes("relay") ||
    stageType.includes("stafett");
}

function classifyResultProfile(event, etappe, explicitOverride) {
  if (explicitOverride) {
    return {profile: explicitOverride, determinedBy: "override"};
  }
  const discipline = event && event.Disiplin ? event.Disiplin : {};
  const disciplineCode = String(discipline.Kode || "").toUpperCase();
  const disciplineName = String(discipline.Navn || "").toLowerCase();
  const stageType = String(etappe && etappe.Type || "").toLowerCase();

  if (isBiathlonEvent(event)) return {profile: "biathlon", determinedBy: "eq"};
  if (isRelayStage(event, etappe)) {
    return {profile: "relay", determinedBy: "eq"};
  }
  if (stageType === "heats" || disciplineName.includes("sprint")) {
    return {profile: "sprint", determinedBy: "eq"};
  }
  return {profile: "standard", determinedBy: "eq"};
}

function profileForStage(event, eventId, etappeUid, explicitOverride) {
  const overrides = resultProfileOverrides();
  const eventOverride = overrides[String(eventId)];
  const override = explicitOverride ||
    (eventOverride && eventOverride.stages && eventOverride.stages[String(etappeUid)]) ||
    (typeof eventOverride === "string" ? eventOverride : eventOverride && eventOverride.profile);
  const etappe = event && event.Etapper ? event.Etapper[String(etappeUid)] : null;
  return classifyResultProfile(event, etappe, override);
}

/**
 * Fetch JSON with browser-like headers.
 */
async function fetchJson(url) {
  return cachedSource(url, fetchJsonUncached, batchSetDocs);
}

async function fetchJsonUncached(url) {
  const parsedUrl = new URL(url);
  if (process.env.NODE_ENV !== "test" &&
    (parsedUrl.protocol !== "https:" || parsedUrl.hostname !== "live.eqtiming.com" ||
    !parsedUrl.pathname.startsWith("/api/"))) {
    throw new Error("EQ Timing URL is not allowed");
  }

  const r = await axios.get(parsedUrl.toString(), {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
      "Accept": "application/json,text/plain,*/*",
      "Referer": "https://live.eqtiming.com/",
    },
    timeout: 30000,
    maxContentLength: MAX_EXTERNAL_RESPONSE_BYTES,
    maxBodyLength: MAX_EXTERNAL_RESPONSE_BYTES,
    validateStatus: (s) => s >= 200 && s < 400,
  });
  let responseBytes = 0;
  try {
    responseBytes = Buffer.byteLength(JSON.stringify(r.data));
  } catch (error) {
    throw new Error("EQ Timing returned an unreadable response");
  }
  if (responseBytes > MAX_EXTERNAL_RESPONSE_BYTES) {
    throw new Error("EQ Timing response is too large");
  }
  if (/^\/api\/Contestants\/\d+\/?$/.test(parsedUrl.pathname) &&
    !parsedUrl.searchParams.has("passes")) {
    return normalizeParticipants(r.data);
  }
  return r.data;
}
async function fetchAllForStation(baseUrl, stationUid, includeParticipants = false) {
  const pageSize = 1000;
  let startAt = 1;
  let all = [];
  let pageCount = 0;
  const seenPages = new Set();
  let expectedTotal = null;

  while (true) {
    pageCount++;
    if (pageCount > MAX_STATION_PAGES) {
      throw new Error("EQ Timing returned too many pages");
    }
    const pageUrl = new URL(withStation(baseUrl, stationUid, startAt, pageSize));
    if (includeParticipants) pageUrl.searchParams.set("justTimeData", "false");
    const url = pageUrl.toString();
    const data = await fetchJson(url);

    const {items, total} = timingPage(data);
    if (total != null) {
      if (expectedTotal != null && expectedTotal !== total) {
        throw sourceError("TIMING_TOTAL_CHANGED");
      }
      expectedTotal = total;
    }
    if (items.length) {
      const fingerprint = crypto.createHash("sha256").update(JSON.stringify(items)).digest("hex");
      if (seenPages.has(fingerprint)) throw sourceError("REPEATED_TIMING_PAGE");
      seenPages.add(fingerprint);
    }

    if (!items || items.length === 0) break;

    all = all.concat(items);
    if (all.length > MAX_STATION_ITEMS) {
      throw new Error("EQ Timing returned too many timing rows");
    }

    // hvis færre enn pageSize, ferdig
    if (items.length < pageSize) break;

    startAt += pageSize;
  }

  if (expectedTotal != null && all.length !== expectedTotal) {
    throw sourceError("INCOMPLETE_TIMING_RESPONSE");
  }
  return all;
}

function buildContestantsPassesUrl(eventId, etappeUid) {
  const u = new URL(`https://live.eqtiming.com/api/Contestants/${eventId}`);
  u.searchParams.set("passes", "true");
  if (etappeUid != null) u.searchParams.set("raceId", String(etappeUid));
  u.searchParams.set("proxykey", String(Date.now()));
  return u.toString();
}

function getEtappeUidFromEtappeDeltaker(ed) {
  return toNumberOrNull(
    (ed && ed.Etappe && ed.Etappe.UID != null) ? ed.Etappe.UID :
    (ed && ed.Pulje && ed.Pulje.EtappeUID != null) ? ed.Pulje.EtappeUID :
    null
  );
}

function collectTimeItemsFromParticipantPasses(participantsWithPasses, classId, etappeUid) {
  const items = [];

  for (const [pidStr, p] of getParticipantEntries(participantsWithPasses)) {
    if (!p || typeof p !== "object") continue;

    const participantClassUid = getParticipantClassUid(p);
    if (participantClassUid == null || participantClassUid !== Number(classId)) {
      continue;
    }

    const edMap = p.EtappeDeltaker && typeof p.EtappeDeltaker === "object" ?
      p.EtappeDeltaker :
      {};

    for (const [edUidStr, ed] of Object.entries(edMap)) {
      if (!ed || typeof ed !== "object") continue;

      const edUid = toNumberOrNull(firstDefined(ed.UID, edUidStr));
      if (edUid == null) continue;

      const edEtappeUid = getEtappeUidFromEtappeDeltaker(ed);
      if (etappeUid != null && edEtappeUid != null &&
        edEtappeUid !== Number(etappeUid)) {
        continue;
      }

      const passeringer = ed.Passeringer;
      if (!passeringer || typeof passeringer !== "object") continue;
      if (Object.keys(passeringer).length === 0) continue;

      const participantUid = toNumberOrNull(firstDefined(p.UID, pidStr));
      const passes = Array.isArray(passeringer) ?
        passeringer :
        Object.values(passeringer);

      for (const pass of passes) {
        if (!pass || typeof pass !== "object") continue;
        items.push(Object.assign({}, pass, {
          ParticipantUID: participantUid,
          EtappeDeltakerUID: edUid,
        }));
      }
    }
  }

  return items;
}

async function fetchParticipantPassTimeItems(eventId, classId, etappeUid) {
  if (eventId == null || classId == null) return {items: [], url: null, error: null};

  const url = buildContestantsPassesUrl(eventId, etappeUid);
  try {
    const payload = await fetchJson(url);
    return {
      items: collectTimeItemsFromParticipantPasses(payload, classId, etappeUid),
      url,
      error: null,
    };
  } catch (e) {
    return {
      items: [],
      url,
      error: "EQ Timing request failed",
    };
  }
}
function withStation(baseUrl, stationUid, startAt, count) {
  const u = new URL(baseUrl);
  if (stationUid == null) {
    u.searchParams.delete("station");
  } else {
    u.searchParams.set("station", String(stationUid));
  }
  u.searchParams.set("passes", "true");
  u.searchParams.set("justTimeData", "true");
  u.searchParams.set("startAt", String(startAt));
  u.searchParams.set("count", String(count));
  u.searchParams.set("proxykey", String(Math.floor(Date.now() / 1000)));
  // behold sortpoint/round/query hvis de finnes
  return u.toString();
}
async function batchSetDocs(docWrites) {
  if (execution.getStore()) {
    const context = execution.getStore();
    for (let index = 0; index < docWrites.length;) {
      const chunk = [];
      let bytes = 0;
      while (index < docWrites.length && chunk.length < 50) {
        const size = Buffer.byteLength(JSON.stringify(docWrites[index].data));
        if (size > 800000) throw sourceError("RESULT_DOCUMENT_TOO_LARGE");
        if (chunk.length && bytes + size > 4 * 1024 * 1024) break;
        bytes += size;
        chunk.push(docWrites[index++]);
      }
      const receiptKey = crypto.createHash("sha256").update(JSON.stringify(
        chunk.map((write) => ({path: write.ref.path, data: write.data})),
      )).digest("hex");
      const receiptRef = context.runId ? context.jobRef.collection("runs")
        .doc(context.runId).collection("writeReceipts").doc(receiptKey) : null;
      if (receiptRef && (await receiptRef.get()).exists) continue;
      assertExecutionBudget();
      await getDb().runTransaction(async (transaction) => {
        await assertWriteLease(transaction);
        for (const write of chunk) {
          transaction.set(write.ref, sanitizeForFirestore(write.data) || {}, {merge: true});
        }
        if (receiptRef) transaction.set(receiptRef, {complete: true});
      });
    }
    return;
  }
  const MAX = 50;
  const dbClient = getDb();
  let batch = dbClient.batch();
  let count = 0;

  for (const w of docWrites) {
    batch.set(w.ref, sanitizeForFirestore(w.data) || {}, { merge: true });
    count++;
    if (count >= MAX) {
      await batch.commit();
      batch = dbClient.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
}

async function batchDeleteDocs(docRefs) {
  if (execution.getStore()) {
    for (let index = 0; index < docRefs.length; index += 100) {
      assertExecutionBudget();
      await getDb().runTransaction(async (transaction) => {
        await assertWriteLease(transaction);
        for (const ref of docRefs.slice(index, index + 100)) transaction.delete(ref);
      });
    }
    return;
  }
  const MAX = 100;
  const dbClient = getDb();
  let batch = dbClient.batch();
  let count = 0;

  for (const ref of docRefs) {
    batch.delete(ref);
    count++;
    if (count >= MAX) {
      await batch.commit();
      batch = dbClient.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
}

async function setImportDocument(ref, data, options) {
  if (!execution.getStore()) return ref.set(data, options);
  return getDb().runTransaction(async (transaction) => {
    await assertWriteLease(transaction);
    transaction.set(ref, data, options);
  });
}

async function publishBiathlonAggregates(classRef, aggregates, preserveOld) {
  if (preserveOld) return;
  const collection = classRef.collection("aggregateProfiles");
  const profiles = aggregates ? [aggregates.all, aggregates.topHalf] : [];
  const publications = [];
  for (const profile of profiles) {
    const root = collection.doc(profile.kind);
    const serialized = Buffer.byteLength(JSON.stringify(profile));
    if (serialized <= 600000) {
      publications.push({root, data: profile, sections: []});
      continue;
    }
    const data = {...profile, timingPoints: {}, shootingPasses: {}, laps: {},
      sections: {}};
    const sections = [];
    for (const field of ["timingPoints", "shootingPasses", "laps"]) {
      let part = {};
      let partBytes = 2;
      let ordinal = 0;
      const flush = () => {
        if (!Object.keys(part).length) return;
        const hash = crypto.createHash("sha256")
          .update(stableJson(part)).digest("hex").slice(0, 20);
        const id = `${field}-${ordinal++}-${hash}`;
        sections.push({ref: root.collection("sections").doc(id),
          data: {schemaVersion: 1, field, entries: part}});
        if (!data.sections[field]) data.sections[field] = [];
        data.sections[field].push(id);
        part = {};
        partBytes = 2;
      };
      for (const [key, entry] of Object.entries(profile[field])
        .sort(([left], [right]) => left.localeCompare(right))) {
        const entryBytes = Buffer.byteLength(JSON.stringify(key)) +
          Buffer.byteLength(JSON.stringify(entry)) + 2;
        if (entryBytes > 300000) {
          throw sourceError("AGGREGATE_SECTION_TOO_LARGE");
        }
        if (partBytes + entryBytes > 300000) flush();
        part[key] = entry;
        partBytes += entryBytes;
      }
      flush();
    }
    if (Buffer.byteLength(JSON.stringify(data)) > 800000) {
      throw sourceError("AGGREGATE_PROFILE_TOO_LARGE");
    }
    publications.push({root, data, sections});
  }
  for (const publication of publications) {
    await batchSetDocs(publication.sections);
  }
  await getDb().runTransaction(async (transaction) => {
    await assertWriteLease(transaction);
    for (const kind of ["biathlon-all", "biathlon-top-half"]) {
      const publication = publications.find((entry) => entry.root.id === kind);
      if (publication) transaction.set(publication.root, publication.data);
      else transaction.delete(collection.doc(kind));
    }
    transaction.set(classRef, {biathlonTopHalf: aggregates ?
      compatibilityTopHalf(aggregates.topHalf) : FieldValue.delete()},
    {merge: true});
  });
  for (const kind of ["biathlon-all", "biathlon-top-half"]) {
    const publication = publications.find((entry) => entry.root.id === kind);
    await deleteDocsNotInSet(collection.doc(kind).collection("sections"),
      new Set(publication ? publication.sections.map((entry) =>
        entry.ref.id) : []));
  }
}

function isEmptyResultDoc(data) {
  if (!data || typeof data !== "object") return false;

  const rawPasses = Array.isArray(data.timingPoints) ? data.timingPoints :
    (Array.isArray(data.rawPasses) ? data.rawPasses : []);
  const splits = data.splits && typeof data.splits === "object" ? data.splits : {};
  return data.totalMs == null &&
    rawPasses.length === 0 &&
    Object.keys(splits).length === 0;
}

async function deleteStaleEmptyResults(resultsRef, currentResultDocIds) {
  const snap = await resultsRef.get();
  const refsToDelete = [];
  const keptDocIds = [];
  const deletedDocIds = [];
  const existingContentHashes = {};
  let kept = 0;

  for (const doc of snap.docs || []) {
    const data = typeof doc.data === "function" ? doc.data() : {};
    if (currentResultDocIds.has(doc.id)) {
      existingContentHashes[doc.id] = data && data.contentHash;
      kept++;
      keptDocIds.push(doc.id);
      continue;
    }

    if (isEmptyResultDoc(data)) {
      refsToDelete.push(doc.ref);
      deletedDocIds.push(doc.id);
    } else {
      kept++;
      keptDocIds.push(doc.id);
    }
  }

  await batchDeleteDocs(refsToDelete);
  return {
    deleted: refsToDelete.length,
    deletedDocIds,
    kept,
    keptDocIds,
    existingContentHashes,
    scanned: (snap.docs || []).length,
  };
}

async function deleteDocsNotInSet(collectionRef, currentDocIds) {
  const snap = await collectionRef.get();
  const refsToDelete = [];

  for (const doc of snap.docs || []) {
    if (!currentDocIds.has(doc.id)) {
      refsToDelete.push(doc.ref);
    }
  }

  await batchDeleteDocs(refsToDelete);
  return {
    deleted: refsToDelete.length,
    kept: (snap.docs || []).length - refsToDelete.length,
    scanned: (snap.docs || []).length,
  };
}


/**
 * Build map: etappeDeltakerUID -> participantUID
 * participants payload is an object keyed by participantUID as string.
 */

function buildEtappeMap(participants) {
  const m = new Map();
  if (!participants || typeof participants !== "object") return m;

  for (const [pidStr, p] of Object.entries(participants)) {
    if (!p || typeof p !== "object") continue;
    const ed = p.EtappeDeltaker || {};
    for (const edUidStr of Object.keys(ed)) {
      const edUid = Number(edUidStr);
      const pid = Number(pidStr);
      if (!Number.isNaN(edUid) && !Number.isNaN(pid)) {
        m.set(edUid, pid);
      }
    }
  }
  return m;
}

function getParticipantEntries(participants) {
  if (!participants || typeof participants !== "object") return [];

  if (Array.isArray(participants)) {
    return participants.map((p) => [String(firstDefined(p && p.UID, "")), p]);
  }
  if (Array.isArray(participants.Items)) {
    return participants.Items.map((p) => [String(firstDefined(p && p.UID, "")), p]);
  }
  if (Array.isArray(participants.items)) {
    return participants.items.map((p) => [String(firstDefined(p && p.UID, "")), p]);
  }

  return Object.entries(participants);
}

function getParticipantClassUid(p) {
  return toNumberOrNull(
    (p && p.Klasse && p.Klasse.UID != null) ? p.Klasse.UID :
    (p && p.KlasseUID != null) ? p.KlasseUID :
    null
  );
}

function getParticipantEtappeUid(p) {
  return toNumberOrNull(
    (p && p.Pulje && p.Pulje.EtappeUID != null) ? p.Pulje.EtappeUID :
    (p && p.EtappeUID != null) ? p.EtappeUID :
    null
  );
}

function getParticipantEtappeDeltakerUids(p, etappeUid) {
  const out = [];
  const edMap = p && p.EtappeDeltaker && typeof p.EtappeDeltaker === "object" ?
    p.EtappeDeltaker :
    {};

  for (const [edUidStr, ed] of Object.entries(edMap)) {
    const edUid = toNumberOrNull(edUidStr);
    if (edUid == null) continue;

    const edEtappeUid = toNumberOrNull(
      (ed && ed.Etappe && ed.Etappe.UID != null) ? ed.Etappe.UID :
      (ed && ed.Pulje && ed.Pulje.EtappeUID != null) ? ed.Pulje.EtappeUID :
      null
    );

    if (etappeUid != null) {
      if (edEtappeUid != null && edEtappeUid !== Number(etappeUid)) continue;
      if (edEtappeUid == null) {
        const participantEtappeUid = getParticipantEtappeUid(p);
        if (participantEtappeUid != null &&
          participantEtappeUid !== Number(etappeUid)) continue;
      }
    }
    out.push(edUid);
  }

  return out;
}

function hasAdvancedToLaterStage(event, participant, etappeUid) {
  const stages = getEventStages(event);
  const currentIndex = stages.findIndex((entry) =>
    entry.id === String(etappeUid));
  if (currentIndex < 0 || !participant ||
    !participant.EtappeDeltaker ||
    typeof participant.EtappeDeltaker !== "object") {
    return false;
  }

  const laterStageIds = new Set(
    stages.slice(currentIndex + 1).map((entry) => entry.id),
  );
  return Object.values(participant.EtappeDeltaker).some((stageParticipant) => {
    const stageId = getEtappeUidFromEtappeDeltaker(stageParticipant);
    return stageId != null && laterStageIds.has(String(stageId));
  });
}

function getClassParticipantRecords(participants, classId, etappeUid) {
  const records = [];
  for (const [pidStr, p] of getParticipantEntries(participants)) {
    if (!p || typeof p !== "object") continue;

    const participantClassUid = getParticipantClassUid(p);
    if (participantClassUid == null || participantClassUid !== Number(classId)) {
      continue;
    }

    const pid = toNumberOrNull(firstDefined(pidStr, p.UID));
    const edUids = getParticipantEtappeDeltakerUids(p, etappeUid);

    if (etappeUid != null && edUids.length === 0) continue;

    for (const edUid of edUids) {
      records.push({pid, p, edUid});
    }
  }

  return records;
}

function seedParticipantResults(byEd, edToPid, participantRecords) {
  let seeded = 0;

  for (const record of participantRecords) {
    if (record.pid != null) edToPid.set(record.edUid, record.pid);
    if (!byEd.has(record.edUid)) seeded++;
  }

  return seeded;
}

function firstDefined(...values) {
  for (const value of values) {
    if (value !== undefined && value !== null) return value;
  }
  return null;
}

function toNumberOrNull(value) {
  if (value === undefined || value === null || value === "") return null;
  const n = Number(value);
  return Number.isNaN(n) ? null : n;
}

function toPositiveNumberOrNull(value) {
  const n = toNumberOrNull(value);
  return n != null && n > 0 ? n : null;
}

function getRawStationSetupUid(raw) {
  if (!raw || typeof raw !== "object") return null;

  const candidates = [
    raw.StasjonsOppsettUID,
    raw.StasjonsOppsett && raw.StasjonsOppsett.UID,
    raw.StasjonsOppsett && raw.StasjonsOppsett.Id,
    raw.StasjonsOppsett && raw.StasjonsOppsett.ID,
    null,
  ];

  for (const candidate of candidates) {
    const n = toPositiveNumberOrNull(candidate);
    if (n != null) return n;
  }

  return null;
}

function normalizeCodeForMatch(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toUpperCase();
}

function getSplitGroupFromCode(code) {
  const m = String(code || "").match(/^[A-Za-z]+/);
  return m ? m[0].toUpperCase() : null;
}

function classifySplitKind(code, meta) {
  const normalized = normalizeCodeForMatch(code);

  if (/^START$/i.test(normalized)) return "start";
  if (/^(MAL|MAAL|FINISH|GOAL)$/i.test(normalized)) return "finish";
  if (/^INS\d+$/i.test(normalized)) return "rangeIn";
  if (/^IS\d+$/i.test(normalized)) return "rangeApproach";
  if (/^S\d+$/i.test(normalized)) return "shooting";
  if (/^UTS\d+$/i.test(normalized)) return "rangeOut";
  if (/^US\d+$/i.test(normalized)) return "rangeExit";
  if (/^R\d+$/i.test(normalized)) return "lap";
  if (/^MT/i.test(normalized)) return "split";
  if (meta && meta.isShootingStation) return "shooting";
  if (meta && meta.isStart) return "start";
  if (meta && meta.isStop) return "finish";

  return "split";
}

/**
 * Build map: map[etappeUID][stasjonsOppsettUID] => rich station/split meta.
 * event payload contains Stasjoner with StasjonsOppsett.
 */
function buildStationSetupMap(event) {
  const out = new Map();
  const stations = event && event.Stasjoner ? event.Stasjoner : {};
  for (const station of Object.values(stations)) {
    if (!station) continue;
    const stationName = station.Navn || null;
    const stationUid = toNumberOrNull(station.UID);
    const isShootingStation = !!station.ErSkyting;
    const setups = station.StasjonsOppsett || {};
    for (const [setupUidStr, setup] of Object.entries(setups)) {
      const setupUid = Number(setupUidStr);
      const etappeUid = Number(setup.EtappeUID);
      if (Number.isNaN(setupUid) || Number.isNaN(etappeUid)) continue;

      const label = setup.Navn || stationName || String(setupUid);
      const sort =
        (setup.Sortering !== undefined && setup.Sortering !== null)
          ? setup.Sortering
          : 10000;

      const group = stationName || getSplitGroupFromCode(label);
      const baseMeta = {
        label: label,
        code: label,
        group,
        stationName: stationName,
        stationUid,
        stationNumber: firstDefined(station.Nummer, null),
        stationAlias: firstDefined(station.Alias, null),
        stationAliases: Array.isArray(station.Aliases) ? station.Aliases : [],
        stationLatitude: firstDefined(station.Latitude, null),
        stationLongitude: firstDefined(station.Longitude, null),
        isShootingStation,
        sort: sort,
        km: (setup.Km !== undefined ? setup.Km : null),
        etappeUid,
        etappeNumber: firstDefined(setup.Etappenummer, null),
        legNumber: firstDefined(setup.Legnummer, null),
        roundNumber: firstDefined(setup.Rundenummer, null),
        isStart: !!setup.Er_start,
        isStop: !!setup.Er_stopp,
        isPublic: firstDefined(setup.Er_offentlig, null),
        isRequired: firstDefined(setup.Obligatorisk, null),
        speakerIn: firstDefined(setup.Speaker_inn, null),
        speakerOut: firstDefined(setup.Speaker_ut, null),
        nettoStart: firstDefined(setup.NettoStart, null),
        print: firstDefined(setup.Print, null),
        startTime: firstDefined(setup.Starttid, null),
        stopTime: firstDefined(setup.Stopptid, null),
        minRoundTime: firstDefined(setup.RundeMinimumTid, null),
        maxRoundTime: firstDefined(setup.RundeMaximumTid, null),
        preTiming: firstDefined(setup.Pretiming, null),
        neutralIn: firstDefined(setup.NeutralIn, null),
        neutralOut: firstDefined(setup.NeutralOut, null),
        ignoreInSplit: firstDefined(setup.IgnoreInSplit, null),
        gpsReading: firstDefined(setup.GPSAvlesning, null),
        smoothingSeconds: firstDefined(setup.SekunderGlatting, null),
      };
      const meta = Object.assign({}, baseMeta, {
        kind: classifySplitKind(label, baseMeta),
      });

      if (!out.has(etappeUid)) out.set(etappeUid, new Map());
      out.get(etappeUid).set(setupUid, meta);
    }
  }
  return out;
}

/**
 * Participant summary stored in results.
 */
function normalizeSimpleName(value) {
  if (value == null) return null;
  const trimmed = String(value).trim().replace(/\s+/g, " ");
  if (!trimmed) return null;
  return trimmed.toLowerCase();
}

function normalizeClubName(name) {
  return normalizeSimpleName(name);
}

function normalizeAffiliationName(name) {
  return normalizeSimpleName(name);
}

function getParticipantDisplayName(p) {
  const utover = p && p.Utover ? p.Utover : {};
  const fn = utover.Fornavn || "";
  const en = utover.Etternavn || "";
  const formatted = utover.NavnFormatert;
  return formatted || (String(fn) + " " + String(en)).trim() || null;
}

function getParticipantBirthYear(p) {
  const utover = p && p.Utover ? p.Utover : {};
  return firstDefined(
    utover.Fodselsaar,
    utover.FodselsAr,
    utover.Aar,
    null,
  );
}

function getParticipantCountry(p) {
  const utover = p && p.Utover ? p.Utover : {};
  const country = utover.Land || p && p.Land || null;
  if (!country || typeof country !== "object") return null;

  return {
    uid: firstDefined(country.UID, country.Id, null),
    name: firstDefined(country.Navn, country.Name, null),
    iso2: firstDefined(country.ISO2, null),
    iso3: firstDefined(country.ISO3, null),
    ioc: firstDefined(country.IOC, null),
  };
}

function getParticipantRegion(p) {
  const region = p && p.Region ? p.Region : null;
  if (!region || typeof region !== "object") return null;

  return {
    uid: firstDefined(region.UID, region.Id, null),
    name: firstDefined(region.Navn, region.Name, null),
    shortName: firstDefined(region.ShortName, null),
  };
}

function getParticipantTimingIds(p) {
  const licenseValues = p && p.Lisens && typeof p.Lisens === "object" ?
    Object.values(p.Lisens) :
    [];
  const licenseTypes = [];
  const emitagIds = [];

  for (const license of licenseValues) {
    if (!license || typeof license !== "object") continue;
    const type = license.Type != null ? String(license.Type) : null;
    const code = license.Kode != null ? String(license.Kode) : null;
    if (type && !licenseTypes.includes(type)) licenseTypes.push(type);
    if (type && /^EMITAGID$/i.test(type) && code) emitagIds.push(code);
  }

  const chipIds = [];
  for (const chip of [p && p.Chip1, p && p.Chip2]) {
    if (chip != null && String(chip).trim()) chipIds.push(String(chip).trim());
  }

  return {
    chipsRaw: firstDefined(p && p.Chips, null),
    chip1: firstDefined(p && p.Chip1, null),
    chip2: firstDefined(p && p.Chip2, null),
    chipIds,
    emitagIds,
    licenseTypes,
  };
}

function getParticipantClubName(p) {
  return p ? (p.Klubbnavn || (p.Klubb && p.Klubb.Navn) || null) : null;
}

function getParticipantClubSourceId(p) {
  if (!p || !p.Klubb || typeof p.Klubb !== "object") return null;
  const sourceClubId = p.Klubb.UID !== undefined ? p.Klubb.UID : p.Klubb.Id;
  return sourceClubId != null ? String(sourceClubId) : null;
}

function getParticipantSchoolName(p) {
  if (!p) return null;
  return p.SkoleNavn || (p.Skole && p.Skole.Navn) || null;
}

function getParticipantSchoolSourceId(p) {
  if (!p || !p.Skole || typeof p.Skole !== "object") return null;
  const sourceSchoolId = p.Skole.UID !== undefined ? p.Skole.UID : p.Skole.Id;
  return sourceSchoolId != null ? String(sourceSchoolId) : null;
}

function getParticipantOrganizationName(p) {
  if (!p) return null;
  return (
    p.OrganisasjonNavn ||
    (p.Organisasjon && p.Organisasjon.Navn) ||
    p.BedriftNavn ||
    null
  );
}

function getParticipantOrganizationSourceId(p) {
  if (!p) return null;
  if (p.Organisasjon && typeof p.Organisasjon === "object") {
    const sourceOrganizationId = p.Organisasjon.UID !== undefined ?
      p.Organisasjon.UID :
      p.Organisasjon.Id;
    return sourceOrganizationId != null ? String(sourceOrganizationId) : null;
  }
  return null;
}

function getParticipantTeamName(p) {
  if (!p) return null;
  return (
    (p.Team && p.Team.Navn) ||
    (p.Utover && p.Utover.Team && p.Utover.Team.Navn) ||
    p.TeamName ||
    null
  );
}

function getParticipantTeamSourceId(p) {
  if (p && p.Team && typeof p.Team === "object") {
    const sourceTeamId = p.Team.UID !== undefined ? p.Team.UID : p.Team.Id;
    return sourceTeamId != null ? String(sourceTeamId) : null;
  }
  if (p && p.Utover && p.Utover.Team && typeof p.Utover.Team === "object") {
    const sourceTeamId = p.Utover.Team.UID !== undefined ? p.Utover.Team.UID : p.Utover.Team.Id;
    return sourceTeamId != null ? String(sourceTeamId) : null;
  }
  return null;
}

function getParticipantLagName(p) {
  if (!p) return null;
  return p.LagNavn || (p.Lag && p.Lag.Navn) || null;
}

function getParticipantLagSourceId(p) {
  if (!p || !p.Lag || typeof p.Lag !== "object") return null;
  const sourceLagId = p.Lag.UID !== undefined ? p.Lag.UID : p.Lag.Id;
  if (sourceLagId == null || Number(sourceLagId) === 0) return null;
  return String(sourceLagId);
}

function buildAthleteId(participant) {
  const athleteUid = participant && participant.Utover ?
    firstDefined(participant.Utover.UID, participant.Utover.Id, null) :
    null;
  if (athleteUid == null || Number(athleteUid) === 0) return null;
  return `athlete:${athleteUid}`;
}

function buildClubId(participant) {
  const sourceClubId = getParticipantClubSourceId(participant);
  if (sourceClubId) return `club:${sourceClubId}`;

  const normalizedName = normalizeClubName(getParticipantClubName(participant));
  if (!normalizedName) return null;
  return `clubname:${normalizedName}`;
}

function buildClubDoc(participant) {
  const clubName = getParticipantClubName(participant);
  const normalizedName = normalizeClubName(clubName);
  const clubId = buildClubId(participant);

  if (!clubId || !clubName || !normalizedName) return null;

  const sourceClubId = getParticipantClubSourceId(participant);

  return {
    clubId,
    name: clubName,
    normalizedName,
    sourceRefs: [
      {
        provider: "eqtiming",
        sourceClubId: sourceClubId,
        sourceName: clubName,
      },
    ],
  };
}

function buildAffiliationEntityId(type, sourceId, normalizedName) {
  if (sourceId) return `${type}:${sourceId}`;
  if (!normalizedName) return null;
  return `${type}name:${normalizedName}`;
}

function buildSchoolId(participant) {
  const sourceId = getParticipantSchoolSourceId(participant);
  const normalizedName = normalizeAffiliationName(getParticipantSchoolName(participant));
  return buildAffiliationEntityId("school", sourceId, normalizedName);
}

function buildOrganizationId(participant) {
  const sourceId = getParticipantOrganizationSourceId(participant);
  const normalizedName = normalizeAffiliationName(getParticipantOrganizationName(participant));
  return buildAffiliationEntityId("organization", sourceId, normalizedName);
}

function buildTeamId(participant) {
  const sourceId = getParticipantTeamSourceId(participant);
  const normalizedName = normalizeAffiliationName(getParticipantTeamName(participant));
  return buildAffiliationEntityId("team", sourceId, normalizedName);
}

function buildLagId(participant) {
  const sourceId = getParticipantLagSourceId(participant);
  const normalizedName = normalizeAffiliationName(getParticipantLagName(participant));
  return buildAffiliationEntityId("lag", sourceId, normalizedName);
}

function buildAffiliationDoc(type, participant) {
  let name = null;
  let sourceId = null;
  let affiliationId = null;

  if (type === "school") {
    name = getParticipantSchoolName(participant);
    sourceId = getParticipantSchoolSourceId(participant);
    affiliationId = buildSchoolId(participant);
  } else if (type === "organization") {
    name = getParticipantOrganizationName(participant);
    sourceId = getParticipantOrganizationSourceId(participant);
    affiliationId = buildOrganizationId(participant);
  } else if (type === "team") {
    name = getParticipantTeamName(participant);
    sourceId = getParticipantTeamSourceId(participant);
    affiliationId = buildTeamId(participant);
  } else if (type === "lag") {
    name = getParticipantLagName(participant);
    sourceId = getParticipantLagSourceId(participant);
    affiliationId = buildLagId(participant);
  }

  const normalizedName = normalizeAffiliationName(name);
  if (!affiliationId || !name || !normalizedName) return null;

  return {
    clubId: affiliationId,
    type,
    name,
    normalizedName,
    sourceRefs: [
      {
        provider: "eqtiming",
        sourceClubId: sourceId,
        sourceName: name,
      },
    ],
  };
}

function buildAthleteDoc(participant, clubId, schoolId, organizationId, teamId, lagId) {
  const athleteId = buildAthleteId(participant);
  if (!participant || !athleteId) return null;

  const displayName = getParticipantDisplayName(participant);
  const normalizedName = normalizeSimpleName(displayName);

  return {
    athleteId,
    displayName,
    normalizedName,
    country: getParticipantCountry(participant),
    region: getParticipantRegion(participant),
    primaryClubId: clubId || null,
    clubIds: clubId ? [clubId] : [],
    primarySchoolId: schoolId || null,
    schoolIds: schoolId ? [schoolId] : [],
    primaryOrganizationId: organizationId || null,
    organizationIds: organizationId ? [organizationId] : [],
    primaryTeamId: teamId || null,
    teamIds: teamId ? [teamId] : [],
    primaryLagId: lagId || null,
    lagIds: lagId ? [lagId] : [],
  };
}

function buildAthleteListEntry(participant, athleteId) {
  if (!participant || !athleteId) return null;
  return {
    athleteId,
    name: getParticipantDisplayName(participant),
  };
}

function buildEventListEntry(eventId, eventName) {
  if (eventId == null) return null;
  return {
    eventId: Number(eventId),
    name: eventName || null,
  };
}

function buildAthleteEventResultEntry(result, context) {
  if (!result || result.eventId == null) return null;
  return {
    eventId: Number(result.eventId),
    name: (context && context.eventName) || null,
    classId: result.classId != null ? Number(result.classId) : null,
    className: firstDefined(result.className, null),
    rank: firstDefined(result.rank, null),
    finishRank: firstDefined(result.finishRank, result.rank, null),
  };
}

function appendUniqueEntityList(data, field, entry, idField) {
  if (!data || !entry || !entry[idField]) return;
  const values = Array.isArray(data[field]) ? data[field] : [];
  const existingIndex = values.findIndex((value) => value && value[idField] === entry[idField]);
  if (existingIndex >= 0) {
    values[existingIndex] = Object.assign({}, values[existingIndex], entry);
  } else {
    values.push(entry);
  }
  data[field] = values;
}

function upsertEntityWrite(writeMap, id, ref, doc, additions) {
  if (!id || !doc) return;

  const existing = writeMap.get(id);
  const data = existing ? existing.data : {};
  Object.assign(data, doc, {
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  if (additions && additions.athlete) {
    appendUniqueEntityList(data, "athletes", additions.athlete, "athleteId");
  }
  if (additions && additions.event) {
    appendUniqueEntityList(data, "events", additions.event, "eventId");
  }

  writeMap.set(id, {
    ref,
    data,
  });
}

function prepareEntityWrite(write) {
  const data = Object.assign({}, write.data);
  if (Array.isArray(data.athletes) && data.athletes.length > 0) {
    data.athletes = FieldValue.arrayUnion(...data.athletes);
  }
  if (Array.isArray(data.events) && data.events.length > 0) {
    data.events = FieldValue.arrayUnion(...data.events);
  }
  return {
    ref: write.ref,
    data,
  };
}

async function filterChangedEntityWrites(writes, eventId) {
  if (!writes.length) return [];
  const snapshots = [];
  const dbClient = getDb();
  for (let start = 0; start < writes.length; start += 200) {
    const refs = writes.slice(start, start + 200).map((write) => write.ref);
    snapshots.push(...await dbClient.getAll(...refs));
  }

  const eventKey = String(eventId);
  return writes.flatMap((write, index) => {
    const contentHash = resultContentHash(write.data);
    const existing = snapshots[index] && snapshots[index].exists ?
      snapshots[index].data() : {};
    const existingHashes = existing && existing.importContentHashes || {};
    if (existingHashes[eventKey] === contentHash) return [];

    const prepared = prepareEntityWrite(write);
    prepared.data.importContentHashes = {[eventKey]: contentHash};
    return [prepared];
  });
}

function addParticipantEntityWrites(participant, clubWritesById, athleteWritesById, context) {
  const clubId = participant ? buildClubId(participant) : null;
  const athleteId = participant ? buildAthleteId(participant) : null;
  const schoolId = participant ? buildSchoolId(participant) : null;
  const organizationId = participant ? buildOrganizationId(participant) : null;
  const teamId = participant ? buildTeamId(participant) : null;
  const lagId = participant ? buildLagId(participant) : null;
  const athleteEntry = buildAthleteListEntry(participant, athleteId);

  if (participant && clubId) {
    const clubDoc = buildClubDoc(participant);
    if (clubDoc) {
      upsertEntityWrite(
        clubWritesById,
        clubId,
        getDb().collection("clubs").doc(clubId),
        clubDoc,
        {athlete: athleteEntry},
      );
    }
  }

  if (participant && schoolId) {
    const schoolDoc = buildAffiliationDoc("school", participant);
    if (schoolDoc) {
      upsertEntityWrite(
        clubWritesById,
        schoolId,
        getDb().collection("clubs").doc(schoolId),
        schoolDoc,
        null,
      );
    }
  }

  if (participant && organizationId) {
    const organizationDoc = buildAffiliationDoc("organization", participant);
    if (organizationDoc) {
      upsertEntityWrite(
        clubWritesById,
        organizationId,
        getDb().collection("clubs").doc(organizationId),
        organizationDoc,
        null,
      );
    }
  }

  if (participant && teamId) {
    const teamDoc = buildAffiliationDoc("team", participant);
    if (teamDoc) {
      upsertEntityWrite(
        clubWritesById,
        teamId,
        getDb().collection("clubs").doc(teamId),
        teamDoc,
        {athlete: athleteEntry},
      );
    }
  }

  if (participant && lagId) {
    const lagDoc = buildAffiliationDoc("lag", participant);
    if (lagDoc) {
      upsertEntityWrite(
        clubWritesById,
        lagId,
        getDb().collection("clubs").doc(lagId),
        lagDoc,
        null,
      );
    }
  }

  if (participant && athleteId) {
    const athleteDoc = buildAthleteDoc(
      participant,
      clubId,
      schoolId,
      organizationId,
      teamId,
      lagId,
    );
    if (athleteDoc) {
      upsertEntityWrite(
        athleteWritesById,
        athleteId,
        getDb().collection("athletes").doc(athleteId),
        athleteDoc,
        null,
      );
      Object.assign(athleteWritesById.get(athleteId).data, {
        source: FieldValue.delete(),
        gender: FieldValue.delete(),
        birthYear: FieldValue.delete(),
        age: FieldValue.delete(),
      });
    }
  }

  return {clubId, athleteId, schoolId, organizationId, teamId, lagId};
}

function addAthleteEventResultWrite(athleteWritesById, result, context) {
  const athleteId = result && result.athleteId ? result.athleteId : null;
  const eventEntry = buildAthleteEventResultEntry(result, context);
  if (!athleteId || !eventEntry) return;

  const existing = athleteWritesById.get(athleteId);
  if (!existing) {
    athleteWritesById.set(athleteId, {
      ref: getDb().collection("athletes").doc(athleteId),
      data: {
        updatedAt: FieldValue.serverTimestamp(),
        events: [eventEntry],
      },
    });
    return;
  }

  appendUniqueEntityList(existing.data, "events", eventEntry, "eventId");
  existing.data.updatedAt = FieldValue.serverTimestamp();
}

function buildResultIdentityFields(participant, clubId, athleteId, schoolId, organizationId, teamId, lagId) {
  return {
    athleteId: athleteId || null,
    clubId: clubId || null,
    clubName: getParticipantClubName(participant),
    schoolId: schoolId || null,
    schoolName: getParticipantSchoolName(participant),
    organizationId: organizationId || null,
    organizationName: getParticipantOrganizationName(participant),
    teamId: teamId || null,
    teamName: getParticipantTeamName(participant),
    lagId: lagId || null,
    lagName: getParticipantLagName(participant),
    name: getParticipantDisplayName(participant),
  };
}

function getParticipantSummary(p) {
  const utover = p && p.Utover ? p.Utover : {};
  const klasse = p && p.Klasse ? p.Klasse : {};
  const clubId = buildClubId(p);
  const athleteId = buildAthleteId(p);
  const schoolId = buildSchoolId(p);
  const organizationId = buildOrganizationId(p);
  const teamId = buildTeamId(p);
  const lagId = buildLagId(p);

  return {
    participantUid: (p.UID !== undefined ? p.UID : null),
    arrangementUid: (p.Arrangement && p.Arrangement.UID !== undefined) ? p.Arrangement.UID : null,
    etappeUid: (p.Pulje && p.Pulje.EtappeUID !== undefined) ? p.Pulje.EtappeUID : null,
    classUid: (klasse.UID !== undefined ? klasse.UID : null),
    className: (klasse.Navn !== undefined ? klasse.Navn : null),
    bib: (p.Startnummer !== undefined ? p.Startnummer : null),
    fullBib: (p.FullStartnummer !== undefined ? p.FullStartnummer : null),
    lane: (p.Skive !== undefined ? p.Skive : null),
    athleteId: athleteId,
    clubId: clubId,
    schoolId: schoolId,
    organizationId: organizationId,
    teamId: teamId,
    lagId: lagId,
    name: getParticipantDisplayName(p),
    club: getParticipantClubName(p),
    clubName: getParticipantClubName(p),
    schoolName: getParticipantSchoolName(p),
    organizationName: getParticipantOrganizationName(p),
    teamName: getParticipantTeamName(p),
    lagName: getParticipantLagName(p),
    gender: utover.Kjonn || null,
    birthYear: getParticipantBirthYear(p),
    age: (p.Alder !== undefined ? p.Alder : null),
    athleteSourceUid: firstDefined(utover.UID, null),
    country: getParticipantCountry(p),
    region: getParticipantRegion(p),
    status: p.Status && typeof p.Status === "object" ? {
      uid: firstDefined(p.Status.UID, null),
      name: firstDefined(p.Status.Navn, null),
      visible: firstDefined(p.Status.Visible, null),
      paid: firstDefined(p.Status.Betalt, null),
    } : null,
    registeredAt: firstDefined(p.Registrert, null),
    confirmedTime: firstDefined(p.BekreftetTid, null),
    timingIds: getParticipantTimingIds(p),
    eqmeNotInUse: firstDefined(p.EQMENotInUse, null),
    ignoreForTracking: firstDefined(p.IgnoreForTracking, null),
  };
}

function compareSplitRows(a, b) {
  const aSort = typeof a.sort === "number" ? a.sort : null;
  const bSort = typeof b.sort === "number" ? b.sort : null;
  if (aSort != null && bSort != null && aSort !== bSort) return aSort - bSort;

  const aMs = typeof a.cumMs === "number" ? a.cumMs : Number.MAX_SAFE_INTEGER;
  const bMs = typeof b.cumMs === "number" ? b.cumMs : Number.MAX_SAFE_INTEGER;
  if (aMs !== bMs) return aMs - bMs;

  return String(a.setupUid || "").localeCompare(String(b.setupUid || ""));
}

function buildOrderedSplitValues(splits) {
  return Object.entries(splits || {})
    .map(([setupUid, split]) => Object.assign({setupUid}, split))
    .sort(compareSplitRows);
}

function buildSplitDefsForClass(setupMap) {
  const splitDefs = {};
  const splitOrder = [];

  if (!setupMap) {
    return {splitDefs, splitOrder};
  }

  const entries = Array.from(setupMap.entries()).sort((a, b) => {
    const aSort = typeof a[1].sort === "number" ? a[1].sort : Number.MAX_SAFE_INTEGER;
    const bSort = typeof b[1].sort === "number" ? b[1].sort : Number.MAX_SAFE_INTEGER;
    if (aSort !== bSort) return aSort - bSort;
    return Number(a[0]) - Number(b[0]);
  });

  for (const [setupUid, meta] of entries) {
    const setupUidStr = String(setupUid);
    const code = meta && meta.label ? String(meta.label) : setupUidStr;
    const group = meta && meta.group ? meta.group : getSplitGroupFromCode(code);
    splitOrder.push(setupUidStr);
    splitDefs[setupUidStr] = Object.assign({}, meta, {
      setupUid: setupUidStr,
      stasjonsOppsettUID: setupUid,
      code,
      group,
      kind: meta && meta.kind ? meta.kind : classifySplitKind(code, meta),
    });
  }

  return {splitDefs, splitOrder};
}

function buildCompactResultIdentity(participantSummary, identityFields) {
  const base = participantSummary || {};
  return Object.assign({}, identityFields || {}, {
    bib: firstDefined(base.bib, null),
    fullBib: firstDefined(base.fullBib, null),
    lane: firstDefined(base.lane, null),
    country: firstDefined(base.country, null),
    region: firstDefined(base.region, null),
    className: firstDefined(base.className, null),
  });
}

function relayMembers(participant) {
  const members = participant && participant.StafettDeltakere;
  if (!members || typeof members !== "object") return [];
  return Object.values(members)
    .filter((member) => member && typeof member === "object")
    .map((member) => ({
      legNumber: toNumberOrNull(firstDefined(member.Sortering, member.Etappe, null)),
      athleteId: member.UtoverUID != null ? `athlete:${member.UtoverUID}` : null,
      name: firstDefined(
        member.NavnFormatert,
        `${member.Fornavn || ""} ${member.Etternavn || ""}`.trim(),
        null,
      ),
      country: member.Nasjon ? {
        name: firstDefined(member.Nasjon.Navn, null),
        iso2: firstDefined(member.Nasjon.ISO2, null),
        iso3: firstDefined(member.Nasjon.ISO3, null),
      } : null,
    }))
    .sort((a, b) => (a.legNumber || 0) - (b.legNumber || 0));
}

function teamDisplayName(participant, fallback) {
  const formatted = firstDefined(
    participant && participant.KlubbTeamFormatert,
    participant && participant.LagNavn,
    participant && participant.TeamName,
    fallback,
  );
  return formatted == null ? null : String(formatted).replace(/^\.\s*/, "").trim();
}

function withoutHitFields(analysis, shooting, laps) {
  const cleanAnalysis = Object.assign({}, analysis || {});
  delete cleanAnalysis.hitsTotal;
  delete cleanAnalysis.targetsTotal;
  delete cleanAnalysis.proneHits;
  delete cleanAnalysis.standingHits;
  const cleanShooting = {};
  for (const [key, pass] of Object.entries(shooting || {})) {
    cleanShooting[key] = Object.assign({}, pass);
    delete cleanShooting[key].hits;
  }
  return {
    metrics: cleanAnalysis,
    passes: cleanShooting,
    laps: Object.assign({}, laps || {}),
  };
}

function buildResultClassDoc(args) {
  const identity = buildCompactResultIdentity(
    args.participantSummary,
    args.identityFields,
  );
  const members = relayMembers(args.participant);
  const isTeam = args.isRelay || args.profile === "relay" || members.length > 0;
  const displayName = isTeam ?
    teamDisplayName(args.participant, identity.name) :
    identity.name;
  const isBiathlon = args.isBiathlon || args.profile === "biathlon";
  const biathlon = isBiathlon ?
    withoutHitFields(args.derived.analysis, args.derived.shooting, args.derived.laps) :
    null;
  const relayLegs = isTeam && isBiathlon ?
    buildRelayLegBiathlon(args.rawSplits) :
    [];
  const document = Object.assign({}, identity, {
    schemaVersion: 3,
    eventId: args.eventId,
    classId: args.classId,
    stageId: String(args.etappeUid),
    etappeUid: args.etappeUid,
    hasTimingData: true,
    isRelay: isTeam,
    isBiathlon,
    totalMs: args.totalMs,
    totalText: args.totalText,
    status: args.status,
    advanced: args.advanced === true,
    entrant: {
      kind: isTeam ? "team" : "athlete",
      athleteId: isTeam ? null : identity.athleteId,
      name: displayName,
      bib: firstDefined(identity.fullBib, identity.bib, null),
      clubId: identity.clubId,
      clubName: identity.clubName,
      teamId: identity.teamId,
      teamName: identity.teamName,
      country: identity.country,
    },
    team: isTeam ? {members, legs: relayLegs} : null,
    timingPoints: args.derived.rawPasses,
    analysis: biathlon ? {biathlon: Object.assign({version: 1}, biathlon)} : null,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return sanitizeForFirestore(document) || {};
}

function getItemsArray(payload) {
  if (!payload || typeof payload !== "object") return [];

  const itemsRaw = firstDefined(payload.Items, payload.items, []);
  return Array.isArray(itemsRaw) ? itemsRaw : Object.values(itemsRaw);
}

function normalizeSmallTimingObject(value) {
  if (!value || typeof value !== "object") return null;

  return {
    total: firstDefined(value.Total, null),
    class: firstDefined(value.Klasse, null),
    gender: firstDefined(value.Kjonn, null),
    totalText: firstDefined(value.TotalFormatert, null),
    classText: firstDefined(value.KlasseFormatert, null),
    genderText: firstDefined(value.KjonnFormatert, null),
    splitTotal: firstDefined(value.SplittTotal, null),
    splitClass: firstDefined(value.SplittKlasse, null),
    splitGender: firstDefined(value.SplittKjonn, null),
  };
}

function parseAdditionParts(addition) {
  if (addition == null) return null;

  const s = String(addition).trim();
  if (!s) return [];

  const parts = s.split("+").map((part) => {
    const v = Number(part.trim());
    return Number.isNaN(v) ? null : v;
  });

  return parts.some((part) => part == null) ? null : parts;
}

function normalizeTimeRecord(raw, fallbackEdUid, sourceType) {
  if (!raw || typeof raw !== "object") return null;

  const edUid = toNumberOrNull(firstDefined(raw.EtappeDeltakerUID, fallbackEdUid));
  const soUid = getRawStationSetupUid(raw);
  if (edUid == null || soUid == null) return null;

  const spl = raw.Splitt && typeof raw.Splitt === "object" ? raw.Splitt : {};
  const addition = firstDefined(raw.Tillegg, null);
  const additionParts = parseAdditionParts(addition);

  return {
    edUid,
    soUid,
    passKey: raw.Key != null ? String(raw.Key) : null,
    sourceType,
    cumMs: toNumberOrNull(firstDefined(
      raw.AkkumulertTid,
      raw.AkkumulertTidGlattet,
      raw.AkkumulertTidNetto,
      raw.RangeringsTid,
      raw.DisplayTid,
    )),
    cumMsSmoothed: toNumberOrNull(firstDefined(raw.AkkumulertTidGlattet, null)),
    cumMsNet: toNumberOrNull(firstDefined(raw.AkkumulertTidNetto, null)),
    cumMsWithoutAddition: toNumberOrNull(firstDefined(raw.AkkumulertTidUtenTillegg, null)),
    cumText: firstDefined(raw.Formatert, raw.NettoFormatert, null),
    netText: firstDefined(raw.NettoFormatert, null),
    legMs: toNumberOrNull(firstDefined(spl.Tid, null)),
    legText: firstDefined(spl.Formatert, null),
    splitKm: firstDefined(spl.Km, null),
    speed: firstDefined(spl.Hastighet, null),
    pace: firstDefined(spl.Tempo, null),
    totalSpeed: firstDefined(spl.TotalHastighet, null),
    totalPace: firstDefined(spl.TotalTempo, null),
    status: firstDefined(raw.StatusTekst, null),
    statusCode: firstDefined(raw.Status, raw.EDStatus, null),
    timeStatus: firstDefined(raw.TidStatus, null),
    active: firstDefined(raw.Aktiv, null),
    passTime: firstDefined(
      raw.PasseringstidAsDateTime,
      raw.PasseringsTid,
      raw.Tid,
      null,
    ),
    smoothedTime: firstDefined(raw.GlattetTid, null),
    timezoneOffset: firstDefined(raw.TimezoneOffset, null),
    roundNumber: firstDefined(raw.Rundenummer, null),
    addition,
    additionParts,
    additionTotal: additionParts == null ?
      null :
      additionParts.reduce((sum, value) => sum + value, 0),
    diff: normalizeSmallTimingObject(raw.Diff),
    placement: normalizeSmallTimingObject(raw.Plassering),
  };
}

function mergeTimeRecord(existing, incoming) {
  if (!existing) return incoming;

  const merged = Object.assign({}, existing);
  for (const [key, value] of Object.entries(incoming)) {
    if (value === null || value === undefined) continue;
    if (Array.isArray(value) && value.length === 0 &&
      Array.isArray(merged[key]) && merged[key].length > 0) {
      continue;
    }
    if (typeof value === "object" && !Array.isArray(value)) {
      if (merged[key] == null) {
        merged[key] = value;
      } else {
        merged[key] = Object.assign({}, merged[key], value);
      }
      continue;
    }
    merged[key] = value;
  }

  return merged;
}

function addNormalizedRecord(recordMap, record) {
  if (!record) return;
  const key = [
    record.edUid,
    record.soUid,
    record.roundNumber != null ? record.roundNumber : "round",
  ].join(":");

  recordMap.set(key, mergeTimeRecord(recordMap.get(key), record));
}

function collectNestedPassRecords(passeringer, fallbackEdUid, recordMap) {
  if (!passeringer || typeof passeringer !== "object") return;

  for (const [outerKey, outerValue] of Object.entries(passeringer)) {
    if (!outerValue || typeof outerValue !== "object") continue;

    if (outerValue.StasjonsOppsettUID != null) {
      addNormalizedRecord(
        recordMap,
        normalizeTimeRecord(outerValue, fallbackEdUid, "nested-pass"),
      );
      continue;
    }

    const outerEdUid = toNumberOrNull(outerKey);
    const nestedFallback = outerEdUid != null ? outerEdUid : fallbackEdUid;
    const passValues = Array.isArray(outerValue) ? outerValue : Object.values(outerValue);

    for (const pass of passValues) {
      addNormalizedRecord(
        recordMap,
        normalizeTimeRecord(pass, nestedFallback, "nested-pass"),
      );
    }
  }
}

function normalizeTimes(times) {
  const recordMap = new Map();
  const items = getItemsArray(times);

  for (const item of items) {
    if (!item || typeof item !== "object") continue;

    const fallbackEdUid = toNumberOrNull(item.EtappeDeltakerUID);
    addNormalizedRecord(
      recordMap,
      normalizeTimeRecord(item, fallbackEdUid, "item"),
    );
    collectNestedPassRecords(item.Passeringer, fallbackEdUid, recordMap);
  }

  return Array.from(recordMap.values()).sort((a, b) => {
    if (a.edUid !== b.edUid) return a.edUid - b.edUid;
    const aMs = typeof a.cumMs === "number" ? a.cumMs : Number.MAX_SAFE_INTEGER;
    const bMs = typeof b.cumMs === "number" ? b.cumMs : Number.MAX_SAFE_INTEGER;
    if (aMs !== bMs) return aMs - bMs;
    return a.soUid - b.soUid;
  });
}

/**
 * Normalize times. EQ Timing can return slightly different shapes.
 *
 * Supported shapes:
 *  A) { Items: [ { EtappeDeltakerUID, Passeringer: { "<ed>": { "<k>": {StasjonsOppsettUID, AkkumulertTid, Formatert, Splitt{Tid,Formatert}} }}} ] }
 *  B) { items: [...] } (lowercase)
 *  C) { Items: [...], Passes / passes } variants (some endpoints name it passes)
 *
 * Returns array of records:
 * { edUid, soUid, cumMs, cumText, legMs, legText, status }
 */
function normalizeTimesLegacy(times) {
  const records = [];
  if (!times || typeof times !== "object") return records;

  // Items kan være array eller object/map
  const itemsRaw = times.Items || times.items || [];
  const items = Array.isArray(itemsRaw) ? itemsRaw : Object.values(itemsRaw);

  if (!Array.isArray(items) || items.length === 0) return records;

  for (const it of items) {
    if (!it || typeof it !== "object") continue;

    const edUid = Number(it.EtappeDeltakerUID);
    const soUid = Number(it.StasjonsOppsettUID);

    if (Number.isNaN(edUid) || Number.isNaN(soUid)) continue;

    const spl = it.Splitt || {};

    records.push({
      edUid,
      soUid,
      cumMs: (it.AkkumulertTid !== undefined ? it.AkkumulertTid : (it.RangeringsTid !== undefined ? it.RangeringsTid : null)),
      cumText: (it.Formatert !== undefined ? it.Formatert : null),
      legMs: (spl.Tid !== undefined ? spl.Tid : null),
      legText: (spl.Formatert !== undefined ? spl.Formatert : null),
      status: (it.StatusTekst !== undefined ? it.StatusTekst : null),
      passTime: (it.PasseringstidAsDateTime !== undefined ? it.PasseringstidAsDateTime :
        (it.PasseringsTid !== undefined ? it.PasseringsTid : null)),
      roundNumber: (it.Rundenummer !== undefined ? it.Rundenummer : null),
      addition: (it.Tillegg !== undefined ? it.Tillegg : null),
    });
  }

  return records;
}

function parseAdditionTotal(addition) {
  const parts = parseAdditionParts(addition);
  if (parts == null) return null;
  return parts.reduce((sum, value) => sum + value, 0);
}

function getShotIndexFromCode(code) {
  const m = normalizeCodeForMatch(code).match(/^(?:INS|UTS|IS|US|S)(\d+)$/i);
  if (!m) return null;

  const v = Number(m[1]);
  return Number.isNaN(v) ? null : v;
}

function getShootingPosition(shotIndex, shootingCount) {
  if (!shootingCount || shootingCount < 2) return "unknown";
  if (shootingCount === 2) return shotIndex === 1 ? "prone" : "standing";
  if (shootingCount === 4) return shotIndex <= 2 ? "prone" : "standing";
  return shotIndex <= Math.ceil(shootingCount / 2) ? "prone" : "standing";
}

function ensureShootingEntry(shooting, shotIndex) {
  const key = `shoot${shotIndex}`;
  if (!shooting[key]) {
    shooting[key] = {
      index: shotIndex,
      position: null,
      approachCumMs: null,
      inCumMs: null,
      shootingCumMs: null,
      outCumMs: null,
      rangeExitCumMs: null,
      rangeMs: null,
      rangeExitMs: null,
      penaltyMs: null,
      misses: null,
      cumulativeMisses: null,
      hits: null,
      addition: null,
      codes: {},
    };
  }
  return shooting[key];
}

function getAdditionPartsFromSplit(split) {
  if (Array.isArray(split.additionParts)) return split.additionParts;
  return parseAdditionParts(split.addition);
}

function sumAdditionParts(parts, count) {
  if (!Array.isArray(parts)) return null;
  const useCount = count == null ? parts.length : Math.min(count, parts.length);
  return parts.slice(0, useCount).reduce((sum, value) => sum + value, 0);
}

function buildPersistedRawPass(split) {
  return {
    setupUid: firstDefined(split.setupUid, null),
    code: firstDefined(split.code, null),
    kind: firstDefined(split.kind, null),
    sort: firstDefined(split.sort, null),
    cumRank: firstDefined(split.cumRank, null),
    legRank: firstDefined(split.legRank, null),
    cumMs: firstDefined(split.cumMs, null),
    legMs: firstDefined(split.legMs, null),
    cumText: firstDefined(split.cumText, null),
    legText: firstDefined(split.legText, null),
    status: firstDefined(split.status, null),
    addition: firstDefined(split.addition, null),
    additionParts: firstDefined(split.additionParts, null),
    legNumber: firstDefined(split.legNumber, split.etappeNumber, null),
    roundNumber: firstDefined(split.roundNumber, null),
  };
}

function deriveSkiTimeMs(netSkiTimeMs, penaltyTimeMs) {
  if (typeof netSkiTimeMs !== "number") return null;
  if (typeof penaltyTimeMs !== "number") return netSkiTimeMs;
  return Math.max(0, netSkiTimeMs - penaltyTimeMs);
}

function buildDerivedResultMetrics(splits, totalMs) {
  const splitEntries = Object.entries(splits || {})
    .map(([setupUid, split]) => {
      const code = split && split.code ? String(split.code) : String(setupUid);
      const kind = split && split.kind ? split.kind : classifySplitKind(code, split);
      return Object.assign({setupUid, code, kind}, split);
    })
    .sort((a, b) => {
      const aSort = typeof a.sort === "number" ? a.sort : null;
      const bSort = typeof b.sort === "number" ? b.sort : null;
      if (aSort != null && bSort != null && aSort !== bSort) return aSort - bSort;
      const aMs = typeof a.cumMs === "number" ? a.cumMs : Number.MAX_SAFE_INTEGER;
      const bMs = typeof b.cumMs === "number" ? b.cumMs : Number.MAX_SAFE_INTEGER;
      if (aMs !== bMs) return aMs - bMs;
      return Number(a.setupUid) - Number(b.setupUid);
    });

  const shooting = {};
  let finalAdditionParts = null;

  for (const split of splitEntries) {
    const code = String(split.code || "");
    const kind = split.kind || classifySplitKind(code, split);
    const shotIndex = getShotIndexFromCode(code);
    const additionParts = getAdditionPartsFromSplit(split);

    if (additionParts != null &&
      (finalAdditionParts == null || additionParts.length >= finalAdditionParts.length)) {
      finalAdditionParts = additionParts;
    }

    if (shotIndex == null) continue;

    const shot = ensureShootingEntry(shooting, shotIndex);
    shot.codes[kind] = code;

    if (kind === "rangeApproach" && typeof split.cumMs === "number") {
      shot.approachCumMs = split.cumMs;
    }
    if (kind === "rangeIn" && typeof split.cumMs === "number") {
      shot.inCumMs = split.cumMs;
    }
    if (kind === "shooting" && typeof split.cumMs === "number") {
      shot.shootingCumMs = split.cumMs;
    }
    if (kind === "rangeOut" && typeof split.cumMs === "number") {
      shot.outCumMs = split.cumMs;
    }
    if (kind === "rangeExit" && typeof split.cumMs === "number") {
      shot.rangeExitCumMs = split.cumMs;
    }

    if (additionParts && additionParts.length >= shotIndex) {
      shot.misses = additionParts[shotIndex - 1];
      shot.cumulativeMisses = sumAdditionParts(additionParts, shotIndex);
      shot.addition = additionParts.slice(0, shotIndex).join("+");
    }
  }

  const shootKeys = Object.keys(shooting)
    .sort((a, b) => Number(a.replace("shoot", "")) - Number(b.replace("shoot", "")));
  const shootingCount = shootKeys.length;
  const finalMissesTotal = finalAdditionParts != null ? sumAdditionParts(finalAdditionParts) : null;
  let rangeTimeMs = 0;
  let hasAnyRangeTime = false;
  let proneTimeMs = 0;
  let standingTimeMs = 0;
  let hasProneTime = false;
  let hasStandingTime = false;
  let proneMisses = 0;
  let standingMisses = 0;
  let proneHits = 0;
  let standingHits = 0;
  let penaltyTimeMs = 0;
  let hasCompletePenaltyTime = shootingCount > 0 && finalMissesTotal != null;
  const shootingResultParts = [];

  for (const shootKey of shootKeys) {
    const shotIndex = Number(shootKey.replace("shoot", ""));
    const shot = shooting[shootKey];
    shot.position = getShootingPosition(shotIndex, shootingCount);

    if (shot.misses == null && Array.isArray(finalAdditionParts) &&
      finalAdditionParts.length >= shotIndex) {
      shot.misses = finalAdditionParts[shotIndex - 1];
      shot.cumulativeMisses = sumAdditionParts(finalAdditionParts, shotIndex);
      shot.addition = finalAdditionParts.slice(0, shotIndex).join("+");
    }

    if (typeof shot.misses === "number") {
      shot.hits = Math.max(0, 5 - shot.misses);
      shootingResultParts.push(String(shot.misses));
    }

    const rangeEndMs = firstDefined(
      shot.outCumMs,
      shot.shootingCumMs,
      shot.rangeExitCumMs,
      null,
    );

    if (typeof shot.inCumMs === "number" && typeof rangeEndMs === "number") {
      shot.rangeMs = rangeEndMs - shot.inCumMs;
      rangeTimeMs += shot.rangeMs;
      hasAnyRangeTime = true;

      if (shot.position === "prone") {
        proneTimeMs += shot.rangeMs;
        hasProneTime = true;
      } else if (shot.position === "standing") {
        standingTimeMs += shot.rangeMs;
        hasStandingTime = true;
      }
    }

    if (typeof shot.inCumMs === "number" && typeof shot.rangeExitCumMs === "number") {
      shot.rangeExitMs = shot.rangeExitCumMs - shot.inCumMs;
    }

    // EQ Timing does not expose a dedicated penalty-loop duration. For a
    // missed shooting, the interval from S/UTS to US covers that segment.
    if (typeof shot.misses !== "number") {
      hasCompletePenaltyTime = false;
    } else if (shot.misses === 0) {
      shot.penaltyMs = 0;
    } else if (typeof rangeEndMs === "number" &&
      typeof shot.rangeExitCumMs === "number" &&
      shot.rangeExitCumMs >= rangeEndMs) {
      shot.penaltyMs = shot.rangeExitCumMs - rangeEndMs;
      penaltyTimeMs += shot.penaltyMs;
    } else {
      hasCompletePenaltyTime = false;
    }

    if (typeof shot.misses === "number") {
      if (shot.position === "prone") {
        proneMisses += shot.misses;
        proneHits += shot.hits != null ? shot.hits : 0;
      } else if (shot.position === "standing") {
        standingMisses += shot.misses;
        standingHits += shot.hits != null ? shot.hits : 0;
      }
    }
  }

  const laps = {};
  let lastSkiStartMs = 0;
  let lastSkiStartCode = "start";
  let lapIndex = 1;

  for (const shootKey of shootKeys) {
    const shot = shooting[shootKey];
    const lapEndMs = firstDefined(shot.inCumMs, shot.shootingCumMs, null);
    if (typeof lapEndMs === "number" && lapEndMs >= lastSkiStartMs) {
      laps[`lap${lapIndex}`] = {
        skiMs: lapEndMs - lastSkiStartMs,
        startCumMs: lastSkiStartMs,
        endCumMs: lapEndMs,
        startCode: lastSkiStartCode,
        endCode: firstDefined(shot.codes.rangeIn, shot.codes.shooting, null),
        beforeShooting: shot.index,
      };
      lapIndex++;
    }

    // US is the point after the shooting area and any penalty loop. Ski time
    // is measured from US to the next INS, so prefer it over UTS/S when EQ
    // exposes both kinds of passings.
    const nextSkiStart = [
      {cumMs: shot.rangeExitCumMs, code: shot.codes.rangeExit},
      {cumMs: shot.outCumMs, code: shot.codes.rangeOut},
      {cumMs: shot.shootingCumMs, code: shot.codes.shooting},
    ].find((point) => typeof point.cumMs === "number");
    if (nextSkiStart) {
      lastSkiStartMs = nextSkiStart.cumMs;
      lastSkiStartCode = firstDefined(nextSkiStart.code, "shooting");
    }
  }

  const finishSplit = splitEntries.find((split) => split.kind === "finish" || split.isStop);
  const finishMs = typeof (finishSplit && finishSplit.cumMs) === "number" ?
    finishSplit.cumMs :
    totalMs;
  if (typeof finishMs === "number" && finishMs >= lastSkiStartMs) {
    laps[`lap${lapIndex}`] = {
      skiMs: finishMs - lastSkiStartMs,
      startCumMs: lastSkiStartMs,
      endCumMs: finishMs,
      startCode: lastSkiStartCode,
      endCode: finishSplit ? finishSplit.code : "finish",
      beforeShooting: null,
    };
  }

  let skiTimeMs = null;
  const lapValues = Object.values(laps);
  if (lapValues.length > 0) {
    skiTimeMs = lapValues.reduce((sum, lap) => sum + (typeof lap.skiMs === "number" ? lap.skiMs : 0), 0);
  }

  const targetsTotal = shootingCount ? shootingCount * 5 : null;
  const hitsTotal = targetsTotal != null && finalMissesTotal != null ?
    Math.max(0, targetsTotal - finalMissesTotal) :
    null;

  const persistedSplitEntries = splitEntries.map(buildPersistedRawPass);
  const explicitPenaltyTimeMs = splitEntries.reduce((largest, split) => {
    if (typeof split.cumMs !== "number" ||
      typeof split.cumMsWithoutAddition !== "number") {
      return largest;
    }
    return Math.max(largest, split.cumMs - split.cumMsWithoutAddition);
  }, 0);
  const measuredPenaltyTimeMs = hasCompletePenaltyTime ? penaltyTimeMs : null;
  const totalPenaltyTimeMs = explicitPenaltyTimeMs > 0 ?
    (measuredPenaltyTimeMs || 0) + explicitPenaltyTimeMs :
    measuredPenaltyTimeMs;
  // netSkiTimeMs is the course time with shooting time removed. When EQ
  // exposes UTS/S separately it still includes penalty loops; skiTimeMs is
  // the more precise US-to-INS sum and therefore must not subtract penalty
  // time a second time.
  let netSkiTimeMs = null;
  if (typeof totalMs === "number" && hasAnyRangeTime) {
    netSkiTimeMs = Math.max(0, totalMs - rangeTimeMs);
  } else if (typeof skiTimeMs === "number") {
    netSkiTimeMs = skiTimeMs;
  }
  if (typeof skiTimeMs !== "number") {
    skiTimeMs = deriveSkiTimeMs(netSkiTimeMs, totalPenaltyTimeMs);
  }

  return {
    rawPasses: persistedSplitEntries,
    analysis: {
      courseTimeMs: (typeof totalMs === "number" ? totalMs : null),
      skiTimeMs,
      netSkiTimeMs,
      rangeTimeMs: hasAnyRangeTime ? rangeTimeMs : null,
      shootingTimeMs: hasAnyRangeTime ? rangeTimeMs : null,
      penaltyTimeMs: totalPenaltyTimeMs,
      missesTotal: finalMissesTotal,
      hitsTotal,
      targetsTotal,
      proneTimeMs: hasProneTime ? proneTimeMs : null,
      standingTimeMs: hasStandingTime ? standingTimeMs : null,
      shootingResult: shootingResultParts.length ? shootingResultParts.join("+") : null,
      proneMisses: shootingResultParts.length ? proneMisses : null,
      standingMisses: shootingResultParts.length ? standingMisses : null,
      proneHits: shootingResultParts.length ? proneHits : null,
      standingHits: shootingResultParts.length ? standingHits : null,
      shootingCount: shootingCount || null,
      skiRank: null,
      netSkiRank: null,
      rangeRank: null,
      shootRank: null,
      penaltyRank: null,
    },
    shooting,
    laps,
  };
}

function buildRelayLegBiathlon(splits) {
  const entries = Object.entries(splits || {})
    .map(([setupUid, split]) => Object.assign({setupUid}, split))
    .filter((split) => relaySplitLegNumber(split) != null);
  const legNumbers = Array.from(new Set(entries.map((split) =>
    relaySplitLegNumber(split)))).sort((a, b) => a - b);
  const legs = [];
  let previousLegNumber = null;
  let previousEndMs = null;
  let previousEndWithoutAdditionMs = null;

  for (const legNumber of legNumbers) {
    const legEntries = entries
      .filter((split) => relaySplitLegNumber(split) === legNumber)
      .sort(compareSplitRows);
    const timedEntries = legEntries.filter((split) =>
      Number.isFinite(split.cumMs));
    if (timedEntries.length === 0) continue;
    // A shooting/mid-course passing is not proof of an exchange. The
    // preceding numbered leg, not the preceding available row, owns the start.
    const endpoints = timedEntries.filter((split) =>
      split.cumMs >= 0 && (split.kind === "finish" || split.isStop === true ||
      classifySplitKind(split.code, split) === "finish" ||
      /^(?:\d+[.\s-]*)?(?:veksling|exchange)(?:[.\s-]*\d+)?$/i
        .test(String(split.code || "").trim())));
    const endpoint = endpoints.length ? endpoints.reduce((latest, split) =>
      split.cumMs >= latest.cumMs ? split : latest) : null;
    const startMs = legNumber === 1 ? 0 :
      previousLegNumber === legNumber - 1 ? previousEndMs : null;
    const startWithoutAdditionMs = legNumber === 1 ? 0 :
      previousLegNumber === legNumber - 1 ? previousEndWithoutAdditionMs : null;
    const totalMs = endpoint && startMs != null ? endpoint.cumMs - startMs : null;
    if (totalMs != null && totalMs < 0) continue;

    const originalShotIndexes = [];
    for (const split of legEntries) {
      const shotIndex = getShotIndexFromCode(split.code);
      if (shotIndex != null && !originalShotIndexes.includes(shotIndex)) {
        originalShotIndexes.push(shotIndex);
      }
    }
    const localShotIndexes = new Map(originalShotIndexes.map(
      (shotIndex, index) => [shotIndex, index + 1],
    ));
    const encounteredShotIndexes = [];
    const localSplits = {};

    for (const split of legEntries) {
      const originalShotIndex = getShotIndexFromCode(split.code);
      if (originalShotIndex != null &&
        !encounteredShotIndexes.includes(originalShotIndex)) {
        encounteredShotIndexes.push(originalShotIndex);
      }
      const localShotIndex = localShotIndexes.get(originalShotIndex);
      const codeMatch = String(split.code || "")
        .match(/^(INS|UTS|IS|US|S)\d+$/i);
      const code = codeMatch && localShotIndex != null ?
        `${codeMatch[1]}${localShotIndex}` :
        split.code;
      const additionParts = localRelayAdditionParts(
        getAdditionPartsFromSplit(split),
        originalShotIndexes,
        encounteredShotIndexes,
      );
      localSplits[split.setupUid] = Object.assign({}, split, {
        code,
        cumMs: Number.isFinite(split.cumMs) ?
          split.cumMs - (startMs == null ? 0 : startMs) : null,
        cumMsWithoutAddition: Number.isFinite(split.cumMsWithoutAddition) &&
          startMs != null && startWithoutAdditionMs != null ?
          split.cumMsWithoutAddition - startWithoutAdditionMs : null,
        additionParts,
        addition: additionParts == null ? null : additionParts.join("+"),
      });
      if (split === endpoint) localSplits[split.setupUid].kind = "finish";
    }

    const derived = buildDerivedResultMetrics(localSplits, totalMs);
    if (totalMs == null) {
      // Partial laps are useful, but cannot stand in for the full leg.
      derived.analysis.courseTimeMs = null;
      derived.analysis.netSkiTimeMs = null;
      derived.analysis.skiTimeMs = null;
    }
    if (startMs == null) {
      // Absolute team times still yield valid within-leg differences. Do not
      // persist them as cumulative times relative to an unknown leg start.
      for (const pass of Object.values(derived.shooting)) {
        for (const key of ["approachCumMs", "inCumMs", "shootingCumMs",
          "outCumMs", "rangeExitCumMs"]) pass[key] = null;
      }
      for (const [key, lap] of Object.entries(derived.laps)) {
        if (lap.startCode === "start") {
          delete derived.laps[key];
        } else {
          lap.startCumMs = null;
          lap.endCumMs = null;
        }
      }
    }
    const biathlon = withoutHitFields(derived.analysis, derived.shooting, derived.laps);
    legs.push({
      legNumber,
      totalMs,
      biathlon: Object.assign({version: 1}, biathlon),
    });
    previousLegNumber = legNumber;
    previousEndMs = endpoint ? endpoint.cumMs : null;
    previousEndWithoutAdditionMs = endpoint &&
      Number.isFinite(endpoint.cumMsWithoutAddition) &&
      endpoint.cumMsWithoutAddition >= 0 ?
      endpoint.cumMsWithoutAddition : null;
  }
  return legs;
}

function relaySplitLegNumber(split) {
  return toNumberOrNull(firstDefined(
    split && split.legNumber,
    split && split.etappeNumber,
    null,
  ));
}

function localRelayAdditionParts(parts, originalIndexes, encounteredIndexes) {
  if (!Array.isArray(parts)) return null;
  if (encounteredIndexes.length === 0) return [];
  const maxOriginalIndex = Math.max(...originalIndexes);
  if (originalIndexes[0] === 1 && parts.length > maxOriginalIndex) {
    return parts.slice(-encounteredIndexes.length);
  }
  return encounteredIndexes
    .map((index) => parts[index - 1])
    .filter((value) => typeof value === "number");
}

function buildDerivedResultMetricsLegacy(splits, totalMs) {
  const splitEntries = Object.entries(splits || {})
    .map(([setupUid, split]) => Object.assign({setupUid}, split))
    .sort((a, b) => {
      const aMs = typeof a.cumMs === "number" ? a.cumMs : Number.MAX_SAFE_INTEGER;
      const bMs = typeof b.cumMs === "number" ? b.cumMs : Number.MAX_SAFE_INTEGER;
      return aMs - bMs;
    });

  const shooting = {};
  const shotCumulativeMisses = {};
  let finalAddition = null;

  for (const split of splitEntries) {
    const code = String(split.code || "");
    const shotIndex = getShotIndexFromCode(code);
    const additionTotal = parseAdditionTotal(split.addition);

    if (additionTotal != null) {
      finalAddition = additionTotal;
    }

    if (shotIndex == null) continue;

    if (!shooting[`shoot${shotIndex}`]) {
      shooting[`shoot${shotIndex}`] = {
        inCumMs: null,
        outCumMs: null,
        rangeMs: null,
        misses: null,
      };
    }

    if (/^INS\d+$/i.test(code) && typeof split.cumMs === "number") {
      shooting[`shoot${shotIndex}`].inCumMs = split.cumMs;
    }

    if ((/^UTS\d+$/i.test(code) || /^S\d+$/i.test(code)) && typeof split.cumMs === "number") {
      if (shooting[`shoot${shotIndex}`].outCumMs == null ||
        split.cumMs > shooting[`shoot${shotIndex}`].outCumMs) {
        shooting[`shoot${shotIndex}`].outCumMs = split.cumMs;
      }
    }

    if (additionTotal != null) {
      if (shotCumulativeMisses[shotIndex] == null ||
        additionTotal > shotCumulativeMisses[shotIndex]) {
        shotCumulativeMisses[shotIndex] = additionTotal;
      }
    }
  }

  const shootKeys = Object.keys(shooting).sort((a, b) => Number(a.replace("shoot", "")) - Number(b.replace("shoot", "")));
  let rangeTimeMs = 0;
  let hasAnyRangeTime = false;
  let proneTimeMs = 0;
  let standingTimeMs = 0;
  let hasProneTime = false;
  let hasStandingTime = false;
  let previousCumulativeMisses = 0;
  let proneMisses = 0;
  let standingMisses = 0;
  const shootingResultParts = [];

  for (const shootKey of shootKeys) {
    const shotIndex = Number(shootKey.replace("shoot", ""));
    const shot = shooting[shootKey];

    if (typeof shot.inCumMs === "number" && typeof shot.outCumMs === "number") {
      shot.rangeMs = shot.outCumMs - shot.inCumMs;
      rangeTimeMs += shot.rangeMs;
      hasAnyRangeTime = true;

      if (shotIndex <= 2) {
        proneTimeMs += shot.rangeMs;
        hasProneTime = true;
      } else {
        standingTimeMs += shot.rangeMs;
        hasStandingTime = true;
      }
    }

    if (shotCumulativeMisses[shotIndex] != null) {
      shot.misses = shotCumulativeMisses[shotIndex] - previousCumulativeMisses;
      previousCumulativeMisses = shotCumulativeMisses[shotIndex];
    }

    if (typeof shot.misses === "number") {
      shootingResultParts.push(String(shot.misses));
      if (shotIndex <= 2) {
        proneMisses += shot.misses;
      } else {
        standingMisses += shot.misses;
      }
    }
  }

  const lapBoundaries = [];
  for (const split of splitEntries) {
    const code = String(split.code || "");
    if (/^INS\d+$/i.test(code) || /^UTS\d+$/i.test(code) || /mål|maal/i.test(code)) {
      lapBoundaries.push({
        code,
        cumMs: split.cumMs,
      });
    }
  }

  const laps = {};
  let lastBoundaryMs = 0;
  let lapIndex = 1;

  for (const boundary of lapBoundaries) {
    if (typeof boundary.cumMs !== "number") continue;

    if (/^INS\d+$/i.test(boundary.code) || /mål|maal/i.test(boundary.code)) {
      laps[`lap${lapIndex}`] = {
        skiMs: boundary.cumMs - lastBoundaryMs,
        endCode: boundary.code,
      };
      lapIndex++;
    }

    if (/^UTS\d+$/i.test(boundary.code)) {
      lastBoundaryMs = boundary.cumMs;
    }
  }

  let netSkiTimeMs = null;
  const lapValues = Object.values(laps);
  if (lapValues.length > 0) {
    netSkiTimeMs = lapValues.reduce((sum, lap) => sum + (typeof lap.skiMs === "number" ? lap.skiMs : 0), 0);
  } else if (typeof totalMs === "number" && hasAnyRangeTime) {
    netSkiTimeMs = totalMs - rangeTimeMs;
  }
  const skiTimeMs = deriveSkiTimeMs(netSkiTimeMs, null);

  return {
    rawPasses: splitEntries.map((split) => {
      const copy = Object.assign({}, split);
      delete copy.addition;
      delete copy.diff;
      delete copy.placement;
      return copy;
    }),
    analysis: {
      courseTimeMs: (typeof totalMs === "number" ? totalMs : null),
      skiTimeMs,
      netSkiTimeMs,
      rangeTimeMs: hasAnyRangeTime ? rangeTimeMs : null,
      shootingTimeMs: hasAnyRangeTime ? rangeTimeMs : null,
      penaltyTimeMs: null,
      missesTotal: finalAddition,
      hitsTotal: null,
      proneTimeMs: hasProneTime ? proneTimeMs : null,
      standingTimeMs: hasStandingTime ? standingTimeMs : null,
      shootingResult: shootingResultParts.length ? shootingResultParts.join("+") : null,
      proneMisses: shootingResultParts.length ? proneMisses : null,
      standingMisses: shootingResultParts.length ? standingMisses : null,
      shootingCount: shootKeys.length || null,
      skiRank: null,
      netSkiRank: null,
      rangeRank: null,
      shootRank: null,
      penaltyRank: null,
    },
    shooting,
    laps,
  };
}

function addMetricRanks(results, field, rankField, options = {}) {
  const metricsOf = (result) => result.analysis && result.analysis.biathlon ?
    result.analysis.biathlon.metrics :
    result.analysis;
  const ranked = results
    .filter((r) => {
      const metrics = metricsOf(r);
      const value = metrics && metrics[field];
      return metrics &&
        !isNonFinishStatus(r.status) &&
        typeof value === "number" &&
        Number.isFinite(value) &&
        (options.positiveOnly !== true || value > 0);
    })
    .sort((a, b) => metricsOf(a)[field] - metricsOf(b)[field]);

  for (const result of results) {
    const metrics = metricsOf(result);
    if (metrics) metrics[rankField] = null;
  }

  let previousValue = null;
  let previousRank = null;

  for (let i = 0; i < ranked.length; i++) {
    const metrics = metricsOf(ranked[i]);
    const value = metrics[field];
    const rank = (previousValue != null && value === previousValue) ? previousRank : i + 1;
    metrics[rankField] = rank;
    previousValue = value;
    previousRank = rank;
  }
}

function addShootingPassRanks(results) {
  const grouped = new Map();

  for (const result of results) {
    const addPasses = (passes, groupKey) => {
      if (!passes || typeof passes !== "object") return;

      for (const [fallbackKey, pass] of Object.entries(passes)) {
        if (!pass || typeof pass !== "object") continue;
        pass.rangeRank = null;
        if (isNonFinishStatus(result.status)) continue;

        const index = Number.isFinite(Number(pass.index)) ?
          Number(pass.index) :
          Number(String(fallbackKey).match(/(\d+)$/)?.[1]);
        const rangeMs = pass.rangeMs;
        if (!Number.isInteger(index) || index <= 0 ||
          typeof rangeMs !== "number" || !Number.isFinite(rangeMs) || rangeMs <= 0) {
          continue;
        }

        const key = `${groupKey}:${index}`;
        if (!grouped.has(key)) grouped.set(key, []);
        grouped.get(key).push({pass, rangeMs});
      }
    };

    const biathlon = result.analysis && result.analysis.biathlon;
    addPasses(biathlon && biathlon.passes, "main");

    const legs = result.team && Array.isArray(result.team.legs) ?
      result.team.legs :
      [];
    for (const leg of legs) {
      if (!leg || typeof leg !== "object") continue;
      const legNumber = Number(leg.legNumber);
      if (!Number.isInteger(legNumber) || legNumber <= 0) continue;
      const legBiathlon = leg.biathlon;
      addPasses(
        legBiathlon && legBiathlon.passes,
        `leg:${legNumber}`,
      );
    }
  }

  for (const entries of grouped.values()) {
    entries.sort((a, b) => a.rangeMs - b.rangeMs);
    let previousValue = null;
    let previousRank = null;
    for (let i = 0; i < entries.length; i++) {
      const value = entries[i].rangeMs;
      const rank = previousValue != null && value === previousValue ?
        previousRank :
        i + 1;
      entries[i].pass.rangeRank = rank;
      previousValue = value;
      previousRank = rank;
    }
  }
}

function isNonFinishStatus(status) {
  const text = String(status || "").trim().toUpperCase();
  return text.includes("DNF") ||
    text.includes("DNS") ||
    text.includes("DSQ") ||
    text.includes("DQ") ||
    text.includes("DID NOT FINISH") ||
    text.includes("DID NOT START") ||
    text.includes("IKKE STARTET") ||
    text.includes("STARTET IKKE") ||
    text.includes("DISQUAL") ||
    text.includes("BRUTT") ||
    text.includes("IKKE FULLF");
}

function addClassRanks(results) {
  for (const result of results) {
    result.finishRank = null;
  }

  const ranked = results
    .filter((r) =>
      typeof r.totalMs === "number" &&
      r.totalMs > 0 &&
      !isNonFinishStatus(r.status))
    .sort((a, b) => a.totalMs - b.totalMs);

  let previousValue = null;
  let previousRank = null;

  for (let i = 0; i < ranked.length; i++) {
    const value = ranked[i].totalMs;
    const rank = (previousValue != null && value === previousValue) ? previousRank : i + 1;
    ranked[i].rank = rank;
    ranked[i].finishRank = rank;
    previousValue = value;
    previousRank = rank;
  }
}

function addRawPassRanks(results) {
  const cumBySetupUid = new Map();
  const legBySetupUid = new Map();

  for (const result of results) {
    const rawPasses = Array.isArray(result.timingPoints) ? result.timingPoints : [];
    for (const pass of rawPasses) {
      if (!pass || typeof pass !== "object") continue;
      pass.cumRank = null;
      pass.cumRankCount = null;
      pass.legRank = null;
      pass.legRankCount = null;
      if (isNonFinishStatus(result.status) || pass.setupUid == null) continue;

      const key = String(pass.setupUid);
      if (typeof pass.cumMs === "number" && Number.isFinite(pass.cumMs) && pass.cumMs > 0) {
        if (!cumBySetupUid.has(key)) cumBySetupUid.set(key, []);
        cumBySetupUid.get(key).push(pass);
      }
      if (typeof pass.legMs === "number" && Number.isFinite(pass.legMs) && pass.legMs > 0) {
        if (!legBySetupUid.has(key)) legBySetupUid.set(key, []);
        legBySetupUid.get(key).push(pass);
      }
    }
  }

  addRawPassRankForGroups(cumBySetupUid, "cumMs", "cumRank", "cumRankCount");
  addRawPassRankForGroups(legBySetupUid, "legMs", "legRank", "legRankCount");
}

function addRawPassRankForGroups(groupedPasses, valueField, rankField, countField) {
  for (const passes of groupedPasses.values()) {
    passes.sort((a, b) => a[valueField] - b[valueField]);

    let previousValue = null;
    let previousRank = null;
    for (let i = 0; i < passes.length; i++) {
      const value = passes[i][valueField];
      const rank = (previousValue != null && value === previousValue) ? previousRank : i + 1;
      passes[i][rankField] = rank;
      passes[i][countField] = passes.length;
      previousValue = value;
      previousRank = rank;
    }
  }
}
/**
 * Batch commit helper (avoid >500 writes per batch).
 */

/**
 * Core import logic used by the HTTP function (also testable).
 */

function getEtappeUidFromTimesUrlBase(timesUrlBase) {
  // matcher: /api/Result/Class/80088/330315/1224375?...
  const m = String(timesUrlBase).match(/\/api\/Result\/Class\/\d+\/(\d+)\/\d+/);
  if (!m) return null;
  const v = Number(m[1]);
  return Number.isNaN(v) ? null : v;
}
function buildTimesUrlBase(eventId, etappeUid, classId) {
  // base-url uten station (vi setter station i withStation())
  return `https://live.eqtiming.com/api/Result/Class/${eventId}/${etappeUid}/${classId}` +
    `?justTimeData=true&count=1000&startAt=1&query=&round=1&passes=true&sortpoint=0`;
}

function getEtappeUidFromParticipants(participants, classId) {
  if (!participants || typeof participants !== "object") return null;

  let list = null;
  if (Array.isArray(participants)) {
    list = participants;
  } else if (Array.isArray(participants.Items)) {
    list = participants.Items;
  } else if (Array.isArray(participants.items)) {
    list = participants.items;
  } else {
    list = Object.values(participants);
  }

  const counts = new Map();

  for (const p of list) {
    if (!p || typeof p !== "object") continue;

    const klasseUid =
      (p.Klasse && p.Klasse.UID != null) ? Number(p.Klasse.UID) :
      (p.KlasseUID != null) ? Number(p.KlasseUID) :
      null;

    if (klasseUid == null || Number.isNaN(klasseUid) || klasseUid !== Number(classId)) {
      continue;
    }

    const etappeUid =
      (p.Pulje && p.Pulje.EtappeUID != null) ? Number(p.Pulje.EtappeUID) :
      (p.EtappeUID != null) ? Number(p.EtappeUID) :
      null;

    if (etappeUid == null || Number.isNaN(etappeUid) || etappeUid === 0) continue;

    counts.set(etappeUid, (counts.get(etappeUid) || 0) + 1);
  }

  let bestEtappeUid = null;
  let bestCount = -1;

  for (const [etappeUid, count] of counts.entries()) {
    if (count > bestCount) {
      bestEtappeUid = etappeUid;
      bestCount = count;
    }
  }

  return bestEtappeUid;
}

function getEtappeUidFromEvent(event, classId, participants) {
  const cid = String(classId);

  // A) BEST: bruk contestants som fasit hvis samme klasse finnes i flere etapper.
  const participantEtappeUid = getEtappeUidFromParticipants(participants, classId);
  if (participantEtappeUid != null) {
    return participantEtappeUid;
  }

  // B) event.Etapper[etappeUid].Klasser[cid] finnes (stabilt i din event.json)
  if (event && event.Etapper && typeof event.Etapper === "object") {
    for (const [etappeUidStr, etappe] of Object.entries(event.Etapper)) {
      if (!etappe || typeof etappe !== "object") continue;
      const kl = etappe.Klasser || {};
      if (kl && Object.prototype.hasOwnProperty.call(kl, cid)) {
        const v = Number(etappeUidStr);
        return Number.isNaN(v) ? null : v;
      }
    }
  }

  // C) Fallback: event.Runder["<etappeUid>_<rundeNr>"].Klasser[cid]
  if (event && event.Runder && typeof event.Runder === "object") {
    for (const [rundeKey, r] of Object.entries(event.Runder)) {
      if (!r || typeof r !== "object") continue;
      const kl = r.Klasser || {};
      if (kl && Object.prototype.hasOwnProperty.call(kl, cid)) {
        const m = String(rundeKey).match(/^(\d+)_/);
        if (m) {
          const v = Number(m[1]);
          return Number.isNaN(v) ? null : v;
        }
      }
    }
  }

  // D) Siste fallback: hvis class-objektet selv tilfeldigvis har EtappeUID (ofte 0 hos deg)
  const classObj = (event && event.Klasser) ? event.Klasser[cid] : null;
  if (classObj && classObj.EtappeUID != null && Number(classObj.EtappeUID) !== 0) {
    const v = Number(classObj.EtappeUID);
    return Number.isNaN(v) ? null : v;
  }

  return null;
}

function getClassIdsWithContestants(participants) {
  const set = new Set();
  if (!participants || typeof participants !== "object") return [];

  // participants kan være:
  // A) object keyed by participantUID (vanlig hos EQ)
  // B) { Items: [...] } eller { items: [...] } (noen endpoints)
  let list = null;

  if (Array.isArray(participants)) {
    list = participants;
  } else if (Array.isArray(participants.Items)) {
    list = participants.Items;
  } else if (Array.isArray(participants.items)) {
    list = participants.items;
  } else {
    list = Object.values(participants);
  }

  for (const p of list) {
    if (!p || typeof p !== "object") continue;

    const klasseUid =
      (p.Klasse && p.Klasse.UID != null) ? Number(p.Klasse.UID) :
      (p.KlasseUID != null) ? Number(p.KlasseUID) :
      null;

    if (klasseUid != null && !Number.isNaN(klasseUid)) set.add(klasseUid);
  }

  return Array.from(set.values());
}

function buildClassOverview(event, participants) {
  const overview = [];
  const countsByEtappeAndClass = new Map();

  let list = null;
  if (Array.isArray(participants)) {
    list = participants;
  } else if (participants && Array.isArray(participants.Items)) {
    list = participants.Items;
  } else if (participants && Array.isArray(participants.items)) {
    list = participants.items;
  } else if (participants && typeof participants === "object") {
    list = Object.values(participants);
  } else {
    list = [];
  }

  for (const p of list) {
    if (!p || typeof p !== "object") continue;

    const classId =
      (p.Klasse && p.Klasse.UID != null) ? Number(p.Klasse.UID) :
      (p.KlasseUID != null) ? Number(p.KlasseUID) :
      null;
    const etappeUid =
      (p.Pulje && p.Pulje.EtappeUID != null) ? Number(p.Pulje.EtappeUID) :
      (p.EtappeUID != null) ? Number(p.EtappeUID) :
      null;

    if (classId == null || Number.isNaN(classId)) continue;

    const key = `${etappeUid != null && !Number.isNaN(etappeUid) ? etappeUid : "none"}:${classId}`;
    countsByEtappeAndClass.set(key, (countsByEtappeAndClass.get(key) || 0) + 1);
  }

  const seen = new Set();
  if (event && event.Etapper && typeof event.Etapper === "object") {
    for (const [etappeUidStr, etappe] of Object.entries(event.Etapper)) {
      if (!etappe || typeof etappe !== "object") continue;
      const etappeUid = Number(etappeUidStr);
      const etappeName = etappe.Navn || null;
      const klasser = etappe.Klasser || {};

      for (const classIdStr of Object.keys(klasser)) {
        const classId = Number(classIdStr);
        if (Number.isNaN(classId)) continue;

        const key = `${etappeUid}:${classId}`;
        if (seen.has(key)) continue;
        seen.add(key);

        const classObj = (event.Klasser || {})[String(classId)] || null;
        overview.push({
          etappeUid,
          etappeName,
          classId,
          className: classObj && classObj.Navn ? classObj.Navn : null,
          contestantCount: countsByEtappeAndClass.get(key) || 0,
        });
      }
    }
  }

  for (const [key, contestantCount] of countsByEtappeAndClass.entries()) {
    if (seen.has(key)) continue;

    const parts = key.split(":");
    const etappeUid = parts[0] === "none" ? null : Number(parts[0]);
    const classId = Number(parts[1]);
    const classObj = event && event.Klasser ? event.Klasser[String(classId)] : null;
    const etappeObj = etappeUid != null && event && event.Etapper ?
      event.Etapper[String(etappeUid)] :
      null;

    overview.push({
      etappeUid,
      etappeName: etappeObj && etappeObj.Navn ? etappeObj.Navn : null,
      classId,
      className: classObj && classObj.Navn ? classObj.Navn : null,
      contestantCount,
    });
  }

  overview.sort((a, b) => {
    if ((a.etappeUid || 0) !== (b.etappeUid || 0)) {
      return (a.etappeUid || 0) - (b.etappeUid || 0);
    }
    if (a.className && b.className && a.className !== b.className) {
      return a.className.localeCompare(b.className);
    }
    return a.classId - b.classId;
  });

  return overview;
}

function buildEventParticipantSummary(participants) {
  const entries = getParticipantEntries(participants)
    .filter((entry) => entry[1] && typeof entry[1] === "object");
  const ages = entries
    .map((entry) => toNumberOrNull(entry[1].Alder))
    .filter((age) => age != null && age >= 0 && age <= 120);
  let ageFrom = null;
  let ageTo = null;
  for (const age of ages) {
    ageFrom = ageFrom == null ? age : Math.min(ageFrom, age);
    ageTo = ageTo == null ? age : Math.max(ageTo, age);
  }

  return {
    participantCount: entries.length,
    ageFrom,
    ageTo,
  };
}

function buildEventDoc(event, eventId, participants) {
  const sport = event && event.Gren ? event.Gren : {};
  const sportParent = sport && sport.Parent ? sport.Parent : {};
  const discipline = event && event.Disiplin ? event.Disiplin : {};
  const federation = event && event.Forbund ? event.Forbund : {};
  const country = event && event.Land ? event.Land : {};
  const resultSetup = event && event.ResultatOppsett ? event.ResultatOppsett : {};
  const participantSummary = buildEventParticipantSummary(participants);

  const eventProfile = profileForStage(event, eventId, null, null);
  return {
    schemaVersion: 3,
    eventId,
    name: event && event.Navn ? event.Navn : null,
    date: firstDefined(event && event.Dato, event && event.Aktiv, null),
    timezone: firstDefined(event && event.TidsSone, null),
    timezoneOffset: firstDefined(event && event.TimezoneOffset, null),
    firstStart: firstDefined(event && event.ForsteStart, null),
    startTime: firstDefined(event && event.StartTid, null),
    stopTime: firstDefined(event && event.StoppTid, null),
    place: firstDefined(event && event.Sted, null),
    participantCount: participantSummary.participantCount,
    ageFrom: participantSummary.ageFrom,
    ageTo: participantSummary.ageTo,
    organizer: firstDefined(event && event.Arrangor, null),
    published: firstDefined(event && event.Publiseres, null),
    resultPublished: firstDefined(event && event.Resultat, null),
    sportName: firstDefined(sport.Navn, null),
    sportCode: firstDefined(sport.Kode, null),
    sportParentName: firstDefined(sportParent.Name, null),
    sport: {
      uid: firstDefined(sport.UID, null),
      name: firstDefined(sport.Navn, null),
      code: firstDefined(sport.Kode, null),
      speed: firstDefined(sport.Hastighet, null),
      parentId: firstDefined(sportParent.Id, null),
      parentName: firstDefined(sportParent.Name, null),
    },
    discipline: {
      uid: firstDefined(discipline.UID, null),
      name: firstDefined(discipline.Navn, null),
      code: firstDefined(discipline.Kode, null),
    },
    federation: {
      uid: firstDefined(federation.UID, null),
      name: firstDefined(federation.Navn, null),
    },
    country: {
      uid: firstDefined(country.UID, null),
      name: firstDefined(country.Navn, null),
      iso2: firstDefined(country.ISO2, null),
      iso3: firstDefined(country.ISO3, null),
      ioc: firstDefined(country.IOC, null),
    },
    resultSettings: {
      showTime: firstDefined(resultSetup.VisTid, null),
      showDiff: firstDefined(resultSetup.VisDiff, null),
      showClub: firstDefined(resultSetup.VisKlubb, null),
      showBirthYear: firstDefined(resultSetup.VisFodt, null),
      showLiveShooting: firstDefined(resultSetup.VisLiveShooting, null),
      hideSplitResults: firstDefined(resultSetup.HideSplitResults, null),
      hideTrackingOnLive: firstDefined(resultSetup.HideTrackingOnLive, null),
      resultRowCount: firstDefined(resultSetup.AntallRader, null),
      nameFormat: firstDefined(resultSetup.NavnFormat, null),
      clubFormat: firstDefined(resultSetup.KlubbFormat, event && event.KlubbFormat, null),
    },
    resultProfile: eventProfile.profile,
    resultProfileSource: eventProfile.determinedBy,
    source: FieldValue.delete(),
  };
}

function getEventStages(event) {
  if (!event || !event.Etapper || typeof event.Etapper !== "object") return [];
  return Object.entries(event.Etapper)
    .map(([id, stage], index) => ({
      id: String(firstDefined(stage && stage.UID, id)),
      index,
      stage,
    }))
    .filter((entry) => entry.stage && typeof entry.stage === "object");
}

function choosePrimaryStageId(event, classId) {
  const classKey = String(classId);
  const candidates = getEventStages(event).filter((entry) => {
    const classes = entry.stage.Klasser || {};
    return Object.prototype.hasOwnProperty.call(classes, classKey);
  });
  candidates.sort(compareStagePriority);
  return candidates.length ? candidates[0].id : null;
}

function compareStagePriority(a, b) {
  const aLevel = toNumberOrNull(a.stage.Nivaa);
  const bLevel = toNumberOrNull(b.stage.Nivaa);
  const aPriority = aLevel === 1 ? -1 : (aLevel == null ? 1000 : aLevel);
  const bPriority = bLevel === 1 ? -1 : (bLevel == null ? 1000 : bLevel);
  return aPriority - bPriority || a.index - b.index;
}

function classStageAthleteCount(summary) {
  const participantCount = toNumberOrNull(summary && summary.participantCount);
  if (participantCount != null && participantCount > 0) return participantCount;
  const resultCount = toNumberOrNull(summary && summary.resultCount);
  return resultCount != null && resultCount > 0 ? resultCount : 0;
}

function choosePrimaryStageSummary(event, classId, stageSummaries) {
  const classKey = String(classId);
  const stageEntries = getEventStages(event).filter((entry) => {
    const classes = entry.stage.Klasser || {};
    return Object.prototype.hasOwnProperty.call(classes, classKey);
  });
  const entryById = new Map(stageEntries.map((entry) => [entry.id, entry]));
  const candidates = stageSummaries
    .map((summary) => {
      const stageId = String(summary.stageId);
      const stage = entryById.get(stageId);
      if (!stage) return null;
      return {
        data: summary.data,
        stageId,
        stage,
        athleteCount: classStageAthleteCount(summary.data),
      };
    })
    .filter((candidate) => candidate != null);

  candidates.sort((a, b) => {
    if (a.athleteCount !== b.athleteCount) {
      return b.athleteCount - a.athleteCount;
    }
    return compareStagePriority(a.stage, b.stage);
  });
  return candidates.length ? candidates[0] : null;
}

async function refreshClassRootSummary(eventDocRef, event, classId) {
  const classKey = String(classId);
  const stageEntries = getEventStages(event).filter((entry) => {
    const classes = entry.stage.Klasser || {};
    return Object.prototype.hasOwnProperty.call(classes, classKey);
  });
  if (stageEntries.length === 0) return null;

  const snapshots = await getDb().getAll(
    ...stageEntries.map((entry) =>
      eventDocRef
        .collection("stages")
        .doc(entry.id)
        .collection("classes")
        .doc(classKey)),
  );
  const stageSummaries = snapshots
    .map((snapshot, index) => ({
      stageId: snapshot.exists && snapshot.data().stageId || stageEntries[index].id,
      data: snapshot.exists ? snapshot.data() : null,
    }))
    .filter((summary) => summary.data != null);
  const primary = choosePrimaryStageSummary(event, classId, stageSummaries);
  if (!primary) return null;

  const rootSummary = sanitizeForFirestore(Object.assign({}, primary.data, {
    primaryStageId: primary.stageId,
    updatedAt: FieldValue.serverTimestamp(),
  })) || {};
  await setImportDocument(eventDocRef.collection("classes").doc(classKey),
    rootSummary,
    {merge: true},
  );
  return primary;
}

function buildStageDoc(event, eventId, etappeUid, profileOverride) {
  const entry = getEventStages(event).find((candidate) =>
    candidate.id === String(etappeUid));
  const stage = entry ? entry.stage : {};
  const classification = profileForStage(
    event,
    eventId,
    etappeUid,
    profileOverride,
  );
  const classIds = Object.keys(stage.Klasser || {})
    .map(toNumberOrNull)
    .filter((id) => id != null);
  return sanitizeForFirestore({
    schemaVersion: 3,
    eventId,
    stageId: String(etappeUid),
    etappeUid: Number(etappeUid),
    name: firstDefined(stage.Navn, `Etappe ${etappeUid}`),
    type: firstDefined(stage.Type, null),
    level: firstDefined(stage.Nivaa, null),
    order: entry ? entry.index : null,
    distanceKm: firstDefined(stage.Km, null),
    rounds: firstDefined(stage.Runder, null),
    firstStart: firstDefined(stage.ForsteStart, null),
    classIds,
    resultProfile: classification.profile,
    resultProfileSource: classification.determinedBy,
    isRelay: isRelayStage(event, stage),
    isBiathlon: isBiathlonEvent(event),
    updatedAt: FieldValue.serverTimestamp(),
  }) || {};
}

function buildClassDoc(event, classId, etappeUid) {
  const classObj = (event && event.Klasser) ? event.Klasser[String(classId)] : null;
  const etappeObj = (etappeUid != null && event && event.Etapper) ?
    event.Etapper[String(etappeUid)] :
    null;

  return {
    schemaVersion: 3,
    classId,
    name: (classObj && classObj.Navn) ? classObj.Navn : null,
    ageFrom: firstDefined(classObj && classObj.AlderFom, null),
    ageTo: firstDefined(classObj && classObj.AlderTom, null),
    gender: firstDefined(classObj && classObj.Kjonn, null),
    ranking: firstDefined(classObj && classObj.Rangering, null),
    showTimes: firstDefined(classObj && classObj.VisTider, null),
    official: firstDefined(classObj && classObj.Offisiell, null),
    priority: firstDefined(classObj && classObj.Prioritet, null),
    startTime: firstDefined(classObj && classObj.StartTid, null),
    commonStart: firstDefined(classObj && classObj.FellesStart, null),
    rounds: firstDefined(classObj && classObj.Runder, null),
    etappeUID: etappeUid != null ? etappeUid : null,
    etappeName: firstDefined(etappeObj && etappeObj.Navn, null),
    etappeType: firstDefined(etappeObj && etappeObj.Type, null),
    etappeKm: firstDefined(etappeObj && etappeObj.Km, null),
    etappeRounds: firstDefined(etappeObj && etappeObj.Runder, null),
    etappeFirstStart: firstDefined(etappeObj && etappeObj.ForsteStart, null),
    resultResolution: firstDefined(
      etappeObj && etappeObj.Resultatopplosning,
      event && event.ResultatOpplosning,
      null,
    ),
    rankingResolution: firstDefined(event && event.RangeringOpplosning, null),
    stopStationName: firstDefined(etappeObj && etappeObj.StasjonStoppNavn, null),
    isBiathlon: isBiathlonEvent(event),
    isRelay: isRelayStage(event, etappeObj),
    primaryStageId: choosePrimaryStageId(event, classId) ||
      (etappeUid != null ? String(etappeUid) : null),
  };
}

function buildClassStructureDoc(args) {
  const resultIds = Array.from(args.resultDocIds || []).sort();

  return {
    schemaVersion: 3,
    eventId: args.eventId,
    classId: args.classId,
    etappeUid: args.etappeUid != null ? Number(args.etappeUid) : null,
    resultCount: resultIds.length,
    participantCount: args.participantCount || 0,
    hasResults: resultIds.length > 0,
    hasTimingData: resultIds.length > 0,
    results: FieldValue.delete(),
    timingSummary: {
      stationsFetched: args.stationsFetched,
      timeItemsFetched: args.timeItemsFetched,
      normalizedCount: args.normalizedCount,
      importedResults: args.importedResults,
      importedParticipants: 0,
      staleEmptyResultsDeleted: args.staleEmptyResultsDeleted,
      sources: args.timeSources || null,
    },
  };
}


async function importEqTimingFromUrls(params) {
  const eventId = Number(params.eventId);
  const classId = Number(params.classId);

  const eventUrl = params.eventUrl;
  const participantsUrl = params.participantsUrl;
  const timesUrlBase = params.timesUrlBase;

  // 1) hent event + participants
  const [event, participantPayload] = params.event && params.participants ?
    [params.event, params.participants] :
    await Promise.all([
      fetchJson(eventUrl),
      fetchJson(participantsUrl),
    ]);
  const participants = normalizeParticipants(participantPayload);
  const publishedByEd = new Map();
  let publishedRows = [];
  if (params.verifyCoverage) {
    publishedRows = await fetchAllForStation(timesUrlBase, null, true);
    for (const row of publishedRows) {
      const edUid = toNumberOrNull(row.EtappeDeltakerUID);
      const participant = row.Deltaker;
      const pid = participant && toNumberOrNull(participant.UID);
      if (edUid == null || pid == null) throw sourceError("UNRESOLVED_PUBLISHED_PARTICIPANT");
      if (publishedByEd.has(edUid)) throw sourceError("DUPLICATE_PUBLISHED_PARTICIPANT");
      publishedByEd.set(edUid, {participant, pid, row});
      participants[String(pid)] = Object.assign({}, participants[String(pid)] || {}, participant);
    }
  }
  const entityContext = {
    eventId,
    eventName: firstDefined(event && event.Navn, null),
  };

  // 2) firestore refs
  const eventDocRef = getDb().collection("events").doc(String(eventId));
  const classDocRef = eventDocRef.collection("classes").doc(String(classId));

  // 3) skriv event
  await setImportDocument(eventDocRef,
    sanitizeForFirestore(Object.assign({}, buildEventDoc(event, eventId, participants), {
      updatedAt: FieldValue.serverTimestamp(),
    })) || {},
    { merge: true }
  );

  // Do not replace the participant-based primary stage while importing a chunk.
  // It is recalculated from all stage summaries after this chunk succeeds.
  const classMetadata = buildClassDoc(event, classId, null);
  delete classMetadata.primaryStageId;
  // 4) skriv class meta
  await setImportDocument(classDocRef,
    sanitizeForFirestore(Object.assign({}, classMetadata, {
      updatedAt: FieldValue.serverTimestamp(),
    })) || {},
    { merge: true }
  );

  // 5) bygg split-defs fra event
  const stationMapByEtappe = buildStationSetupMap(event);

  // 6) finn etappeUid uten firstP (kun fra event)
  // etappeUid: bruk det som står i timesUrlBase (fasit)
  let etappeUid = getEtappeUidFromTimesUrlBase(timesUrlBase);

// fallback: hvis parsing feiler, prøv event.json (som før)
  if (etappeUid == null) {
    etappeUid = getEtappeUidFromEvent(event, classId, participants);
  }

  if (etappeUid == null) throw new Error("Could not determine etappeUid");
  const stageDocRef = eventDocRef.collection("stages").doc(String(etappeUid));
  const stageClassDocRef = stageDocRef.collection("classes").doc(String(classId));
  const classification = profileForStage(
    event,
    eventId,
    etappeUid,
    params.resultProfile,
  );
  await setImportDocument(stageDocRef,
    buildStageDoc(event, eventId, etappeUid, params.resultProfile),
    {merge: true},
  );
  await setImportDocument(stageClassDocRef,
    sanitizeForFirestore(Object.assign({}, buildClassDoc(event, classId, etappeUid), {
      eventId,
      stageId: String(etappeUid),
      resultProfile: classification.profile,
      isRelay: isRelayStage(
        event,
        event && event.Etapper ? event.Etapper[String(etappeUid)] : null,
      ),
      isBiathlon: isBiathlonEvent(event),
      updatedAt: FieldValue.serverTimestamp(),
    })) || {},
    {merge: true},
  );

  if (etappeUid == null) {
    const classObj2 = (event && event.Klasser) ?
      event.Klasser[String(classId)] :
      null;
    if (classObj2 && classObj2.PuljeUID != null) {
      const pulje = (event.Puljer || {})[String(classObj2.PuljeUID)] || null;
      if (pulje && pulje.EtappeUID != null) etappeUid = pulje.EtappeUID;
    }
  }

  // 7) splitDefs for denne etappen
  const setupMap = (etappeUid != null) ?
    stationMapByEtappe.get(Number(etappeUid)) :
    null;
  const classSplits = buildSplitDefsForClass(setupMap);
  const splitMetaByUid = classSplits.splitDefs;
  const stationUids = classSplits.splitOrder.map((setupUid) => Number(setupUid));
  let splitDefCleanup = {deleted: 0, kept: 0, scanned: 0};
  // skriv splitDefs
  if (setupMap) {
    const splitWrites = classSplits.splitOrder.map((setupUid) => ({
      ref: stageClassDocRef.collection("splitDefs").doc(setupUid),
      data: sanitizeForFirestore(classSplits.splitDefs[setupUid]) || {},
    }));
    await batchSetDocs(splitWrites);
    if (!params.verifyCoverage) {
      splitDefCleanup = await deleteDocsNotInSet(
        stageClassDocRef.collection("splitDefs"),
        new Set(classSplits.splitOrder),
      );
    }
  }
  const importedSplitDefs = classSplits.splitOrder.length;
  // 8) HENT TIDER: én station om gangen (så vi får alle splits)
  let allTimeItems = publishedRows.slice();
  const stationFetches = [];
  for (const stationUid of stationUids) {
    const itemsForStation = await fetchAllForStation(timesUrlBase, stationUid);
    stationFetches.push({
      stationUid: String(stationUid),
      count: itemsForStation.length,
      source: "Result/Class",
    });
    allTimeItems = allTimeItems.concat(itemsForStation);
  }
  if (stationUids.length === 0) {
      const itemsWithoutStation = await fetchAllForStation(timesUrlBase, null);
      stationFetches.push({
        stationUid: null,
        count: itemsWithoutStation.length,
        source: "Result/Class",
      });
      allTimeItems = allTimeItems.concat(itemsWithoutStation);
  }

  // Lag "times" objekt som normalizeTimes() kan lese
  const times = { Items: allTimeItems };

  // 9) parse tider (nå vil den gi masse records)
  let timeRecs = normalizeTimes(times);
  let participantPassItemsFetched = 0;
  let participantPassesFallbackUsed = false;
  let participantPassesFallbackError = null;
  let participantPassesFallbackUrl = null;

  const timedEdUids = new Set(timeRecs.map((record) => record.edUid));
  const missingPublishedTimes = [...publishedByEd.entries()].some(([edUid, entry]) =>
    !timedEdUids.has(edUid) && Number(entry.row.AkkumulertTid) > 0);
  if ((!params.verifyCoverage && timeRecs.length === 0) || missingPublishedTimes) {
    const fallback = await fetchParticipantPassTimeItems(eventId, classId, etappeUid);
    participantPassItemsFetched = fallback.items.length;
    participantPassesFallbackError = fallback.error;
    participantPassesFallbackUrl = fallback.url;
    if (params.verifyCoverage && fallback.error && publishedRows.length) {
      throw sourceError("PARTICIPANT_FALLBACK_FAILED");
    }

    if (fallback.items.length > 0) {
      allTimeItems = allTimeItems.concat(fallback.items);
      timeRecs = normalizeTimes({ Items: allTimeItems });
      participantPassesFallbackUsed = timeRecs.length > 0;
    }
  }

  // 10) group by edUid
  const byEd = new Map();
  for (const r of timeRecs) {
    if (!byEd.has(r.edUid)) byEd.set(r.edUid, []);
    byEd.get(r.edUid).push(r);
  }

  // 11) map EDUID -> participantUID
  const edToPid = buildEtappeMap(participants);
  for (const [edUid, entry] of publishedByEd) {
    edToPid.set(edUid, entry.pid);
    if (!byEd.has(edUid)) byEd.set(edUid, []);
  }
  const classParticipantRecords = getClassParticipantRecords(participants, classId, etappeUid)
    .filter((record) => !params.verifyCoverage || publishedByEd.has(record.edUid));
  const seededParticipantResults = seedParticipantResults(
    byEd,
    edToPid,
    classParticipantRecords,
  );

  // 12) lag Firestore writes for results
  const preparedResults = [];
  const clubWritesById = new Map();
  const athleteWritesById = new Map();
  const participantCount = params.verifyCoverage ? publishedByEd.size : classParticipantRecords.length;

  for (const record of classParticipantRecords) {
    addParticipantEntityWrites(record.p, clubWritesById, athleteWritesById, entityContext);
  }

  for (const [edUid, recs] of byEd.entries()) {
    if (!Array.isArray(recs) || (recs.length === 0 && !publishedByEd.has(edUid))) continue;
    if (params.verifyCoverage && !publishedByEd.has(edUid)) {
      throw sourceError("TIMING_PARTICIPANT_NOT_IN_PUBLISHED_LIST");
    }

    const pid = edToPid.get(edUid);
    const p = (pid != null && participants) ? participants[String(pid)] : null;
    const base = p ? getParticipantSummary(p) : { participantUid: pid != null ? pid : null };
    const ids = addParticipantEntityWrites(p, clubWritesById, athleteWritesById, entityContext);
    const identity = buildResultIdentityFields(
      p,
      ids.clubId,
      ids.athleteId,
      ids.schoolId,
      ids.organizationId,
      ids.teamId,
      ids.lagId,
    );

    const rawSplits = {};
    const splits = {};
    let totalMs = null;
    let totalText = null;
    let finishTotalMs = null;
    let finishTotalText = null;
    let resultStatus = publishedByEd.has(edUid) ?
      firstDefined(publishedByEd.get(edUid).row.StatusTekst, null) : null;

    for (const r of recs) {
      if (isNonFinishStatus(r.status)) {
        resultStatus = r.status;
      } else if (resultStatus == null && r.status != null && String(r.status).trim()) {
        resultStatus = r.status;
      }
      const key = String(r.soUid);
      const meta = splitMetaByUid[key] || {
        code: key,
        group: null,
        kind: classifySplitKind(key, null),
      };

      rawSplits[key] = {
        code: meta.code,
        group: meta.group,
        kind: meta.kind,
        sort: firstDefined(meta.sort, null),
        km: firstDefined(meta.km, null),
        stationUid: firstDefined(meta.stationUid, null),
        stationName: firstDefined(meta.stationName, null),
        isShootingStation: firstDefined(meta.isShootingStation, null),
        isStart: firstDefined(meta.isStart, null),
        isStop: firstDefined(meta.isStop, null),
        etappeNumber: firstDefined(meta.etappeNumber, null),
        legNumber: firstDefined(meta.legNumber, null),
        roundNumber: firstDefined(meta.roundNumber, r.roundNumber, null),
        cumMs: r.cumMs,
        cumMsSmoothed: r.cumMsSmoothed,
        cumMsNet: r.cumMsNet,
        cumMsWithoutAddition: r.cumMsWithoutAddition,
        cumText: r.cumText,
        netText: r.netText,
        legMs: r.legMs,
        legText: r.legText,
        splitKm: r.splitKm,
        speed: r.speed,
        pace: r.pace,
        totalSpeed: r.totalSpeed,
        totalPace: r.totalPace,
        status: r.status,
        statusCode: r.statusCode,
        timeStatus: r.timeStatus,
        active: r.active,
        passTime: r.passTime,
        smoothedTime: r.smoothedTime,
        timezoneOffset: r.timezoneOffset,
        sourceRoundNumber: r.roundNumber,
        addition: r.addition,
        additionParts: r.additionParts,
        additionTotal: r.additionTotal,
        diff: r.diff,
        placement: r.placement,
        passKey: r.passKey,
        sourceType: r.sourceType,
      };

      splits[key] = {
        code: meta.code,
        group: meta.group,
        kind: meta.kind,
        sort: firstDefined(meta.sort, null),
        km: firstDefined(meta.km, null),
        stationName: firstDefined(meta.stationName, null),
        isShootingStation: firstDefined(meta.isShootingStation, null),
        etappeNumber: firstDefined(meta.etappeNumber, null),
        legNumber: firstDefined(meta.legNumber, null),
        cumMs: r.cumMs,
        cumText: r.cumText,
        legMs: r.legMs,
        legText: r.legText,
        status: r.status,
        roundNumber: firstDefined(meta.roundNumber, r.roundNumber, null),
        addition: r.addition,
        additionTotal: r.additionTotal,
      };

      if (typeof r.cumMs === "number" && (totalMs == null || r.cumMs > totalMs)) {
        totalMs = r.cumMs;
        totalText = r.cumText;
      }
      if ((meta.isStop || meta.kind === "finish") && typeof r.cumMs === "number" &&
        (finishTotalMs == null || r.cumMs > finishTotalMs)) {
        finishTotalMs = r.cumMs;
        finishTotalText = r.cumText;
      }
    }

    if (finishTotalMs != null) {
      totalMs = finishTotalMs;
      totalText = finishTotalText;
    }

    const derived = buildDerivedResultMetrics(rawSplits, totalMs);

    const docId = String(base.participantUid != null ? base.participantUid : edUid);
    const ref = stageClassDocRef.collection("results").doc(docId);

    preparedResults.push({
      ref,
      data: buildResultClassDoc({
        eventId,
        classId,
        etappeUid,
        etappeDeltakerUid: edUid,
        participantSummary: base,
        identityFields: identity,
        docId,
        totalMs,
        totalText,
        status: resultStatus,
        advanced: hasAdvancedToLaterStage(event, p, etappeUid),
        splits,
        rawSplits,
        derived,
        profile: classification.profile,
        isRelay: isRelayStage(
          event,
          event && event.Etapper ? event.Etapper[String(etappeUid)] : null,
        ),
        isBiathlon: isBiathlonEvent(event),
        participant: p,
      }),
    });
  }

  const resultDocIds = new Set(preparedResults.map((r) => r.ref.id));
  if (resultDocIds.size !== preparedResults.length) {
    throw sourceError("RESULT_IDENTITY_CONFLICT");
  }
  if (params.verifyCoverage && resultDocIds.size !== publishedByEd.size) {
    throw sourceError("INCOMPLETE_PUBLISHED_RESULTS");
  }
  if (params.verifyCoverage) {
    const existingResults = await stageClassDocRef.collection("results").get();
    if (existingResults.docs.some((document) => !resultDocIds.has(document.id))) {
      throw sourceError("PUBLISHED_RESULTS_DISAPPEARED");
    }
  }
  const staleResultCleanup = await deleteStaleEmptyResults(
    stageClassDocRef.collection("results"),
    resultDocIds,
  );

  addClassRanks(preparedResults.map((r) => r.data));
  addMetricRanks(preparedResults.map((r) => r.data), "skiTimeMs", "skiRank", {positiveOnly: true});
  addMetricRanks(preparedResults.map((r) => r.data), "netSkiTimeMs", "netSkiRank", {positiveOnly: true});
  addMetricRanks(preparedResults.map((r) => r.data), "rangeTimeMs", "rangeRank", {positiveOnly: true});
  addMetricRanks(preparedResults.map((r) => r.data), "shootingTimeMs", "shootRank", {positiveOnly: true});
  addMetricRanks(preparedResults.map((r) => r.data), "penaltyTimeMs", "penaltyRank");
  addShootingPassRanks(preparedResults.map((r) => r.data));
  addRawPassRanks(preparedResults.map((r) => r.data));
  addDisplayOrder(preparedResults.map((r) => r.data),
    new Map(preparedResults.map((r) => [r.data, r.ref.id])));
  for (const preparedResult of preparedResults) {
    addAthleteEventResultWrite(athleteWritesById, preparedResult.data, entityContext);
  }
  const privateAnalysisWrites = [];
  for (const preparedResult of preparedResults) {
    Object.assign(preparedResult.data, {
      participantUid: FieldValue.delete(),
      etappeDeltakerUid: FieldValue.delete(),
      arrangementUid: FieldValue.delete(),
      athleteSourceUid: FieldValue.delete(),
      gender: FieldValue.delete(),
      birthYear: FieldValue.delete(),
      age: FieldValue.delete(),
      timingIds: FieldValue.delete(),
      registration: FieldValue.delete(),
    });
    preparedResult.data.entrant = {...preparedResult.data.entrant,
      participantUid: FieldValue.delete()};
    const detailedAnalysis = preparedResult.data.analysis;
    if (detailedAnalysis) {
      privateAnalysisWrites.push({
        ref: preparedResult.ref.collection("privateAnalysis").doc("current"),
        data: {
          schemaVersion: 1,
          analysis: detailedAnalysis,
          contentHash: resultContentHash(detailedAnalysis),
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
    }
    preparedResult.data.analysisSummary = buildPublicAnalysisSummary(detailedAnalysis);
    preparedResult.data.analysis = FieldValue.delete();
    preparedResult.data.contentHash = resultContentHash(preparedResult.data);
  }
  const clubWrites = await filterChangedEntityWrites(
    Array.from(clubWritesById.values()),
    eventId,
  );
  const athleteWrites = await filterChangedEntityWrites(
    Array.from(athleteWritesById.values()),
    eventId,
  );
  await batchSetDocs(clubWrites);
  await batchSetDocs(athleteWrites);
  await batchSetDocs(privateAnalysisWrites);
  const existingContentHashes = staleResultCleanup.existingContentHashes || {};
  delete staleResultCleanup.existingContentHashes;
  const resultWrites = preparedResults
    .filter((result) => existingContentHashes[result.ref.id] !== result.data.contentHash)
    .map((result) => ({
      ref: result.ref,
      data: sanitizeForFirestore(result.data) || {},
    }));
  await batchSetDocs(resultWrites);
  if (params.verifyCoverage && preparedResults.length) {
    const stored = await getDb().getAll(...preparedResults.map((result) => result.ref));
    if (stored.some((snapshot, index) => !snapshot.exists ||
      snapshot.data().contentHash !== preparedResults[index].data.contentHash)) {
      throw sourceError("RESULT_WRITE_VERIFICATION_FAILED");
    }
  }
  if (params.verifyCoverage && setupMap) {
    splitDefCleanup = await deleteDocsNotInSet(
      stageClassDocRef.collection("splitDefs"), new Set(classSplits.splitOrder),
    );
  }
  const finalResultDocIds = new Set([
    ...(staleResultCleanup.keptDocIds || []),
    ...Array.from(resultDocIds),
  ]);

  const timeSources = {
    primary: "Result/Class",
    resultClassUrl: timesUrlBase,
    stationFetches,
    participantPassesFallback: {
      source: "Contestants?passes=true",
      url: participantPassesFallbackUrl,
      fetchedItems: participantPassItemsFetched,
      used: participantPassesFallbackUsed,
      error: participantPassesFallbackError,
    },
  };

  const stageClassSummary = sanitizeForFirestore(Object.assign(
    {},
    buildClassDoc(event, classId, etappeUid),
    buildClassStructureDoc({
      classDocRef,
      eventId,
      classId,
      etappeUid,
      splitDefs: classSplits.splitDefs,
      splitOrder: classSplits.splitOrder,
      participantCount,
      resultDocIds: finalResultDocIds,
      stationsFetched: stationUids.length,
      timeItemsFetched: allTimeItems.length,
      normalizedCount: timeRecs.length,
      importedResults: preparedResults.length,
      importedParticipants: 0,
      staleEmptyResultsDeleted: staleResultCleanup.deleted,
      timeSources,
    }),
    {
      stageId: String(etappeUid),
      resultProfile: classification.profile,
      resultOrderVersion: 1,
      hasTimingData: preparedResults.some((result) =>
        typeof result.data.totalMs === "number" ||
        Object.keys(result.data.splits || {}).length > 0),
      changedResultCount: resultWrites.length,
      changedClubCount: clubWrites.length,
      changedAthleteCount: athleteWrites.length,
      updatedAt: FieldValue.serverTimestamp(),
    },
  )) || {};
  await setImportDocument(stageClassDocRef, stageClassSummary, { merge: true });
  await refreshClassRootSummary(eventDocRef, event, classId);
  const hasCompleteResults = !(staleResultCleanup.keptDocIds || [])
    .some((id) => !resultDocIds.has(id));
  const aggregates = (classification.profile === "biathlon" ||
    isBiathlonEvent(event)) &&
    !isRelayStage(event, event && event.Etapper &&
      event.Etapper[String(etappeUid)]) ?
    buildBiathlonAggregates(preparedResults.map((result) =>
      Object.assign({}, result.data, {id: result.ref.id})), splitMetaByUid) : null;
  await publishBiathlonAggregates(stageClassDocRef, aggregates,
    !hasCompleteResults);

  // 13) return debug
  return {
    ok: true,
    eventId,
    classId,
    etappeUid,
    importedSplitDefs,
    importedParticipants: 0,
    importedResults: preparedResults.length,
    hasTimingData: preparedResults.some((result) =>
      typeof result.data.totalMs === "number" || Object.keys(result.data.splits || {}).length > 0),
    changedResults: resultWrites.length,
    changedClubs: clubWrites.length,
    changedAthletes: athleteWrites.length,
    seededParticipantResults,
    normalizedCount: timeRecs.length,
    stationsFetched: stationUids.length,
    timeItemsFetched: allTimeItems.length,
    timeSources,
    staleResultCleanup,
    splitDefCleanup,
  };
}
function getClassIdsFromEtapper(event) {
  const set = new Set();
  if (!event || !event.Etapper || typeof event.Etapper !== "object") return [];

  for (const etappe of Object.values(event.Etapper)) {
    if (!etappe || typeof etappe !== "object") continue;
    const kl = etappe.Klasser || {};
    for (const classIdStr of Object.keys(kl)) {
      const v = Number(classIdStr);
      if (!Number.isNaN(v)) set.add(v);
    }
  }

  return Array.from(set.values());
}

function getImportableClassIds(event, participants) {
  const set = new Set();

  for (const classId of getClassIdsFromEtapper(event)) {
    set.add(classId);
  }

  for (const classId of getClassIdsWithContestants(participants)) {
    set.add(classId);
  }

  return Array.from(set.values());
}

function isAdministrativeStage(stage) {
  const name = normalizeCodeForMatch(stage && stage.Navn);
  return name === "PAMELDING" || name === "REGISTRATION" ||
    name.startsWith("VISITASJON");
}

function getImportTargets(event, participants) {
  const targets = new Map();
  const excludedStageIds = new Set();
  const add = (stageId, classId, order) => {
    const sid = toNumberOrNull(stageId);
    const cid = toNumberOrNull(classId);
    if (sid == null || cid == null) return;
    if (excludedStageIds.has(String(sid))) return;
    const key = `${sid}/${cid}`;
    if (!targets.has(key)) targets.set(key, {stageId: sid, classId: cid, order});
  };

  for (const entry of getEventStages(event)) {
    if (isAdministrativeStage(entry.stage)) {
      excludedStageIds.add(String(entry.id));
      continue;
    }
    for (const classId of Object.keys(entry.stage.Klasser || {})) {
      add(entry.id, classId, entry.index);
    }
  }
  for (const [, participant] of getParticipantEntries(participants)) {
    const classId = getParticipantClassUid(participant);
    const stageEntries = participant && participant.EtappeDeltaker || {};
    for (const stageParticipant of Object.values(stageEntries)) {
      add(getEtappeUidFromEtappeDeltaker(stageParticipant), classId, 10000);
    }
    add(getParticipantEtappeUid(participant), classId, 10000);
  }

  return Array.from(targets.values()).sort((a, b) =>
    a.order - b.order || a.stageId - b.stageId || a.classId - b.classId);
}

async function importWholeEvent(params) {
  const eventId = Number(params.eventId);
  if (Number.isNaN(eventId)) throw new Error("eventId must be a number");

  const classIndex = params.classIndex != null ? Number(params.classIndex) : 0;
  const classCount = params.classCount != null ? Number(params.classCount) : 1;

  const eventUrl = `https://live.eqtiming.com/api/Event/${eventId}`;
  const participantsUrl = `https://live.eqtiming.com/api/Contestants/${eventId}`;

  // Hent grunn-data én gang
  const [event, participants] = await Promise.all([
    fetchJson(eventUrl),
    fetchJson(participantsUrl),
  ]);

  // Finn alle klasser som enten finnes i event-oppsettet eller har contestants.
  // Noen resultatklasser (for eksempel U23) kan mangle egne contestants i participants-endpointet.
  // A queued job supplies a snapshot so later chunks cannot skip classes when
  // EQ Timing returns a slightly different participant list.
  const importTargets = Array.isArray(params.importTargets) ?
    params.importTargets : getImportTargets(event, participants);

  // Lagre event-meta tidlig
  const eventDocRef = getDb().collection("events").doc(String(eventId));
  await setImportDocument(eventDocRef,
    sanitizeForFirestore(Object.assign({}, buildEventDoc(event, eventId, participants), {
      updatedAt: FieldValue.serverTimestamp(),
    })) || {},
    { merge: true }
  );

  // Slice (chunk)
  const slice = importTargets.slice(classIndex, classIndex + classCount);

  const results = [];
  let classesImported = 0;

  for (const target of slice) {
    const classId = target.classId;
    const etappeUid = target.stageId;

    const timesUrlBase = buildTimesUrlBase(eventId, etappeUid, classId);

    let r;
    try {
    r = await importEqTimingFromUrls({
      eventId,
      classId,
      eventUrl,
      participantsUrl,
      timesUrlBase,
      event,
      participants,
      verifyCoverage: params.verifyCoverage === true,
    });
    } catch (error) {
      const code = typeof error.code === "string" && /^[A-Z_]{3,80}$/.test(error.code) ?
        error.code : "IMPORT_TARGET_FAILED";
      const isValidationError = /^(INVALID_|INCOMPLETE_|UNRESOLVED_|DUPLICATE_|REPEATED_|TIMING_|RESULT_|PUBLISHED_|PARTICIPANT_)/.test(code);
      if (!params.verifyCoverage || !isValidationError) throw error;
      r = {ok: false, eventId, classId, etappeUid, errorCode: code, importedResults: 0};
    }

    results.push(r);
    if (r && r.ok) classesImported++;
  }

  const nextClassIndex = classIndex + slice.length;
  const done = nextClassIndex >= importTargets.length;

  return {
    ok: true,
    eventId,
    classesFound: importTargets.length,
    stageClassesFound: importTargets.length,
    classIndex,
    classCount,
    classesAttempted: slice.length,
    classesImported,
    nextClassIndex,
    done,
    perClass: results,
  };
}
/**
 * HTTP Cloud Function
 */
async function importFromEqTimingUrlsHandler(req, res) {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const body = req.body || {};
    const eventId = body.eventId;
    const classId = body.classId;
    const eventUrl = body.eventUrl;
    const participantsUrl = body.participantsUrl;
   const timesUrlBase = body.timesUrlBase;

if (!eventId || !classId || !eventUrl || !participantsUrl || !timesUrlBase) {
  res.status(400).json({
    error: "Missing eventId/classId/eventUrl/participantsUrl/timesUrlBase",
  });
  return;
}

const result = await importEqTimingFromUrls({
  eventId,
  classId,
  eventUrl,
  participantsUrl,
  timesUrlBase,
});

    res.json(result);
  } catch (e) {
    console.error("importFromEqTimingUrls failed", e && e.stack || e && e.message || String(e));
    res.status(500).json({error: "Internal server error"});
  }
}

function resultStatusOrder(result) {
  const status = String(result && result.status || "").trim().toUpperCase();
  if (status.includes("DNS") || status.includes("DID NOT START") ||
    status.includes("IKKE STARTET") || status.includes("STARTET IKKE")) return 3;
  if (status.includes("DNF") || status.includes("DID NOT FINISH") ||
    status.includes("BRUTT") || status.includes("IKKE FULLF")) return 2;
  if (status.includes("DSQ") || status.includes("DQ") ||
    status.includes("DISQUAL")) return 1;
  const finished = typeof result.totalMs === "number" && result.totalMs > 0 ||
    typeof result.rank === "number";
  return finished ? 0 : 1;
}

function compareResultDisplayOrder(a, b, resultIds) {
  const status = resultStatusOrder(a) - resultStatusOrder(b);
  if (status !== 0) return status;
  for (const field of ["rank", "totalMs"]) {
    const aValue = typeof a[field] === "number" && Number.isFinite(a[field]) ? a[field] : null;
    const bValue = typeof b[field] === "number" && Number.isFinite(b[field]) ? b[field] : null;
    if (aValue !== bValue) {
      if (aValue === null) return 1;
      if (bValue === null) return -1;
      return aValue - bValue;
    }
  }
  const aName = String(a.entrant && a.entrant.name || a.name || "");
  const bName = String(b.entrant && b.entrant.name || b.name || "");
  if (aName !== bName) return aName < bName ? -1 : 1;
  const aId = String(resultIds && resultIds.get(a) || a.id || "");
  const bId = String(resultIds && resultIds.get(b) || b.id || "");
  return aId === bId ? 0 : aId < bId ? -1 : 1;
}

function addDisplayOrder(results, resultIds) {
  const ordered = results.slice().sort((a, b) => compareResultDisplayOrder(a, b, resultIds));
  ordered.forEach((result, index) => {
    result.displayOrder = index;
  });
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value && typeof value === "object") {
    const entries = Object.entries(value)
      .filter(([key, item]) => key !== "updatedAt" && key !== "contentHash" &&
        !(item && typeof item === "object" &&
          (item._methodName || item.constructor && item.constructor.name === "FieldValue")))
      .sort(([left], [right]) => left.localeCompare(right));
    return `{${entries.map(([key, item]) =>
      `${JSON.stringify(key)}:${stableJson(item)}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function resultContentHash(data) {
  return crypto.createHash("sha256").update(stableJson(data)).digest("hex");
}

function buildPublicAnalysisSummary(analysis) {
  const biathlon = analysis && analysis.biathlon;
  const metrics = biathlon && biathlon.metrics;
  if (!metrics || typeof metrics !== "object") return null;
  const publicAnalysis = withoutHitFields(metrics, biathlon.passes, biathlon.laps);
  return sanitizeForFirestore({
    biathlon: {
      version: firstDefined(biathlon.version, 1),
      metrics: publicAnalysis.metrics,
      passes: publicAnalysis.passes,
      laps: publicAnalysis.laps,
    },
  }) || null;
}


// Export internal functions for tests
module.exports._test = {
  dispatchPendingImport,
  publishBiathlonAggregates,
  getDb,
  withStation,
  buildEtappeMap,
  buildStationSetupMap,
  buildClassOverview,
  buildEventParticipantSummary,
  normalizeTimes,
  normalizeClubName,
  buildDerivedResultMetrics,
  buildRelayLegBiathlon,
  sanitizeForFirestore,
  resultContentHash,
  addDisplayOrder,
  compareResultDisplayOrder,
  buildPublicAnalysisSummary,
  classifyResultProfile,
  buildStageDoc,
  addMetricRanks,
  addShootingPassRanks,
  addRawPassRanks,
  choosePrimaryStageSummary,
  classStageAthleteCount,
  refreshClassRootSummary,
  buildClubDoc,
  buildAffiliationDoc,
  buildAthleteDoc,
  buildResultIdentityFields,
  getParticipantSummary,
  getEtappeUidFromTimesUrlBase,
  getEtappeUidFromParticipants,
  getEtappeUidFromEvent,
  getClassIdsWithContestants,
  getClassIdsFromEtapper,
  getImportableClassIds,
  getImportTargets,
  importFromEqTimingUrlsHandler,
  hasAdvancedToLaterStage,
  collectTimeItemsFromParticipantPasses,
  buildContestantsPassesUrl,
};
module.exports._import = importEqTimingFromUrls;
module.exports._importWholeEvent = importWholeEvent;
// --- Cloud Tasks async importer ---

let tasksClient = null;

function getTasksClient() {
  if (!tasksClient) {
    const { CloudTasksClient } = require("@google-cloud/tasks");
    tasksClient = new CloudTasksClient();
  }
  return tasksClient;
}

const QUEUE_LOCATION = FUNCTION_REGION;
const QUEUE_ID = "imports";

async function enqueueImportChunk(jobId, eventId, nextClassIndex, classCount, runId, dispatchGeneration = 0) {
  const parent = getTasksClient().queuePath(PROJECT_ID, QUEUE_LOCATION, QUEUE_ID);

  const url = `https://${FUNCTION_REGION}-${PROJECT_ID}.cloudfunctions.net/runImportEventChunk`;
  const serviceAccountEmail = TASKS_SERVICE_ACCOUNT;
// 79179
  const payload = {
    jobId,
    eventId,
    classIndex: nextClassIndex,
    classCount,
    ...(runId ? {runId, dispatchGeneration} : {}),
  };

  const task = {
    ...(runId ? {name: `${parent}/tasks/import-${runId}-${nextClassIndex}-${dispatchGeneration}`} : {}),
    httpRequest: {
      httpMethod: "POST",
      url,
      headers: { "Content-Type": "application/json" },
      body: Buffer.from(JSON.stringify(payload)).toString("base64"),
      oidcToken: {
        serviceAccountEmail,
        audience: url,
      },
    },
  };

  try {
    await getTasksClient().createTask({ parent, task });
  } catch (error) {
    if (!runId || Number(error.code) !== 6) throw error;
    // ALREADY_EXISTS: the same durable dispatch was previously accepted.
  }
}

async function dispatchPendingImport(jobRef) {
  const snapshot = await jobRef.get();
  const job = snapshot.exists ? snapshot.data() : {};
  const pending = job.pendingDispatch;
  if (!pending || pending.runId !== job.runId || job.done ||
    ["initializing", "blocked", "partial"].includes(job.status)) return;
  try {
    await enqueueImportChunk(jobRef.id, job.eventId, pending.classIndex,
      job.classCount, pending.runId, pending.dispatchGeneration || 0);
  } catch (error) {
    await getDb().runTransaction(async (transaction) => {
      const current = await transaction.get(jobRef);
      const data = current.exists ? current.data() : {};
      if (data.runId !== pending.runId || !data.pendingDispatch ||
        data.pendingDispatch.classIndex !== pending.classIndex ||
        (data.pendingDispatch.dispatchGeneration || 0) !==
        (pending.dispatchGeneration || 0)) return;
      transaction.set(jobRef, {
        dispatchFailureCount: (data.dispatchFailureCount || 0) + 1,
        lastDispatchErrorCode: String(error.code || "UNKNOWN"),
      }, {merge: true});
    });
    throw error;
  }
  await getDb().runTransaction(async (transaction) => {
    const current = await transaction.get(jobRef);
    const data = current.exists ? current.data() : {};
    if (data.runId !== pending.runId || !data.pendingDispatch ||
      (data.pendingDispatch.dispatchGeneration || 0) !== (pending.dispatchGeneration || 0) ||
      data.pendingDispatch.classIndex !== pending.classIndex) return;
    transaction.set(jobRef, {
      pendingDispatch: FieldValue.delete(),
      lastDispatchAtMs: Date.now(),
      dispatchFailureCount: 0,
      lastDispatchErrorCode: FieldValue.delete(),
    }, {merge: true});
  });
}

/**
 * Starter en importjobb og legger første task i kø.
 * Body: { eventId: number, classCount?: number }
 */
exports.startImportEvent = onRequest({
  region: FUNCTION_REGION,
  timeoutSeconds: 60,
  maxInstances: 2,
  serviceAccount: RUNTIME_SERVICE_ACCOUNT,
  invoker: "private",
}, async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const body = req.body && typeof req.body === "object" &&
      !Array.isArray(req.body) ? req.body : {};
    const eventId = Number(body.eventId);
    const classCount = body.classCount != null ? Number(body.classCount) : 1;

    if (!Number.isInteger(eventId) || eventId <= 0) {
      res.status(400).json({ error: "Missing/invalid eventId" });
      return;
    }
    if (!Number.isInteger(classCount) || classCount <= 0 || classCount > 20) {
      res.status(400).json({ error: "classCount must be an integer between 1 and 20" });
      return;
    }

    const resumeRunId = body.resumeRunId;
    if (resumeRunId != null && (typeof resumeRunId !== "string" ||
      !/^[A-Za-z0-9-]{1,128}$/.test(resumeRunId))) {
      throw new HttpError(400, "Invalid resumeRunId");
    }

    const eventUrl = `https://live.eqtiming.com/api/Event/${eventId}`;
    const participantsUrl = `https://live.eqtiming.com/api/Contestants/${eventId}`;
    const [event, participants] = await Promise.all([
      fetchJson(eventUrl),
      fetchJson(participantsUrl),
    ]);

    const classOverview = buildClassOverview(event, participants);
    const allImportTargets = getImportTargets(event, participants);
    let importTargets = allImportTargets;

    const jobRef = getDb().collection("importJobs").doc(`event-${eventId}`);
    if (resumeRunId != null) {
      const previous = await jobRef.get();
      if (!previous.exists || previous.data().runId !== resumeRunId ||
        previous.data().manifestVersion !== 1 || previous.data().initialized !== true ||
        !["partial", "blocked", "error"].includes(previous.data().status)) {
        throw new HttpError(409, "This run cannot be resumed");
      }
      const targets = await jobRef.collection("runs").doc(resumeRunId)
        .collection("targets").get();
      if (targets.docs.length !== previous.data().targetCount) {
        throw new HttpError(409, "Incomplete manifest; start a new verified import instead");
      }
      importTargets = targets.docs.map((doc) => doc.data())
        .filter((target) => target.status !== "done")
        .sort((a, b) => a.ordinal - b.ordinal)
        .map((target) => ({stageId: target.stageId, classId: target.classId, order: target.order}));
      if (!importTargets.length) throw new HttpError(409, "No unresolved targets");
    }
    const jobId = jobRef.id;
    const runId = crypto.randomUUID();
    let alreadyRunning = false;
    await getDb().runTransaction(async (transaction) => {
      const existing = await transaction.get(jobRef);
      if (resumeRunId && (!existing.exists || existing.data().runId !== resumeRunId)) {
        throw new HttpError(409, "Import run changed before resumption");
      }
      const status = existing.exists ? String(existing.data().status || "") : "";
      if (status === "initializing" || status === "queued" || status === "running") {
        alreadyRunning = true;
        return;
      }
      transaction.set(jobRef, {
        jobId,
        runId,
        ...(resumeRunId ? {resumedFromRunId: resumeRunId} : {}),
        eventId,
        classCount,
        status: "initializing",
        initializationExpiresAtMs: Date.now() + INITIALIZATION_TIMEOUT_MS,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        nextClassIndex: 0,
        done: false,
        errors: [],
        manifestVersion: 1,
        targetCount: importTargets.length,
        completedTargetCount: 0,
      });
    });
    if (alreadyRunning) {
      res.status(409).json({error: "An import is already running for this event", jobId});
      return;
    }

    try {
      const targetCollection = jobRef.collection("runs").doc(runId).collection("targets");
      await batchSetDocs(importTargets.map((target, ordinal) => ({
        ref: targetCollection.doc(`${target.stageId}_${target.classId}`),
        data: {...target, ordinal, status: "queued", attempts: 0},
      })));
      const eventRef = getDb().collection("events").doc(String(eventId));
      await eventRef.set(sanitizeForFirestore({...buildEventDoc(event, eventId, participants),
        importState: "importing"}) || {}, {merge: true});
      await batchSetDocs([...new Set(allImportTargets.map((target) => target.classId))]
        .map((classId) => ({
          ref: eventRef.collection("classes").doc(String(classId)),
          data: {classId, name: event.Klasser && event.Klasser[String(classId)] &&
            event.Klasser[String(classId)].Navn || `Klasse ${classId}`},
        })));
      const stageWrites = getEventStages(event)
        .filter((entry) => !isAdministrativeStage(entry.stage))
        .map((entry) => ({
          ref: eventRef.collection("stages").doc(entry.id),
          data: Object.assign({}, buildStageDoc(event, eventId, entry.id), {
            classImportStates: Object.fromEntries(importTargets
              .filter((target) => String(target.stageId) === entry.id)
              .map((target) => [String(target.classId), "importing"])),
            classIds: [...new Set(allImportTargets
              .filter((target) => String(target.stageId) === entry.id)
              .map((target) => target.classId))],
          }),
        }));
      await batchSetDocs(stageWrites);
      await getDb().runTransaction(async (transaction) => {
        const current = await transaction.get(jobRef);
        if (!current.exists ||
          !canFinalizeInitialization(current.data(), runId, Date.now())) {
          throw new HttpError(409, "Import initialization expired or run changed");
        }
        transaction.set(jobRef, {
          status: "queued", pendingDispatch: {runId, classIndex: 0, dispatchGeneration: 0},
          initialized: true, initializationExpiresAtMs: FieldValue.delete(),
          dispatchGeneration: 0, lastProgressAtMs: Date.now(),
        }, {merge: true});
      });
      await dispatchPendingImport(jobRef);
    } catch (enqueueError) {
      await getDb().runTransaction(async (transaction) => {
      const current = await transaction.get(jobRef);
      if (!current.exists || current.data().runId !== runId ||
        !["initializing", "queued"].includes(current.data().status)) return;
      transaction.set(jobRef, {
        status: "error",
        lastError: "Could not queue the first import chunk.",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      });
      throw enqueueError;
    }

    res.json({ ok: true, jobId, runId, eventId, status: "queued" });
  } catch (e) {
    sendHandlerError(res, e, "startImportEvent failed");
  }
});

/**
 * Worker som kjører én chunk, oppdaterer jobben, og legger neste chunk i kø hvis ikke ferdig.
 * Body: { jobId: string, eventId: number, classIndex: number, classCount: number }
 */
exports.runImportEventChunk = onRequest({
  region: FUNCTION_REGION,
  memory: "1GiB",
  timeoutSeconds: 540,
  maxInstances: 2,
  serviceAccount: RUNTIME_SERVICE_ACCOUNT,
  invoker: [TASKS_SERVICE_ACCOUNT],
}, async (req, res) => {
  let jobId = "";
  let claimed = false;
  const leaseOwner = crypto.randomUUID();
  let claimedRunId = null;

  try {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const body = req.body && typeof req.body === "object" &&
      !Array.isArray(req.body) ? req.body : {};
    jobId = String(body.jobId || "");
    if (body.kind === "probe") {
      if (typeof body.probeId !== "string" || !/^[a-f0-9-]{36}$/.test(body.probeId)) {
        throw new HttpError(400, "Invalid probeId");
      }
      await getDb().collection("importProbes").doc(body.probeId).set({
        ok: true, processedAt: FieldValue.serverTimestamp(),
      });
      res.json({ok: true, probeId: body.probeId});
      return;
    }
    const eventId = Number(body.eventId);
    const classIndex = Number(body.classIndex);
    const classCount = Number(body.classCount);

    if (!jobId || !Number.isInteger(eventId) || eventId <= 0 ||
      !Number.isInteger(classIndex) || classIndex < 0 ||
      !Number.isInteger(classCount) || classCount <= 0 || classCount > 20) {
      res.status(400).json({ error: "Missing/invalid jobId/eventId" });
      return;
    }

    

    const jobRef = getDb().collection("importJobs").doc(jobId);
    const claim = await getDb().runTransaction(async (transaction) => {
      const jobSnap = await transaction.get(jobRef);
      if (!jobSnap.exists) throw new HttpError(404, "Job not found");

      const job = jobSnap.data() || {};
      const decision = claimDecision(job, {
        eventId, classCount, classIndex, runId: body.runId,
        dispatchGeneration: body.dispatchGeneration,
      }, Date.now());
      if (decision === "mismatch") {
        throw new HttpError(409, "Chunk does not match the import job");
      }
      if (decision === "complete" || decision === "obsolete") {
        return {shouldRun: false, recoverDispatch: decision === "complete"};
      }
      if (decision === "busy" || decision === "legacy-lock") {
        throw new HttpError(409, "Another import chunk is already running");
      }
      if (decision !== "claim") {
        throw new HttpError(409, "Chunk is not the next import chunk");
      }

      transaction.set(jobRef, {
        status: "running",
        activeClassIndex: classIndex,
        leaseOwner,
        leaseExpiresAtMs: Date.now() + LEASE_MS,
        lastError: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        shouldRun: true,
        runId: job.runId || null,
        manifestVersion: job.manifestVersion || null,
        targetCount: job.targetCount,
        importTargets: Array.isArray(job.importTargets) ? job.importTargets : null,
      };
    });

    if (!claim.shouldRun) {
      if (claim.recoverDispatch) await dispatchPendingImport(jobRef);
      res.json({ok: true, skipped: true, jobId});
      return;
    }
    claimed = true;
    claimedRunId = claim.runId;
    if (claim.manifestVersion === 1) {
      const snapshot = await jobRef.collection("runs").doc(claimedRunId)
        .collection("targets").get();
      claim.importTargets = snapshot.docs.map((doc) => doc.data())
        .sort((left, right) => left.ordinal - right.ordinal);
      if (claim.importTargets.length !== claim.targetCount ||
        claim.importTargets.some((target, ordinal) => target.ordinal !== ordinal)) {
        throw sourceError("INCOMPLETE_IMPORT_MANIFEST");
      }
    }

    // 👇 Denne må finnes: chunk-importen din
    const chunkResult = await execution.run({
      jobRef, owner: leaseOwner, runId: claimedRunId,
      deadlineMs: Date.now() + 7 * 60 * 1000,
    }, () => importWholeEvent({
      eventId,
      classIndex,
      classCount,
      importTargets: claim.importTargets || undefined,
      verifyCoverage: claim.manifestVersion === 1,
    }));
    if (claim.manifestVersion === 1) {
      verifyChunk(claim.importTargets, classIndex, classCount, chunkResult);
    }

    const classResults = {};
    for (const classResult of chunkResult.perClass || []) {
      if (classResult && classResult.classId != null) {
        classResults[`${classResult.etappeUid}_${classResult.classId}`] = classResult;
      }
    }

    await getDb().runTransaction(async (transaction) => {
    const currentJob = await transaction.get(jobRef);
    if (!currentJob.exists || !ownsLease(currentJob.data(), leaseOwner, claimedRunId)) {
      throw new HttpError(409, "Import lease ownership changed");
    }
    const previousClassResults = currentJob.exists &&
      currentJob.data() && typeof currentJob.data().classResults === "object" ?
      currentJob.data().classResults : {};
    const failedThisChunk = (chunkResult.perClass || []).filter((result) => !result.ok).length;
    const failedTargetCount = Number(currentJob.data().failedTargetCount || 0) + failedThisChunk;
    const verifiedDone = chunkResult.done && failedTargetCount === 0;
    transaction.set(jobRef,
      {
        updatedAt: FieldValue.serverTimestamp(),
        nextClassIndex: chunkResult.nextClassIndex,
        lastProgressAtMs: Date.now(),
        recoveryCount: 0,
        done: verifiedDone,
        lastResult: claim.manifestVersion === 1 ? {
          classIndex: chunkResult.classIndex,
          nextClassIndex: chunkResult.nextClassIndex,
          classesFound: chunkResult.classesFound,
          classesImported: chunkResult.classesImported,
          done: chunkResult.done,
        } : chunkResult,
        ...(claim.manifestVersion === 1 ? {
          completedTargetCount: Number(currentJob.data().completedTargetCount || 0) + chunkResult.classesImported,
          failedTargetCount,
          allTargetsAttempted: chunkResult.done,
        } : {classResults: Object.assign({}, previousClassResults, classResults)}),
        lastError: FieldValue.delete(),
        activeClassIndex: FieldValue.delete(),
        leaseOwner: FieldValue.delete(),
        leaseExpiresAtMs: FieldValue.delete(),
        status: chunkResult.done ? (verifiedDone ? "done" : "partial") : "queued",
        pendingDispatch: !chunkResult.done && claimedRunId ? {
          runId: claimedRunId, classIndex: chunkResult.nextClassIndex,
          dispatchGeneration: currentJob.data().dispatchGeneration || 0,
        } : FieldValue.delete(),
      },
      { merge: true }
    );
    if (claim.manifestVersion === 1) {
      transaction.set(getDb().collection("events").doc(String(eventId)), {
        importState: chunkResult.done ? (verifiedDone ? "updated" : "partial") : "importing",
        ...(verifiedDone ? {lastVerifiedRunId: claimedRunId} : {}),
      }, {merge: true});
      for (const result of chunkResult.perClass || []) {
        const targetRef = jobRef.collection("runs").doc(claimedRunId)
          .collection("targets").doc(`${result.etappeUid}_${result.classId}`);
        transaction.set(targetRef, {
          status: result.ok ? "done" : "failed",
          importedResults: result.importedResults,
          errorCode: result.errorCode || FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        const importState = result.ok ? (result.hasTimingData ? "updated" : "waiting") : "partial";
        const stageRef = getDb().collection("events").doc(String(eventId))
          .collection("stages").doc(String(result.etappeUid));
        transaction.set(stageRef, {
          classImportStates: {[String(result.classId)]: importState},
        }, {merge: true});
        transaction.set(stageRef.collection("classes").doc(String(result.classId)), {
          importState,
        }, {merge: true});
      }
    }
    });

    if (!chunkResult.done) {
      if (claimedRunId) {
        await dispatchPendingImport(jobRef);
      } else {
        await enqueueImportChunk(jobId, eventId, chunkResult.nextClassIndex, classCount);
      }
    }

    res.json({ ok: true, jobId, chunk: chunkResult });
  } catch (e) {
    if (claimed && jobId) {
      try {
        let yielded = false;
        const failedJobRef = getDb().collection("importJobs").doc(jobId);
        await getDb().runTransaction(async (transaction) => {
        const snapshot = await transaction.get(failedJobRef);
        if (!snapshot.exists || !ownsLease(snapshot.data(), leaseOwner, claimedRunId)) return;
        yielded = e.code === "IMPORT_SLICE_YIELD" && Boolean(claimedRunId);
        const generation = (snapshot.data().dispatchGeneration || 0) + 1;
        transaction.set(failedJobRef, {
          status: yielded ? "queued" : "error",
          lastError: yielded ? FieldValue.delete() : "Import failed; see function logs for details.",
          ...(yielded ? {
            dispatchGeneration: generation,
            pendingDispatch: {runId: claimedRunId,
              classIndex: snapshot.data().nextClassIndex, dispatchGeneration: generation},
          } : {}),
          activeClassIndex: FieldValue.delete(),
          leaseOwner: FieldValue.delete(),
          leaseExpiresAtMs: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        });
        if (yielded) {
          await dispatchPendingImport(failedJobRef);
          res.json({ok: true, yielded: true, jobId});
          return;
        }
      } catch (statusError) {
        console.error(
          "Failed to persist import job error",
          statusError && statusError.stack || statusError && statusError.message ||
            String(statusError),
        );
      }
    }
    sendHandlerError(res, e, "runImportEventChunk failed");
  }
});

/**
 * Sjekk status: GET ?jobId=...
 */
exports.repairImportDispatches = onSchedule({
  schedule: "every 5 minutes",
  region: FUNCTION_REGION,
  timeoutSeconds: 300,
  maxInstances: 1,
  serviceAccount: RUNTIME_SERVICE_ACCOUNT,
}, async () => {
  const pending = await getDb().collection("importJobs")
    .where("status", "in", ["initializing", "queued", "running", "error"]).get();
  for (const snapshot of pending.docs) {
    const job = snapshot.data();
    if (!job.runId || job.done) continue;
    try {
      await getDb().runTransaction(async (transaction) => {
        const current = await transaction.get(snapshot.ref);
        if (!current.exists) return;
        const data = current.data();
        if (data.runId !== job.runId) return;
        const decision = recoveryDecision(data, Date.now());
        if (decision === "block-initialization") {
          const eventRef = getDb().collection("events").doc(String(data.eventId));
          const event = await transaction.get(eventRef);
          transaction.set(snapshot.ref, {
            status: "blocked", lastError: "IMPORT_INITIALIZATION_EXPIRED",
            initialized: false, pendingDispatch: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          if (event.exists) transaction.set(eventRef, {importState: "partial"}, {merge: true});
        } else if (decision === "block") {
          transaction.set(snapshot.ref, {
            status: "blocked", lastError: "IMPORT_RECOVERY_EXHAUSTED",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          transaction.set(getDb().collection("events").doc(String(data.eventId)), {
            importState: "partial",
          }, {merge: true});
        } else if (decision === "recover") {
          const generation = (data.dispatchGeneration || 0) + 1;
          transaction.set(snapshot.ref, {
            status: "queued",
            recoveryCount: (data.recoveryCount || 0) + 1,
            dispatchGeneration: generation,
            activeClassIndex: FieldValue.delete(),
            leaseOwner: FieldValue.delete(),
            leaseExpiresAtMs: FieldValue.delete(),
            pendingDispatch: {runId: data.runId, classIndex: data.nextClassIndex,
              dispatchGeneration: generation},
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      });
      await dispatchPendingImport(snapshot.ref);
      const latest = await snapshot.ref.get();
      if (latest.data().status === "blocked") {
        console.error("IMPORT_RECOVERY_EXHAUSTED", {jobId: snapshot.id});
      }
    } catch (error) {
      console.error("IMPORT_DISPATCH_FAILED", {
        jobId: snapshot.id,
        code: String(error.code || "UNKNOWN"),
      });
    }
  }
});

exports.getImportStatus = onRequest({
  region: FUNCTION_REGION,
  timeoutSeconds: 60,
  maxInstances: 2,
  serviceAccount: RUNTIME_SERVICE_ACCOUNT,
  invoker: "private",
}, async (req, res) => {
  try {
    if (req.method !== "GET") {
      res.status(405).send("Use GET");
      return;
    }

    if (req.query && req.query.probeId != null) {
      const probeId = String(req.query.probeId);
      if (!/^[a-f0-9-]{36}$/.test(probeId)) throw new HttpError(400, "Invalid probeId");
      const probe = await getDb().collection("importProbes").doc(probeId).get();
      res.json({ok: probe.exists && probe.data().ok === true});
      return;
    }

    const jobId = String((req.query && req.query.jobId) || "");
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(jobId)) {
      res.status(400).json({error: "Missing/invalid jobId"});
      return;
    }

 
    const snap = await getDb().collection("importJobs").doc(jobId).get();
    if (!snap.exists) {
      res.status(404).json({ error: "Job not found" });
      return;
    }

    const job = snap.data();
    if (req.query.includeTargets === "true" && job.runId && job.manifestVersion === 1) {
      const offset = Number(req.query.offset || 0);
      if (!Number.isInteger(offset) || offset < 0) {
        throw new HttpError(400, "Invalid target offset");
      }
      const targets = await snap.ref.collection("runs").doc(job.runId)
        .collection("targets").orderBy("ordinal").offset(offset).limit(100).get();
      res.json({...job, targets: targets.docs.map((target) => ({id: target.id, ...target.data()})),
        nextOffset: targets.size === 100 && offset + targets.size < job.targetCount ?
          offset + targets.size : null});
    } else {
      res.json(job);
    }
  } catch (e) {
    sendHandlerError(res, e, "getImportStatus failed");
  }
});
