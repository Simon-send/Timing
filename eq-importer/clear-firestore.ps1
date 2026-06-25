param(
  [string]$ProjectId = "time-plotting",
  [string]$DatabaseId = "(default)",
  [switch]$YesDeleteEverything
)

$ErrorActionPreference = "Stop"

if (-not $YesDeleteEverything) {
  Write-Error "Refusing to delete Firestore. Re-run with -YesDeleteEverything to delete ALL documents in project '$ProjectId', database '$DatabaseId'."
}

Write-Host "Deleting ALL Cloud Firestore documents..."
Write-Host "Project:  $ProjectId"
Write-Host "Database: $DatabaseId"

firebase firestore:delete `
  --project $ProjectId `
  --database $DatabaseId `
  --all-collections `
  --recursive `
  --force

Write-Host "Done. Firestore database '$DatabaseId' in project '$ProjectId' has been cleared."
