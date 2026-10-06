"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const {spawnSync} = require("child_process");

const sourceScript = path.resolve(__dirname, "../../deploy-web.sh");
let fixture;

beforeEach(() => {
  fixture = fs.mkdtempSync(path.join(os.tmpdir(), "deploy-web-test-"));
  fs.mkdirSync(path.join(fixture, "eq-importer/functions/node_modules/.bin"), {recursive: true});
  fs.mkdirSync(path.join(fixture, "results"));
  fs.mkdirSync(path.join(fixture, "bin"));
  fs.copyFileSync(sourceScript, path.join(fixture, "eq-importer/deploy-web.sh"));

  // Only these local fakes can run; PATH Firebase/npx are fallback traps.
  const fake = `#!${process.execPath}
const fs = require("fs");
const path = require("path");
const executable = path.basename(process.argv[1]);
const tool = executable === "firebase" && process.argv[1].includes("node_modules") ? "locked-firebase" : executable;
const args = process.argv.slice(2);
fs.appendFileSync(process.env.FAKE_LOG, JSON.stringify({tool, args, executable: process.argv[1]}) + "\\n");
if (["npx", "firebase"].includes(tool)) process.exit(91);
if (process.env.FAKE_FAIL === tool + ":" + args[0]) process.exit(42);
`;
  for (const tool of ["flutter", "node", "rsync", "npx", "firebase"]) {
    fs.writeFileSync(path.join(fixture, "bin", tool), fake, {mode: 0o755});
  }
  fs.writeFileSync(path.join(fixture, "eq-importer/functions/node_modules/.bin/firebase"), fake, {mode: 0o755});
});

afterEach(() => {
  fs.rmSync(fixture, {recursive: true, force: true});
});

/** Run the copied deployment script exclusively against local fake tools.
 * @param {string} mode Script mode.
 * @param {object} env Additional fixture environment.
 * @return {object} Process result and recorded tool calls.
 */
function runScript(mode = "preview", env = {}) {
  const result = spawnSync("/bin/bash", [path.join(fixture, "eq-importer/deploy-web.sh"), mode], {
    cwd: fixture,
    env: {
      PATH: `${path.join(fixture, "bin")}${path.delimiter}/usr/bin${path.delimiter}/bin`,
      TMPDIR: fixture,
      FAKE_LOG: path.join(fixture, "calls.jsonl"),
      EQ_APP_CHECK_SITE_KEY: "public-fixture-key",
      ...env,
    },
    encoding: "utf8",
    timeout: 10000,
  });
  const log = path.join(fixture, "calls.jsonl");
  const calls = fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").map((line) => JSON.parse(line)) : [];
  return {...result, calls};
}

test("preview uses the installed CLI and disables authorized-domain changes", () => {
  const result = runScript();
  expect(result.status).toBe(0);
  expect(result.calls.map((call) => call.tool)).toEqual([
    "flutter", "flutter", "flutter", "node", "rsync", "locked-firebase",
  ]);
  const buildArgs = result.calls[2].args;
  expect(buildArgs).toEqual([
    "build", "web", "--release", "--pwa-strategy=none",
    expect.stringMatching(new RegExp(`^--output=${fixture}/plotting-web\\.`)),
    "--dart-define=FIREBASE_APP_CHECK_SITE_KEY=public-fixture-key",
  ]);
  const staging = buildArgs[4].slice("--output=".length);
  expect(result.calls[3].args).toEqual(["../eq-importer/verify-web-build.mjs", staging]);
  expect(result.calls[4].args).toEqual(["-a", "--delete", "--exclude=.gitignore", `${staging}/`, "hosting/"]);
  expect(result.calls[5].executable).toBe(path.join(fixture, "eq-importer/functions/node_modules/.bin/firebase"));
  expect(result.calls[5].args).toEqual([
    "hosting:channel:deploy", "security-review", "--expires", "7d",
    "--project", "time-plotting", "--no-authorized-domains",
  ]);
});

test.each(["preview", "publish"])("missing installed CLI stops %s before any build or fallback", (mode) => {
  fs.unlinkSync(path.join(fixture, "eq-importer/functions/node_modules/.bin/firebase"));
  const result = runScript(mode);
  expect(result.status).toBe(1);
  expect(result.stderr).toContain("Locked Firebase CLI is not installed");
  expect(result.stderr).toContain("npm ci");
  expect(result.calls).toEqual([]);
});

test.each([
  ["flutter:analyze", ["flutter"]],
  ["flutter:test", ["flutter", "flutter"]],
  ["flutter:build", ["flutter", "flutter", "flutter"]],
  ["node:../eq-importer/verify-web-build.mjs", ["flutter", "flutter", "flutter", "node"]],
  ["rsync:-a", ["flutter", "flutter", "flutter", "node", "rsync"]],
])("%s failure stops before upload", (failure, tools) => {
  const result = runScript("preview", {FAKE_FAIL: failure});
  expect(result.status).toBe(42);
  expect(result.calls.map((call) => call.tool)).toEqual(tools);
});

test("publish clones the reviewed channel using the installed CLI without rebuilding", () => {
  const result = runScript("publish", {EQ_APP_CHECK_SITE_KEY: ""});
  expect(result.status).toBe(0);
  expect(result.calls).toEqual([{
    tool: "locked-firebase",
    executable: path.join(fixture, "eq-importer/functions/node_modules/.bin/firebase"),
    args: ["hosting:clone", "time-plotting:security-review", "time-plotting:live", "--project", "time-plotting"],
  }]);
  expect(fs.existsSync(path.join(fixture, "eq-importer/hosting"))).toBe(false);
});

test("preview requires the public App Check site key before building", () => {
  const result = runScript("preview", {EQ_APP_CHECK_SITE_KEY: ""});
  expect(result.status).toBe(1);
  expect(result.stderr).toContain("Set the public reCAPTCHA site key before building");
  expect(result.calls).toEqual([]);
});

test("an unsupported mode stops before tools run", () => {
  const result = runScript("invalid");
  expect(result.status).toBe(1);
  expect(result.stdout).toContain("Usage: bash deploy-web.sh [preview|publish]");
  expect(result.calls).toEqual([]);
});
