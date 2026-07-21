[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)]
  [string]$Theme,
  [int]$Port
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$null = Find-CdsCursorExe
$themeDir = Resolve-CdsThemeDir -ThemeArg $Theme

$check = Invoke-CdsNode -ArgumentList @(
  $script:CdsInjector, '--check-payload', '--theme-dir', $themeDir
) -PassThru
if ($check.ExitCode -ne 0) {
  Write-Host $check.StdErr
  Write-CdsFail "Theme payload validation failed for $themeDir"
}

Set-CdsActiveTheme -ThemeDir $themeDir

$resolvedPort = $Port
if (-not $resolvedPort) {
  $state = Read-CdsState
  if ($state -and $state.port) { $resolvedPort = [int]$state.port }
}
if (-not $resolvedPort) { $resolvedPort = $script:CdsDefaultPort }

if (-not (Test-CdsCdpHttpReady -Port $resolvedPort)) {
  Write-Host "Theme `"$(Split-Path -Leaf $themeDir)`" recorded. No live skin session on port $resolvedPort — it will apply on the next start-dream-skin.ps1."
  Sync-CdsDeskPetForTheme -ThemeDir $themeDir
  exit 0
}

if (-not (Test-CdsPortBelongsToCursor -Port $resolvedPort)) {
  Write-CdsFail "Port $resolvedPort is not owned by Cursor; refusing to touch it."
}

Stop-CdsRecordedInjector
Stop-CdsStrayInjectors
$injectorPid = Start-CdsInjectorDaemon -Port $resolvedPort -ThemeDir $themeDir
$startedAt = (Get-Process -Id $injectorPid -ErrorAction SilentlyContinue).StartTime.ToString('o')
if (-not $startedAt) { $startedAt = (Get-Date).ToUniversalTime().ToString('o') }
Write-CdsState -Port $resolvedPort -InjectorPid $injectorPid -InjectorStartedAt $startedAt -ThemeDir $themeDir

$null = Invoke-CdsNode -ArgumentList @(
  $script:CdsInjector, '--once', '--port', "$resolvedPort",
  '--theme-dir', $themeDir, '--timeout-ms', '15000'
) -PassThru

$verify = Invoke-CdsNode -ArgumentList @(
  $script:CdsInjector, '--verify', '--port', "$resolvedPort",
  '--theme-dir', $themeDir, '--timeout-ms', '10000'
) -PassThru

$name = Split-Path -Leaf $themeDir
if ($verify.ExitCode -eq 0) {
  Write-Host "Theme switched to `"$name`" (hot, no restart)."
} else {
  Write-Host "Theme `"$name`" injected but verification was soft; check verify-dream-skin.ps1 if it looks off."
}

Sync-CdsDeskPetForTheme -ThemeDir $themeDir
