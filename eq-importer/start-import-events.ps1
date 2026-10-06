param(
  [int[]]$EventIds = @(69431, 74685, 74689, 74695, 74696, 79179, 80088, 80092, 80093, 81337, 81792, 83078),
  [int]$ClassCount = 1,
  [string]$Uri = "https://europe-west1-time-plotting.cloudfunctions.net/startImportEvent"
)

$results = @()
$identityToken = (& gcloud auth print-identity-token "--audiences=$Uri").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($identityToken)) {
  throw "Kunne ikke hente Google identity token. Kjør 'gcloud auth login' først."
}
$headers = @{ Authorization = "Bearer $identityToken" }

foreach ($eventId in $EventIds) {
  $body = @{
    eventId = $eventId
    classCount = $ClassCount
  } | ConvertTo-Json -Compress

  try {
    $start = Invoke-RestMethod -Method Post `
      -Uri $Uri `
      -Headers $headers `
      -ContentType "application/json" `
      -Body $body

    $results += [PSCustomObject]@{
      EventId = $eventId
      Ok = $start.ok
      JobId = $start.jobId
      Status = $start.status
    }
  } catch {
    $message = if ($_.Exception.Message) {
      $_.Exception.Message
    } else {
      $_ | Out-String
    }

    $results += [PSCustomObject]@{
      EventId = $eventId
      Ok = $false
      JobId = $null
      Status = $message.Trim()
    }
  }
}

$results | Format-Table -AutoSize
