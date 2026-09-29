# Download Ad Video media on Windows PowerShell. Equivalent of download_media.sh.
# Usage:
#   powershell -ExecutionPolicy Bypass -File download_media.ps1 <video_ad_id> [-Kind product|storyboard|video|all] [-Destination <dir>]
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$VideoAdId,
  [ValidateSet('product', 'storyboard', 'video', 'all')][string]$Kind = 'all',
  [Parameter(Position = 1)][string]$Destination
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
# so the garble is used as if it were correct (product names, folder slugs).
# Pin the decoder to UTF-8 for the call, then restore it: this script's own
# output must keep following the console's own encoding.
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
    # preference, so confine the required compatibility relaxation to this call.
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
    [Console]::Error.WriteLine("detail output not parseable (id=$VideoAdId)")
    exit 4
  }
}

function Get-Value([object]$Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Get-Slug([string]$Text, [string]$Fallback) {
  $slug = ($Text -replace '[^A-Za-z0-9_-]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) { return $Fallback }
  return $slug.Substring(0, [math]::Min($slug.Length, 60))
}

function Get-Extension([string]$Url, [string]$Default) {
  if ([string]::IsNullOrWhiteSpace($Url)) { return $Default }
  $path = ($Url -split '\?')[0]
  $extension = [IO.Path]::GetExtension($path).TrimStart('.').ToLowerInvariant()
  if ($extension -in @('png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'mov', 'webm')) { return $extension }
  return $Default
}

$detail = Get-Detail
$name = [string](Get-Value (Get-Value $detail 'product_info') 'name')
if ([string]::IsNullOrWhiteSpace($Destination)) {
  $Destination = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('Downloads\ad-video-' + (Get-Slug $name $VideoAdId))
}
$productDir = Join-Path $Destination 'product'
$storyboardDir = Join-Path $Destination 'storyboard'
New-Item -ItemType Directory -Force -Path $productDir, $storyboardDir | Out-Null

$saved = 0
function Save-Media([string]$Url, [string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Url)) { return }
  try {
    Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing
    Write-Output $Path
    $script:saved++
  } catch {
    [Console]::Error.WriteLine("download failed: $Url")
  }
}

function Get-Urls([object]$Value) {
  if ($null -eq $Value) { return @() }
  $urls = New-Object System.Collections.Generic.List[string]
  function Visit([object]$Item) {
    if ($null -eq $Item) { return }
    if ($Item -is [System.Collections.IEnumerable] -and $Item -isnot [string]) {
      foreach ($child in $Item) { Visit $child }
      return
    }
    $url = Get-Value $Item 'url'
    if ($url -and ([string]$url).StartsWith('http')) { $urls.Add([string]$url) }
    foreach ($property in $Item.PSObject.Properties) {
      if ($property.Name -ne 'url') { Visit $property.Value }
    }
  }
  Visit $Value
  return @($urls | Select-Object -Unique)
}

if ($Kind -in @('all', 'product')) {
  $product = Get-Value $detail 'product_info'
  $entries = @()
  $logo = Get-Value $product 'logo'
  if (Get-Value $logo 'url') { $entries += @{ tag = 'logo'; url = [string](Get-Value $logo 'url') } }
  foreach ($pair in @(@{ tag = 'logo'; items = (Get-Value $product 'logo_images') }, @{ tag = 'primary'; items = (Get-Value $product 'primary_images') }, @{ tag = 'image'; items = (Get-Value $product 'images') })) {
    $index = 0
    foreach ($item in @($pair.items)) {
      $index++
      $url = [string](Get-Value $item 'url')
      if ($url) { $entries += @{ tag = ('{0}-{1}' -f $pair.tag, $index); url = $url } }
    }
  }
  $seen = @{}
  foreach ($entry in $entries) {
    if ($seen[$entry.url]) { continue }
    $seen[$entry.url] = $true
    Save-Media $entry.url (Join-Path $productDir ('{0}.{1}' -f $entry.tag, (Get-Extension $entry.url 'png')))
  }
}

if ($Kind -in @('all', 'storyboard')) {
  $outputs = Get-Value $detail 'outputs'
  foreach ($pair in @(@{ tag = 'sketch'; value = (Get-Value (Get-Value $outputs 'storyboard_sketch') 'value') }, @{ tag = 'panels'; value = (Get-Value (Get-Value $outputs 'storyboard_image') 'value') })) {
    $index = 0
    foreach ($url in (Get-Urls $pair.value)) {
      $index++
      Save-Media $url (Join-Path $storyboardDir ('{0}-{1}.{2}' -f $pair.tag, $index, (Get-Extension $url 'png')))
    }
  }
}

if ($Kind -in @('all', 'video')) {
  $outputs = Get-Value $detail 'outputs'
  $url = $null
  foreach ($key in @('final_video', 'voiceover_final_video', 'talking_video')) {
    # Capture pipeline output as an array even when it contains only one URL.
    $candidates = @(Get-Urls (Get-Value (Get-Value $outputs $key) 'value'))
    if ($candidates.Count -gt 0) { $url = $candidates[0]; break }
  }
  if ($url) { Save-Media $url (Join-Path $Destination ((Get-Slug $name $VideoAdId) + '_ad_video.' + (Get-Extension $url 'mp4'))) }
}

if ($saved -eq 0) {
  [Console]::Error.WriteLine("nothing to download yet (kind=$Kind, id=$VideoAdId) - media appears as stages complete")
  exit 5
}
[Console]::Error.WriteLine("$saved file(s) saved under $Destination")
