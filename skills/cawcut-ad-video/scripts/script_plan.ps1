# Ad Video storyboard working-copy and review-table helper for Windows PowerShell.
# Equivalent of script_plan.sh. Prompts stay in the plan and are submitted, but
# are intentionally omitted from rendered review tables.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File script_plan.ps1 take <video_ad_id> [-Destination <dir>]
#   powershell -ExecutionPolicy Bypass -File script_plan.ps1 apply <plan.json> <edits.json>
#   powershell -ExecutionPolicy Bypass -File script_plan.ps1 render <plan.json>
#   powershell -ExecutionPolicy Bypass -File script_plan.ps1 show <plan.json> <edits.json>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][ValidateSet('take', 'apply', 'render', 'show')][string]$Command,
  [Parameter(Mandatory = $true, Position = 1)][string]$PlanOrVideoAdId,
  [Parameter(Position = 2)][string]$EditsPath,
  [Alias('dest')][string]$Destination
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
$editableFields = @('duration', 'shot_type', 'shot_description', 'dialogue', 'camera', 'light', 'sfx', 'shot_prompt', 'video_prompt')

function Fail([string]$Message) { [Console]::Error.WriteLine($Message); exit 2 }
function Get-PropertyValue([object]$Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Set-PropertyValue([object]$Object, [string]$Name, [object]$Value) {
  $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
}
# Read the CLI's stdout, decoding its UTF-8 bytes explicitly.
#
# Windows PowerShell decodes a native command's stdout with
# [Console]::OutputEncoding - the console code page, not UTF-8 - while the CLI
# writes UTF-8 and Node does not re-encode it for a pipe. On a non-UTF-8 console
# that turns zh-CN text into mojibake while leaving the JSON structurally valid,
# so `take` would write a plausible-looking but corrupted working copy. Pin the
# decoder to UTF-8 for the call, then restore it: this script's own output must
# keep following the console's own encoding.
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
    # Native stderr redirection becomes an ErrorRecord under the Stop
    # preference, so constrain the compatibility relaxation to this CLI call.
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

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "no such file: $Path" }
  # Windows PowerShell 5.1 falls back to the active ANSI code page for a
  # BOM-less file. Write-Json intentionally emits BOM-less UTF-8, so decoding
  # must be explicit or zh-CN scripts become invalid JSON on GBK machines.
  try { return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { Fail "invalid JSON: $Path" }
}
function Write-Json([object]$Value, [string]$Path) {
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
}
function Get-Slug([string]$Text, [string]$Fallback) {
  $slug = ($Text -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) { return $Fallback }
  return $slug.Substring(0, [math]::Min($slug.Length, 60))
}
function Format-Cell([object]$Value) {
  return (([string]$Value) -replace '\\r?\\n|\r?\n', '<br>' -replace '\|', '\\|').Trim()
}
function Get-Columns([string]$PlanPath) {
  $parent = Split-Path -Parent $PlanPath
  if ([string]::IsNullOrWhiteSpace($parent)) { $parent = '.' }
  $meta = Join-Path $parent 'script.meta.json'
  $videoType = ''
  if (Test-Path -LiteralPath $meta) { $videoType = [string](Get-PropertyValue (Read-Json $meta) 'video_type') }
  if ($videoType -eq 'product_showcase') {
    return @(@('shot_no', 'Shot #'), @('duration', 'Duration'), @('shot_type', 'Shot Type'), @('shot_description', 'Shot Description'), @('camera', 'Camera'), @('light', 'Light'), @('sfx', 'SFX'))
  }
  return @(@('shot_no', 'Shot #'), @('duration', 'Duration'), @('shot_type', 'Shot Type'), @('shot_description', 'Shot Description'), @('dialogue', 'Voiceover'), @('camera', 'Camera'), @('light', 'Light'), @('sfx', 'SFX'))
}
function Render-Plan([string]$PlanPath) {
  $plan = Read-Json $PlanPath
  $shots = @(Get-PropertyValue $plan 'shots')
  if ($shots.Count -eq 0) { Fail 'the plan has no shots array - is the storyboard generated yet?' }
  $title = Format-Cell (Get-PropertyValue $plan 'title')
  $synopsis = Format-Cell (Get-PropertyValue $plan 'synopsis')
  Write-Output "**$title**"
  if ($synopsis) { Write-Output "`n$synopsis" }
  $columns = Get-Columns $PlanPath
  Write-Output ''
  Write-Output ('| ' + (($columns | ForEach-Object { $_[1] }) -join ' | ') + ' |')
  Write-Output ('| ' + (($columns | ForEach-Object { '---' }) -join ' | ') + ' |')
  foreach ($shot in $shots) {
    $cells = foreach ($column in $columns) { Format-Cell (Get-PropertyValue $shot $column[0]) }
    Write-Output ('| ' + ($cells -join ' | ') + ' |')
  }
}

switch ($Command) {
  'take' {
    $id = $PlanOrVideoAdId
    try {
      $detail = ((Get-CawcutJson @('ad-video', 'detail', $id, '--json')) | ConvertFrom-Json)
    } catch { [Console]::Error.WriteLine("detail output not parseable (id=$id)"); exit 4 }
    $value = Get-PropertyValue (Get-PropertyValue $detail 'outputs') 'storyboard_plan'
    $plan = Get-PropertyValue $value 'value'
    if ($null -eq $plan -or @((Get-PropertyValue $plan 'shots')).Count -eq 0) { [Console]::Error.WriteLine('the plan has no shots array - is the storyboard generated yet?'); exit 5 }
    if ([string]::IsNullOrWhiteSpace($Destination)) {
      $name = [string](Get-PropertyValue (Get-PropertyValue $detail 'product_info') 'name')
      $Destination = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('Downloads\ad-video-' + (Get-Slug $name $id))
    }
    $storyboardDir = Join-Path $Destination 'storyboard'
    New-Item -ItemType Directory -Force -Path $storyboardDir | Out-Null
    $planPath = Join-Path $storyboardDir 'script.json'
    $metaPath = Join-Path $storyboardDir 'script.meta.json'
    Write-Json $plan $planPath
    $meta = [pscustomobject]@{ video_type = [string](Get-PropertyValue (Get-PropertyValue (Get-PropertyValue $detail 'product_info') 'video_settings') 'video_type'); revision = (Get-PropertyValue $plan 'revision'); title = [string](Get-PropertyValue $plan 'title') }
    Write-Json $meta $metaPath
    Write-Output "plan: $planPath"
    Write-Output "meta: $metaPath"
  }
  'apply' {
    if ([string]::IsNullOrWhiteSpace($EditsPath)) { Fail 'missing edits.json' }
    $plan = Read-Json $PlanOrVideoAdId
    $edits = Read-Json $EditsPath
    foreach ($entry in $edits.PSObject.Properties) {
      if ($entry.Name -in @('title', 'synopsis')) { Set-PropertyValue $plan $entry.Name $entry.Value; Write-Output $entry.Name; continue }
      if (-not $entry.Name.StartsWith('shot-')) { Fail "unknown key in edits: $($entry.Name)" }
      $shot = @((Get-PropertyValue $plan 'shots') | Where-Object { [string](Get-PropertyValue $_ 'shot_id') -eq $entry.Name }) | Select-Object -First 1
      if ($null -eq $shot) { Fail "unknown shot in edits: $($entry.Name)" }
      foreach ($field in $entry.Value.PSObject.Properties) {
        if ($field.Name -notin $editableFields) { Fail "field not editable: $($entry.Name).$($field.Name)" }
        Set-PropertyValue $shot $field.Name $field.Value
      }
      Write-Output ('{0}: {1}' -f $entry.Name, (($entry.Value.PSObject.Properties.Name) -join ', '))
    }
    Write-Json $plan $PlanOrVideoAdId
  }
  'render' { Render-Plan $PlanOrVideoAdId }
  'show' {
    if ([string]::IsNullOrWhiteSpace($EditsPath)) { Fail 'missing edits.json' }
    & $PSCommandPath apply $PlanOrVideoAdId $EditsPath
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Render-Plan $PlanOrVideoAdId
  }
}
