$ErrorActionPreference = "Stop"
$source = Join-Path (Split-Path -Parent $PSScriptRoot) "results\build\web"
$destination = Join-Path $PSScriptRoot "hosting"
$staging = Join-Path $PSScriptRoot "hosting-staging"
$backup = Join-Path $PSScriptRoot "hosting-previous"

if (-not (Test-Path -LiteralPath $source)) {
  throw "Flutter webbygget mangler: $source"
}

if (Test-Path -LiteralPath $staging) {
  Remove-Item -LiteralPath $staging -Recurse -Force
}
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $staging -Recurse -Force

if (Test-Path -LiteralPath $backup) {
  Remove-Item -LiteralPath $backup -Recurse -Force
}
if (Test-Path -LiteralPath $destination) {
  Move-Item -LiteralPath $destination -Destination $backup
}

try {
  Move-Item -LiteralPath $staging -Destination $destination
  if (Test-Path -LiteralPath $backup) {
    Remove-Item -LiteralPath $backup -Recurse -Force
  }
} catch {
  if (-not (Test-Path -LiteralPath $destination) -and
      (Test-Path -LiteralPath $backup)) {
    Move-Item -LiteralPath $backup -Destination $destination
  }
  throw
}

Write-Output "Kopierte et rent Flutter webbygg til $destination"
