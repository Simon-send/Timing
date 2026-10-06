"use strict";

/* eslint-disable require-jsdoc */
const {sourceError} = require("./import-source");

function verifyChunk(manifest, classIndex, classCount, result) {
  const expected = manifest.slice(classIndex, classIndex + classCount);
  const reports = result.perClass || [];
  const keys = reports.map((row) => `${row.etappeUid}_${row.classId}`);
  const expectedKeys = expected.map((row) => `${row.stageId}_${row.classId}`);
  if (keys.length !== expectedKeys.length ||
      new Set(keys).size !== keys.length ||
      expectedKeys.some((key) => !keys.includes(key)) ||
      result.nextClassIndex !== classIndex + expected.length ||
      result.done !== (result.nextClassIndex === manifest.length) ||
      result.classesImported !== reports.filter((row) => row.ok).length) {
    throw sourceError("INCOMPLETE_CHUNK_REPORT");
  }
}

module.exports = {verifyChunk};
