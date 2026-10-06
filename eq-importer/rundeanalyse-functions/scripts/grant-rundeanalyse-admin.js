"use strict";

const EXPECTED_PROJECT_ID = "time-plotting";

// Keep the modular Admin SDK imports inside this factory. Jest can then test
// the narrow command parsing and claim-merge contract with a small adapter,
// while the CLI still loads the real SDK only when it is executed.
function defaultAdminSdk() {
  const {getApps, initializeApp} = require("firebase-admin/app");
  const {getAuth} = require("firebase-admin/auth");
  const {getFirestore} = require("firebase-admin/firestore");
  return {getApps, initializeApp, getAuth, getFirestore};
}

function parseArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--yes") {
      values.yes = true;
      continue;
    }
    if (["--email", "--confirm-email", "--project"].includes(argument)) {
      const value = argv[index + 1];
      if (!value || value.startsWith("--")) throw new Error(`Missing value for ${argument}.`);
      values[argument.slice(2)] = value;
      index += 1;
      continue;
    }
    throw new Error(`Unknown argument: ${argument}`);
  }

  const email = typeof values.email === "string" ? values.email.trim().toLowerCase() : "";
  const confirmEmail = typeof values["confirm-email"] === "string" ?
    values["confirm-email"].trim().toLowerCase() : "";
  if (!values.yes) throw new Error("Refusing to change Firebase without --yes.");
  if (!email || email !== confirmEmail) {
    throw new Error("--email and --confirm-email must be the same email address.");
  }
  if (values.project !== EXPECTED_PROJECT_ID) {
    throw new Error(`--project must be ${EXPECTED_PROJECT_ID}.`);
  }
  return {
    email,
    projectId: values.project,
  };
}

async function grantAdministrator({adminSdk, email, projectId}) {
  if (!adminSdk.getApps().length) adminSdk.initializeApp({projectId});
  const user = await adminSdk.getAuth().getUserByEmail(email);
  const claims = Object.assign({}, user.customClaims || {}, {rundeanalyseAdmin: true});
  await adminSdk.getAuth().setCustomUserClaims(user.uid, claims);
  await adminSdk.getFirestore().collection("rundeanalyseAdminGrants").doc(user.uid).set({
    email: user.email || email,
    grantedAtMs: Date.now(),
    source: "one-off-admin-bootstrap",
  }, {merge: true});
  return {
    uid: user.uid,
    email: user.email || email,
  };
}

async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const result = await grantAdministrator({
    adminSdk: defaultAdminSdk(),
    email: args.email,
    projectId: args.projectId,
  });
  console.log(`Granted Rundeanalyse administrator access to ${result.email} (${result.uid}).`);
  console.log("The user must refresh their Firebase ID token or sign in again before the claim is visible.");
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  EXPECTED_PROJECT_ID,
  defaultAdminSdk,
  grantAdministrator,
  parseArgs,
};
