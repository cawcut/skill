# Poll a CawCut Ad Video project's detail endpoint until a stage reaches a
# terminal state. Windows PowerShell equivalent of poll.sh.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File poll.ps1 <video_ad_id> <json_path> <success_value> <timeout_s> [interval_s]
#
# json_path supports the paths used by this Skill, including `//` fallbacks.
# Exit codes: 0 = success | 2 = failed | 3 = timeout | 4 = unreadable detail.
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$VideoAdId,
  [Parameter(Mandatory = $true, Position = 1)][string]$JsonPath,
  [Parameter(Mandatory = $true, Position = 2)][string]$SuccessValue,
  [Parameter(Mandatory = $true, Position = 3)][int]$TimeoutSeconds,
  [Parameter(Position = 4)][int]$IntervalSeconds = 30
)

$ErrorActionPreference = 'Stop'

# A program reading this script's output through a pipe (an agent, a redirect
# into a file) expects UTF-8; a person at a console expects whatever that
# console uses. Pin UTF-8 only in the piped case, so a legacy code page console
# keeps its own encoding - and so nothing this script prints is replaced by "?"
# on the way out.
if ([Console]::IsOutputRedirected) {
  try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
}

# Read the CLI's stdout, decoding its UTF-8 bytes explicitly.
#
# Windows PowerShell decodes a native command's stdout with
# [Console]::OutputEncoding - the console code page, not UTF-8 - while the CLI
# writes UTF-8 and Node does not re-encode it for a pipe. On a non-UTF-8 console
# that turns zh-CN text into mojibake while leaving the JSON structurally valid,
# so the garble is written to disk as if it were correct. Pin the decoder to
# UTF-8 for the call, then restore it: this script's own output must keep
# following the console's own encoding.
function Get-CawcutJson {
  param([string[]]$Arguments)

  $previousPreference = $ErrorActionPreference
  $previousOutputEncoding = $null
  try {
    try { $previousOutputEncoding = [Console]::OutputEncoding } catch { }
    try {
      # The setter also switches the console output code page; a host with no
      # console at all throws here, and the output decodes as it did before.
      [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    } catch { }
    # PowerShell turns native stderr redirection into an ErrorRecord; relax the
    # preference around this call so CLI progress cannot terminate polling.
    $ErrorActionPreference = 'Continue'
    $raw = & cawcut @Arguments 2>$null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
    if ($null -ne $previousOutputEncoding) {
      try { [Console]::OutputEncoding = $previousOutputEncoding } catch { }
    }
  }

  if ($exitCode -ne 0) { throw "cawcut exited $exitCode" }
  $text = $raw -join "`n"
  if ([string]::IsNullOrWhiteSpace($text)) { throw 'empty output' }
  return $text
}

function Get-Detail {
  try {
    return ((Get-CawcutJson @('ad-video', 'detail', $VideoAdId, '--json')) | ConvertFrom-Json)
  } catch {
    [Console]::Error.WriteLine("detail output not parseable (id=$VideoAdId) - inspect: cawcut ad-video detail $VideoAdId --json")
    exit 4
  }
}

function Get-PropertyValue([object]$Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Get-PathValue([object]$Detail, [string]$Path) {
  foreach ($candidate in ($Path -split '\s*//\s*')) {
    $value = $Detail
    $segments = $candidate.Trim() -replace '^\.', '' -split '\.'
    foreach ($segment in $segments) {
      $value = Get-PropertyValue $value $segment
      if ($null -eq $value) { break }
    }
    if ($null -ne $value -and [string]$value -ne '') { return $value }
  }
  return 'pending'
}

$started = Get-Date
$firstTick = $true
while ($true) {
  $detail = Get-Detail
  $status = [string](Get-PathValue $detail $JsonPath)
  Write-Output ('[{0}] {1} = {2}' -f (Get-Date -Format 'HH:mm:ss'), $JsonPath, $status)

  if ($firstTick) {
    $firstTick = $false
    $estimate = Get-PropertyValue $detail 'estimated_running_ms'
    if ($estimate -as [long]) {
      $milliseconds = [long]$estimate
      if ($milliseconds -lt 60000) { Write-Output ('   estimated: about {0}s' -f [math]::Ceiling($milliseconds / 1000)) }
      elseif ($milliseconds -lt 3600000) { Write-Output ('   estimated: about {0}m' -f [math]::Ceiling($milliseconds / 60000)) }
      else { Write-Output ('   estimated: about {0}h' -f [math]::Ceiling($milliseconds / 3600000)) }
    }
  }

  if ($status -eq $SuccessValue) { exit 0 }
  if ($status -eq 'failed') {
    [Console]::Error.WriteLine("stage failed - read the error: cawcut ad-video detail $VideoAdId --json")
    exit 2
  }
  if (((Get-Date) - $started).TotalSeconds -ge $TimeoutSeconds) {
    [Console]::Error.WriteLine("timed out after ${TimeoutSeconds}s (id=$VideoAdId)")
    exit 3
  }
  Start-Sleep -Seconds $IntervalSeconds
}
