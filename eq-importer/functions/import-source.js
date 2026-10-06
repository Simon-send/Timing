"use strict";

/* eslint-disable require-jsdoc */

function sourceError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

function normalizeParticipants(payload) {
  if (!payload || typeof payload !== "object") {
    throw sourceError("INVALID_PARTICIPANTS_RESPONSE");
  }
  const rows = payload.Items !== undefined ? payload.Items :
    payload.items !== undefined ? payload.items : payload;
  if (!rows || typeof rows !== "object") {
    throw sourceError("INVALID_PARTICIPANTS_RESPONSE");
  }
  const participants = Object.create(null);
  for (const [key, row] of Object.entries(rows)) {
    const id = row && row.UID != null ? row.UID :
      row && row.uid != null ? row.uid : !Array.isArray(rows) ? key : null;
    if (!row || typeof row !== "object" ||
        !/^\d+$/.test(String(id)) || Number(id) <= 0) {
      throw sourceError("INVALID_PARTICIPANT_ID");
    }
    if (participants[id]) throw sourceError("DUPLICATE_PARTICIPANT_ID");
    participants[id] = row;
  }
  const total = payload.TotalItems ?? payload.TotalCount ?? payload.totalCount;
  if (total != null && Number(total) !== Object.keys(participants).length) {
    throw sourceError("INCOMPLETE_PARTICIPANTS_RESPONSE");
  }
  return participants;
}

function timingPage(payload) {
  if (!payload || typeof payload !== "object") {
    throw sourceError("INVALID_TIMING_RESPONSE");
  }
  const rows = payload.Items ?? payload.items;
  if (!rows || typeof rows !== "object") {
    throw sourceError("INVALID_TIMING_RESPONSE");
  }
  const items = Array.isArray(rows) ? rows : Object.values(rows);
  if (items.some((row) => !row || typeof row !== "object")) {
    throw sourceError("INVALID_TIMING_ROW");
  }
  const total = payload.TotalItems ?? payload.TotalCount ?? payload.totalCount;
  if (total != null &&
      (!Number.isInteger(Number(total)) || Number(total) < 0)) {
    throw sourceError("INVALID_TIMING_TOTAL");
  }
  return {items, total: total == null ? null : Number(total)};
}

module.exports = {normalizeParticipants, timingPage, sourceError};
