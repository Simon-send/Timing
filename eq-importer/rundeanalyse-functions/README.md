# Rundeanalyse Firebase Functions

This directory is an isolated Cloud Functions v2 codebase for Rundeanalyse. It
does not import, export, or modify the existing EQ importer functions.

## Before deployment

1. Add this directory as the `rundeanalyse` codebase in the parent
   `eq-importer/firebase.json`; deploy it with `--only functions:rundeanalyse`.
2. Create the Firebase Secret `RUNDEANALYSE_CODE_PEPPER` with a random value of
   at least 32 characters. Code values are HMACed with this secret and are
   never written to Firestore.
3. Use the dedicated `rundeanalyse-runtime` service account with only these
   runtime roles:
   - `roles/datastore.user`, limited to the default Firestore database when
     possible;
   - `roles/firebaseauth.viewer`, used only to find a recipient for a manual
     annual-access grant;
   - `roles/logging.logWriter`; and
   - `roles/secretmanager.secretAccessor` on `RUNDEANALYSE_CODE_PEPPER`.

   Set `RUNDEANALYSE_RUNTIME_SERVICE_ACCOUNT` only when using a deliberately
   different account; the deployment default is
   `rundeanalyse-runtime@time-plotting.iam.gserviceaccount.com`.
4. Add the Rundeanalyse Firestore rule paths to the existing shared rule file.
   Client writes must remain denied for all entitlement, code, usage, and
   statistics documents. The only intended public data is active event metadata
   returned by `getRundeanalyseAccessStatus`.
5. Run the administrator bootstrap exactly once after deployment:

   ```sh
   npm run grant:admin -- --project time-plotting --email admin@example.com \
     --confirm-email admin@example.com --yes
   ```

   The user must refresh the Firebase ID token or sign in again afterwards.

`RUNDEANALYSE_ENFORCE_APP_CHECK=true` enables callable App Check enforcement at
the next function deployment. Leave it off until the Flutter app has registered
App Check successfully.

## Callable contract

All callables run in `europe-west1`. Mutating calls are server-controlled;
Flutter must never update code balances, grants, events, or usage directly.

| Callable | Request | Result |
| --- | --- | --- |
| `getRundeanalyseAccessStatus` | `{}` | Sign-in state, administrator flag, free/annual status, linked-code summaries and current event metadata. |
| `consumeRundeanalyseAnalysis` | `{idempotencyKey, code?, linkedCodeId?, useFreeAllowance?, eventCandidate?}` | `{allowed, idempotencyKey?, analysisAccessId?, access?, reason?, nextStep?}`. `eventCandidate` is `{eventId, capturedAtMs, latitude, longitude}` and is checked again by the server. |
| `linkRundeanalyseCode` | `{code}` | `{linked, alreadyLinked, code}`. |
| `createRundeanalyseCode` | `{code?, label?, credits, expiresAtMs?, active?}` | The new plaintext `code` once, its opaque `codeId`, and code metadata. Administrator only. |
| `setRundeanalyseConfig` | Any of `{freeAnalysisLimit, freePeriodDays, offerEnabled}` | `{config}`. Administrator only. |
| `upsertRundeanalyseEvent` | `{eventId?, name, startAtMs, endAtMs, goalLatitude, goalLongitude, radiusMeters, active?}` | `{event}`. Administrator only. |
| `grantRundeanalyseAnnualAccess` | `{uid? \| email?, accessUntilMs}` | `{uid, email, annualAccessUntilMs}`. Administrator only. |
| `getRundeanalyseAdminOverview` | `{limit?}` | Configuration, total/today source counts and recent code, event, and user summaries. Administrator only. |

`code`, `linkedCodeId` and `useFreeAllowance` are mutually exclusive. A successful explicitly
entered code use links its opaque `codeId` to the signed-in account when there
is room. If an account has usable linked codes but no code is selected,
`consumeRundeanalyseAnalysis` returns `{allowed:false, reason:"CHOOSE_CODE"}`
instead of taking an arbitrary balance. The client can explicitly pass
`useFreeAllowance:true` when the user chooses the free allowance instead.

The access priority is: matching event, annual access, explicit code, selected
linked code, then the free allowance. An invalid explicit code never silently
uses a free analysis. Code and idempotency writes happen in the same Firestore
transaction, so concurrent attempts cannot spend a shared final credit twice.

## Local checks

From this directory:

```sh
npm install
npm run verify
```

Do not deploy as part of local verification.
