# Cursor Dream Skin — reliable GUI launcher (called by launch-gui.vbs).
# Reopens an already-running GUI, or restarts a dead/orphaned one.

param(
  [int]$Port = 17865
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

Ensure-CdsStateRoot
$logPath = Join-Path $script:CdsStateRoot 'gui-launch.log'
$url = "http://127.0.0.1:$Port/"
$prefix = $url

function Write-CdsGuiLaunchLog([string]$Message) {
  $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

function Test-CdsGuiHttp {
  param([string]$BaseUrl = $url, [int]$TimeoutSec = 1)
  try {
    $req = [System.Net.HttpWebRequest]::Create(($BaseUrl.TrimEnd('/') + '/api/status'))
    $req.Timeout = [Math]::Max(500, $TimeoutSec * 1000)
    $req.ReadWriteTimeout = $req.Timeout
    $req.Method = 'GET'
    $resp = $req.GetResponse()
    try {
      $reader = New-Object IO.StreamReader($resp.GetResponseStream())
      $body = $reader.ReadToEnd()
      $reader.Close()
      if ([int]$resp.StatusCode -lt 200 -or [int]$resp.StatusCode -ge 300) { return $false }
      # Stale GUI servers (pre-wizard / pre-pet split) — force recycle.
      if ($body -notmatch '"version"\s*:' -or $body -notmatch '"cursorFound"\s*:' -or $body -notmatch '"petId"\s*:') {
        Write-CdsGuiLaunchLog 'Existing GUI is outdated — will recycle'
        return $false
      }
      return $true
    } finally {
      $resp.Close()
    }
  } catch {
    return $false
  }
}

function Open-CdsGuiBrowser {
  param([string]$AppUrl = $url)
  $edge = $null
  foreach ($c in @(
      "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
      "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
      "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )) {
    if (Test-Path -LiteralPath $c) { $edge = $c; break }
  }
  if ($edge) {
    Start-Process -FilePath $edge -ArgumentList @(
      "--app=$AppUrl",
      '--disable-features=TranslateUI',
      "--user-data-dir=$($script:CdsStateRoot)\edge-profile"
    ) | Out-Null
  } else {
    Start-Process $AppUrl | Out-Null
  }
}

function Stop-CdsGuiServers {
  # Kill by recorded pid
  $pidFile = Join-Path $script:CdsStateRoot 'gui-server.pid'
  if (Test-Path -LiteralPath $pidFile) {
    $raw = (Get-Content -LiteralPath $pidFile -Raw -ErrorAction SilentlyContinue)
    if ($raw) {
      $old = 0
      if ([int]::TryParse($raw.Trim(), [ref]$old) -and $old -gt 0) {
        Stop-Process -Id $old -Force -ErrorAction SilentlyContinue
      }
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  }

  # Kill orphans whose command line still points at gui-server.ps1
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and ($_.CommandLine -like '*gui-server.ps1*') -and ($_.ProcessId -ne $PID) } |
    ForEach-Object {
      Write-CdsGuiLaunchLog "Stopping orphan gui-server PID $($_.ProcessId)"
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }

  Start-Sleep -Milliseconds 400
}

# Prefer persisted Cursor path
$saved = Get-CdsSavedCursorExe
if ($saved) { $env:CURSOR_EXE = $saved }

Write-CdsGuiLaunchLog "Launch requested (port $Port)"

try {
  if (Test-CdsGuiHttp -TimeoutSec 1) {
    Write-CdsGuiLaunchLog "Existing GUI healthy — reopening browser"
    Set-Content -LiteralPath (Join-Path $script:CdsStateRoot 'gui-url.txt') -Value $prefix -Encoding ASCII
    Open-CdsGuiBrowser
    exit 0
  }

  Write-CdsGuiLaunchLog "No healthy GUI — recycling listeners"
  Stop-CdsGuiServers

  # Brief wait if http.sys still releasing the prefix
  $deadline = (Get-Date).AddSeconds(3)
  while ((Get-Date) -lt $deadline) {
    try {
      $probe = [System.Net.HttpListener]::new()
      $probe.Prefixes.Add($prefix)
      $probe.Start()
      $probe.Stop()
      $probe.Close()
      break
    } catch {
      Start-Sleep -Milliseconds 250
    }
  }

  $server = Join-Path $PSScriptRoot 'gui-server.ps1'
  $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
    '-File', $server, '-Port', "$Port"
  ) -PassThru -WindowStyle Hidden

  Write-CdsGuiLaunchLog "Started gui-server PID $($proc.Id)"

  $ready = $false
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 250
    if (Test-CdsGuiHttp -TimeoutSec 1) { $ready = $true; break }
    if ($proc.HasExited) { break }
  }

  if (-not $ready) {
    $msg = "GUI server did not become ready on $prefix (pid $($proc.Id), exited=$($proc.HasExited)). See $logPath"
    Write-CdsGuiLaunchLog $msg
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
      "Cursor Dream Skin 未能打开界面。`n`n$port 端口可能被占用，或启动失败。`n详情见：`n$logPath",
      'Cursor Dream Skin',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
  }

  Write-CdsGuiLaunchLog "GUI ready"
  # gui-server already opens the browser; open again only if somehow missed
  exit 0
} catch {
  Write-CdsGuiLaunchLog ("ERROR: " + $_.Exception.Message)
  try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
      ("Cursor Dream Skin 启动失败：`n`n" + $_.Exception.Message + "`n`n日志：`n" + $logPath),
      'Cursor Dream Skin',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
  } catch { }
  exit 1
}
