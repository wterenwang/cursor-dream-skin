[CmdletBinding()]
param(
  [int]$Port = 9666,
  [string]$ThemeDir,
  [string]$Theme,
  [switch]$RestartExisting,
  [switch]$PromptRestart,
  [switch]$ForegroundInjector
)

$ErrorActionPreference = 'Stop'
$PortExplicit = $PSBoundParameters.ContainsKey('Port')
try {
  . (Join-Path $PSScriptRoot 'common-windows.ps1')

  Write-Host 'Cursor Dream Skin - starting...' -ForegroundColor Cyan
  Assert-CdsPort -Port $Port
  $cursorExe = Find-CdsCursorExe
  Write-Host "Cursor: $cursorExe"

  $runner = Get-CdsNodeRunner
  Write-Host "Node runtime: $($runner.Kind) ($($runner.Exe))"

  if ($ThemeDir) {
    $resolvedTheme = Resolve-CdsThemeDir -ThemeArg $ThemeDir
  } elseif ($Theme) {
    $resolvedTheme = Resolve-CdsThemeDir -ThemeArg $Theme
  } else {
    $resolvedTheme = Resolve-CdsThemeDir -ThemeArg (Get-CdsActiveThemeDir)
  }
  Set-CdsActiveTheme -ThemeDir $resolvedTheme
  Write-Host "Theme: $resolvedTheme"

  Write-Host 'Validating theme payload...'
  $check = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--check-payload', '--theme-dir', $resolvedTheme
  ) -PassThru
  if ($check.ExitCode -ne 0) {
    Write-Host $check.StdErr
    Write-CdsFail "Theme payload validation failed for $resolvedTheme"
  }
  Write-Host 'Payload OK.'

  if (-not $PortExplicit) {
    $state = Read-CdsState
    if ($state -and $state.port) { $Port = [int]$state.port }
  }

  Write-Host "Checking CDP on port $Port..."
  $debugReady = Test-CdsVerifiedCdpEndpoint -Port $Port
  $cursorRunning = Test-CdsCursorRunning
  Write-Host "Cursor running: $cursorRunning | CDP ready: $debugReady"

  if ($cursorRunning -and -not $debugReady) {
    if ($PromptRestart -and -not $RestartExisting) {
      if (-not (Confirm-CdsRestartDialog)) {
        Write-CdsFail 'Theme launch was cancelled by the user.'
      }
      $RestartExisting = $true
    }
    if (-not $RestartExisting) {
      Write-CdsFail 'Cursor is already running without the skin CDP endpoint. Pass -RestartExisting (or -PromptRestart), or close Cursor first.'
    }
    Write-Host 'Restarting Cursor to enable Dream Skin CDP...'
    Stop-CdsCursor -Force
    $debugReady = $false
  }

  if (-not $debugReady) {
    $Port = Select-CdsAvailablePort -StartPort $Port
    Write-Host "Launching Cursor with skin debug port $Port..."
    Start-CdsCursorWithCdp -Port $Port
    if (-not (Wait-CdsCdp -Port $Port -TimeoutSec 60)) {
      Write-CdsFail "Cursor did not expose a loopback CDP endpoint on port $Port within 60 seconds. See $script:CdsAppLog"
    }
  }

  Write-Host 'Starting injector daemon...'
  Stop-CdsRecordedInjector
  Stop-CdsStrayInjectors
  if (Test-Path -LiteralPath $script:CdsStatePath) {
    Remove-Item -LiteralPath $script:CdsStatePath -Force
  }

  if ($ForegroundInjector) {
    Write-Host 'Running injector in foreground (Ctrl+C to stop)...'
    & $runner.Exe @(
      $script:CdsInjector, '--watch', '--port', "$Port", '--theme-dir', $resolvedTheme
    )
    return
  }

  $injectorPid = Start-CdsInjectorDaemon -Port $Port -ThemeDir $resolvedTheme
  $startedAt = (Get-Process -Id $injectorPid -ErrorAction SilentlyContinue).StartTime.ToString('o')
  if (-not $startedAt) { $startedAt = (Get-Date).ToUniversalTime().ToString('o') }
  Write-CdsState -Port $Port -InjectorPid $injectorPid -InjectorStartedAt $startedAt -ThemeDir $resolvedTheme
  Write-Host "Injector PID: $injectorPid"

  Write-Host 'Verifying injection...'
  $verify = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--verify', '--port', "$Port",
    '--theme-dir', $resolvedTheme, '--timeout-ms', '20000'
  ) -PassThru

  $themeName = Split-Path -Leaf $resolvedTheme
  if ($verify.ExitCode -eq 0) {
    Write-Host "Cursor Dream Skin $($script:CdsSkinVersion) is active on loopback port $Port (theme: $themeName)." -ForegroundColor Green
  } elseif ($verify.StdOut -match '"installed"\s*:\s*true') {
    Write-Host "Cursor Dream Skin $($script:CdsSkinVersion) active (soft verify) on port $Port, theme $themeName." -ForegroundColor Green
  } else {
    Stop-CdsRecordedInjector
    if (Test-Path -LiteralPath $script:CdsStatePath) {
      Remove-Item -LiteralPath $script:CdsStatePath -Force
    }
    Write-Host $verify.StdOut
    Write-Host $verify.StdErr
    Write-CdsFail "Injection verification failed; the injector was stopped. See $script:CdsInjectorErrorLog"
  }

  Write-Host ''
  Write-Host 'Done. Press Enter to close...'
  $null = Read-Host
} catch {
  Write-Host ''
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.ScriptStackTrace) { Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray }
  Write-Host ''
  Write-Host 'Failed. Press Enter to close...'
  $null = Read-Host
  exit 1
}
