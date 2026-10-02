"use strict";

const path = require("node:path");
const {spawnSync} = require("node:child_process");

test("importer loads with the real modular Firebase Admin SDK", () => {
  const script = [
    "const assert = require('node:assert/strict');",
    "const app = require('firebase-admin/app');",
    "const firestore = require('firebase-admin/firestore');",
    "assert.equal(typeof app.initializeApp, 'function');",
    "assert.equal(typeof firestore.getFirestore, 'function');",
    "assert.equal(typeof firestore.FieldValue.serverTimestamp, 'function');",
    "assert.equal(typeof firestore.FieldValue.arrayUnion, 'function');",
    "assert.equal(typeof firestore.FieldValue.delete, 'function');",
    "const importer = require('./index.js');",
    "for (const name of ['startImportEvent', 'runImportEventChunk',",
    "  'getImportStatus']) assert.equal(typeof importer[name], 'function');",
  ].join("\n");
  const child = spawnSync(process.execPath, ["-e", script], {
    cwd: path.resolve(__dirname, ".."),
    encoding: "utf8",
    timeout: 10000,
    env: {
      ...process.env,
      GCLOUD_PROJECT: "demo-eq-results",
      GOOGLE_CLOUD_PROJECT: "demo-eq-results",
      FIREBASE_CONFIG: JSON.stringify({projectId: "demo-eq-results"}),
    },
  });
  expect(child.error).toBeUndefined();
  expect({status: child.status, stderr: child.stderr}).toEqual({
    status: 0,
    stderr: "",
  });
});

test("storage HTTP client supports the patched CommonJS UUID dependency", () => {
  const script = [
    "const assert = require('node:assert/strict');",
    "const {createRequire} = require('node:module');",
    "const storage = createRequire(require.resolve('@google-cloud/storage'));",
    "const {Gaxios} = storage('gaxios');",
    "const http = createRequire(storage.resolve('gaxios'));",
    "const uuid = http('uuid');",
    "(async () => {",
    "  let called = false;",
    "  const response = await new Gaxios().request({",
    "    url: 'https://example.test/upload',",
    "    method: 'POST',",
    "    multipart: [{headers: {}, content: 'test-payload'}],",
    "    fetchImplementation: async (url, options) => {",
    "      called = true;",
    "      assert.equal(url, 'https://example.test/upload');",
    "      const header = options.headers['Content-Type'];",
    "      const boundary = /boundary=([0-9a-f-]+)/.exec(header)[1];",
    "      assert.equal(uuid.validate(boundary), true);",
    "      assert.equal(uuid.version(boundary), 4);",
    "      let body = '';",
    "      for await (const chunk of options.body) body += chunk.toString();",
    "      assert.ok(body.includes('test-payload'));",
    "      assert.ok(body.endsWith('--' + boundary + '--'));",
    "      return new Response(JSON.stringify({ok: true}), {",
    "        headers: {'Content-Type': 'application/json'},",
    "      });",
    "    },",
    "  });",
    "  assert.equal(called, true);",
    "  assert.deepEqual(response.data, {ok: true});",
    "})().catch((error) => {console.error(error); process.exitCode = 1;});",
  ].join("\n");
  const child = spawnSync(process.execPath, ["-e", script], {
    cwd: path.resolve(__dirname, ".."),
    encoding: "utf8",
    timeout: 10000,
  });
  expect(child.error).toBeUndefined();
  expect({status: child.status, stderr: child.stderr}).toEqual({
    status: 0,
    stderr: "",
  });
});
