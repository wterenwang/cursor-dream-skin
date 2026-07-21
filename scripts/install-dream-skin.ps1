[CmdletBinding()]
param(
  [int]$Port = 9666,
  [switch]$NoShortcuts,
  [switch]$NoTray,
  [string]$DefaultTheme
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

Assert-CdsPort -Port $Port
$hit = Try-CdsFindCursorExe
if (-not $hit.Path) {
  Write-Host '还没找到 Cursor——第一次打开管理界面时，会请你选一次位置。' -ForegroundColor Yellow
} else {
  $script:CdsCursorExe = $hit.Path
  $null = Get-CdsNodeRunner
}

# Featured default (catalog) unless caller overrides
if ($DefaultTheme) {
  $featuredTheme = Resolve-CdsThemeDir -ThemeArg $DefaultTheme
} else {
  $featuredTheme = Get-CdsFeaturedDefaultThemeDir
}
if (-not $featuredTheme) {
  Write-CdsFail 'themes 下没有可用的推荐主题。'
}

$check = Invoke-CdsNode -ArgumentList @(
  $script:CdsInjector, '--check-payload', '--theme-dir', $featuredTheme
) -PassThru
if ($check.ExitCode -ne 0) {
  Write-Host $check.StdErr
  Write-CdsFail "推荐主题检查未通过：$featuredTheme"
}

Ensure-CdsStateRoot
Set-CdsActiveTheme -ThemeDir $featuredTheme
$featuredPet = Get-CdsFeaturedDefaultPetDir
if ($featuredPet) {
  Set-CdsActivePet -ThemeDir $featuredPet
} else {
  Set-CdsActivePet -ThemeDir 'none'
}
Set-Content -LiteralPath (Join-Path $script:CdsStateRoot 'engine-root.txt') -Value $script:CdsProjectRoot -Encoding UTF8

$featuredMeta = Get-Content (Join-Path $featuredTheme 'theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$featuredName = if ($featuredMeta.name) { [string]$featuredMeta.name } else { Split-Path -Leaf $featuredTheme }
$petName = $null
if ($featuredPet) {
  try {
    $petMeta = Get-Content (Join-Path $featuredPet 'theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($petMeta.name) { $petName = [string]$petMeta.name }
  } catch { }
  if (-not $petName) { $petName = Split-Path -Leaf $featuredPet }
}

Write-Host ''
Write-Host ('  推荐默认壁纸：{0}' -f $featuredName) -ForegroundColor Cyan
if ($petName) {
  Write-Host ('  推荐默认桌宠：{0}' -f $petName) -ForegroundColor Cyan
}
Write-Host '  提示：可在右下角小助手图标里切换壁纸和桌宠。' -ForegroundColor DarkGray
Write-Host ''

if (-not $NoShortcuts) {
  $shell = New-Object -ComObject WScript.Shell
  $desktop = [Environment]::GetFolderPath('Desktop')
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $trayVbs = Join-Path $PSScriptRoot 'launch-tray.vbs'
  $guiVbs = Join-Path $PSScriptRoot 'launch-gui.vbs'
  $restoreCmd = Join-Path $PSScriptRoot 'restore-dream-skin.cmd'
  $iconTarget = $null
  if ($script:CdsCursorExe -and (Test-Path -LiteralPath $script:CdsCursorExe)) {
    $iconTarget = "$($script:CdsCursorExe),0"
  }

  foreach ($folder in @($desktop, $startMenu)) {
    if (-not (Test-Path -LiteralPath $folder)) {
      New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $tray = $shell.CreateShortcut((Join-Path $folder 'Cursor Dream Skin.lnk'))
    $tray.TargetPath = 'wscript.exe'
    $tray.Arguments = "`"$trayVbs`""
    $tray.WorkingDirectory = $script:CdsProjectRoot
    $tray.Description = '打开 Cursor Dream Skin 小助手'
    if ($iconTarget) { $tray.IconLocation = $iconTarget }
    $tray.Save()

    $gui = $shell.CreateShortcut((Join-Path $folder 'Cursor Dream Skin - 管理界面.lnk'))
    $gui.TargetPath = 'wscript.exe'
    $gui.Arguments = "`"$guiVbs`""
    $gui.WorkingDirectory = $script:CdsProjectRoot
    $gui.Description = '打开 Cursor Dream Skin 管理界面'
    if ($iconTarget) { $gui.IconLocation = $iconTarget }
    $gui.Save()

    $oldGui = Join-Path $folder 'Cursor Dream Skin - Manager.lnk'
    if (Test-Path -LiteralPath $oldGui) {
      Remove-Item -LiteralPath $oldGui -Force -ErrorAction SilentlyContinue
    }
  }

  $restore = $shell.CreateShortcut((Join-Path $desktop 'Cursor Dream Skin - 还原外观.lnk'))
  $restore.TargetPath = $restoreCmd
  $restore.Arguments = ''
  $restore.WorkingDirectory = $script:CdsProjectRoot
  $restore.Description = '还原 Cursor 官方外观'
  $restore.Save()

  $oldRestore = Join-Path $desktop 'Cursor Dream Skin - Restore.lnk'
  if (Test-Path -LiteralPath $oldRestore) {
    Remove-Item -LiteralPath $oldRestore -Force -ErrorAction SilentlyContinue
  }
}

if (-not $NoTray) {
  $trayVbs = Join-Path $PSScriptRoot 'launch-tray.vbs'
  Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$trayVbs`"" | Out-Null
}

Sync-CdsDeskPet

Write-Host '安装完成。'
Write-Host ('当前推荐壁纸：{0}' -f $featuredName)
if ($petName) { Write-Host ('当前推荐桌宠：{0}' -f $petName) }
Write-Host '桌面：「Cursor Dream Skin」打开小助手；「管理界面」选壁纸和桌宠；「还原外观」回到官方样子。'
Write-Host '桌宠在屏幕右下角，气泡里会显示你正在做的事。'
Write-Host 'First GUI launch may ask you to locate Cursor once.'
