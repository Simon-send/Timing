"use strict";

/* eslint-disable require-jsdoc */

// Keep aligned with results/lib/features/results/domain/result_status.dart.
// A non-finishing status excludes the entire race, including partial splits.
function resultStatusSortOrder(status) {
  const text = String(status || "").trim().toUpperCase();
  if (text.includes("DNS") || text.includes("DID NOT START") ||
      text.includes("IKKE STARTET") || text.includes("STARTET IKKE")) return 3;
  if (text.includes("DNF") || text.includes("DID NOT FINISH") ||
      text.includes("BRUTT") || text.includes("IKKE FULLF")) return 2;
  if (/\b(?:DFQ|DSQ|DQ|NC|NQ)\b/.test(text) || text.includes("DISQUAL") ||
      text.includes("DISKVAL")) return 1;
  return 0;
}

function isNonFinishStatus(status) {
  return resultStatusSortOrder(status) > 0;
}

module.exports = {resultStatusSortOrder, isNonFinishStatus};
