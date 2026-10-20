# Same deterministic implementation as Bash; never ask the LLM to restore template keys.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true,Position=0)][ValidateSet('take','apply','render','show')][string]$Command,
  [Parameter(Mandatory=$true,Position=1)][string]$PlanOrVideoAdId,
  [Parameter(Position=2)][string]$EditsPath,
  [Alias('dest')][string]$Destination
)
$ErrorActionPreference='Stop'
$previousEncoding=[Console]::OutputEncoding
try {
  [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
  $arguments=@($Command,$PlanOrVideoAdId)
  if ($EditsPath) { $arguments += $EditsPath }
  if ($Destination) { $arguments += @('--dest',$Destination) }
  & node (Join-Path $PSScriptRoot 'script_plan.mjs') @arguments
  $result=$LASTEXITCODE
} finally { [Console]::OutputEncoding=$previousEncoding }
exit $result
