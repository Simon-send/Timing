#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="${FIREBASE_PROJECT_ID:-time-plotting}"
REGION="${FUNCTION_REGION:-europe-west1}"
OPERATOR_MEMBER="${1:-}"
REMOVE_LEGACY_EDITOR="${2:-}"

if [[ -z "$OPERATOR_MEMBER" ]]; then
  account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
  if [[ -z "$account" ]]; then
    echo "Fant ingen aktiv gcloud-konto. Kjør: gcloud auth login" >&2
    exit 1
  fi
  OPERATOR_MEMBER="user:${account}"
fi

if [[ "$OPERATOR_MEMBER" != user:* && "$OPERATOR_MEMBER" != serviceAccount:* ]]; then
  echo "OperatorMember må starte med user: eller serviceAccount:" >&2
  exit 1
fi

project_number="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
runtime_service_account="eq-import-runtime@${PROJECT_ID}.iam.gserviceaccount.com"
tasks_service_account="import-tasks@${PROJECT_ID}.iam.gserviceaccount.com"
legacy_service_account="${project_number}-compute@developer.gserviceaccount.com"

gcloud services enable cloudtasks.googleapis.com cloudfunctions.googleapis.com \
  --project="$PROJECT_ID"

if ! gcloud iam service-accounts describe "$tasks_service_account" \
  --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create import-tasks \
    --display-name="EQ import Cloud Tasks" \
    --project="$PROJECT_ID"
fi

if ! gcloud iam service-accounts describe "$runtime_service_account" \
  --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create eq-import-runtime \
    --display-name="EQ importer runtime" \
    --project="$PROJECT_ID"
fi

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${runtime_service_account}" \
  --role="roles/cloudtasks.enqueuer" \
  --condition=None >/dev/null
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${runtime_service_account}" \
  --role="roles/datastore.user" \
  --condition=None >/dev/null
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${legacy_service_account}" \
  --role="roles/cloudbuild.builds.builder" \
  --condition=None >/dev/null
gcloud iam service-accounts add-iam-policy-binding "$tasks_service_account" \
  --member="serviceAccount:${runtime_service_account}" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None \
  --project="$PROJECT_ID" >/dev/null
gcloud iam service-accounts add-iam-policy-binding "$runtime_service_account" \
  --member="$OPERATOR_MEMBER" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None \
  --project="$PROJECT_ID" >/dev/null

if [[ "$REMOVE_LEGACY_EDITOR" == "--remove-legacy-editor" ]]; then
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${legacy_service_account}" \
    --role="roles/editor" \
    --quiet
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${legacy_service_account}" \
    --role="roles/cloudtasks.enqueuer" \
    --quiet >/dev/null 2>&1 || true
  echo "roles/editor er fjernet fra ${legacy_service_account}."
fi

configure_invoker() {
  local function_name="$1"
  local member="$2"
  local service_path
  local service_name

  if ! gcloud functions describe "$function_name" \
    --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "${function_name} finnes ikke ennå; kjør functions-deploy og kjør skriptet på nytt."
    return
  fi

  service_path="$(gcloud functions describe "$function_name" \
    --gen2 --region="$REGION" --project="$PROJECT_ID" \
    --format='value(serviceConfig.service)')"
  service_name="${service_path##*/}"
  if [[ -z "$service_name" || "$service_name" == "$service_path" ]]; then
    echo "Fant ikke Cloud Run-tjenesten for ${function_name}." >&2
    exit 1
  fi

  gcloud run services remove-iam-policy-binding "$service_name" \
    --region="$REGION" --member=allUsers --role=roles/run.invoker \
    --project="$PROJECT_ID" >/dev/null 2>&1 || true
  gcloud run services remove-iam-policy-binding "$service_name" \
    --region="$REGION" --member=allAuthenticatedUsers --role=roles/run.invoker \
    --project="$PROJECT_ID" >/dev/null 2>&1 || true
  gcloud run services add-iam-policy-binding "$service_name" \
    --region="$REGION" --member="$member" --role=roles/run.invoker \
    --project="$PROJECT_ID" >/dev/null

  verify_invoker "$function_name" "$member"
}

verify_invoker() {
  local function_name="$1"
  local expected_member="$2"
  local service_path
  local service_name
  local members

  service_path="$(gcloud functions describe "$function_name" \
    --gen2 --region="$REGION" --project="$PROJECT_ID" \
    --format='value(serviceConfig.service)')"
  service_name="${service_path##*/}"
  if [[ -z "$service_name" || "$service_name" == "$service_path" ]]; then
    echo "Fant ikke Cloud Run-tjenesten for ${function_name}." >&2
    exit 1
  fi

  members="$(gcloud run services get-iam-policy "$service_name" \
    --region="$REGION" --project="$PROJECT_ID" \
    --flatten='bindings[].members' \
    --filter='bindings.role=roles/run.invoker' \
    --format='value(bindings.members)')"

  if printf '%s\n' "$members" | grep -Eq '^(allUsers|allAuthenticatedUsers)$'; then
    echo "Bred invoker-tilgang ble funnet på ${function_name}." >&2
    exit 1
  fi
  if ! printf '%s\n' "$members" | grep -Fqx "$expected_member"; then
    echo "Forventet invoker mangler på ${function_name}: ${expected_member}" >&2
    exit 1
  fi
}

configure_invoker startImportEvent "$OPERATOR_MEMBER"
configure_invoker getImportStatus "$OPERATOR_MEMBER"
configure_invoker runImportEventChunk "serviceAccount:${tasks_service_account}"

echo "Produksjons-IAM er konfigurert."
echo "Runtime-identitet: ${runtime_service_account}"
echo "Cloud Tasks-identitet: ${tasks_service_account}"
echo "Cloud Build-identitet: ${legacy_service_account}"
if [[ "$REMOVE_LEGACY_EDITOR" != "--remove-legacy-editor" ]]; then
  echo "Når ny functions-deploy er verifisert, kjør skriptet på nytt med --remove-legacy-editor."
fi
