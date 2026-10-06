"use strict";

/* eslint-disable require-jsdoc */
const crypto = require("node:crypto");
const {execution, assertExecutionBudget} = require("./import-execution");
const {sourceError} = require("./import-source");

async function cachedSource(url, fetchSource, writeDocuments) {
  const context = execution.getStore();
  if (!context || !context.runId) return fetchSource(url);
  const canonical = new URL(url);
  canonical.searchParams.delete("proxykey");
  canonical.searchParams.sort();
  const key = crypto.createHash("sha256").update(canonical.toString())
      .digest("hex");
  const pageRef = context.jobRef.collection("runs").doc(context.runId)
      .collection("sourcePages").doc(key);
  const snapshot = await pageRef.get();
  if (snapshot.exists && snapshot.data().complete) {
    const metadata = snapshot.data();
    const buffers = [];
    for (let index = 0; index < metadata.fragmentCount; index++) {
      const part = await pageRef.collection("sourceFragments")
          .doc(String(index)).get();
      if (!part.exists) throw sourceError("INCOMPLETE_SOURCE_CACHE");
      buffers.push(Buffer.from(part.data().payload, "base64"));
    }
    const body = Buffer.concat(buffers);
    if (crypto.createHash("sha256").update(body).digest("hex") !==
        metadata.hash) throw sourceError("INVALID_SOURCE_CACHE");
    return JSON.parse(body.toString("utf8"));
  }
  assertExecutionBudget();
  const data = await fetchSource(url);
  const body = Buffer.from(JSON.stringify(data));
  const fragmentSize = 384 * 1024;
  const fragmentCount = Math.ceil(body.length / fragmentSize);
  for (let index = 0; index < fragmentCount; index++) {
    await writeDocuments([{
      ref: pageRef.collection("sourceFragments").doc(String(index)),
      data: {payload: body.subarray(index * fragmentSize,
          (index + 1) * fragmentSize).toString("base64")},
    }]);
  }
  await writeDocuments([{ref: pageRef, data: {
    complete: true, fragmentCount,
    hash: crypto.createHash("sha256").update(body).digest("hex"),
  }}]);
  return data;
}

module.exports = {cachedSource};
