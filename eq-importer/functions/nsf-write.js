"use strict";

/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

const {randomUUID} = require("node:crypto");
const {digest} = require("./nsf-normalize");

const MAX_RECEIPT_BYTES = 850000;
const MAX_COMMIT_BYTES = 6 * 1024 * 1024;

function coverageOf(docs) {
  return Object.fromEntries(docs.map(({path, data}) => [
    digest(path).slice(0, 32), {
      points: (data.timingPoints || []).map((point) => point.setupUid).sort(),
      rankedPoints: (data.timingPoints || []).filter((point) => point.cumRank > 0)
          .map((point) => point.setupUid).sort(),
      ranked: data.rank > 0 || data.finishRank > 0,
      official: data.resultAuthority === "official",
    },
  ]));
}

function assertCoverage(previous, next, terminalCorrections = new Map()) {
  for (const [id, previousValue] of Object.entries(previous || {})) {
    const old = Array.isArray(previousValue) ? {points: previousValue} : previousValue;
    const current = next[id];
    const allowedFinish = terminalCorrections.get(id) || new Set();
    if (!current || old.points.some((point) =>
      !current.points.includes(point) && !allowedFinish.has(point))) {
      throw new Error("Kilden mangler tidligere importerte rader eller målinger. Ingen data er skrevet.");
    }
    if (old.official && !current.official) {
      throw new Error("En offisiell resultatliste kan ikke erstattes av svakere liveverdier. Ingen data er skrevet.");
    }
    if ((old.ranked && !current.ranked && !terminalCorrections.has(id)) ||
        (old.rankedPoints || []).some((point) =>
          !current.rankedPoints.includes(point) && !allowedFinish.has(point))) {
      throw new Error("Kilden mangler tidligere importerte plasseringer. Ingen data er skrevet.");
    }
  }
}

/** Publish one checked snapshot atomically; the private claim fences concurrent writers. */
async function writeNsfImport(db, bundle, {checksum, resume = false} = {}) {
  if (!bundle.report?.ready || !checksum || checksum !== bundle.report.checksum ||
      checksum !== digest(bundle.docs) || !/^nsf-[1-9]\d{0,11}$/.test(bundle.eventId)) {
    throw new Error("Krever en gyldig forhåndsvisning og tilhørende kontrollsum.");
  }
  const eventPath = `events/${bundle.eventId}`;
  const event = bundle.docs.find((doc) => doc.path === eventPath);
  const children = bundle.docs.filter((doc) => doc.path.startsWith(`${eventPath}/`));
  if (!event || children.length + 1 !== bundle.docs.length) {
    throw new Error("NSF-importen kan bare skrive under sitt eget arrangementsdokument.");
  }
  const coverage = coverageOf(bundle.docs);
  const terminalCorrections = new Map(children.filter(({data}) =>
    data.entrant && data.status && data.officialStatus === true)
      .map(({path}) => [digest(path).slice(0, 32), new Set(children.filter((doc) =>
        doc.path.startsWith(`${path.slice(0, path.lastIndexOf("/results/"))}/splitDefs/`) &&
          doc.data.kind === "finish").map((doc) => doc.data.setupUid))]));
  const receiptBytes = Buffer.byteLength(JSON.stringify(coverage));
  if (receiptBytes > MAX_RECEIPT_BYTES ||
      receiptBytes + Buffer.byteLength(JSON.stringify(bundle.docs)) > MAX_COMMIT_BYTES) {
    throw new Error("Rennet er for stort for én atomisk NSF-import. Ingen data er skrevet.");
  }
  const receipt = db.collection("nsfImportReceipts").doc(bundle.eventId);
  const runId = randomUUID();
  const state = await db.runTransaction(async (tx) => {
    const previous = (await tx.get(receipt)).data();
    const existing = (await tx.get(db.doc(eventPath))).data();
    if (existing && (existing.source !== "nsf" || !previous)) {
      throw new Error("Arrangementet finnes allerede uten en tilhørende NSF-kvittering.");
    }
    if (previous?.state === "complete" && previous.checksum === checksum) {
      return {unchanged: true};
    }
    if (previous && previous.state !== "complete" &&
        (!resume || previous.pendingChecksum !== checksum)) {
      throw new Error("En NSF-import er uavsluttet. Bruk samme forhåndsvisning med --resume.");
    }
    assertCoverage(previous?.coverage, coverage, terminalCorrections);
    tx.set(receipt, {
      state: "writing", runId, pendingChecksum: checksum,
      coverage: previous?.coverage || {},
    });
    return {unchanged: false};
  });
  if (state.unchanged) return {eventId: bundle.eventId, unchanged: true, written: 0};

  try {
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(receipt)).data();
      if (current?.state !== "writing" || current.runId !== runId) {
        throw new Error("En annen kjøring har overtatt denne NSF-importen.");
      }
      for (const doc of bundle.docs) tx.set(db.doc(doc.path), doc.data);
      tx.set(receipt, {state: "complete", checksum, coverage});
    });
    return {eventId: bundle.eventId, unchanged: false, written: bundle.docs.length};
  } catch (error) {
    await db.runTransaction(async (tx) => {
      const current = (await tx.get(receipt)).data();
      if (current?.runId === runId && current.state === "writing") {
        tx.update(receipt, {state: "failed"});
      }
    }).catch(() => {});
    throw error;
  }
}

module.exports = {writeNsfImport, assertCoverage, coverageOf};
