"use strict";

/* eslint-disable require-jsdoc */
const {cachedSource} = require("../import-source-cache");
const {execution} = require("../import-execution");

function fixture() {
  const documents = new Map();
  const ref = (path) => ({path,
    collection: (name) => ({doc: (id) => ref(`${path}/${name}/${id}`)}),
    get: async () => ({exists: documents.has(path),
      data: () => documents.get(path)}),
  });
  const write = async (entries) => {
    for (const entry of entries) documents.set(entry.ref.path, entry.data);
  };
  return {documents, write, context: {jobRef: ref("importJobs/job"),
    runId: "run", deadlineMs: Date.now() + 60000}};
}

test("resumption reuses validated pages without storing proxy credentials", async () => {
  const {documents, write, context} = fixture();
  const source = jest.fn().mockResolvedValue({Items: [{value: "x".repeat(800000)}]});
  const first = await execution.run(context, () => cachedSource(
      "https://example.test/page?b=2&proxykey=secret&a=1", source, write));
  const second = await execution.run({...context, deadlineMs: 1}, () =>
    cachedSource("https://example.test/page?a=1&b=2&proxykey=changed", source, write));
  expect(second).toEqual(first);
  expect(source).toHaveBeenCalledTimes(1);
  expect(JSON.stringify([...documents])).not.toContain("secret");
  expect([...documents.keys()].filter((key) => key.includes("sourceFragments")))
      .toHaveLength(3);
});

test("expired slice yields before fetching an uncached page", async () => {
  const {write, context} = fixture();
  const source = jest.fn();
  await expect(execution.run({...context, deadlineMs: 1}, () =>
    cachedSource("https://example.test/page", source, write)))
      .rejects.toMatchObject({code: "IMPORT_SLICE_YIELD"});
  expect(source).not.toHaveBeenCalled();
});

test("missing cached fragments are errors rather than empty source data", async () => {
  const {documents, write, context} = fixture();
  const source = jest.fn().mockResolvedValue({Items: []});
  const read = () => cachedSource("https://example.test/page", source, write);
  await execution.run(context, read);
  for (const key of documents.keys()) {
    if (key.includes("sourceFragments")) documents.delete(key);
  }
  await expect(execution.run(context, read))
      .rejects.toMatchObject({code: "INCOMPLETE_SOURCE_CACHE"});
  expect(source).toHaveBeenCalledTimes(1);
});
