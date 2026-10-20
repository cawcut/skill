# Same implementation as Bash: wait for display -> script table -> entity images.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true,Position=0)][string]$VideoAdId,
  [Alias('dest')][string]$Destination,
  [int]$Timeout = 3600,
  [ValidateSet('display','ready')][string]$Until = 'display'
)
$ErrorActionPreference='Stop'
$previousEncoding=[Console]::OutputEncoding
try {
  [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
  $arguments=@((Join-Path $PSScriptRoot 'storyboard_review.mjs'),$VideoAdId,'--timeout',"$Timeout",'--until',$Until)
  if ($Destination) { $arguments += @('--dest',$Destination) }
  & node @arguments
  $result=$LASTEXITCODE
} finally { [Console]::OutputEncoding=$previousEncoding }
exit $result
