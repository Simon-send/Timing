param(
  [string]$ProjectId = "time-plotting",
  [string]$Region = "europe-west1",
  [Parameter(Mandatory = $true)]
  [string]$OperatorMember,
  [switch]$RemoveLegacyDefaultComputeEditor
)

# gcloud skriver enkelte vellykkede statusmeldinger til stderr på Windows.
# Exit-koder kontrolleres eksplisitt underveis.
$ErrorActionPreference = "Continue"
$serviceAccountName = "import-tasks"
$serviceAccountEmail = "$serviceAccountName@$ProjectId.iam.gserviceaccount.com"
$runtimeServiceAccountName = "eq-import-runtime"
$runtimeServiceAccountEmail = "$runtimeServiceAccountName@$ProjectId.iam.gserviceaccount.com"
$projectNumber = (& gcloud projects describe $ProjectId `
  --format "value(projectNumber)").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($projectNumber)) {
  throw "Kunne ikke lese prosjektnummeret."
}
$legacyRuntimeServiceAccountEmail = "$projectNumber-compute@developer.gserviceaccount.com"

& gcloud services enable cloudtasks.googleapis.com cloudfunctions.googleapis.com `
  --project $ProjectId
if ($LASTEXITCODE -ne 0) { throw "Kunne ikke aktivere nødvendige API-er." }

$existingServiceAccount = @(
  & gcloud iam service-accounts list `
  --project $ProjectId `
  --filter "email:$serviceAccountEmail" `
  --format "value(email)" 2>$null
) | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($existingServiceAccount)) {
  & gcloud iam service-accounts create $serviceAccountName `
    --display-name "EQ import Cloud Tasks" `
    --project $ProjectId
  if ($LASTEXITCODE -ne 0) { throw "Kunne ikke opprette Cloud Tasks-servicekonto." }
}

$existingRuntimeServiceAccount = @(
  & gcloud iam service-accounts list `
  --project $ProjectId `
  --filter "email:$runtimeServiceAccountEmail" `
  --format "value(email)" 2>$null
) | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($existingRuntimeServiceAccount)) {
  & gcloud iam service-accounts create $runtimeServiceAccountName `
    --display-name "EQ importer runtime" `
    --project $ProjectId
  if ($LASTEXITCODE -ne 0) { throw "Kunne ikke opprette runtime-servicekonto." }
}

& gcloud tasks queues describe imports --location $Region --project $ProjectId *> $null
if ($LASTEXITCODE -ne 0) {
  & gcloud tasks queues create imports `
    --location $Region `
    --max-concurrent-dispatches 2 `
    --max-dispatches-per-second 1 `
    --project $ProjectId
} else {
  & gcloud tasks queues update imports `
    --location $Region `
    --max-concurrent-dispatches 2 `
    --max-dispatches-per-second 1 `
    --project $ProjectId
}
if ($LASTEXITCODE -ne 0) { throw "Kunne ikke konfigurere importkøen." }

& gcloud projects add-iam-policy-binding $ProjectId `
  --member "serviceAccount:$runtimeServiceAccountEmail" `
  --role "roles/cloudtasks.enqueuer" *> $null
if ($LASTEXITCODE -ne 0) { throw "Kunne ikke gi Functions tilgang til Cloud Tasks." }

& gcloud projects add-iam-policy-binding $ProjectId `
  --member "serviceAccount:$runtimeServiceAccountEmail" `
  --role "roles/datastore.user" *> $null
if ($LASTEXITCODE -ne 0) { throw "Kunne ikke gi runtime tilgang til Firestore." }

& gcloud projects add-iam-policy-binding $ProjectId `
  --member "serviceAccount:$legacyRuntimeServiceAccountEmail" `
  --role "roles/cloudbuild.builds.builder" *> $null
if ($LASTEXITCODE -ne 0) {
  throw "Kunne ikke gi standard Compute-servicekontoen Cloud Build-rollen."
}

& gcloud iam service-accounts add-iam-policy-binding $serviceAccountEmail `
  --member "serviceAccount:$runtimeServiceAccountEmail" `
  --role "roles/iam.serviceAccountUser" `
  --project $ProjectId *> $null
if ($LASTEXITCODE -ne 0) { throw "Kunne ikke gi Functions tilgang til OIDC-identiteten." }

& gcloud iam service-accounts add-iam-policy-binding $runtimeServiceAccountEmail `
  --member $OperatorMember `
  --role "roles/iam.serviceAccountUser" `
  --project $ProjectId *> $null
if ($LASTEXITCODE -ne 0) { throw "Kunne ikke gi deploy-operatøren tilgang til runtime-identiteten." }

if ($RemoveLegacyDefaultComputeEditor) {
  & gcloud projects remove-iam-policy-binding $ProjectId `
    --member "serviceAccount:$legacyRuntimeServiceAccountEmail" `
    --role "roles/editor" `
    --quiet
  if ($LASTEXITCODE -ne 0) {
    throw "Kunne ikke fjerne roles/editor fra standard Compute-servicekontoen."
  }
  & gcloud projects remove-iam-policy-binding $ProjectId `
    --member "serviceAccount:$legacyRuntimeServiceAccountEmail" `
    --role "roles/cloudtasks.enqueuer" `
    --quiet *> $null
  Write-Output "roles/editor er fjernet fra $legacyRuntimeServiceAccountEmail."
}

function Test-CloudFunctionExists([string]$FunctionName) {
  & gcloud functions describe $FunctionName `
    --region $Region `
    --project $ProjectId *> $null
  return $LASTEXITCODE -eq 0
}

foreach ($functionName in @("startImportEvent", "getImportStatus")) {
  if (-not (Test-CloudFunctionExists $functionName)) {
    Write-Output "$functionName finnes ikke ennå; kjør functions-deploy og kjør dette skriptet på nytt."
    continue
  }
  & gcloud functions remove-invoker-policy-binding $functionName `
    --region $Region `
    --member "allUsers" `
    --project $ProjectId *> $null
  & gcloud functions remove-invoker-policy-binding $functionName `
    --region $Region `
    --member "allAuthenticatedUsers" `
    --project $ProjectId *> $null
  & gcloud functions add-invoker-policy-binding $functionName `
    --region $Region `
    --member $OperatorMember `
    --project $ProjectId
  if ($LASTEXITCODE -ne 0) { throw "Kunne ikke sikre $functionName." }
}

if (Test-CloudFunctionExists "runImportEventChunk") {
  & gcloud functions remove-invoker-policy-binding runImportEventChunk `
    --region $Region `
    --member "allUsers" `
    --project $ProjectId *> $null
  & gcloud functions remove-invoker-policy-binding runImportEventChunk `
    --region $Region `
    --member "allAuthenticatedUsers" `
    --project $ProjectId *> $null
  & gcloud functions add-invoker-policy-binding runImportEventChunk `
    --region $Region `
    --member "serviceAccount:$serviceAccountEmail" `
    --project $ProjectId
  if ($LASTEXITCODE -ne 0) { throw "Kunne ikke sikre worker-funksjonen." }
} else {
  Write-Output "runImportEventChunk finnes ikke ennå; kjør functions-deploy og kjør dette skriptet på nytt."
}

Write-Output "Produksjons-IAM og Cloud Tasks er konfigurert."
Write-Output "Cloud Tasks-identitet: $serviceAccountEmail"
Write-Output "Runtime-identitet: $runtimeServiceAccountEmail"
Write-Output "Cloud Build-identitet: $legacyRuntimeServiceAccountEmail"
