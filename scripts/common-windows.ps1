# Cursor Dream Skin — shared Windows helpers.
# Inspired by Fei-Away/Codex-Dream-Skin (Windows) and KinGao294/cursor-dream-skin (Cursor CDP).

$ErrorActionPreference = 'Stop'

$script:CdsProjectRoot = Split-Path -Parent $PSScriptRoot
$script:CdsInjector = Join-Path $PSScriptRoot 'injector.mjs'
$script:CdsStateRoot = Join-Path $env:LOCALAPPDATA 'CursorDreamSkin'
$script:CdsStatePath = Join-Path $script:CdsStateRoot 'state.json'
$script:CdsActiveThemePath = Join-Path $script:CdsStateRoot 'active-theme.txt'
$script:CdsInjectorLog = Join-Path $script:CdsStateRoot 'injector.log'
$script:CdsInjectorErrorLog = Join-Path $script:CdsStateRoot 'injector-error.log'
$script:CdsAppLog = Join-Path $script:CdsStateRoot 'cursor-launch.log'
$script:CdsDefaultPort = 9666
$script:CdsSkinVersion = '1.1.0-win'
$script:CdsCursorExeFile = Join-Path $script:CdsStateRoot 'cursor-exe.txt'
$script:CdsSetupDoneFile = Join-Path $script:CdsStateRoot 'setup-done.txt'

function Write-CdsFail {
  param([Parameter(Mandatory)][string]$Message)
  throw "Cursor Dream Skin: $Message"
}

function Ensure-CdsStateRoot {
  if (-not (Test-Path -LiteralPath $script:CdsStateRoot)) {
    New-Item -ItemType Directory -Path $script:CdsStateRoot -Force | Out-Null
  }
}

function Test-CdsCursorExePath {
  param([Parameter(Mandatory)][string]$Path)
  if (-not $Path) { return $false }
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $leaf = [IO.Path]::GetFileName($Path)
  return ($leaf -ieq 'Cursor.exe')
}

function Get-CdsSavedCursorExe {
  if (-not (Test-Path -LiteralPath $script:CdsCursorExeFile)) { return $null }
  try {
    $raw = (Get-Content -LiteralPath $script:CdsCursorExeFile -Raw -Encoding UTF8).Trim()
    if ($raw -and (Test-CdsCursorExePath $raw)) { return (Resolve-Path -LiteralPath $raw).Path }
  } catch { }
  return $null
}

function Set-CdsCursorExe {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-CdsCursorExePath $Path)) {
    Write-CdsFail "Not a valid Cursor.exe path: $Path"
  }
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  Ensure-CdsStateRoot
  Set-Content -LiteralPath $script:CdsCursorExeFile -Value $resolved -Encoding UTF8
  $script:CdsCursorExe = $resolved
  $env:CURSOR_EXE = $resolved
  return $resolved
}

function Test-CdsSetupDone {
  return (Test-Path -LiteralPath $script:CdsSetupDoneFile)
}

function Set-CdsSetupDone {
  Ensure-CdsStateRoot
  Set-Content -LiteralPath $script:CdsSetupDoneFile -Value ((Get-Date).ToUniversalTime().ToString('o')) -Encoding ASCII
}

function Find-CdsCursorExeCandidates {
  $candidates = [System.Collections.Generic.List[string]]::new()
  if ($env:CURSOR_EXE) { [void]$candidates.Add($env:CURSOR_EXE) }
  $saved = Get-CdsSavedCursorExe
  if ($saved) { [void]$candidates.Add($saved) }

  @(
    (Join-Path $env:LOCALAPPDATA 'Programs\cursor\Cursor.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Cursor\Cursor.exe'),
    'C:\Program Files\Cursor\Cursor.exe',
    'C:\Program Files (x86)\Cursor\Cursor.exe',
    'D:\cursor\Cursor.exe',
    'E:\cursor\Cursor.exe'
  ) | ForEach-Object { if ($_) { [void]$candidates.Add($_) } }

  $cmd = Get-Command cursor.cmd -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    $binDir = Split-Path -Parent $cmd.Source
    # ...\resources\app\bin\cursor.cmd -> ...\Cursor.exe
    $fromBin = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $binDir))) 'Cursor.exe'
    $candidates.Insert(0, $fromBin)
  }

  return @($candidates)
}

function Resolve-CdsCursorExe {
  <#
    Returns @{ Path; Source } where Source is env|saved|discovered|missing.
    Does not throw.
  #>
  if ($env:CURSOR_EXE -and (Test-CdsCursorExePath $env:CURSOR_EXE)) {
    $p = (Resolve-Path -LiteralPath $env:CURSOR_EXE).Path
    return @{ Path = $p; Source = 'env' }
  }

  $saved = Get-CdsSavedCursorExe
  if ($saved) {
    return @{ Path = $saved; Source = 'saved' }
  }

  foreach ($path in (Find-CdsCursorExeCandidates)) {
    if ($path -and (Test-CdsCursorExePath $path)) {
      return @{ Path = (Resolve-Path -LiteralPath $path).Path; Source = 'discovered' }
    }
  }

  return @{ Path = $null; Source = 'missing' }
}

function Find-CdsCursorExe {
  $hit = Resolve-CdsCursorExe
  if (-not $hit.Path) {
    Write-CdsFail 'Could not find Cursor.exe. Open Dream Skin GUI and pick Cursor.exe, or set CURSOR_EXE.'
  }
  $script:CdsCursorExe = $hit.Path
  return $hit.Path
}

function Try-CdsFindCursorExe {
  $hit = Resolve-CdsCursorExe
  if ($hit.Path) { $script:CdsCursorExe = $hit.Path }
  return $hit
}

function Get-CdsNodeRunner {
  param([string]$CursorExe = $script:CdsCursorExe)

  # Prefer system Node — spawning Cursor.exe as Node while Cursor is open often hangs.
  $nodeCmd = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($nodeCmd -and $nodeCmd.Source) {
    return @{
      Exe  = $nodeCmd.Source
      Env  = @{}
      Kind = 'node'
    }
  }

  if (-not $CursorExe) {
    $hit = Try-CdsFindCursorExe
    $CursorExe = $hit.Path
  }
  if (-not $CursorExe) {
    Write-CdsFail 'Need Node.js (node.exe on PATH) or a valid Cursor.exe to run the injector.'
  }
  $script:CdsCursorExe = $CursorExe

  $helpers = Join-Path (Split-Path -Parent $CursorExe) 'resources\app\resources\helpers\node.exe'
  if (Test-Path -LiteralPath $helpers) {
    return @{
      Exe  = (Resolve-Path -LiteralPath $helpers).Path
      Env  = @{}
      Kind = 'cursor-helper-node'
    }
  }

  return @{
    Exe  = $CursorExe
    Env  = @{ ELECTRON_RUN_AS_NODE = '1' }
    Kind = 'electron'
  }
}

function Invoke-CdsNode {
  param(
    [Parameter(Mandatory)][string[]]$ArgumentList,
    [switch]$PassThru,
    [string]$WorkingDirectory = $script:CdsProjectRoot
  )
  $runner = Get-CdsNodeRunner
  $argLine = ($ArgumentList | ForEach-Object {
      if ($_ -match '[\s"]') { '"{0}"' -f ($_ -replace '"', '\"') } else { $_ }
    }) -join ' '

  # Avoid stdout/stderr ReadToEnd deadlock: capture via cmd redirection to temp files.
  Ensure-CdsStateRoot
  $outFile = Join-Path $script:CdsStateRoot "node-out-$PID.txt"
  $errFile = Join-Path $script:CdsStateRoot "node-err-$PID.txt"
  Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue

  $envPairs = @()
  foreach ($key in $runner.Env.Keys) {
    $envPairs += "set `"$key=$($runner.Env[$key])`""
  }
  $bat = Join-Path $script:CdsStateRoot "node-run-$PID.cmd"
  @(
    '@echo off'
    $envPairs
    "cd /d `"$WorkingDirectory`""
    "`"$($runner.Exe)`" $argLine >`"$outFile`" 2>`"$errFile`""
    'exit /b %ERRORLEVEL%'
  ) | Set-Content -LiteralPath $bat -Encoding ASCII

  $proc = Start-Process -FilePath $bat -Wait -PassThru -WindowStyle Hidden
  $stdout = if (Test-Path -LiteralPath $outFile) { Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue } else { '' }
  $stderr = if (Test-Path -LiteralPath $errFile) { Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue } else { '' }
  Remove-Item -LiteralPath $bat, $outFile, $errFile -Force -ErrorAction SilentlyContinue

  if ($null -eq $stdout) { $stdout = '' }
  if ($null -eq $stderr) { $stderr = '' }

  if ($PassThru) {
    return [pscustomobject]@{
      ExitCode = $proc.ExitCode
      StdOut   = $stdout
      StdErr   = $stderr
    }
  }
  if ($proc.ExitCode -ne 0) {
    if ($stderr) { Write-Host $stderr -ForegroundColor Red }
    if ($stdout) { Write-Host $stdout }
    throw "Node script failed with exit code $($proc.ExitCode)"
  }
  if ($stdout) { Write-Output $stdout.TrimEnd() }
}

function Assert-CdsPort {
  param([int]$Port)
  if ($Port -lt 1024 -or $Port -gt 65535) {
    Write-CdsFail "Port must be between 1024 and 65535 (got $Port)."
  }
}

function Get-CdsListeningPidsFast {
  param([int]$Port)
  # netstat is much faster/more reliable than Get-NetTCPConnection on many PCs.
  $pids = @()
  $lines = & netstat.exe -ano -p tcp 2>$null
  foreach ($line in $lines) {
    if ($line -match "^\s*TCP\s+127\.0\.0\.1:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$" -or
        $line -match "^\s*TCP\s+\[::1\]:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$" -or
        $line -match "^\s*TCP\s+0\.0\.0\.0:$Port\s+\S+\s+LISTENING\s+(\d+)\s*$") {
      $pids += [int]$Matches[1]
    }
  }
  return @($pids | Select-Object -Unique)
}

function Test-CdsPortAvailable {
  param([int]$Port)
  return ((Get-CdsListeningPidsFast -Port $Port).Count -eq 0)
}

function Select-CdsAvailablePort {
  param([int]$StartPort = $script:CdsDefaultPort)
  $last = [Math]::Min($StartPort + 100, 65535)
  for ($p = $StartPort; $p -le $last; $p++) {
    if (Test-CdsPortAvailable -Port $p) { return $p }
  }
  Write-CdsFail "No free loopback port found between $StartPort and $last."
}

function Get-CdsListenerPids {
  param([int]$Port)
  Get-CdsListeningPidsFast -Port $Port
}

function Test-CdsPortBelongsToCursor {
  param([int]$Port, [string]$CursorExe = $script:CdsCursorExe)
  if (-not $CursorExe) { $CursorExe = Find-CdsCursorExe; $script:CdsCursorExe = $CursorExe }
  $pids = Get-CdsListenerPids -Port $Port
  if ($pids.Count -eq 0) { return $false }
  $cursorName = [IO.Path]::GetFileNameWithoutExtension($CursorExe)
  foreach ($procId in $pids) {
    $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if (-not $proc) { return $false }
    $path = $null
    try { $path = $proc.Path } catch { }
    if ($path) {
      if ((Resolve-Path -LiteralPath $path -ErrorAction SilentlyContinue).Path -ne
          (Resolve-Path -LiteralPath $CursorExe -ErrorAction SilentlyContinue).Path) {
        return $false
      }
    } elseif ($proc.ProcessName -ne $cursorName) {
      return $false
    }
  }
  return $true
}

function Test-CdsCdpHttpReady {
  param([int]$Port)
  try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 2
    return $resp.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Test-CdsVerifiedCdpEndpoint {
  param([int]$Port)
  if (-not (Test-CdsCdpHttpReady -Port $Port)) { return $false }
  return (Test-CdsPortBelongsToCursor -Port $Port)
}

function Wait-CdsCdp {
  param([int]$Port, [int]$TimeoutSec = 45)
  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-CdsVerifiedCdpEndpoint -Port $Port) { return $true }
    Start-Sleep -Milliseconds 400
  }
  return $false
}

function Get-CdsCursorAppProcesses {
  param([string]$CursorExe = $script:CdsCursorExe)
  if (-not $CursorExe) { $CursorExe = Find-CdsCursorExe; $script:CdsCursorExe = $CursorExe }
  $resolved = (Resolve-Path -LiteralPath $CursorExe).Path
  @(Get-CimInstance Win32_Process -Filter "Name='Cursor.exe'" -ErrorAction SilentlyContinue | Where-Object {
      $_.ExecutablePath -and ((Resolve-Path -LiteralPath $_.ExecutablePath -ErrorAction SilentlyContinue).Path -eq $resolved) -and
      ($_.CommandLine -notmatch '--type=') -and
      ($_.CommandLine -notmatch 'injector\.mjs') -and
      ($_.CommandLine -notmatch 'ELECTRON_RUN_AS_NODE')
    })
}

function Test-CdsCursorRunning {
  return ((Get-CdsCursorAppProcesses).Count -gt 0)
}

function Read-CdsState {
  if (-not (Test-Path -LiteralPath $script:CdsStatePath)) { return $null }
  try {
    return Get-Content -LiteralPath $script:CdsStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Write-CdsState {
  param(
    [int]$Port,
    [int]$InjectorPid,
    [string]$InjectorStartedAt,
    [string]$ThemeDir
  )
  Ensure-CdsStateRoot
  $state = [ordered]@{
    schemaVersion     = 1
    skinVersion       = $script:CdsSkinVersion
    port              = $Port
    injectorPid       = $InjectorPid
    injectorStartedAt = $InjectorStartedAt
    injectorPath      = $script:CdsInjector
    themeDir          = $ThemeDir
    cursorExe         = $script:CdsCursorExe
    createdAt         = (Get-Date).ToUniversalTime().ToString('o')
  }
  $tmp = "$script:CdsStatePath.$PID.tmp"
  ($state | ConvertTo-Json -Depth 5) + "`n" | Set-Content -LiteralPath $tmp -Encoding UTF8 -NoNewline
  Move-Item -LiteralPath $tmp -Destination $script:CdsStatePath -Force
}

function Get-CdsActiveThemeDir {
  if (Test-Path -LiteralPath $script:CdsActiveThemePath) {
    $path = (Get-Content -LiteralPath $script:CdsActiveThemePath -Raw -Encoding UTF8).Trim()
    if ($path -and (Test-Path -LiteralPath (Join-Path $path 'theme.json'))) { return $path }
  }
  $default = Join-Path $script:CdsProjectRoot 'themes\default'
  if (Test-Path -LiteralPath (Join-Path $default 'theme.json')) { return $default }
  return $null
}

function Set-CdsActiveTheme {
  param([Parameter(Mandatory)][string]$ThemeDir)
  $resolved = (Resolve-Path -LiteralPath $ThemeDir).Path
  if (-not (Test-Path -LiteralPath (Join-Path $resolved 'theme.json'))) {
    Write-CdsFail "Not a theme directory (theme.json missing): $resolved"
  }
  Ensure-CdsStateRoot
  Set-Content -LiteralPath $script:CdsActiveThemePath -Value $resolved -Encoding UTF8
}

function Resolve-CdsThemeDir {
  param([string]$ThemeArg)
  if (-not $ThemeArg) {
    $active = Get-CdsActiveThemeDir
    if ($active) { return $active }
    Write-CdsFail 'No theme specified and no active theme recorded.'
  }
  if (Test-Path -LiteralPath (Join-Path $ThemeArg 'theme.json')) {
    return (Resolve-Path -LiteralPath $ThemeArg).Path
  }
  $byId = Join-Path $script:CdsProjectRoot "themes\$ThemeArg"
  if (Test-Path -LiteralPath (Join-Path $byId 'theme.json')) {
    return (Resolve-Path -LiteralPath $byId).Path
  }
  Write-CdsFail "Theme not found: $ThemeArg"
}

function Stop-CdsRecordedInjector {
  $state = Read-CdsState
  if (-not $state -or -not $state.injectorPid) { return }
  $injectorPid = [int]$state.injectorPid
  $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$injectorPid" -ErrorAction SilentlyContinue
  if (-not $proc) { return }
  if ($proc.CommandLine -notmatch 'injector\.mjs' -or $proc.CommandLine -notmatch '--watch') { return }
  Stop-Process -Id $injectorPid -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 300
}

function Stop-CdsStrayInjectors {
  $injectorEscaped = [regex]::Escape($script:CdsInjector)
  Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $_.CommandLine -and
      $_.CommandLine -match $injectorEscaped -and
      $_.CommandLine -match '--watch'
    } | ForEach-Object {
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Start-CdsInjectorDaemon {
  param(
    [Parameter(Mandatory)][int]$Port,
    [Parameter(Mandatory)][string]$ThemeDir
  )
  Ensure-CdsStateRoot
  $null = New-Item -ItemType File -Path $script:CdsInjectorLog -Force
  $null = New-Item -ItemType File -Path $script:CdsInjectorErrorLog -Force

  $runner = Get-CdsNodeRunner
  $launcher = Join-Path $script:CdsStateRoot 'run-injector.cmd'
  $exe = $runner.Exe
  $inj = $script:CdsInjector
  $outLog = $script:CdsInjectorLog
  $errLog = $script:CdsInjectorErrorLog
  $envLine = if ($runner.Kind -eq 'electron') { 'set ELECTRON_RUN_AS_NODE=1' } else { 'set ELECTRON_RUN_AS_NODE=' }
  @(
    '@echo off'
    $envLine
    "cd /d `"$($script:CdsProjectRoot)`""
    "`"$exe`" `"$inj`" --watch --port $Port --theme-dir `"$ThemeDir`" >>`"$outLog`" 2>>`"$errLog`""
  ) | Set-Content -LiteralPath $launcher -Encoding ASCII

  $null = Start-Process -FilePath $launcher -WindowStyle Hidden
  Start-Sleep -Milliseconds 900

  $child = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
      $_.CommandLine -and
      $_.CommandLine -match [regex]::Escape($inj) -and
      $_.CommandLine -match '--watch' -and
      $_.CommandLine -match "--port $Port"
    } | Select-Object -First 1

  if ($child) {
    return [int]$child.ProcessId
  }
  Write-CdsFail "The injector exited during startup. See $script:CdsInjectorErrorLog"
}

function Stop-CdsCursor {
  param([switch]$Force)
  $procs = Get-CdsCursorAppProcesses
  if ($procs.Count -eq 0) { return }
  foreach ($p in $procs) {
    try { Stop-Process -Id $p.ProcessId -ErrorAction SilentlyContinue } catch { }
  }
  $deadline = [DateTime]::UtcNow.AddSeconds(20)
  while ((Test-CdsCursorRunning) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 250
  }
  if (Test-CdsCursorRunning) {
    if (-not $Force) {
      Write-CdsFail 'Cursor did not close within 20 seconds.'
    }
    Get-CdsCursorAppProcesses | ForEach-Object {
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
  }
  if (Test-CdsCursorRunning) {
    Write-CdsFail 'Cursor could not be stopped safely.'
  }
}

function Start-CdsCursorWithCdp {
  param([Parameter(Mandatory)][int]$Port)
  Ensure-CdsStateRoot
  $null = New-Item -ItemType File -Path $script:CdsAppLog -Force
  $exe = Find-CdsCursorExe
  $script:CdsCursorExe = $exe

  # CRITICAL: do not inherit ELECTRON_RUN_AS_NODE into the real app launch.
  $launcher = Join-Path $script:CdsStateRoot 'launch-cursor-cdp.cmd'
  @(
    '@echo off'
    'set ELECTRON_RUN_AS_NODE='
    "start `"`" `"$exe`" --remote-debugging-port=$Port"
  ) | Set-Content -LiteralPath $launcher -Encoding ASCII

  Start-Process -FilePath $launcher -WindowStyle Hidden | Out-Null
}

function Confirm-CdsRestartDialog {
  Write-Host ''
  Write-Host 'Cursor needs a one-time restart to enable Dream Skin.' -ForegroundColor Yellow
  Write-Host '(Open windows/files are kept, but the current Agent chat will interrupt.)'
  Write-Host ''
  Write-Host -NoNewline 'Restart and apply skin now? [Y/N] '
  $answer = Read-Host
  if ($answer -match '^(y|yes|Y)$') { return $true }
  return $false
}

function Pause-CdsIfInteractive {
  param([string]$Message = 'Press any key to close...')
  try {
    Write-Host ''
    Write-Host $Message
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  } catch {
    Start-Sleep -Seconds 8
  }
}

