"use strict";

const crypto = require("node:crypto");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {AccessError, RundeanalyseAccessService} = require("./access_service");

const FUNCTION_REGION = "europe-west1";
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "time-plotting";
const RUNTIME_SERVICE_ACCOUNT = process.env.RUNDEANALYSE_RUNTIME_SERVICE_ACCOUNT ||
  `rundeanalyse-runtime@${PROJECT_ID}.iam.gserviceaccount.com`;
const codePepper = defineSecret("RUNDEANALYSE_CODE_PEPPER");
const enforceAppCheck = process.env.RUNDEANALYSE_ENFORCE_APP_CHECK === "true";
// Firebase Hosting forwards only this cookie to rewritten Cloud Functions.
const GUEST_SESSION_COOKIE = "__session";

function isVerifiedAccount(request) {
  return request.auth && request.auth.token &&
    request.auth.token.email_verified === true &&
    request.auth.token.firebase &&
    request.auth.token.firebase.sign_in_provider !== "anonymous";
}

function guestSessionToken(request) {
  const header = request.rawRequest && request.rawRequest.headers.cookie;
  if (typeof header !== "string") return undefined;
  const prefix = `${GUEST_SESSION_COOKIE}=`;
  const part = header.split(";").map((value) => value.trim())
    .find((value) => value.startsWith(prefix));
  return part ? decodeURIComponent(part.slice(prefix.length)) : undefined;
}

function setGuestSessionCookie(request, token, maxAgeSeconds) {
  const response = request.rawRequest && request.rawRequest.res;
  if (!response || typeof response.append !== "function") return;
  const value = token ? encodeURIComponent(token) : "";
  const attributes = [
    `${GUEST_SESSION_COOKIE}=${value}`,
    "Path=/api/consume",
    "HttpOnly",
    "Secure",
    "SameSite=Strict",
    `Max-Age=${maxAgeSeconds}`,
  ];
  response.append("Set-Cookie", attributes.join("; "));
}

function getApp() {
  return getApps().find((app) => app.name === "[DEFAULT]") || initializeApp();
}

function getService() {
  // Pass the same explicit Admin app to both services. On a cold v2
  // invocation, relying on each modular service to look up the default app
  // independently can race and caused authenticated access calls to fail.
  const app = getApp();
  return new RundeanalyseAccessService({
    db: getFirestore(app),
    auth: getAuth(app),
    codePepper: codePepper.value(),
  });
}

function callable(operation, handler) {
  return onCall({
    region: FUNCTION_REGION,
    serviceAccount: RUNTIME_SERVICE_ACCOUNT,
    enforceAppCheck,
    secrets: [codePepper],
  }, async (request) => {
    try {
      const service = getService();
      const guest = !isVerifiedAccount(request);
      const suppliedCode = typeof request.data?.code === "string" &&
        request.data.code.trim() !== "";
      let sessionToken;
      if (operation === "consumeRundeanalyseAnalysis" && guest && !suppliedCode) {
        sessionToken = guestSessionToken(request);
        if (sessionToken) {
          const codeId = await service.codeIdForGuestSession(sessionToken);
          if (codeId) {
            request.guestSessionCodeId = codeId;
          } else {
            setGuestSessionCookie(request, undefined, 0);
          }
        }
      }
      const result = await handler(service, request);
      if (operation === "consumeRundeanalyseAnalysis" && guest && suppliedCode &&
          result.allowed === true && result.access?.source === "code") {
        const token = crypto.randomBytes(32).toString("base64url");
        await service.createGuestSession({token, codeId: result.access.codeId});
        setGuestSessionCookie(request, token, 8 * 60 * 60);
      } else if (sessionToken && request.guestSessionCodeId && result.allowed === false) {
        setGuestSessionCookie(request, undefined, 0);
      }
      return result;
    } catch (error) {
      if (error instanceof AccessError) {
        throw new HttpsError(error.code, error.message, error.details);
      }
      console.error("Rundeanalyse callable failed.", {
        operation,
        message: error && error.message || String(error),
      });
      throw new HttpsError("internal", "The access request could not be completed.");
    }
  });
}

exports.getRundeanalyseAccessStatus = callable(
  "getRundeanalyseAccessStatus",
  (service, request) => service.getAccessStatus(request),
);

exports.consumeRundeanalyseAnalysis = callable(
  "consumeRundeanalyseAnalysis",
  (service, request) => service.consumeAnalysis(request),
);

exports.linkRundeanalyseCode = callable(
  "linkRundeanalyseCode",
  (service, request) => service.linkCode(request),
);

exports.createRundeanalyseCode = callable(
  "createRundeanalyseCode",
  (service, request) => service.createCode(request),
);

exports.setRundeanalyseConfig = callable(
  "setRundeanalyseConfig",
  (service, request) => service.setConfig(request),
);

exports.upsertRundeanalyseEvent = callable(
  "upsertRundeanalyseEvent",
  (service, request) => service.upsertEvent(request),
);

exports.grantRundeanalyseAnnualAccess = callable(
  "grantRundeanalyseAnnualAccess",
  (service, request) => service.grantAnnualAccess(request),
);

exports.grantRundeanalyseBonusAnalyses = callable(
  "grantRundeanalyseBonusAnalyses",
  (service, request) => service.grantBonusAnalyses(request),
);

exports.updateRundeanalyseCode = callable(
  "updateRundeanalyseCode",
  (service, request) => service.updateCode(request),
);

exports.getRundeanalyseAdminUsage = callable(
  "getRundeanalyseAdminUsage",
  (service, request) => service.getAdminUsage(request),
);

exports.getRundeanalyseAdminAudit = callable(
  "getRundeanalyseAdminAudit",
  (service, request) => service.getAdminAudit(request),
);

exports.getRundeanalyseAdminOverview = callable(
  "getRundeanalyseAdminOverview",
  (service, request) => service.getAdminOverview(request),
);
