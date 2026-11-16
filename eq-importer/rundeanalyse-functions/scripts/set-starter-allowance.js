"use strict";

const {createHash} = require("node:crypto");
const PROJECT = "time-plotting";

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  return value;
}
function configDigest(snapshot) {
  return createHash("sha256").update(JSON.stringify({exists: snapshot.exists, data: stable(snapshot.data() || {})})).digest("hex");
}
function parseArgs(argv) {
  const result = {apply: false};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--apply") {
      result.apply = true;
    } else if (["--project", "--expected-sha", "--reason"].includes(argv[i])) {
      if (!argv[i + 1] || argv[i + 1].startsWith("--")) throw new Error(`Missing value for ${argv[i]}.`);
      result[argv[i].slice(2)] = argv[++i];
    } else {
      throw new Error(`Unknown argument: ${argv[i]}`);
    }
  }
  if (result.project !== PROJECT) throw new Error(`--project must be ${PROJECT}.`);
  if (result.apply && (!/^[a-f0-9]{64}$/.test(result["expected-sha"] || "") || !result.reason?.trim() || result.reason.length > 500)) {
    throw new Error("Apply requires --expected-sha from the preview and a --reason of 1–500 characters.");
  }
  return result;
}
async function updateStarterConfig(db, args, now = () => Date.now()) {
  const ref = db.collection("rundeanalyseConfig").doc("default");
  const preview = (snapshot) => ({
    project: PROJECT,
    expectedSha: configDigest(snapshot),
    currentLimit: snapshot.data()?.freeAnalysisLimit ?? null,
    proposedLimit: 15,
    preservesAllUserCounters: true,
    applied: false,
  });
  if (!args.apply) return preview(await ref.get());
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (configDigest(snapshot) !== args["expected-sha"]) throw new Error("Configuration changed after preview; preview again before applying.");
    if (snapshot.data()?.freeAnalysisLimit === 15) return {...preview(snapshot), unchanged: true};
    const at = now();
    tx.set(ref, {freeAnalysisLimit: 15, updatedAtMs: at}, {merge: true});
    const audit = db.collection("rundeanalyseAdminAudit").doc();
    tx.set(audit, {action: "starter-allowance-configured", beforeLimit: snapshot.data()?.freeAnalysisLimit ?? null,
      afterLimit: 15, reason: args.reason.trim(), occurredAtMs: at, source: "reviewed-operator-script"});
    return {...preview(snapshot), applied: true};
  });
}
async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const {initializeApp, deleteApp} = require("firebase-admin/app");
  const {getFirestore} = require("firebase-admin/firestore");
  const app = initializeApp({projectId: PROJECT});
  try {
    console.log(JSON.stringify(await updateStarterConfig(getFirestore(app), args), null, 2));
  } finally {
    await deleteApp(app);
  }
}
if (require.main === module) {
  main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
  });
}
module.exports = {configDigest, parseArgs, updateStarterConfig};
