"use strict";

const {verifyChunk} = require("../import-completeness");
const manifest = [{stageId: 1, classId: 10}, {stageId: 2, classId: 10}];
const report = {perClass: [{etappeUid: 1, classId: 10, ok: true},
  {etappeUid: 2, classId: 10, ok: false}], nextClassIndex: 2,
done: true, classesImported: 1};

test("separate stage reports are required even for the same class", () => {
  expect(() => verifyChunk(manifest, 0, 2, report)).not.toThrow();
  expect(() => verifyChunk(manifest, 0, 2, {...report,
    perClass: [report.perClass[0], report.perClass[0]]}))
      .toThrow("INCOMPLETE_CHUNK_REPORT");
});

test.each([
  {done: false}, {nextClassIndex: 3}, {classesImported: 2}, {perClass: []},
])("rejects incomplete or contradictory progress: %j", (change) => {
  expect(() => verifyChunk(manifest, 0, 2, {...report, ...change}))
      .toThrow("INCOMPLETE_CHUNK_REPORT");
});
