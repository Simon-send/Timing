#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mode="${1:-preview}"
[[ "$mode" == "preview" || "$mode" == "publish" ]] || { echo 'Usage: bash deploy-web.sh [preview|publish]'; exit 1; }
firebase_cli="$PWD/functions/node_modules/.bin/firebase"
[[ -x "$firebase_cli" ]] || {
  echo "Locked Firebase CLI is not installed. Run npm ci in $PWD/functions before deploying." >&2
  exit 1
}
if [[ "$mode" == "publish" ]]; then
  # Publish exactly the version that was reviewed, without rebuilding.
  "$firebase_cli" hosting:clone time-plotting:security-review time-plotting:live --project time-plotting
  exit
fi
: "${EQ_APP_CHECK_SITE_KEY:?Set the public reCAPTCHA site key before building}"
staging=$(mktemp -d "${TMPDIR:-/tmp}/plotting-web.XXXXXX")
cd ../results
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none --output="$staging" \
  --dart-define="FIREBASE_APP_CHECK_SITE_KEY=$EQ_APP_CHECK_SITE_KEY"
node ../eq-importer/verify-web-build.mjs "$staging"
cd ../eq-importer
mkdir -p hosting
rsync -a --delete --exclude='.gitignore' "$staging/" hosting/
"$firebase_cli" hosting:channel:deploy security-review --expires 7d --project time-plotting --no-authorized-domains
echo "Preview deployed. Review before running: bash deploy-web.sh publish"
