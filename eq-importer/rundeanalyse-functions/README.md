# Rundeanalyse Firebase Functions

This directory is an isolated Cloud Functions v2 codebase for Rundeanalyse. It
does not import, export, or modify the existing EQ importer functions.

## Before deployment

1. Add this directory as the `rundeanalyse` codebase in the parent
   `eq-importer/firebase.json`; deploy it with `--only functions:rundeanalyse`.
2. Create the Firebase Secret `RUNDEANALYSE_CODE_PEPPER` with a random value of
   at least 32 characters. Code values are HMACed with this secret and are
   never stored in a separate raw-code field. A self-chosen code used as its
   display label is intentionally visible in linked-code summaries and admin
   history; treat that label as a shareable access capability.
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
| `createRundeanalyseCode` | `{code?, label?, credits, expiresAtMs?, active?}` | The new plaintext `code` in the creation response, its opaque `codeId`, and code metadata. Administrator only. |
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


## Permanent starter allowance and self-chosen codes

New deployments default to 15 starter analyses without a time limit. The current
configured `freeAnalysisLimit` remains authoritative for all accounts; remaining
credits are max(0, limit minus existing freeAnalysesUsed). No counter is reset.
An old account whose date expired regains only its unspent balance. An account
that spent all 15 remains at zero. Reducing/increasing the global limit clamps or
increases the remaining balance without rewriting users.

Access responses include `freeAllowanceExpires:false` and
`freePeriodEndsAtMs:null`. `freePeriodActive:true` remains a legacy compatibility
field; new clients use the explicit flag. Admin config also reports the flag.
`freePeriodDays` is accepted and retained for old admin clients, but no longer
limits starter credits. The paired Rundeanalyse group-debit backend must use the
same permanent calculation. Code/annual/event expiry policies are unchanged.

The new admin form submits one entered value as both `code` and `label` and
chooses a shared pool size. Existing optional random-code API behavior remains.
Code canonicalization still uppercases and removes non-ASCII letters/digits:
KLUBB-2026 and klubb2026 identify the same pool and cannot both be created.
Creation and redemption remain admin/auth checked and transactionally charged.

### Reviewed initial limit configuration

An existing stored limit overrides the new default. This operator script only
reads `rundeanalyseConfig/default` in preview mode and changes that config plus
an audit entry when explicitly applied. It never reads or rewrites user counters.
Do not run it against production as part of tests.

```sh
node scripts/set-starter-allowance.js --project time-plotting
# Review currentLimit/proposedLimit and copy expectedSha from that output.
node scripts/set-starter-allowance.js --project time-plotting --apply \
  --expected-sha <reviewed-preview-sha> --reason 'Approved permanent starter allowance'
```

Apply uses a transaction to reject stale previews. An existing limit15 is a
no-op. Other config fields are merged unchanged. Previewing again is required if
another operator edits config between preview and apply.

Release the paired access backend, Rundeanalyse saved/group backend and refreshed
web client together. Old cached web clients require a refresh to understand the
explicit non-expiring flag; they may hide the starter choice after a backend-first
cutover until refreshed. No production deploy or config apply was executed for
this patch. Client settings keep later global limit changes configurable.

Validation includes service tests and real demo Firestore transactions covering
simultaneous last-credit requests, replay, code collisions and expired-but-unspent
starter credits. CI runs these alongside the existing Firestore rules tests.
