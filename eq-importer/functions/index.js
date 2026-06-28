const functions = require("firebase-functions");
const { onInit } = require("firebase-functions/v2/core");
const admin = require("firebase-admin");
const axios = require("axios");

let appInitialized = false;
let db = null;

function ensureInitialized() {
  if (appInitialized) return;
  admin.initializeApp();
  appInitialized = true;
}

onInit(() => {
  ensureInitialized();
});

function getDb() {
  ensureInitialized();
  if (!db) db = admin.firestore();
  return db;
}

/**
 * Fetch JSON with browser-like headers.
 */
async function fetchJson(url) {
  const r = await axios.get(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
      "Accept": "application/json,text/plain,*/*",
      "Referer": "https://live.eqtiming.com/",
    },
    timeout: 30000,
    validateStatus: (s) => s >= 200 && s < 400,
  });
  return r.data;
}
async function fetchAllForStation(baseUrl, stationUid) {
  const pageSize = 1000;
  let startAt = 1;
  let all = [];

  while (true) {
    const url = withStation(baseUrl, stationUid, startAt, pageSize);
    const data = await fetchJson(url);

    const itemsRaw = data && typeof data === "object" ?
      firstDefined(data.Items, data.items, []) :
      [];
    const items = Array.isArray(itemsRaw) ? itemsRaw : Object.values(itemsRaw);

    if (!items || items.length === 0) break;

    all = all.concat(items);

    // hvis færre enn pageSize, ferdig
    if (items.length < pageSize) break;

    startAt += pageSize;
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

    const participantEtappeUid = getParticipantEtappeUid(p);
    if (etappeUid != null && participantEtappeUid != null &&
      participantEtappeUid !== Number(etappeUid)) {
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
      error: e && e.message ? e.message : String(e),
    };
  }
}
function withStation(baseUrl, stationUid, startAt, count) {
  const u = new URL(baseUrl);
  u.searchParams.set("station", String(stationUid));
  u.searchParams.set("passes", "true");
  u.searchParams.set("justTimeData", "true");
  u.searchParams.set("startAt", String(startAt));
  u.searchParams.set("count", String(count));
  u.searchParams.set("proxykey", String(Math.floor(Date.now() / 1000)));
  // behold sortpoint/round/query hvis de finnes
  return u.toString();
}
async function batchSetDocs(docWrites) {
  const MAX = 50;
  const dbClient = getDb();
  let batch = dbClient.batch();
  let count = 0;

  for (const w of docWrites) {
    batch.set(w.ref, w.data, { merge: true });
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

function isEmptyResultDoc(data) {
  if (!data || typeof data !== "object") return false;

  const rawPasses = Array.isArray(data.rawPasses) ? data.rawPasses : [];
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
  let kept = 0;

  for (const doc of snap.docs || []) {
    if (currentResultDocIds.has(doc.id)) {
      kept++;
      keptDocIds.push(doc.id);
      continue;
    }

    const data = typeof doc.data === "function" ? doc.data() : {};
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

    if (etappeUid != null && edEtappeUid != null && edEtappeUid !== Number(etappeUid)) {
      continue;
    }
    out.push(edUid);
  }

  return out;
}

function getClassParticipantRecords(participants, classId, etappeUid) {
  const records = [];
  for (const [pidStr, p] of getParticipantEntries(participants)) {
    if (!p || typeof p !== "object") continue;

    const participantClassUid = getParticipantClassUid(p);
    if (participantClassUid == null || participantClassUid !== Number(classId)) {
      continue;
    }

    const participantEtappeUid = getParticipantEtappeUid(p);
    if (etappeUid != null && participantEtappeUid != null &&
      participantEtappeUid !== Number(etappeUid)) {
      continue;
    }

    const pid = toNumberOrNull(firstDefined(pidStr, p.UID));
    const edUids = getParticipantEtappeDeltakerUids(p, etappeUid);

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
  const utover = participant && participant.Utover ? participant.Utover : {};
  const birthYear = getParticipantBirthYear(participant);

  return {
    athleteId,
    source: {
      provider: "eqtiming",
      participantUid: participant.UID,
      athleteUid: firstDefined(utover.UID, null),
    },
    displayName,
    normalizedName,
    gender: utover.Kjonn || null,
    birthYear: birthYear != null ? birthYear : null,
    age: participant.Alder !== undefined ? participant.Alder : null,
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
  const analysis = result.analysis || {};
  return {
    eventId: Number(result.eventId),
    name: (context && context.eventName) || null,
    classId: result.classId != null ? Number(result.classId) : null,
    className: firstDefined(result.className, null),
    rank: firstDefined(result.rank, null),
    finishRank: firstDefined(result.finishRank, result.rank, null),
    proneHits: firstDefined(analysis.proneHits, null),
    proneMisses: firstDefined(analysis.proneMisses, null),
    standingHits: firstDefined(analysis.standingHits, null),
    standingMisses: firstDefined(analysis.standingMisses, null),
    skiRank: firstDefined(analysis.skiRank, null),
    netSkiRank: firstDefined(analysis.netSkiRank, analysis.skiRank, null),
    shootRank: firstDefined(analysis.shootRank, null),
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    data.athletes = admin.firestore.FieldValue.arrayUnion(...data.athletes);
  }
  if (Array.isArray(data.events) && data.events.length > 0) {
    data.events = admin.firestore.FieldValue.arrayUnion(...data.events);
  }
  return {
    ref: write.ref,
    data,
  };
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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        events: [eventEntry],
      },
    });
    return;
  }

  appendUniqueEntityList(existing.data, "events", eventEntry, "eventId");
  existing.data.updatedAt = admin.firestore.FieldValue.serverTimestamp();
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
    participantUid: firstDefined(base.participantUid, null),
    arrangementUid: firstDefined(base.arrangementUid, null),
    athleteSourceUid: firstDefined(base.athleteSourceUid, null),
    bib: firstDefined(base.bib, null),
    fullBib: firstDefined(base.fullBib, null),
    lane: firstDefined(base.lane, null),
    gender: firstDefined(base.gender, null),
    birthYear: firstDefined(base.birthYear, null),
    age: firstDefined(base.age, null),
    country: firstDefined(base.country, null),
    region: firstDefined(base.region, null),
    timingIds: firstDefined(base.timingIds, null),
    className: firstDefined(base.className, null),
    registration: {
      status: firstDefined(base.status, null),
      registeredAt: firstDefined(base.registeredAt, null),
      confirmedTime: firstDefined(base.confirmedTime, null),
      eqmeNotInUse: firstDefined(base.eqmeNotInUse, null),
      ignoreForTracking: firstDefined(base.ignoreForTracking, null),
    },
  });
}

function buildResultClassDoc(args) {
  return Object.assign(
    {},
    buildCompactResultIdentity(args.participantSummary, args.identityFields),
    {
    eventId: args.eventId,
    classId: args.classId,
    etappeUid: args.etappeUid,
    etappeDeltakerUid: args.etappeDeltakerUid,
    hasTimingData: true,
    totalMs: args.totalMs,
    totalText: args.totalText,
    status: args.status,
    rawPasses: args.derived.rawPasses,
    analysis: args.derived.analysis,
    shooting: args.derived.shooting,
    resultId: admin.firestore.FieldValue.delete(),
    laps: admin.firestore.FieldValue.delete(),
    source: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
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
  let lapIndex = 1;

  for (const shootKey of shootKeys) {
    const shot = shooting[shootKey];
    const lapEndMs = firstDefined(shot.inCumMs, shot.shootingCumMs, null);
    if (typeof lapEndMs === "number" && lapEndMs >= lastSkiStartMs) {
      laps[`lap${lapIndex}`] = {
        skiMs: lapEndMs - lastSkiStartMs,
        startCumMs: lastSkiStartMs,
        endCumMs: lapEndMs,
        endCode: firstDefined(shot.codes.rangeIn, shot.codes.shooting, null),
        beforeShooting: shot.index,
      };
      lapIndex++;
    }

    const nextSkiStartMs = firstDefined(
      shot.outCumMs,
      shot.shootingCumMs,
      shot.rangeExitCumMs,
      null,
    );
    if (typeof nextSkiStartMs === "number") lastSkiStartMs = nextSkiStartMs;
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
      endCode: finishSplit ? finishSplit.code : "finish",
      beforeShooting: null,
    };
  }

  let netSkiTimeMs = null;
  const lapValues = Object.values(laps);
  if (lapValues.length > 0) {
    netSkiTimeMs = lapValues.reduce((sum, lap) => sum + (typeof lap.skiMs === "number" ? lap.skiMs : 0), 0);
  } else if (typeof totalMs === "number" && hasAnyRangeTime) {
    netSkiTimeMs = totalMs - rangeTimeMs;
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
  const skiTimeMs = deriveSkiTimeMs(netSkiTimeMs, totalPenaltyTimeMs);

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

function addMetricRanks(results, field, rankField) {
  const ranked = results
    .filter((r) => r.analysis && typeof r.analysis[field] === "number")
    .sort((a, b) => a.analysis[field] - b.analysis[field]);

  let previousValue = null;
  let previousRank = null;

  for (let i = 0; i < ranked.length; i++) {
    const value = ranked[i].analysis[field];
    const rank = (previousValue != null && value === previousValue) ? previousRank : i + 1;
    ranked[i].analysis[rankField] = rank;
    previousValue = value;
    previousRank = rank;
  }
}

function isNonFinishStatus(status) {
  const text = String(status || "").trim().toUpperCase();
  return text.includes("DNF") ||
    text.includes("DNS") ||
    text.includes("DSQ") ||
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
    const rawPasses = Array.isArray(result.rawPasses) ? result.rawPasses : [];
    for (const pass of rawPasses) {
      pass.cumRank = null;
      pass.legRank = null;
      if (!pass || pass.setupUid == null) continue;

      const key = String(pass.setupUid);
      if (typeof pass.cumMs === "number") {
        if (!cumBySetupUid.has(key)) cumBySetupUid.set(key, []);
        cumBySetupUid.get(key).push(pass);
      }
      if (typeof pass.legMs === "number") {
        if (!legBySetupUid.has(key)) legBySetupUid.set(key, []);
        legBySetupUid.get(key).push(pass);
      }
    }
  }

  addRawPassRankForGroups(cumBySetupUid, "cumMs", "cumRank");
  addRawPassRankForGroups(legBySetupUid, "legMs", "legRank");
}

function addRawPassRankForGroups(groupedPasses, valueField, rankField) {
  for (const passes of groupedPasses.values()) {
    passes.sort((a, b) => a[valueField] - b[valueField]);

    let previousValue = null;
    let previousRank = null;
    for (let i = 0; i < passes.length; i++) {
      const value = passes[i][valueField];
      const rank = (previousValue != null && value === previousValue) ? previousRank : i + 1;
      passes[i][rankField] = rank;
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

function buildEventDoc(event, eventId) {
  const sport = event && event.Gren ? event.Gren : {};
  const sportParent = sport && sport.Parent ? sport.Parent : {};
  const discipline = event && event.Disiplin ? event.Disiplin : {};
  const federation = event && event.Forbund ? event.Forbund : {};
  const country = event && event.Land ? event.Land : {};
  const resultSetup = event && event.ResultatOppsett ? event.ResultatOppsett : {};

  return {
    eventId,
    name: event && event.Navn ? event.Navn : null,
    date: firstDefined(event && event.Dato, event && event.Aktiv, null),
    timezone: firstDefined(event && event.TidsSone, null),
    timezoneOffset: firstDefined(event && event.TimezoneOffset, null),
    firstStart: firstDefined(event && event.ForsteStart, null),
    startTime: firstDefined(event && event.StartTid, null),
    stopTime: firstDefined(event && event.StoppTid, null),
    place: firstDefined(event && event.Sted, null),
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
    source: admin.firestore.FieldValue.delete(),
  };
}

function buildClassDoc(event, classId, etappeUid) {
  const classObj = (event && event.Klasser) ? event.Klasser[String(classId)] : null;
  const etappeObj = (etappeUid != null && event && event.Etapper) ?
    event.Etapper[String(etappeUid)] :
    null;

  return {
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
    isBiathlon: !!(event && event.Gren && event.Gren.Kode === "BT"),
  };
}

function buildClassStructureDoc(args) {
  const resultIds = Array.from(args.resultDocIds || []).sort();

  return {
    schemaVersion: 2,
    eventId: args.eventId,
    classId: args.classId,
    etappeUid: args.etappeUid != null ? Number(args.etappeUid) : null,
    resultCount: resultIds.length,
    participantCount: args.participantCount || 0,
    hasResults: resultIds.length > 0,
    hasTimingData: resultIds.length > 0,
    results: admin.firestore.FieldValue.delete(),
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
  const [event, participants] = await Promise.all([
    fetchJson(eventUrl),
    fetchJson(participantsUrl),
  ]);
  const entityContext = {
    eventId,
    eventName: firstDefined(event && event.Navn, null),
  };

  // 2) firestore refs
  const eventDocRef = getDb().collection("events").doc(String(eventId));
  const classDocRef = eventDocRef.collection("classes").doc(String(classId));

  // 3) skriv event
  await eventDocRef.set(
    Object.assign({}, buildEventDoc(event, eventId), {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    { merge: true }
  );

  // 4) skriv class meta
  await classDocRef.set(
    Object.assign({}, buildClassDoc(event, classId, null), {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
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
      ref: classDocRef.collection("splitDefs").doc(setupUid),
      data: classSplits.splitDefs[setupUid],
    }));
    await batchSetDocs(splitWrites);
    splitDefCleanup = await deleteDocsNotInSet(
      classDocRef.collection("splitDefs"),
      new Set(classSplits.splitOrder),
    );
  }
  const importedSplitDefs = classSplits.splitOrder.length;
  // 8) HENT TIDER: én station om gangen (så vi får alle splits)
  let allTimeItems = [];
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

  // Lag "times" objekt som normalizeTimes() kan lese
  const times = { Items: allTimeItems };

  // 9) parse tider (nå vil den gi masse records)
  let timeRecs = normalizeTimes(times);
  let participantPassItemsFetched = 0;
  let participantPassesFallbackUsed = false;
  let participantPassesFallbackError = null;
  let participantPassesFallbackUrl = null;

  if (timeRecs.length === 0) {
    const fallback = await fetchParticipantPassTimeItems(eventId, classId, etappeUid);
    participantPassItemsFetched = fallback.items.length;
    participantPassesFallbackError = fallback.error;
    participantPassesFallbackUrl = fallback.url;

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
  const classParticipantRecords = getClassParticipantRecords(participants, classId, etappeUid);
  const seededParticipantResults = seedParticipantResults(
    byEd,
    edToPid,
    classParticipantRecords,
  );

  // 12) lag Firestore writes for results
  const preparedResults = [];
  const clubWritesById = new Map();
  const athleteWritesById = new Map();
  const participantCount = classParticipantRecords.length;

  for (const record of classParticipantRecords) {
    addParticipantEntityWrites(record.p, clubWritesById, athleteWritesById, entityContext);
  }

  for (const [edUid, recs] of byEd.entries()) {
    if (!Array.isArray(recs) || recs.length === 0) continue;

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
    let resultStatus = null;

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
        roundNumber: r.roundNumber,
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
        cumMs: r.cumMs,
        cumText: r.cumText,
        legMs: r.legMs,
        legText: r.legText,
        status: r.status,
        roundNumber: r.roundNumber,
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
    const ref = classDocRef.collection("results").doc(docId);

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
        splits,
        derived,
      }),
    });
  }

  const resultDocIds = new Set(preparedResults.map((r) => r.ref.id));
  const staleResultCleanup = await deleteStaleEmptyResults(
    classDocRef.collection("results"),
    resultDocIds,
  );

  addClassRanks(preparedResults.map((r) => r.data));
  addMetricRanks(preparedResults.map((r) => r.data), "skiTimeMs", "skiRank");
  addMetricRanks(preparedResults.map((r) => r.data), "netSkiTimeMs", "netSkiRank");
  addMetricRanks(preparedResults.map((r) => r.data), "rangeTimeMs", "rangeRank");
  addMetricRanks(preparedResults.map((r) => r.data), "shootingTimeMs", "shootRank");
  addMetricRanks(preparedResults.map((r) => r.data), "penaltyTimeMs", "penaltyRank");
  addRawPassRanks(preparedResults.map((r) => r.data));
  for (const preparedResult of preparedResults) {
    addAthleteEventResultWrite(athleteWritesById, preparedResult.data, entityContext);
  }

  await batchSetDocs(Array.from(clubWritesById.values()).map(prepareEntityWrite));
  await batchSetDocs(Array.from(athleteWritesById.values()).map(prepareEntityWrite));
  const resultWrites = preparedResults;
  await batchSetDocs(resultWrites);

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

  await classDocRef.set(Object.assign(
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
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ), { merge: true });

  // 13) return debug
  return {
    ok: true,
    eventId,
    classId,
    etappeUid,
    importedSplitDefs,
    importedParticipants: 0,
    importedResults: preparedResults.length,
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
  const classIds = getImportableClassIds(event, participants);
  classIds.sort((a, b) => a - b);

  // Lagre event-meta tidlig
  const eventDocRef = getDb().collection("events").doc(String(eventId));
  await eventDocRef.set(
    Object.assign({}, buildEventDoc(event, eventId), {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    { merge: true }
  );

  // Slice (chunk)
  const slice = classIds.slice(classIndex, classIndex + classCount);

  const results = [];
  let classesImported = 0;

  for (const classId of slice) {
    const etappeUid = getEtappeUidFromEvent(event, classId, participants);

    if (etappeUid == null) {
      results.push({ classId, ok: false, error: "Could not determine etappeUid" });
      continue;
    }

    const timesUrlBase = buildTimesUrlBase(eventId, etappeUid, classId);

    const r = await importEqTimingFromUrls({
      eventId,
      classId,
      eventUrl,
      participantsUrl,
      timesUrlBase,
    });

    results.push(r);
    if (r && r.ok) classesImported++;
  }

  const nextClassIndex = classIndex + slice.length;
  const done = nextClassIndex >= classIds.length;

  return {
    ok: true,
    eventId,
    classesFound: classIds.length,
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
exports.importFromEqTimingUrls = functions.https.onRequest(async (req, res) => {
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
    console.error(e);
    res.status(500).json({
      error: (e && e.message) ? e.message : String(e),
    });
  }
});


// Export internal functions for tests
module.exports._test = {
  withStation,
  buildEtappeMap,
  buildStationSetupMap,
  buildClassOverview,
  normalizeTimes,
  normalizeClubName,
  buildDerivedResultMetrics,
  addMetricRanks,
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

const PROJECT_ID = process.env.GCLOUD_PROJECT;
const QUEUE_LOCATION = "us-central1"; // samme region som functions
const QUEUE_ID = "imports";

async function enqueueImportChunk(jobId, eventId, nextClassIndex, classCount) {
  const parent = getTasksClient().queuePath(PROJECT_ID, QUEUE_LOCATION, QUEUE_ID);

  const url = `https://us-central1-${PROJECT_ID}.cloudfunctions.net/runImportEventChunk`;
// 79179
  const payload = {
    jobId,
    eventId,
    classIndex: nextClassIndex,
    classCount,
  };

  const task = {
    httpRequest: {
      httpMethod: "POST",
      url,
      headers: { "Content-Type": "application/json" },
      body: Buffer.from(JSON.stringify(payload)).toString("base64"),
    },
  };

  await getTasksClient().createTask({ parent, task });
}

/**
 * Starter en importjobb og legger første task i kø.
 * Body: { eventId: number, classCount?: number }
 */
exports.startImportEvent = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const body = req.body || {};
    const eventId = Number(body.eventId);
    const classCount = body.classCount != null ? Number(body.classCount) : 1;

    if (Number.isNaN(eventId)) {
      res.status(400).json({ error: "Missing/invalid eventId" });
      return;
    }
    if (Number.isNaN(classCount) || classCount <= 0) {
      res.status(400).json({ error: "classCount must be a number > 0" });
      return;
    }

    const eventUrl = `https://live.eqtiming.com/api/Event/${eventId}`;
    const participantsUrl = `https://live.eqtiming.com/api/Contestants/${eventId}`;
    const [event, participants] = await Promise.all([
      fetchJson(eventUrl),
      fetchJson(participantsUrl),
    ]);

    const classOverview = buildClassOverview(event, participants);

    const jobRef = getDb().collection("importJobs").doc();
    const jobId = jobRef.id;

    await jobRef.set({
      jobId,
      eventId,
      classCount,
      status: "queued",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      nextClassIndex: 0,
      done: false,
      errors: [],
      classOverview,
      classResults: {},
    });

    await enqueueImportChunk(jobId, eventId, 0, classCount);

    res.json({ ok: true, jobId, eventId, status: "queued" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e?.message || String(e) });
  }
});

/**
 * Worker som kjører én chunk, oppdaterer jobben, og legger neste chunk i kø hvis ikke ferdig.
 * Body: { jobId: string, eventId: number, classIndex: number, classCount: number }
 */
exports.runImportEventChunk = functions.https.onRequest({
  memory: "1GiB",
  timeoutSeconds: 540,
}, async (req, res) => {
  let jobId = "";

  try {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const body = req.body || {};
    jobId = String(body.jobId || "");
    const eventId = Number(body.eventId);
    const classIndex = Number(body.classIndex || 0);
    const classCount = Number(body.classCount || 1);

    if (!jobId || Number.isNaN(eventId)) {
      res.status(400).json({ error: "Missing/invalid jobId/eventId" });
      return;
    }

    

    const jobRef = getDb().collection("importJobs").doc(jobId);
    const jobSnap = await jobRef.get();
    if (!jobSnap.exists) {
      res.status(404).json({ error: "Job not found" });
      return;
    }

    await jobRef.set(
      {
        status: "running",
        lastError: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 👇 Denne må finnes: chunk-importen din
    const chunkResult = await importWholeEvent({
      eventId,
      classIndex,
      classCount,
    });

    const classResults = {};
    for (const classResult of chunkResult.perClass || []) {
      if (classResult && classResult.classId != null) {
        classResults[String(classResult.classId)] = classResult;
      }
    }

    await jobRef.set(
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        nextClassIndex: chunkResult.nextClassIndex,
        done: chunkResult.done,
        lastResult: chunkResult,
        classResults,
        lastError: admin.firestore.FieldValue.delete(),
        status: chunkResult.done ? "done" : "running",
      },
      { merge: true }
    );

    if (!chunkResult.done) {
      await enqueueImportChunk(jobId, eventId, chunkResult.nextClassIndex, classCount);
    }

    res.json({ ok: true, jobId, chunk: chunkResult });
  } catch (e) {
    console.error(e);
    if (jobId) {
      try {
        await getDb().collection("importJobs").doc(jobId).set({
          status: "error",
          lastError: e?.message || String(e),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      } catch (statusError) {
        console.error("Failed to persist import job error", statusError);
      }
    }
    res.status(500).json({ error: e?.message || String(e) });
  }
});

/**
 * Sjekk status: GET ?jobId=...
 */
exports.getImportStatus = functions.https.onRequest(async (req, res) => {
  try {
    const jobId = String(req.query.jobId || "");
    if (!jobId) {
      res.status(400).json({ error: "Missing jobId" });
      return;
    }

 
    const snap = await getDb().collection("importJobs").doc(jobId).get();
    if (!snap.exists) {
      res.status(404).json({ error: "Job not found" });
      return;
    }

    res.json(snap.data());
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e?.message || String(e) });
  }
});
