import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";

admin.initializeApp();
const db = admin.firestore();

type AnyObj = Record<string, any>;

// ---- (samme hjelpefunksjoner som før, forkortet her) ----
function buildEtappeMap(participants: AnyObj): Map<number, number> {
  const m = new Map<number, number>();
  for (const [pidStr, p] of Object.entries(participants)) {
    const ed = (p as AnyObj)["EtappeDeltaker"] || {};
    for (const edUidStr of Object.keys(ed)) {
      const edUid = Number(edUidStr);
      const pid = Number(pidStr);
      if (!Number.isNaN(edUid) && !Number.isNaN(pid)) m.set(edUid, pid);
    }
  }
  return m;
}

function buildStationSetupMap(event: AnyObj) {
  const out = new Map<number, Map<number, AnyObj>>();
  const stations = event["Stasjoner"] || {};
  for (const station of Object.values(stations) as AnyObj[]) {
    const stationName = station["Navn"] ?? null;
    const setups = station["StasjonsOppsett"] || {};
    for (const [setupUidStr, setup] of Object.entries(setups) as [string, AnyObj][]) {
      const setupUid = Number(setupUidStr);
      const etappeUid = Number(setup["EtappeUID"]);
      if (Number.isNaN(setupUid) || Number.isNaN(etappeUid)) continue;

      const label = setup["Navn"] || stationName || String(setupUid);
      const meta = {
        label,
        stationName,
        sort: setup["Sortering"] ?? 10000,
        km: setup["Km"] ?? null,
        isStart: !!setup["Er_start"],
        isStop: !!setup["Er_stopp"],
      };

      if (!out.has(etappeUid)) out.set(etappeUid, new Map());
      out.get(etappeUid)!.set(setupUid, meta);
    }
  }
  return out;
}

function getParticipantSummary(p: AnyObj) {
  const utover = p["Utover"] || {};
  const name =
    utover["NavnFormatert"] ||
    `${utover["Fornavn"] || ""} ${utover["Etternavn"] || ""}`.trim() ||
    null;

  const klasse = p["Klasse"] || {};
  return {
    participantUid: p["UID"] ?? null,
    etappeUid: p["Pulje"]?.["EtappeUID"] ?? null,
    arrangementUid: p["Arrangement"]?.["UID"] ?? null,
    classUid: klasse["UID"] ?? null,
    className: klasse["Navn"] ?? null,
    bib: p["Startnummer"] ?? null,
    name,
    club: p["Klubbnavn"] || p["Klubb"]?.["Navn"] || null,
    gender: utover["Kjonn"] || null,
    age: p["Alder"] ?? null,
  };
}

function normalizeTimes(times: AnyObj) {
  // Forventer Items-format: times.Items[].Passeringer[edUid][...]
  const out: Array<{
    etappeDeltakerUid: number;
    stasjonsOppsettUid: number;
    cumMs: number | null;
    cumText: string | null;
    legMs: number | null;
    legText: string | null;
    status: string | null;
  }> = [];

  const items: AnyObj[] = times["Items"] || [];
  for (const item of items) {
    const edUid = Number(item["EtappeDeltakerUID"]);
    if (Number.isNaN(edUid)) continue;

    const pass = item["Passeringer"] || {};
    const inner = pass[String(edUid)] || {};
    for (const rec of Object.values(inner) as AnyObj[]) {
      const soUid = Number(rec["StasjonsOppsettUID"]);
      if (Number.isNaN(soUid)) continue;
      const spl = rec["Splitt"] || {};
      out.push({
        etappeDeltakerUid: edUid,
        stasjonsOppsettUid: soUid,
        cumMs: rec["AkkumulertTid"] ?? null,
        cumText: rec["Formatert"] ?? null,
        legMs: spl["Tid"] ?? null,
        legText: spl["Formatert"] ?? null,
        status: rec["StatusTekst"] ?? null,
      });
    }
  }
  return out;
}

async function fetchJson(url: string): Promise<any> {
  // Mange slike endpoints funker uten spesielle headers,
  // men vi setter en User-Agent for å være “normal nettleser”.
  const r = await axios.get(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (ImportBot; +https://yourdomain.example)",
      "Accept": "application/json,text/plain,*/*",
      "Referer": "https://live.eqtiming.com/",
    },
    timeout: 30_000,
  });
  return r.data;
}

async function commitBatches(batches: FirebaseFirestore.WriteBatch[]) {
  for (const b of batches) await b.commit();
}

// ✅ Dette er “API-importeren”
export const importFromEqTimingUrls = functions.https.onRequest(async (req, res): Promise<void> => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Use POST");
      return;
    }

    const { eventId, classId, eventUrl, participantsUrl, timesUrl } = req.body || {};
    if (!eventId || !classId || !eventUrl || !participantsUrl || !timesUrl) {
      res.status(400).json({
        error: "Missing eventId/classId/eventUrl/participantsUrl/timesUrl",
      });
      return;
    }


    // 1) LAST NED JSON
    const [event, participants, times] = await Promise.all([
      fetchJson(eventUrl),
      fetchJson(participantsUrl),
      fetchJson(timesUrl),
    ]);

    // 2) Firestore refs
    const eventDocRef = db.collection("events").doc(String(eventId));
    const classDocRef = eventDocRef.collection("classes").doc(String(classId));

    // 3) skriv event + class meta
    await eventDocRef.set({
      eventId: Number(eventId),
      name: event["Navn"] ?? null,
      source: { provider: "eqtiming", eventId: Number(eventId) },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const classObj = (event["Klasser"] || {})[String(classId)] || null;
    await classDocRef.set({
      classId: Number(classId),
      name: classObj?.["Navn"] ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 4) splitDefs fra event.json
    const stationMapByEtappe = buildStationSetupMap(event);

    // finn etappeUID (praktisk) fra første deltaker
    const pFirst = participants?.[Object.keys(participants)[0]];
    const etappeUid = pFirst?.["Pulje"]?.["EtappeUID"] ?? null;
    const setupMap = etappeUid ? stationMapByEtappe.get(Number(etappeUid)) : undefined;

    if (setupMap) {
      let batch = db.batch();
      let op = 0;
      const batches: FirebaseFirestore.WriteBatch[] = [];

      for (const [setupUid, meta] of setupMap.entries()) {
        const ref = classDocRef.collection("splitDefs").doc(String(setupUid));
        batch.set(ref, { stasjonsOppsettUID: setupUid, ...meta }, { merge: true });
        op++;
        if (op === 450) { batches.push(batch); batch = db.batch(); op = 0; }
      }
      if (op > 0) batches.push(batch);
      await commitBatches(batches);

      await classDocRef.set({ etappeUID: etappeUid }, { merge: true });
    }

    // 5) results merge: participants + times
    const edToPid = buildEtappeMap(participants);
    const timeRecs = normalizeTimes(times);

    const byEd = new Map<number, typeof timeRecs>();
    for (const r of timeRecs) {
      const arr = byEd.get(r.etappeDeltakerUid) || [];
      arr.push(r);
      byEd.set(r.etappeDeltakerUid, arr);
    }

    let batch = db.batch();
    let op = 0;
    const batches: FirebaseFirestore.WriteBatch[] = [];

    for (const [edUid, recs] of byEd.entries()) {
      const pid = edToPid.get(edUid);
      const p = pid != null ? participants[String(pid)] : null;
      const base = p ? getParticipantSummary(p) : { participantUid: pid ?? null };

      const splits: AnyObj = {};
      for (const r of recs) {
        splits[String(r.stasjonsOppsettUid)] = {
          cumMs: r.cumMs, cumText: r.cumText,
          legMs: r.legMs, legText: r.legText,
          status: r.status
        };
      }

      // total = maks cumMs
      let totalMs: number | null = null;
      let totalText: string | null = null;
      for (const r of recs) {
        if (typeof r.cumMs === "number" && (totalMs == null || r.cumMs > totalMs)) {
          totalMs = r.cumMs;
          totalText = r.cumText;
        }
      }

      const docId = String(base.participantUid ?? edUid);
      const ref = classDocRef.collection("results").doc(docId);

      batch.set(ref, {
        ...base,
        etappeDeltakerUid: edUid,
        totalMs, totalText,
        splits,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      op++;
      if (op === 450) { batches.push(batch); batch = db.batch(); op = 0; }
    }
    if (op > 0) batches.push(batch);
    await commitBatches(batches);

    res.json({
      ok: true,
      eventId,
      classId,
    });
    return;

  } catch (e: any) {
    res.status(500).json({ error: e?.message ?? String(e) });
    return;
  }

});