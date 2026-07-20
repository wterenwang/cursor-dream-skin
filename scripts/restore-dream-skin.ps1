[CmdletBinding()]
param(
  [int]$Port
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$null = Find-CdsCursorExe

$resolvedPort = $Port
if (-not $resolvedPort) {
  $state = Read-CdsState
  if ($state -and $state.port) { $resolvedPort = [int]$state.port }
}

Stop-CdsRecordedInjector
Stop-CdsStrayInjectors

$removed = 'skipped (no CDP endpoint)'
if ($resolvedPort -and (Test-CdsCdpHttpReady -Port $resolvedPort)) {
  $result = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--remove', '--port', "$resolvedPort", '--timeout-ms', '10000'
  ) -PassThru
  if ($result.ExitCode -eq 0) {
    $removed = 'removed from live windows'
  } else {
    $removed = 'removal reported issues (windows may need a reload)'
  }
}

if (Test-Path -LiteralPath $script:CdsStatePath) {
  Remove-Item -LiteralPath $script:CdsStatePath -Force
}

Write-Host "Cursor Dream Skin restored: injector stopped, skin $removed, state cleared."
Write-Host 'Note: Cursor is still running with a loopback CDP port until you restart it normally.'
