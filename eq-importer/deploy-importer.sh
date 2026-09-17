#!/usr/bin/env bash
set -euo pipefail

project="${1:?Oppgi Firebase-prosjekt-ID}"
operator_member="${2:?Oppgi user:epost for importoperatøren}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if [[ "$project" == "time-plotting" ]]; then
  echo "Produksjonsutrulling krever først verifisert testimport og gjennomgang av aktive jobber." >&2
  echo "Dette skriptet er foreløpig begrenset til testmiljøet." >&2
  exit 1
fi

billing_enabled="$(gcloud billing projects describe "$project" --format='value(billingEnabled)')"
if [[ "$billing_enabled" != "True" && "$billing_enabled" != "true" ]]; then
  echo "Testprosjektet mangler aktiv fakturering. Ingen deploy eller IAM-endring er utført." >&2
  exit 1
fi

FIREBASE_PROJECT_ID="$project" bash configure-production.sh "$operator_member"
./functions/node_modules/.bin/firebase deploy --only functions:default --project "$project"
FIREBASE_PROJECT_ID="$project" bash configure-production.sh "$operator_member"
node functions/scripts/verify-import-access.js "$project"
