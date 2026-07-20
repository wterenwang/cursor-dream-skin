[CmdletBinding()]
param(
  [int]$Port = 9666,
  [switch]$NoShortcuts
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

Assert-CdsPort -Port $Port
$hit = Try-CdsFindCursorExe
if (-not $hit.Path) {
  Write-Host 'Cursor.exe not found yet - the GUI first-run wizard will ask you to pick it.' -ForegroundColor Yellow
} else {
  $null = Get-CdsNodeRunner
}

$defaultTheme = Join-Path $script:CdsProjectRoot 'themes\default'
if (-not (Test-Path -LiteralPath (Join-Path $defaultTheme 'theme.json'))) {
  Write-CdsFail "Bundled theme missing: $defaultTheme"
}
$check = Invoke-CdsNode -ArgumentList @(
  $script:CdsInjector, '--check-payload', '--theme-dir', $defaultTheme
) -PassThru
if ($check.ExitCode -ne 0) {
  Write-Host $check.StdErr
  Write-CdsFail 'Default theme payload validation failed.'
}

Ensure-CdsStateRoot
Set-CdsActiveTheme -ThemeDir $defaultTheme
Set-Content -LiteralPath (Join-Path $script:CdsStateRoot 'engine-root.txt') -Value $script:CdsProjectRoot -Encoding UTF8

if (-not $NoShortcuts) {
  $shell = New-Object -ComObject WScript.Shell
  $desktop = [Environment]::GetFolderPath('Desktop')
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $guiVbs = Join-Path $PSScriptRoot 'launch-gui.vbs'
  $restoreCmd = Join-Path $PSScriptRoot 'restore-dream-skin.cmd'

  foreach ($folder in @($desktop, $startMenu)) {
    if (-not (Test-Path -LiteralPath $folder)) {
      New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    $shortcut = $shell.CreateShortcut((Join-Path $folder 'Cursor Dream Skin.lnk'))
    $shortcut.TargetPath = 'wscript.exe'
    $shortcut.Arguments = "`"$guiVbs`""
    $shortcut.WorkingDirectory = $script:CdsProjectRoot
    $shortcut.Description = 'Open Cursor Dream Skin'
    if (Test-Path -LiteralPath $script:CdsCursorExe) {
      $shortcut.IconLocation = "$($script:CdsCursorExe),0"
    }
    $shortcut.Save()
  }

  $restore = $shell.CreateShortcut((Join-Path $desktop 'Cursor Dream Skin - Restore.lnk'))
  $restore.TargetPath = $restoreCmd
  $restore.WorkingDirectory = $script:CdsProjectRoot
  $restore.Description = 'Restore the official Cursor appearance'
  $restore.Save()
}

Write-Host 'Cursor Dream Skin installed.'
Write-Host 'Open the desktop shortcut (or scripts\launch-gui.cmd) for the Edge GUI.'
Write-Host 'First launch may ask you to locate Cursor.exe once.'
