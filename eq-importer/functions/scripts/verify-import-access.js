"use strict";

/* eslint-disable require-jsdoc */
const {execFileSync} = require("node:child_process");
const {randomUUID} = require("node:crypto");

function gcloud(args) {
  return execFileSync("gcloud", args, {encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"]}).trim();
}

async function verify(project) {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(project || "")) {
    throw new Error("Specify the Firebase project ID");
  }
  const region = "europe-west1";
  const account = `import-tasks@${project}.iam.gserviceaccount.com`;
  const servicePath = gcloud(["functions", "describe", "runImportEventChunk",
    "--gen2", `--region=${region}`, `--project=${project}`,
    "--format=value(serviceConfig.service)"]);
  const service = servicePath.split("/").pop();
  if (!service) throw new Error("Missing worker service");
  const policy = JSON.parse(gcloud([
    "run", "services", "get-iam-policy", service,
    `--region=${region}`, `--project=${project}`, "--format=json"]));
  const members = (policy.bindings || [])
      .filter((binding) => binding.role === "roles/run.invoker")
      .flatMap((binding) => binding.members || []);
  if (!members.includes(`serviceAccount:${account}`) ||
      members.includes("allUsers") ||
      members.includes("allAuthenticatedUsers")) {
    throw new Error("Worker IAM verification failed");
  }
  const base = `https://${region}-${project}.cloudfunctions.net`;
  const url = `${base}/runImportEventChunk`;
  const anonymous = await fetch(url, {signal: AbortSignal.timeout(15000)});
  if (![401, 403].includes(anonymous.status)) {
    throw new Error("Worker did not reject an unauthenticated request");
  }
  const probeId = randomUUID();
  gcloud(["tasks", "create-http-task", `import-probe-${probeId}`,
    "--queue=imports", `--location=${region}`, `--project=${project}`,
    `--url=${url}`, "--method=POST", "--header=Content-Type:application/json",
    `--oidc-service-account-email=${account}`, `--oidc-token-audience=${url}`,
    `--body-content=${JSON.stringify({kind: "probe", probeId})}`, "--quiet"]);
  const token = gcloud(["auth", "print-identity-token"]);
  const deadline = Date.now() + 90000;
  while (Date.now() < deadline) {
    const response = await fetch(`${base}/getImportStatus?probeId=${probeId}`, {
      headers: {Authorization: `Bearer ${token}`},
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`Status API HTTP ${response.status}`);
    if ((await response.json()).ok === true) {
      console.log("Cloud Tasks identity and private worker access verified.");
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  throw new Error("Cloud Tasks probe did not complete within 90 seconds");
}

if (require.main === module) {
  verify(process.argv[2]).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {verify};
