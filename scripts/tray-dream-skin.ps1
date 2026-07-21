# Cursor Dream Skin - system tray (STA WinForms).
# Encoding: UTF-8 with BOM (required for Windows PowerShell 5.1 + CJK).

param(
  [switch]$Silent
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. (Join-Path $PSScriptRoot 'common-windows.ps1')
Ensure-CdsStateRoot

$mutex = New-Object System.Threading.Mutex($false, 'Global\CursorDreamSkinTray')
if (-not $mutex.WaitOne(0, $false)) {
  if (-not $Silent) {
    [System.Windows.Forms.MessageBox]::Show(
      'Cursor Dream Skin tray is already running.',
      'Cursor Dream Skin',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
  }
  exit 0
}

function Get-CdsTrayLang {
  $langFile = Join-Path $script:CdsStateRoot 'ui-lang.txt'
  if (Test-Path -LiteralPath $langFile) {
    $v = (Get-Content -LiteralPath $langFile -Raw -Encoding ASCII).Trim().ToLowerInvariant()
    if ($v -eq 'en') { return 'en' }
  }
  return 'zh'
}

function T([string]$Zh, [string]$En) {
  if ((Get-CdsTrayLang) -eq 'en') { return $En }
  return $Zh
}

function Get-CdsTrayIcon {
  $png = Join-Path $script:CdsProjectRoot 'assets\dream-skin-icon.png'
  if (Test-Path -LiteralPath $png) {
    try {
      $bmp = [System.Drawing.Bitmap]::FromFile($png)
      $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
      $ms = New-Object System.IO.MemoryStream
      $icon.Save($ms)
      $ms.Position = 0
      $clone = New-Object System.Drawing.Icon $ms
      $bmp.Dispose()
      $icon.Dispose()
      return $clone
    } catch { }
  }
  $hit = Try-CdsFindCursorExe
  if ($hit.Path) {
    try { return [System.Drawing.Icon]::ExtractAssociatedIcon($hit.Path) } catch { }
  }
  return [System.Drawing.SystemIcons]::Application
}

function Invoke-CdsTrayScript {
  param(
    [Parameter(Mandatory)][string]$File,
    [string[]]$ArgumentList = @()
  )
  $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $File) + $ArgumentList
  Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -WindowStyle Hidden | Out-Null
}

function Show-CdsTrayTip([string]$Title, [string]$Text, [int]$Ms = 2500) {
  try {
    $script:Notify.BalloonTipTitle = $Title
    $script:Notify.BalloonTipText = $Text
    $script:Notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $script:Notify.ShowBalloonTip($Ms)
  } catch { }
}

function Update-CdsTrayStatusText {
  $active = Get-CdsActiveThemeDir
  $name = if ($active) { Split-Path -Leaf $active } else { '(none)' }
  if ($active -and (Test-Path (Join-Path $active 'theme.json'))) {
    try {
      $meta = Get-Content (Join-Path $active 'theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($meta.name) { $name = [string]$meta.name }
    } catch { }
  }
  $script:Notify.Text = ("Dream Skin · {0}" -f $name)
  if ($script:Notify.Text.Length -gt 63) {
    $script:Notify.Text = $script:Notify.Text.Substring(0, 60) + '...'
  }
}

function Build-CdsTrayMenu {
  $menu = New-Object System.Windows.Forms.ContextMenuStrip
  $menu.ShowImageMargin = $false

  $openGui = New-Object System.Windows.Forms.ToolStripMenuItem (T 'Open manager' 'Open manager')
  $openGui.Text = T ((-join ([char]0x6253,[char]0x5F00,[char]0x7BA1,[char]0x7406,[char]0x754C,[char]0x9762))) 'Open manager'
  $openGui.add_Click({
    $vbs = Join-Path $PSScriptRoot 'launch-gui.vbs'
    Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$vbs`"" | Out-Null
  })
  [void]$menu.Items.Add($openGui)

  [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

  $apply = New-Object System.Windows.Forms.ToolStripMenuItem 'Apply'
  $apply.Text = T ((-join ([char]0x5E94,[char]0x7528,[char]0x5F53,[char]0x524D,[char]0x76AE,[char]0x80A4))) 'Apply current skin'
  $apply.add_Click({
    Show-CdsTrayTip 'Dream Skin' (T ((-join ([char]0x6B63,[char]0x5728,[char]0x5E94,[char]0x7528,[char]0x76AE,[char]0x80A4,[char]0x2026))) 'Applying skin...')
    $start = Join-Path $PSScriptRoot 'start-dream-skin.ps1'
    Invoke-CdsTrayScript -File $start -ArgumentList @('-PromptRestart')
  })
  [void]$menu.Items.Add($apply)

  $featured = New-Object System.Windows.Forms.ToolStripMenuItem 'Featured'
  $featured.Text = T ((-join ([char]0x7CBE,[char]0x9009,[char]0x58C1,[char]0x7EB8))) 'Featured wallpapers'
  foreach ($theme in (Get-CdsFeaturedThemeEntries -Kind wallpaper)) {
    $label = $theme.name
    if ($theme.blurb) { $label = "{0}  -  {1}" -f $theme.name, $theme.blurb }
    $item = New-Object System.Windows.Forms.ToolStripMenuItem $label
    $item.Tag = $theme.id
    $item.add_Click({
      param($sender, $e)
      $id = [string]$sender.Tag
      $prefix = T ((-join ([char]0x5207,[char]0x6362,[char]0x5230,[char]0xFF1A))) 'Switch to: '
      Show-CdsTrayTip 'Dream Skin' ($prefix + $id)
      Set-CdsActiveTheme -ThemeDir (Resolve-CdsThemeDir -ThemeArg $id)
      Update-CdsTrayStatusText
      $state = Read-CdsState
      $port = if ($state -and $state.port) { [int]$state.port } else { $script:CdsDefaultPort }
      if (Test-CdsCdpHttpReady -Port $port) {
        $switch = Join-Path $PSScriptRoot 'switch-theme.ps1'
        Invoke-CdsTrayScript -File $switch -ArgumentList @('-Theme', $id)
      } else {
        $start = Join-Path $PSScriptRoot 'start-dream-skin.ps1'
        Invoke-CdsTrayScript -File $start -ArgumentList @('-Theme', $id, '-PromptRestart')
      }
      Sync-CdsDeskPet
    })
    [void]$featured.DropDownItems.Add($item)
  }
  [void]$menu.Items.Add($featured)

  $pets = New-Object System.Windows.Forms.ToolStripMenuItem 'Pets'
  $pets.Text = T ((-join ([char]0x684C,[char]0x5BA0))) 'Desk pet'
  $nonePet = New-Object System.Windows.Forms.ToolStripMenuItem (T ((-join ([char]0x4E0D,[char]0x663E,[char]0x793A,[char]0x684C,[char]0x5BA0))) 'Hide desk pet')
  $nonePet.add_Click({
    Set-CdsActivePet -ThemeDir 'none'
    Stop-CdsDeskPet
    Show-CdsTrayTip 'Dream Skin' (T ((-join ([char]0x684C,[char]0x5BA0,[char]0x5DF2,[char]0x9690,[char]0x85CF))) 'Desk pet hidden.')
  })
  [void]$pets.DropDownItems.Add($nonePet)
  foreach ($theme in (Get-CdsFeaturedThemeEntries -Kind pet)) {
    $label = $theme.name
    if ($theme.blurb) { $label = "{0}  -  {1}" -f $theme.name, $theme.blurb }
    $item = New-Object System.Windows.Forms.ToolStripMenuItem $label
    $item.Tag = $theme.id
    $item.add_Click({
      param($sender, $e)
      $id = [string]$sender.Tag
      Set-CdsActivePet -ThemeDir (Resolve-CdsThemeDir -ThemeArg $id)
      Start-CdsDeskPet
      $prefix = T ((-join ([char]0x684C,[char]0x5BA0,[char]0xFF1A))) 'Pet: '
      Show-CdsTrayTip 'Dream Skin' ($prefix + $id)
    })
    [void]$pets.DropDownItems.Add($item)
  }
  [void]$menu.Items.Add($pets)

  $restore = New-Object System.Windows.Forms.ToolStripMenuItem 'Restore'
  $restore.Text = T ((-join ([char]0x8FD8,[char]0x539F,[char]0x5B98,[char]0x65B9,[char]0x5916,[char]0x89C2))) 'Restore official look'
  $restore.add_Click({
    Show-CdsTrayTip 'Dream Skin' (T ((-join ([char]0x6B63,[char]0x5728,[char]0x8FD8,[char]0x539F,[char]0x2026))) 'Restoring...')
    Stop-CdsDeskPet
    $restorePs1 = Join-Path $PSScriptRoot 'restore-dream-skin.ps1'
    Invoke-CdsTrayScript -File $restorePs1
  })
  [void]$menu.Items.Add($restore)

  [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

  $quit = New-Object System.Windows.Forms.ToolStripMenuItem 'Quit'
  $quit.Text = T ((-join ([char]0x9000,[char]0x51FA,[char]0x5C0F,[char]0x52A9,[char]0x624B))) 'Quit helper'
  $quit.add_Click({
    $script:Notify.Visible = $false
    $script:Notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
  })
  [void]$menu.Items.Add($quit)

  return $menu
}

$script:Notify = New-Object System.Windows.Forms.NotifyIcon
$script:Notify.Icon = Get-CdsTrayIcon
$script:Notify.Visible = $true
$script:Notify.ContextMenuStrip = (Build-CdsTrayMenu)
Update-CdsTrayStatusText

$script:Notify.add_DoubleClick({
  $vbs = Join-Path $PSScriptRoot 'launch-gui.vbs'
  Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$vbs`"" | Out-Null
})

Show-CdsTrayTip 'Cursor Dream Skin' (T ((-join ([char]0x5C0F,[char]0x52A9,[char]0x624B,[char]0x5DF2,[char]0x5C31,[char]0x7EEA))) 'Helper ready.')

try {
  [System.Windows.Forms.Application]::Run()
} finally {
  if ($script:Notify) {
    $script:Notify.Visible = $false
    $script:Notify.Dispose()
  }
  try { $mutex.ReleaseMutex() } catch { }
  $mutex.Dispose()
}