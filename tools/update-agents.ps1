param(
  [switch]$Check,
  [switch]$Watch
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$agentsPath = Join-Path $repoRoot "AGENTS.md"
$startMarker = "<!-- BEGIN AUTO-GENERATED PROJECT FACTS -->"
$endMarker = "<!-- END AUTO-GENERATED PROJECT FACTS -->"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Get-RepoFiles {
  param([string]$RelativePath)

  $target = Join-Path $repoRoot $RelativePath
  if (-not (Test-Path -LiteralPath $target)) {
    return @()
  }

  if (Get-Command rg -ErrorAction SilentlyContinue) {
    return @(& rg --files $target `
      -g "!**/.git/**" `
      -g "!**/.dart_tool/**" `
      -g "!**/build/**" `
      -g "!**/node_modules/**" `
      -g "!**/.firebase/**")
  }

  return @(Get-ChildItem -LiteralPath $target -File -Recurse | Where-Object {
      $_.FullName -notmatch "[\\/](\.git|\.dart_tool|build|node_modules|\.firebase)[\\/]"
    } | ForEach-Object FullName)
}

function Get-MatchCount {
  param(
    [string[]]$Paths,
    [string]$Pattern
  )

  $count = 0
  foreach ($path in $Paths) {
    if (Test-Path -LiteralPath $path) {
      $count += @(Select-String -LiteralPath $path -Pattern $Pattern).Count
    }
  }
  return $count
}

function Get-PubspecFacts {
  param([string]$RelativePath)

  $path = Join-Path $repoRoot $RelativePath
  $content = [IO.File]::ReadAllText($path)
  $name = [regex]::Match($content, "(?m)^name:\s*([^\r\n]+)").Groups[1].Value.Trim()
  $sdk = [regex]::Match($content, "(?m)^\s{2}sdk:\s*([^\r\n]+)").Groups[1].Value.Trim()
  return "$name (Dart SDK $sdk)"
}

function Get-GeneratedFacts {
  $resultsFiles = @(Get-RepoFiles "results")
  $importerFiles = @(Get-RepoFiles "eq-importer")
  $eqFiles = @(Get-RepoFiles "eq")
  $scraperFiles = @(Get-RepoFiles "webScraper")
  $aiFiles = @(Get-RepoFiles "AI")

  $dartSources = @($resultsFiles | Where-Object { $_ -match "[\\/]lib[\\/].*\.dart$" })
  $dartTests = @($resultsFiles | Where-Object { $_ -match "[\\/]test[\\/].*_test\.dart$" })
  $jestTests = @($importerFiles | Where-Object { $_ -match "[\\/]__tests__[\\/].*\.test\.js$" })
  $arbFiles = @($resultsFiles | Where-Object { $_ -match "[\\/]lib[\\/]l10n[\\/]app_[^\\/]+\.arb$" })

  $locales = @($arbFiles | ForEach-Object {
      [IO.Path]::GetFileNameWithoutExtension($_).Substring(4)
    } | Sort-Object -Unique)

  $routerPath = Join-Path $repoRoot "results/lib/app/app_router.dart"
  $routerText = [IO.File]::ReadAllText($routerPath)
  $routes = @([regex]::Matches($routerText, "path:\s*'([^']+)'(?=,|\))") |
      ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

  $functionsPath = Join-Path $repoRoot "eq-importer/functions/index.js"
  $functionsText = [IO.File]::ReadAllText($functionsPath)
  $functionExports = @([regex]::Matches($functionsText, "(?m)^exports\.([A-Za-z0-9_]+)\s*=") |
      ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

  $packagePath = Join-Path $repoRoot "eq-importer/functions/package.json"
  $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
  $nodeEngine = $package.engines.node

  $flutterFacts = Get-PubspecFacts "results/pubspec.yaml"
  $eqFacts = Get-PubspecFacts "eq/pubspec.yaml"
  $dartTestCount = Get-MatchCount $dartTests "\b(?:test|testWidgets)\s*\("
  $jestTestCount = Get-MatchCount $jestTests "\btest\s*\("

  $facts = @(
    "## Genererte prosjektfakta",
    "",
    "Denne delen avledes deterministisk fra arbeidsomradet. Oppdater den med ``tools/update-agents.ps1``.",
    "",
    "| Arbeidsomrade | Oppdagede filer | Manifest/runtime |",
    "| --- | ---: | --- |",
    "| ``results/`` | $($resultsFiles.Count) | $flutterFacts |",
    "| ``eq-importer/`` | $($importerFiles.Count) | Node $nodeEngine |",
    "| ``eq/`` | $($eqFiles.Count) | $eqFacts |",
    "| ``webScraper/`` | $($scraperFiles.Count) | Python-prototyper uten manifest |",
    "| ``AI/`` | $($aiFiles.Count) | Referansemateriale |",
    "",
    "- Flutter-kilde: $($dartSources.Count) Dart-filer under ``results/lib``.",
    "- Flutter-tester: $($dartTests.Count) testfiler med $dartTestCount oppdagede ``test``/``testWidgets``-tilfeller.",
    "- Importortester: $($jestTests.Count) Jest-fil med $jestTestCount oppdagede testtilfeller.",
    "- Lokaler: $($locales -join ', ').",
    "- Deklarerte rutesegmenter: $($routes -join ', ').",
    "- Eksporterte Cloud Functions: $($functionExports -join ', ')."
  )

  return ($facts -join [Environment]::NewLine)
}

function Get-UpdatedDocument {
  $document = [IO.File]::ReadAllText($agentsPath)
  $start = $document.IndexOf($startMarker, [StringComparison]::Ordinal)
  $end = $document.IndexOf($endMarker, [StringComparison]::Ordinal)

  if ($start -lt 0 -or $end -lt 0 -or $end -le $start) {
    throw "AGENTS.md mangler gyldige generator-markorer."
  }

  $before = $document.Substring(0, $start + $startMarker.Length)
  $after = $document.Substring($end)
  $facts = Get-GeneratedFacts
  return $before + [Environment]::NewLine + $facts + [Environment]::NewLine + $after
}

function Update-AgentsDocument {
  $current = [IO.File]::ReadAllText($agentsPath)
  $updated = Get-UpdatedDocument

  if ($current -ceq $updated) {
    return $false
  }

  if ($Check) {
    throw "AGENTS.md er utdatert. Kjor tools/update-agents.ps1."
  }

  [IO.File]::WriteAllText($agentsPath, $updated, $utf8NoBom)
  Write-Host "Oppdaterte AGENTS.md"
  return $true
}

function Test-RelevantChange {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }
  if ($Path -eq $agentsPath) {
    return $false
  }
  if ($Path -match "[\\/](\.git|\.dart_tool|build|node_modules|\.firebase)[\\/]") {
    return $false
  }
  return $true
}

Update-AgentsDocument | Out-Null

if (-not $Watch) {
  exit 0
}

Write-Host "Overvaker $repoRoot. Avslutt med Ctrl+C."
$watcher = New-Object IO.FileSystemWatcher $repoRoot, "*"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$sourceIds = @(
  "EqAgentsChanged-$PID",
  "EqAgentsCreated-$PID",
  "EqAgentsDeleted-$PID",
  "EqAgentsRenamed-$PID"
)

try {
  Register-ObjectEvent $watcher Changed -SourceIdentifier $sourceIds[0] | Out-Null
  Register-ObjectEvent $watcher Created -SourceIdentifier $sourceIds[1] | Out-Null
  Register-ObjectEvent $watcher Deleted -SourceIdentifier $sourceIds[2] | Out-Null
  Register-ObjectEvent $watcher Renamed -SourceIdentifier $sourceIds[3] | Out-Null
  $watcher.EnableRaisingEvents = $true

  while ($true) {
    $event = Wait-Event -Timeout 2
    if ($null -eq $event) {
      continue
    }

    $relevant = Test-RelevantChange $event.SourceEventArgs.FullPath
    Remove-Event -EventIdentifier $event.EventIdentifier
    foreach ($next in @(Get-Event)) {
      if (Test-RelevantChange $next.SourceEventArgs.FullPath) {
        $relevant = $true
      }
      Remove-Event -EventIdentifier $next.EventIdentifier
    }

    if ($relevant) {
      Start-Sleep -Milliseconds 300
      Update-AgentsDocument | Out-Null
    }
  }
}
finally {
  $watcher.EnableRaisingEvents = $false
  foreach ($sourceId in $sourceIds) {
    Unregister-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue
  }
  $watcher.Dispose()
}
