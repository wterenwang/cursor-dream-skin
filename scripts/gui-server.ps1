# Cursor Dream Skin - local GUI server (localhost only).
# Serves gui/ + JSON API for apply/restore/status.

param(
  [int]$Port = 17865,
  [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$GuiRoot = Join-Path $script:CdsProjectRoot 'gui'
$AssetsRoot = Join-Path $script:CdsProjectRoot 'assets'
$I18nPath = Join-Path $PSScriptRoot 'i18n.json'
$Prefix = "http://127.0.0.1:$Port/"

function Read-CdsI18nObject {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  $raw = [System.IO.File]::ReadAllText($I18nPath, $utf8)
  if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
  return ($raw | ConvertFrom-Json)
}

function Get-CdsUiLang {
  $langFile = Join-Path $script:CdsStateRoot 'ui-lang.txt'
  if (Test-Path -LiteralPath $langFile) {
    $v = (Get-Content -LiteralPath $langFile -Raw -Encoding ASCII).Trim().ToLowerInvariant()
    if ($v -eq 'en' -or $v -eq 'zh') { return $v }
  }
  $ui = [System.Globalization.CultureInfo]::CurrentUICulture.Name
  if ($ui -like 'zh*') { return 'zh' }
  return 'en'
}

function Set-CdsUiLang([string]$Lang) {
  Ensure-CdsStateRoot
  Set-Content -LiteralPath (Join-Path $script:CdsStateRoot 'ui-lang.txt') -Value $Lang -Encoding ASCII
}

function Get-CdsRgbaAlpha([string]$Color) {
  if (-not $Color) { return 1.0 }
  if ($Color -match ',\s*([01](?:\.\d+)?|\.\d+)\s*\)\s*$') {
    return [double]$Matches[1]
  }
  return 1.0
}

function Set-CdsRgbaAlpha([string]$Color, [double]$Alpha) {
  $a = [Math]::Max(0.0, [Math]::Min(1.0, $Alpha))
  $aStr = ('{0:0.00}' -f $a)
  if ($Color -match '^(rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+)\s*(?:,\s*[0-9.]+\s*)?\)$') {
    return "$($Matches[1]), $aStr)"
  }
  return $Color
}

function Get-CdsThemeListApi {
  param([bool]$ShowHidden = $false)
  $themesRoot = Join-Path $script:CdsProjectRoot 'themes'
  $list = @()
  if (Test-Path -LiteralPath $themesRoot) {
    Get-ChildItem -LiteralPath $themesRoot -Directory | ForEach-Object {
      $jsonPath = Join-Path $_.FullName 'theme.json'
      if (-not (Test-Path -LiteralPath $jsonPath)) { return }
      $name = $_.Name
      $image = $null
      $builtin = $true
      $hidden = $false
      $custom = $false
      $mode = 'dark'
      $artPosition = 'center'
      $dimAlpha = 0.2
      $editorAlpha = 0.9
      $artMode = 'wallpaper'
      try {
        $meta = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($meta.name) { $name = [string]$meta.name }
        if ($meta.image) { $image = [string]$meta.image }
        if ($null -ne $meta.builtin) { $builtin = [bool]$meta.builtin }
        if ($null -ne $meta.hidden) { $hidden = [bool]$meta.hidden }
        if ($null -ne $meta.custom) { $custom = [bool]$meta.custom }
        if ($meta.mode) { $mode = [string]$meta.mode }
        if ($meta.artPosition) { $artPosition = [string]$meta.artPosition }
        if ($meta.artMode) { $artMode = [string]$meta.artMode }
        if ($meta.colors) {
          if ($meta.colors.dim) { $dimAlpha = Get-CdsRgbaAlpha ([string]$meta.colors.dim) }
          if ($meta.colors.editor) { $editorAlpha = Get-CdsRgbaAlpha ([string]$meta.colors.editor) }
        }
        # Heuristic: demo/smoke ids stay hidden even without flags
        if ($_.Name -match '^(smoke-test|demo-)') { $hidden = $true; $custom = $true; $builtin = $false }
      } catch { }
      if ($hidden -and -not $ShowHidden) { return }
      $list += [pscustomobject]@{
        id           = $_.Name
        name         = $name
        path         = $_.FullName
        image        = $image
        builtin      = $builtin
        hidden       = $hidden
        custom       = $custom
        deletable    = (-not $builtin) -or $custom
        mode         = $mode
        artMode      = $artMode
        artPosition  = $artPosition
        dimAlpha     = [Math]::Round($dimAlpha, 2)
        editorAlpha  = [Math]::Round($editorAlpha, 2)
      }
    }
  }
  return @($list | Sort-Object @{ Expression = 'builtin'; Descending = $true }, name)
}

function Invoke-CdsHotSwitchTheme([string]$ThemeDir) {
  $state = Read-CdsState
  $port = if ($state -and $state.port) { [int]$state.port } else { $script:CdsDefaultPort }
  if (-not (Test-CdsCdpHttpReady -Port $port)) {
    return [ordered]@{ ok = $true; hot = $false; message = 'Theme saved. Apply Skin to see changes.' }
  }
  if (-not (Test-CdsPortBelongsToCursor -Port $port)) {
    throw "Port $port is not owned by Cursor."
  }
  Stop-CdsRecordedInjector
  Stop-CdsStrayInjectors
  $injectorPid = Start-CdsInjectorDaemon -Port $port -ThemeDir $ThemeDir
  $startedAt = (Get-Process -Id $injectorPid -ErrorAction SilentlyContinue).StartTime.ToString('o')
  if (-not $startedAt) { $startedAt = (Get-Date).ToUniversalTime().ToString('o') }
  Write-CdsState -Port $port -InjectorPid $injectorPid -InjectorStartedAt $startedAt -ThemeDir $ThemeDir
  $null = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--once', '--port', "$port",
    '--theme-dir', $ThemeDir, '--timeout-ms', '15000'
  ) -PassThru
  return [ordered]@{ ok = $true; hot = $true; injectorPid = $injectorPid }
}

function Invoke-CdsUpdateThemeApi {
  param(
    [string]$ThemeId,
    [object]$DimAlpha,
    [object]$EditorAlpha,
    [string]$ArtPosition,
    [bool]$Reapply = $true
  )
  $themeDir = Join-Path $script:CdsProjectRoot "themes\$ThemeId"
  $jsonPath = Join-Path $themeDir 'theme.json'
  if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Theme not found: $ThemeId" }
  $meta = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $meta.colors) { $meta | Add-Member -NotePropertyName colors -NotePropertyValue ([pscustomobject]@{}) -Force }

  $allowedPos = @(
    'center', 'left', 'right', 'top', 'bottom',
    'left top', 'left bottom', 'right top', 'right bottom',
    'center top', 'center bottom'
  )
  if ($ArtPosition) {
    if ($ArtPosition -notin $allowedPos) { throw "Invalid artPosition: $ArtPosition" }
    $meta.artPosition = $ArtPosition
  }
  if ($null -ne $DimAlpha -and "$DimAlpha" -ne '') {
    $d = [double]$DimAlpha
    if ($d -lt 0 -or $d -gt 0.6) { throw 'dimAlpha must be between 0 and 0.6' }
    $meta.colors.dim = Set-CdsRgbaAlpha ([string]$meta.colors.dim) $d
  }
  if ($null -ne $EditorAlpha -and "$EditorAlpha" -ne '') {
    $e = [double]$EditorAlpha
    if ($e -lt 0.5 -or $e -gt 1.0) { throw 'editorAlpha must be between 0.5 and 1.0' }
    $meta.colors.editor = Set-CdsRgbaAlpha ([string]$meta.colors.editor) $e
  }

  $utf8 = New-Object System.Text.UTF8Encoding $true
  [IO.File]::WriteAllText($jsonPath, (($meta | ConvertTo-Json -Depth 8) + "`n"), $utf8)

  $hot = $null
  if ($Reapply) {
    $active = Get-CdsActiveThemeDir
    if ($active -and ((Split-Path -Leaf $active) -eq $ThemeId)) {
      Set-CdsActiveTheme -ThemeDir $themeDir
      $hot = Invoke-CdsHotSwitchTheme -ThemeDir $themeDir
    }
  }
  return [ordered]@{
    ok          = $true
    themeId     = $ThemeId
    artPosition = [string]$meta.artPosition
    dimAlpha    = Get-CdsRgbaAlpha ([string]$meta.colors.dim)
    editorAlpha = Get-CdsRgbaAlpha ([string]$meta.colors.editor)
    hot         = $hot
  }
}

function Invoke-CdsDeleteThemeApi([string]$ThemeId) {
  if ($ThemeId -eq 'default') { throw 'Cannot delete the default theme.' }
  $themeDir = Join-Path $script:CdsProjectRoot "themes\$ThemeId"
  $jsonPath = Join-Path $themeDir 'theme.json'
  if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Theme not found: $ThemeId" }
  $meta = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $builtin = $true
  $custom = $false
  if ($null -ne $meta.builtin) { $builtin = [bool]$meta.builtin }
  if ($null -ne $meta.custom) { $custom = [bool]$meta.custom }
  if ($ThemeId -match '^(smoke-test|demo-)') { $custom = $true; $builtin = $false }
  if ($builtin -and -not $custom) { throw 'Built-in themes cannot be deleted.' }

  $active = Get-CdsActiveThemeDir
  if ($active -and ((Split-Path -Leaf $active) -eq $ThemeId)) {
    $fallback = Join-Path $script:CdsProjectRoot 'themes\default'
    Set-CdsActiveTheme -ThemeDir $fallback
  }
  Remove-Item -LiteralPath $themeDir -Recurse -Force
  return [ordered]@{ ok = $true; deleted = $ThemeId }
}

function Get-CdsStatusApi {
  $hit = Try-CdsFindCursorExe
  $cursorExe = $hit.Path
  $cursorSource = $hit.Source
  $state = Read-CdsState
  $port = if ($state -and $state.port) { [int]$state.port } else { $script:CdsDefaultPort }
  $themeDir = Get-CdsActiveThemeDir
  $themeId = if ($themeDir) { Split-Path -Leaf $themeDir } else { $null }
  $themeName = $themeId
  if ($themeDir -and (Test-Path (Join-Path $themeDir 'theme.json'))) {
    try {
      $meta = Get-Content (Join-Path $themeDir 'theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($meta.name) { $themeName = [string]$meta.name }
    } catch { }
  }
  $running = $false
  $cdp = $false
  $injectorAlive = $false
  if ($cursorExe) {
    $running = Test-CdsCursorRunning
    $cdp = Test-CdsVerifiedCdpEndpoint -Port $port
  }
  if ($state -and $state.injectorPid) {
    $injectorAlive = $null -ne (Get-Process -Id ([int]$state.injectorPid) -ErrorAction SilentlyContinue)
  }
  $skinActive = ($cdp -and $injectorAlive)
  $setupDone = Test-CdsSetupDone
  $needsSetup = (-not $cursorExe) -or (-not $setupDone)

  # Human-readable lifecycle hint for the GUI (key resolved client-side via i18n).
  $hintKey = 'hintReady'
  $tone = 'idle'
  if (-not $cursorExe) {
    $hintKey = 'hintNeedCursor'
    $tone = 'danger'
  } elseif ($skinActive) {
    $hintKey = 'hintSkinActive'
    $tone = 'ok'
  } elseif ($cdp -and -not $injectorAlive) {
    $hintKey = 'hintCdpIdle'
    $tone = 'warn'
  } elseif ($running -and -not $cdp) {
    $hintKey = 'hintRestartNeeded'
    $tone = 'warn'
  } elseif (-not $running) {
    $hintKey = 'hintReadyLaunch'
    $tone = 'idle'
  }

  return [ordered]@{
    lang            = Get-CdsUiLang
    version         = $script:CdsSkinVersion
    cursorExe       = $cursorExe
    cursorSource    = $cursorSource
    cursorFound     = [bool]$cursorExe
    setupDone       = $setupDone
    needsSetup      = $needsSetup
    cursorRunning   = $running
    port            = $port
    cdpReady        = $cdp
    injectorAlive   = $injectorAlive
    skinActive      = $skinActive
    themeId         = $themeId
    themeName       = $themeName
    themeDir        = $themeDir
    statusTone      = $tone
    hintKey         = $hintKey
    checks          = @(
      [ordered]@{ id = 'cursor'; ok = [bool]$cursorExe; key = 'checkCursor' }
      [ordered]@{ id = 'running'; ok = $running; key = 'checkRunning' }
      [ordered]@{ id = 'cdp';     ok = $cdp; key = 'checkCdp' }
      [ordered]@{ id = 'injector'; ok = $injectorAlive; key = 'checkInjector' }
      [ordered]@{ id = 'skin';     ok = $skinActive; key = 'checkSkin' }
    )
  }
}

function Invoke-CdsBrowseCursorExe {
  # OpenFileDialog needs STA; HttpListener thread is usually MTA.
  Ensure-CdsStateRoot
  $outFile = Join-Path $script:CdsStateRoot 'browse-cursor-out.txt'
  Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
  $ps = @"
Add-Type -AssemblyName System.Windows.Forms
`$dlg = New-Object System.Windows.Forms.OpenFileDialog
`$dlg.Filter = 'Cursor|Cursor.exe|Executable (*.exe)|*.exe'
`$dlg.Title = 'Select Cursor.exe'
`$dlg.CheckFileExists = `$true
`$dlg.Multiselect = `$false
if (`$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Set-Content -LiteralPath '$($outFile.Replace("'","''"))' -Value `$dlg.FileName -Encoding UTF8
}
"@
  $tmpPs1 = Join-Path $script:CdsStateRoot 'browse-cursor.ps1'
  Set-Content -LiteralPath $tmpPs1 -Value $ps -Encoding UTF8
  try {
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
      '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $tmpPs1
    ) -Wait -PassThru -WindowStyle Normal
    if ($proc.ExitCode -ne 0) { return $null }
    if (-not (Test-Path -LiteralPath $outFile)) { return $null }
    $picked = (Get-Content -LiteralPath $outFile -Raw -Encoding UTF8).Trim()
    if (-not $picked) { return $null }
    return $picked
  } finally {
    Remove-Item -LiteralPath $tmpPs1, $outFile -Force -ErrorAction SilentlyContinue
  }
}

function Write-CdsHttpJson($Response, $Object, [int]$StatusCode = 200) {
  $json = ($Object | ConvertTo-Json -Depth 8 -Compress)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $Response.StatusCode = $StatusCode
  $Response.ContentType = 'application/json; charset=utf-8'
  $Response.ContentLength64 = $bytes.Length
  $Response.Headers['Cache-Control'] = 'no-store'
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Response.OutputStream.Close()
}

function Write-CdsHttpFile($Response, [string]$FilePath, [string]$ContentType) {
  if (-not (Test-Path -LiteralPath $FilePath)) {
    $Response.StatusCode = 404
    $Response.Close()
    return
  }
  $bytes = [IO.File]::ReadAllBytes($FilePath)
  $Response.StatusCode = 200
  $Response.ContentType = $ContentType
  $Response.ContentLength64 = $bytes.Length
  $Response.Headers['Cache-Control'] = 'no-cache'
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Response.OutputStream.Close()
}

function Get-CdsMime([string]$Path) {
  switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    '.html' { 'text/html; charset=utf-8' }
    '.css'  { 'text/css; charset=utf-8' }
    '.js'   { 'application/javascript; charset=utf-8' }
    '.json' { 'application/json; charset=utf-8' }
    '.png'  { 'image/png' }
    '.jpg'  { 'image/jpeg' }
    '.jpeg' { 'image/jpeg' }
    '.webp' { 'image/webp' }
    '.svg'  { 'image/svg+xml' }
    default { 'application/octet-stream' }
  }
}

function Read-CdsHttpBody($Request) {
  if ($Request.ContentLength64 -le 0) { return '' }
  $reader = New-Object IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
  try { return $reader.ReadToEnd() } finally { $reader.Close() }
}

function Invoke-CdsApplyApi([string]$ThemeId, [bool]$AllowRestart) {
  $script:logs = @()
  function Add-Log([string]$Message, [string]$Level = 'info') {
    $script:logs = @($script:logs) + @([pscustomobject]@{ message = $Message; level = $Level })
  }

  $themePath = Join-Path $script:CdsProjectRoot "themes\$ThemeId"
  if (-not (Test-Path -LiteralPath (Join-Path $themePath 'theme.json'))) {
    throw "Theme not found: $ThemeId"
  }

  Add-Log "Applying theme: $ThemeId"
  Set-CdsActiveTheme -ThemeDir $themePath

  Add-Log 'Validating payload...'
  $check = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--check-payload', '--theme-dir', $themePath
  ) -PassThru
  if ($check.ExitCode -ne 0) { throw "Theme payload validation failed. $($check.StdErr)" }

  $state = Read-CdsState
  $port = if ($state -and $state.port) { [int]$state.port } else { $script:CdsDefaultPort }
  $null = Find-CdsCursorExe
  $debugReady = Test-CdsVerifiedCdpEndpoint -Port $port
  $running = Test-CdsCursorRunning

  if ($running -and -not $debugReady) {
    if (-not $AllowRestart) { throw 'Cursor is running without CDP. Allow restart to continue.' }
    Add-Log 'Restarting Cursor for CDP...' 'warn'
    Stop-CdsCursor -Force
    $debugReady = $false
    Start-Sleep -Milliseconds 800
  }

  if (-not $debugReady) {
    $port = Select-CdsAvailablePort -StartPort $port
    Add-Log "Launching Cursor with debug port $port..."
    Start-CdsCursorWithCdp -Port $port
    if (-not (Wait-CdsCdp -Port $port -TimeoutSec 60)) {
      throw "Cursor did not open CDP on port $port within 60s."
    }
  }

  Add-Log 'Starting injector...'
  Stop-CdsRecordedInjector
  Stop-CdsStrayInjectors
  if (Test-Path -LiteralPath $script:CdsStatePath) { Remove-Item -LiteralPath $script:CdsStatePath -Force }

  $injectorPid = Start-CdsInjectorDaemon -Port $port -ThemeDir $themePath
  $startedAt = (Get-Process -Id $injectorPid -ErrorAction SilentlyContinue).StartTime.ToString('o')
  if (-not $startedAt) { $startedAt = (Get-Date).ToUniversalTime().ToString('o') }
  Write-CdsState -Port $port -InjectorPid $injectorPid -InjectorStartedAt $startedAt -ThemeDir $themePath
  Add-Log "Injector PID $injectorPid"

  Add-Log 'Verifying...'
  $verify = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--verify', '--port', "$port",
    '--theme-dir', $themePath, '--timeout-ms', '20000'
  ) -PassThru
  $hardOk = ($verify.ExitCode -eq 0)
  $softOk = ($verify.StdOut -match '"installed"\s*:\s*true')
  if (-not ($hardOk -or $softOk)) {
    Stop-CdsRecordedInjector
    throw "Verification failed. $($verify.StdErr)"
  }
  if ($softOk -and -not $hardOk) {
    Add-Log 'Verify soft-pass: markers found, but not every check passed. Re-apply after a Cursor update if the skin looks wrong.' 'warn'
  }

  Set-CdsSetupDone
  $mode = 'dark'
  try {
    $meta = Get-Content (Join-Path $themePath 'theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($meta.mode) { $mode = [string]$meta.mode }
  } catch { }
  return [ordered]@{
    ok         = $true
    softVerify = [bool]($softOk -and -not $hardOk)
    themeId    = $ThemeId
    themeMode  = $mode
    logs       = @($script:logs)
  }
}

function Invoke-CdsRestoreApi {
  $script:logs = @()
  function Add-Log([string]$Message, [string]$Level = 'info') {
    $script:logs = @($script:logs) + @([pscustomobject]@{ message = $Message; level = $Level })
  }
  Add-Log 'Restoring official look...'
  $state = Read-CdsState
  $port = if ($state -and $state.port) { [int]$state.port } else { $null }
  $null = Find-CdsCursorExe
  Stop-CdsRecordedInjector
  Stop-CdsStrayInjectors
  if ($port -and (Test-CdsCdpHttpReady -Port $port)) {
    $result = Invoke-CdsNode -ArgumentList @(
      $script:CdsInjector, '--remove', '--port', "$port", '--timeout-ms', '10000'
    ) -PassThru
    if ($result.ExitCode -eq 0) { Add-Log 'Skin removed from live windows.' 'ok' }
    else { Add-Log 'Removal reported issues - reload Cursor windows if needed.' 'warn' }
  } else {
    Add-Log 'No live CDP session; cleared local state.' 'warn'
  }
  if (Test-Path -LiteralPath $script:CdsStatePath) { Remove-Item -LiteralPath $script:CdsStatePath -Force }
  Add-Log 'Note: Cursor may still have been started with a debug port until you quit and reopen it normally.' 'warn'
  return [ordered]@{ ok = $true; logs = @($script:logs); cdpMayLinger = $true }
}

function Invoke-CdsCreateThemeApi {
  param(
    [string]$Id,
    [string]$Name,
    [string]$Mode = 'auto',
    [string]$ImagePath,
    [string]$ImageExt = 'png'
  )

  if (-not $Id -or $Id -notmatch '^[a-z0-9][a-z0-9-]{0,60}$') {
    throw 'Theme id must be lowercase letters, digits and dashes.'
  }
  if (-not $Name) { throw 'Display name is required.' }
  if ($Mode -notin @('auto', 'dark', 'light')) { throw 'Mode must be auto, dark, or light.' }
  if ($ImageExt -notin @('png', 'jpg', 'jpeg', 'webp')) { throw 'Unsupported image type.' }
  if (-not $ImagePath -or -not (Test-Path -LiteralPath $ImagePath)) { throw 'Image file is required.' }

  $len = (Get-Item -LiteralPath $ImagePath).Length
  if ($len -lt 1 -or $len -gt (20 * 1024 * 1024)) {
    throw 'Image must be between 1 byte and 20 MB.'
  }

  # Avoid clobbering an existing theme id.
  $candidate = $Id
  $n = 2
  while (Test-Path -LiteralPath (Join-Path $script:CdsProjectRoot "themes\$candidate\theme.json")) {
    $candidate = "{0}-{1}" -f $Id, $n
    $n++
    if ($n -gt 99) { throw 'Too many themes with similar ids.' }
  }
  $Id = $candidate

  $makeTheme = Join-Path $PSScriptRoot 'make-theme.mjs'
  $result = Invoke-CdsNode -ArgumentList @(
    $makeTheme,
    '--image', $ImagePath,
    '--id', $Id,
    '--name', $Name,
    '--mode', $Mode
  ) -PassThru
  if ($result.ExitCode -ne 0) {
    throw "make-theme failed. $($result.StdErr)"
  }
  $themeDir = Join-Path $script:CdsProjectRoot "themes\$Id"
  if (-not (Test-Path -LiteralPath (Join-Path $themeDir 'theme.json'))) {
    throw 'Theme was not created on disk.'
  }
  return [ordered]@{
    ok       = $true
    themeId  = $Id
    themeDir = $themeDir
  }
}

function Find-CdsEdge {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
  )
  foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
  return $null
}

# ---- listen ----
Ensure-CdsStateRoot
$hitBoot = Try-CdsFindCursorExe
if ($hitBoot.Path) { $env:CURSOR_EXE = $hitBoot.Path }

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($Prefix)
try {
  $listener.Start()
} catch {
  # If an old instance is still healthy, just reopen the browser and exit quietly.
  try {
    $req = [System.Net.HttpWebRequest]::Create(("http://127.0.0.1:$Port/api/status"))
    $req.Timeout = 800
    $resp = $req.GetResponse()
    $resp.Close()
    if (-not $NoBrowser) {
      $edge = Find-CdsEdge
      $appUrl = "http://127.0.0.1:$Port/"
      if ($edge) {
        Start-Process -FilePath $edge -ArgumentList @(
          "--app=$appUrl",
          '--disable-features=TranslateUI',
          "--user-data-dir=$($script:CdsStateRoot)\edge-profile"
        ) | Out-Null
      } else {
        Start-Process $appUrl | Out-Null
      }
    }
    Write-Host "Reused existing GUI at $Prefix"
    exit 0
  } catch {
    $log = Join-Path $script:CdsStateRoot 'gui-launch.log'
    $msg = "Could not bind $Prefix - is another Dream Skin GUI already open? $_"
    Add-Content -LiteralPath $log -Value ("{0}  {1}" -f (Get-Date -Format 'o'), $msg) -Encoding UTF8
    throw $msg
  }
}

$pidFile = Join-Path $script:CdsStateRoot 'gui-server.pid'
Set-Content -LiteralPath $pidFile -Value $PID -Encoding ASCII
$urlFile = Join-Path $script:CdsStateRoot 'gui-url.txt'
Set-Content -LiteralPath $urlFile -Value $Prefix -Encoding ASCII

if (-not $NoBrowser) {
  $edge = Find-CdsEdge
  $appUrl = $Prefix
  if ($edge) {
    Start-Process -FilePath $edge -ArgumentList @(
      "--app=$appUrl",
      '--disable-features=TranslateUI',
      "--user-data-dir=$($script:CdsStateRoot)\edge-profile"
    ) | Out-Null
  } else {
    Start-Process $appUrl | Out-Null
  }
}

Write-Host "Cursor Dream Skin GUI at $Prefix (pid $PID)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
      if ($path -eq '/') { $path = '/index.html' }

      if ($path -eq '/api/status' -and $req.HttpMethod -eq 'GET') {
        Write-CdsHttpJson $res (Get-CdsStatusApi)
        continue
      }
      if ($path -eq '/api/themes' -and $req.HttpMethod -eq 'GET') {
        $showHidden = ($req.Url.Query -match '(?i)[?&]showHidden=(1|true)\b')
        Write-CdsHttpJson $res ([ordered]@{ themes = @(Get-CdsThemeListApi -ShowHidden $showHidden) })
        continue
      }
      if ($path -eq '/api/i18n' -and $req.HttpMethod -eq 'GET') {
        Write-CdsHttpJson $res (Read-CdsI18nObject)
        continue
      }
      if ($path -eq '/api/lang' -and $req.HttpMethod -eq 'POST') {
        $body = Read-CdsHttpBody $req | ConvertFrom-Json
        $lang = [string]$body.lang
        if ($lang -ne 'en' -and $lang -ne 'zh') { throw 'lang must be en or zh' }
        Set-CdsUiLang $lang
        Write-CdsHttpJson $res ([ordered]@{ ok = $true; lang = $lang })
        continue
      }
      if ($path -eq '/api/set-cursor' -and $req.HttpMethod -eq 'POST') {
        $body = Read-CdsHttpBody $req | ConvertFrom-Json
        $exePath = [string]$body.path
        $resolved = Set-CdsCursorExe -Path $exePath
        if ([bool]$body.completeSetup) { Set-CdsSetupDone }
        Write-CdsHttpJson $res ([ordered]@{ ok = $true; cursorExe = $resolved; status = (Get-CdsStatusApi) })
        continue
      }
      if ($path -eq '/api/browse-cursor' -and $req.HttpMethod -eq 'POST') {
        $picked = Invoke-CdsBrowseCursorExe
        if (-not $picked) {
          Write-CdsHttpJson $res ([ordered]@{ ok = $false; cancelled = $true })
          continue
        }
        $resolved = Set-CdsCursorExe -Path $picked
        Write-CdsHttpJson $res ([ordered]@{ ok = $true; cursorExe = $resolved; status = (Get-CdsStatusApi) })
        continue
      }
      if ($path -eq '/api/setup-complete' -and $req.HttpMethod -eq 'POST') {
        $hit = Try-CdsFindCursorExe
        if (-not $hit.Path) { throw 'Select Cursor.exe before finishing setup.' }
        # Persist discovered path so later launches stay stable.
        if ($hit.Source -ne 'saved') { $null = Set-CdsCursorExe -Path $hit.Path }
        Set-CdsSetupDone
        Write-CdsHttpJson $res ([ordered]@{ ok = $true; status = (Get-CdsStatusApi) })
        continue
      }
      if ($path -eq '/api/apply' -and $req.HttpMethod -eq 'POST') {
        $body = Read-CdsHttpBody $req | ConvertFrom-Json
        $result = Invoke-CdsApplyApi -ThemeId ([string]$body.themeId) -AllowRestart ([bool]$body.allowRestart)
        Write-CdsHttpJson $res $result
        continue
      }
      if ($path -eq '/api/create-theme' -and $req.HttpMethod -eq 'POST') {
        $id = [string]$req.Headers['X-Theme-Id']
        $name = [Uri]::UnescapeDataString([string]$req.Headers['X-Theme-Name'])
        $mode = [string]$req.Headers['X-Theme-Mode']
        if (-not $mode) { $mode = 'auto' }
        $ext = [string]$req.Headers['X-Image-Ext']
        if (-not $ext) { $ext = 'png' }

        Ensure-CdsStateRoot
        $tmpDir = Join-Path $script:CdsStateRoot 'uploads'
        New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
        $tmpImage = Join-Path $tmpDir ("upload-{0}.{1}" -f [Guid]::NewGuid().ToString('N'), $ext)
        $fs = [IO.File]::Open($tmpImage, [IO.FileMode]::Create, [IO.FileAccess]::Write)
        try {
          $req.InputStream.CopyTo($fs)
        } finally {
          $fs.Close()
        }
        try {
          $result = Invoke-CdsCreateThemeApi -Id $id -Name $name -Mode $mode -ImagePath $tmpImage -ImageExt $ext
          Write-CdsHttpJson $res $result
        } finally {
          Remove-Item -LiteralPath $tmpImage -Force -ErrorAction SilentlyContinue
        }
        continue
      }
      if ($path -eq '/api/open-themes' -and $req.HttpMethod -eq 'POST') {
        $themesDir = Join-Path $script:CdsProjectRoot 'themes'
        New-Item -ItemType Directory -Force -Path $themesDir | Out-Null
        Start-Process explorer.exe -ArgumentList $themesDir | Out-Null
        Write-CdsHttpJson $res ([ordered]@{ ok = $true; path = $themesDir })
        continue
      }
      if ($path -eq '/api/restore' -and $req.HttpMethod -eq 'POST') {
        Write-CdsHttpJson $res (Invoke-CdsRestoreApi)
        continue
      }
      if ($path -eq '/api/update-theme' -and $req.HttpMethod -eq 'POST') {
        $body = Read-CdsHttpBody $req | ConvertFrom-Json
        $result = Invoke-CdsUpdateThemeApi `
          -ThemeId ([string]$body.themeId) `
          -DimAlpha $body.dimAlpha `
          -EditorAlpha $body.editorAlpha `
          -ArtPosition ([string]$body.artPosition) `
          -Reapply ([bool]($null -eq $body.reapply -or $body.reapply))
        Write-CdsHttpJson $res $result
        continue
      }
      if ($path -eq '/api/delete-theme' -and $req.HttpMethod -eq 'POST') {
        $body = Read-CdsHttpBody $req | ConvertFrom-Json
        Write-CdsHttpJson $res (Invoke-CdsDeleteThemeApi -ThemeId ([string]$body.themeId))
        continue
      }
      if ($path -like '/api/theme-art/*' -and $req.HttpMethod -eq 'GET') {
        $id = $path.Substring('/api/theme-art/'.Length)
        $themeDir = Join-Path $script:CdsProjectRoot "themes\$id"
        $metaPath = Join-Path $themeDir 'theme.json'
        if (-not (Test-Path -LiteralPath $metaPath)) { $res.StatusCode = 404; $res.Close(); continue }
        $meta = Get-Content -LiteralPath $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $img = Join-Path $themeDir ([string]$meta.image)
        Write-CdsHttpFile $res $img (Get-CdsMime $img)
        continue
      }

      # static: /assets/* from project assets, everything else from gui/
      $file = $null
      if ($path -like '/assets/*') {
        $rel = $path.Substring('/assets/'.Length) -replace '/', '\'
        $file = Join-Path $AssetsRoot $rel
      } else {
        $rel = $path.TrimStart('/') -replace '/', '\'
        $file = Join-Path $GuiRoot $rel
      }
      $full = [IO.Path]::GetFullPath($file)
      $rootFull = if ($path -like '/assets/*') {
        [IO.Path]::GetFullPath($AssetsRoot)
      } else {
        [IO.Path]::GetFullPath($GuiRoot)
      }
      if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        $res.StatusCode = 403
        $res.Close()
        continue
      }
      Write-CdsHttpFile $res $full (Get-CdsMime $full)
    } catch {
      try {
        Write-CdsHttpJson $res ([ordered]@{ error = $_.Exception.Message }) 500
      } catch {
        try { $res.Abort() } catch { }
      }
    }
  }
} finally {
  if ($listener.IsListening) { $listener.Stop() }
  $listener.Close()
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
