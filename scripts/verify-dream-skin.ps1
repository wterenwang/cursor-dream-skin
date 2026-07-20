[CmdletBinding()]
param(
  [int]$Port,
  [string]$Screenshot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$null = Find-CdsCursorExe

$resolvedPort = $Port
$themeDir = Get-CdsActiveThemeDir
$state = Read-CdsState
if (-not $resolvedPort -and $state -and $state.port) { $resolvedPort = [int]$state.port }
if (-not $resolvedPort) { $resolvedPort = $script:CdsDefaultPort }
if ($state -and $state.themeDir) { $themeDir = $state.themeDir }

$args = @(
  $script:CdsInjector, '--verify', '--port', "$resolvedPort",
  '--theme-dir', $themeDir, '--timeout-ms', '15000'
)
if ($Screenshot) {
  $args += @('--screenshot', $Screenshot)
}

$result = Invoke-CdsNode -ArgumentList $args -PassThru
if ($result.StdOut) { Write-Host $result.StdOut }
if ($result.StdErr) { Write-Host $result.StdErr }
exit $result.ExitCode
