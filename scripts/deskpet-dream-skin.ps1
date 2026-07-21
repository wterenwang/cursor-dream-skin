# Cursor Dream Skin — desktop pet (LLMPET-style moods + true alpha).
# Encoding: UTF-8 with BOM (Windows PowerShell 5.1 + CJK).

param(
  [switch]$Silent
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'cds-transcript-sense.ps1')
Ensure-CdsStateRoot

$mutex = New-Object System.Threading.Mutex($false, 'Global\CursorDreamSkinDeskPet')
if (-not $mutex.WaitOne(0, $false)) {
  if (-not $Silent) {
    [System.Windows.Forms.MessageBox]::Show(
      '桌宠已在运行。',
      'Cursor Dream Skin',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
  }
  exit 0
}

# Layered-window helpers (per-pixel alpha via UpdateLayeredWindow)
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class CdsLayered {
  public const int GWL_EXSTYLE = -20;
  public const int WS_EX_LAYERED = 0x80000;
  public const int ULW_ALPHA = 0x02;
  public const byte AC_SRC_OVER = 0;
  public const byte AC_SRC_ALPHA = 1;

  [StructLayout(LayoutKind.Sequential)]
  public struct POINT { public int X; public int Y; public POINT(int x, int y) { X = x; Y = y; } }
  [StructLayout(LayoutKind.Sequential)]
  public struct SIZE { public int Cx; public int Cy; public SIZE(int cx, int cy) { Cx = cx; Cy = cy; } }
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  public struct BLENDFUNCTION {
    public byte BlendOp; public byte BlendFlags; public byte SourceConstantAlpha; public byte AlphaFormat;
  }

  [DllImport("user32.dll", SetLastError = true)]
  public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref POINT pptDst,
    ref SIZE psize, IntPtr hdcSrc, ref POINT pptSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
  [DllImport("gdi32.dll", SetLastError = true)]
  public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
  [DllImport("gdi32.dll", SetLastError = true)]
  public static extern bool DeleteDC(IntPtr hdc);
  [DllImport("gdi32.dll", SetLastError = true)]
  public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
  [DllImport("gdi32.dll", SetLastError = true)]
  public static extern bool DeleteObject(IntPtr hObject);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern IntPtr GetDC(IntPtr hWnd);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll", SetLastError = true)]
  public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

  public const int SW_RESTORE = 9;

  public static void FocusWindow(IntPtr hWnd) {
    if (hWnd == IntPtr.Zero) return;
    if (IsIconic(hWnd)) ShowWindow(hWnd, SW_RESTORE);
    SwitchToThisWindow(hWnd, true);
    SetForegroundWindow(hWnd);
  }

  public static void EnsureLayered(Form form) {
    IntPtr h = form.Handle;
    int ex = GetWindowLong(h, GWL_EXSTYLE);
    if ((ex & WS_EX_LAYERED) == 0) SetWindowLong(h, GWL_EXSTYLE, ex | WS_EX_LAYERED);
  }

  public static void Paint(Form form, Bitmap bmp) {
    if (form == null || bmp == null) return;
    EnsureLayered(form);
    IntPtr screenDc = GetDC(IntPtr.Zero);
    IntPtr memDc = CreateCompatibleDC(screenDc);
    IntPtr hBitmap = IntPtr.Zero;
    IntPtr oldBitmap = IntPtr.Zero;
    try {
      hBitmap = bmp.GetHbitmap(Color.FromArgb(0));
      oldBitmap = SelectObject(memDc, hBitmap);
      SIZE size = new SIZE(bmp.Width, bmp.Height);
      POINT pointSource = new POINT(0, 0);
      POINT topPos = new POINT(form.Left, form.Top);
      BLENDFUNCTION blend = new BLENDFUNCTION();
      blend.BlendOp = AC_SRC_OVER;
      blend.BlendFlags = 0;
      blend.SourceConstantAlpha = 255;
      blend.AlphaFormat = AC_SRC_ALPHA;
      UpdateLayeredWindow(form.Handle, screenDc, ref topPos, ref size, memDc, ref pointSource, 0, ref blend, ULW_ALPHA);
    } finally {
      if (oldBitmap != IntPtr.Zero) SelectObject(memDc, oldBitmap);
      if (hBitmap != IntPtr.Zero) DeleteObject(hBitmap);
      DeleteDC(memDc);
      ReleaseDC(IntPtr.Zero, screenDc);
    }
  }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing

function Get-CdsPetLang {
  $langFile = Join-Path $script:CdsStateRoot 'ui-lang.txt'
  if (Test-Path -LiteralPath $langFile) {
    $v = (Get-Content -LiteralPath $langFile -Raw -Encoding ASCII).Trim().ToLowerInvariant()
    if ($v -eq 'en') { return 'en' }
  }
  return 'zh'
}

function PT([string]$Zh, [string]$En) {
  if ((Get-CdsPetLang) -eq 'en') { return $En }
  return $Zh
}

function Get-CdsPetThemeMeta {
  $dir = Get-CdsActivePetDir
  if (-not $dir) { return $null }
  if (-not (Test-CdsThemeIsPet -ThemeDir $dir)) { return $null }
  $jsonPath = Join-Path $dir 'theme.json'
  if (-not (Test-Path -LiteralPath $jsonPath)) { return $null }
  try {
    $meta = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $states = @{}
    if ($meta.petStates) {
      foreach ($p in $meta.petStates.PSObject.Properties) {
        $states[$p.Name] = [string]$p.Value
      }
    }
    $defaultArt = if ($states['idle']) { $states['idle'] } elseif ($meta.image) { [string]$meta.image } else { 'idle.png' }
    return [pscustomobject]@{
      Dir     = $dir
      Meta    = $meta
      ArtPath = (Join-Path $dir $defaultArt)
      States  = $states
      Motto   = if ($meta.decor -and $meta.decor.motto) { [string]$meta.decor.motto } else { '' }
      Name    = if ($meta.name) { [string]$meta.name } else { Split-Path -Leaf $dir }
    }
  } catch { return $null }
}

function Resolve-CdsPetArtPath($info, [string]$Mood) {
  if (-not $info) { return $null }
  $file = $null
  if ($info.States -and $info.States.ContainsKey($Mood)) { $file = [string]$info.States[$Mood] }
  if (-not $file -and $info.States -and $info.States.ContainsKey('idle')) { $file = [string]$info.States['idle'] }
  if (-not $file) { $file = Split-Path -Leaf $info.ArtPath }
  $path = Join-Path $info.Dir $file
  if (Test-Path -LiteralPath $path) { return $path }
  if (Test-Path -LiteralPath $info.ArtPath) { return $info.ArtPath }
  return $null
}

# Magenta / green screen → true alpha via edge flood only (safe for purple hair)
function Convert-CdsBitmapMagentaToAlpha([System.Drawing.Bitmap]$Bmp) {
  $w = $Bmp.Width; $h = $Bmp.Height
  $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
  $data = $Bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $stride = $data.Stride
  $bytes = New-Object byte[] ($stride * $h)
  [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

  $isScreen = {
    param([byte]$r, [byte]$g, [byte]$b)
    if ($r -eq 255 -and $g -eq 0 -and $b -eq 255) { return $true }
    if ($r -eq 0 -and $g -eq 255 -and $b -eq 0) { return $true }
    if ($r -ge 220 -and $b -ge 220 -and $g -le 60) { return $true }
    if ($g -ge 220 -and $r -le 60 -and $b -le 60) { return $true }
    return $false
  }

  $visited = New-Object bool[] ($w * $h)
  $q = New-Object System.Collections.Generic.Queue[int]
  $seed = {
    param($x, $y)
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $w -or $y -ge $h) { return }
    $i = $y * $w + $x
    if ($visited[$i]) { return }
    $o = $y * $stride + $x * 4
    $a = $bytes[$o + 3]; $b = $bytes[$o]; $g = $bytes[$o + 1]; $r = $bytes[$o + 2]
    if ($a -eq 0 -or (& $isScreen $r $g $b)) {
      $visited[$i] = $true
      $q.Enqueue($i)
    }
  }
  for ($x = 0; $x -lt $w; $x++) { & $seed $x 0; & $seed $x ($h - 1) }
  for ($y = 0; $y -lt $h; $y++) { & $seed 0 $y; & $seed ($w - 1) $y }
  while ($q.Count -gt 0) {
    $i = $q.Dequeue()
    $x = $i % $w
    $y = [int][Math]::Floor($i / [double]$w)
    $o = $y * $stride + $x * 4
    $bytes[$o] = 0; $bytes[$o + 1] = 0; $bytes[$o + 2] = 0; $bytes[$o + 3] = 0
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
      $nx = $x + $d[0]; $ny = $y + $d[1]
      if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $w -or $ny -ge $h) { continue }
      $ni = $ny * $w + $nx
      if ($visited[$ni]) { continue }
      $no = $ny * $stride + $nx * 4
      $na = $bytes[$no + 3]; $nb = $bytes[$no]; $ng = $bytes[$no + 1]; $nr = $bytes[$no + 2]
      if ($na -eq 0 -or (& $isScreen $nr $ng $nb)) {
        $visited[$ni] = $true
        $q.Enqueue($ni)
      }
    }
  }
  [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
  $Bmp.UnlockBits($data)
}

function Test-CdsPetNoiseTitle([string]$Title) {
  if (-not $Title) { return $true }
  $t = $Title.Trim()
  if ($t -eq '' -or $t -eq 'about:blank') { return $true }
  # Persistent Cursor chrome — not real activity
  if ($t -match '(?i)^(cursor\s*)?agents?$') { return $true }
  if ($t -match '(?i)^(cursor|welcome|getting started|home)$') { return $true }
  if ($t -match '(?i)devtools|extension://|chrome-extension') { return $true }
  return $false
}

function Test-CdsPetAgentTitle([string]$Title) {
  if (Test-CdsPetNoiseTitle $Title) { return $false }
  # Real agent activity cues (not the always-open "Cursor Agents" panel name)
  if ($Title -match '(?i)\b(thinking|generating|streaming|working on|tool call|compiling)\b') { return $true }
  if ($Title -match '(?i)(正在思考|正在生成|正在回复|调用工具)') { return $true }
  # Composer / Agent with a concrete subtitle (not bare panel name)
  if ($Title -match '(?i)^(composer|agent|chat)\s*[-—:|]') { return $true }
  if ($Title -match '(?i)[-—:|]\s*(composer|agent chat)\b') { return $true }
  return $false
}

function Get-CdsCursorTaskSnapshot {
  $result = [pscustomobject]@{
    Line     = (PT '待命中' 'Standing by')
    Detail   = ''
    Kind     = 'idle'
    MoodHint = $null
    Source   = 'title'
  }

  if (-not (Test-CdsCursorRunning)) {
    $result.Line = PT 'Cursor 还没打开' 'Cursor is closed'
    $result.Kind = 'offline'
    return $result
  }

  # Prefer Agent transcript (read-only) over window-title heuristics
  try {
    $tx = Read-CdsTranscriptActivity
    $mapped = Convert-CdsTranscriptToSnapshot $tx
    if ($mapped) {
      $result.Kind = $mapped.Kind
      $result.Detail = $mapped.Detail
      $result.MoodHint = $mapped.MoodHint
      $result.Source = 'transcript'
      if ($mapped.MoodHint -eq 'working') {
        $result.Line = PT '正在写' 'Working on'
      } else {
        $result.Line = PT '正在想' 'Thinking'
      }
      return $result
    }
  } catch { }

  $state = Read-CdsState
  $port = if ($state -and $state.port) { [int]$state.port } else { $script:CdsDefaultPort }
  $titles = @()
  if (Test-CdsCdpHttpReady -Port $port) {
    try {
      $list = Invoke-RestMethod -Uri "http://127.0.0.1:$port/json/list" -TimeoutSec 1.2
      foreach ($t in @($list)) {
        if ($t.title) { $titles += [string]$t.title }
      }
    } catch { }
  }

  try {
    foreach ($p in @(Get-CdsCursorAppProcesses)) {
      if ($p.MainWindowTitle) { $titles += [string]$p.MainWindowTitle }
    }
  } catch { }
  Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle } |
    ForEach-Object { $titles += [string]$_.MainWindowTitle }

  $titles = @($titles | Where-Object { $_ -and $_.Trim() } | Select-Object -Unique)

  $joined = ($titles -join ' | ')
  if ($joined -match '(?i)\b(error|failed|failure|exception)\b|(无法|失败|出错)') {
    $errTitle = ($titles | Where-Object { -not (Test-CdsPetNoiseTitle $_) } | Select-Object -First 1)
    if ($errTitle) {
      $clean = ($errTitle -replace '\s*[-—|]\s*Cursor\s*$', '').Trim()
      if ($clean.Length -gt 48) { $clean = $clean.Substring(0, 46) + '…' }
      $result.Line = PT '出了点问题' 'Something went wrong'
      $result.Detail = $clean
      $result.Kind = 'error'
      return $result
    }
  }

  foreach ($title in $titles) {
    if (-not (Test-CdsPetAgentTitle $title)) { continue }
    $clean = ($title -replace '\s*[-—|]\s*Cursor\s*$', '').Trim()
    if ($clean.Length -gt 48) { $clean = $clean.Substring(0, 46) + '…' }
    $result.Line = PT '正在想' 'Thinking'
    $result.Detail = $clean
    $result.Kind = 'agent'
    $result.MoodHint = 'thinking'
    return $result
  }

  foreach ($title in $titles) {
    if (Test-CdsPetNoiseTitle $title) { continue }
    if ($title -notmatch '(?i)cursor') {
      $fileOnly = $title.Trim()
      if ($fileOnly -match '\.[A-Za-z0-9]{1,10}$') {
        if ($fileOnly.Length -gt 42) { $fileOnly = $fileOnly.Substring(0, 40) + '…' }
        $result.Line = PT '正在写' 'Working on'
        $result.Detail = $fileOnly
        $result.Kind = 'file'
        return $result
      }
      continue
    }
    $clean = ($title -replace '\s*[-—|]\s*Cursor\s*$', '').Trim()
    $parts = @($clean -split '\s*[-—|]\s*')
    $file = $parts[0].Trim()
    if (-not $file) { continue }
    if (Test-CdsPetNoiseTitle $file) { continue }
    if ($file.Length -gt 42) { $file = $file.Substring(0, 40) + '…' }
    $result.Line = PT '正在写' 'Working on'
    $result.Detail = $file
    $result.Kind = 'file'
    return $result
  }

  $meta = Get-CdsPetThemeMeta
  if ($meta -and $meta.Motto) {
    $result.Detail = $meta.Motto
  }
  return $result
}

# LLMPET-style mood FSM over Cursor activity kinds
function Update-CdsPetMoodFromSnapshot($snap) {
  $now = [datetime]::UtcNow
  $kind = [string]$snap.Kind
  $detail = [string]$snap.Detail

  if (-not $script:IdleSince) { $script:IdleSince = $now }
  if (-not $script:PrevKind) { $script:PrevKind = 'idle' }

  # Timed overlays
  if ($script:MoodUntil -and $now -lt $script:MoodUntil -and $script:OverlayMood) {
    return $script:OverlayMood
  }
  # attention just ended → brief happy celebration
  if ($script:OverlayMood -eq 'attention') {
    $script:OverlayMood = 'happy'
    $script:MoodUntil = $now.AddSeconds(2.5)
    return 'happy'
  }
  $script:MoodUntil = $null
  $script:OverlayMood = $null

  # Agent → not agent: attention then happy
  if ($script:PrevKind -eq 'agent' -and $kind -ne 'agent' -and $kind -ne 'error' -and $kind -ne 'offline') {
    $script:OverlayMood = 'attention'
    $script:MoodUntil = $now.AddSeconds(4)
    $script:PrevKind = $kind
    $script:IdleSince = $now
    return 'attention'
  }

  if ($kind -eq 'file' -and $detail -and $script:LastDetail -and $detail -ne $script:LastDetail) {
    $script:OverlayMood = 'happy'
    $script:MoodUntil = $now.AddSeconds(2.5)
    $script:LastDetail = $detail
    $script:PrevKind = $kind
    $script:IdleSince = $now
    return 'happy'
  }

  $script:LastDetail = $detail
  $script:PrevKind = $kind

  switch ($kind) {
    'offline' {
      $script:IdleSince = $now
      return 'sleeping'
    }
    'error' {
      $script:IdleSince = $now
      return 'error'
    }
    'agent' {
      $script:IdleSince = $now
      if ($snap.MoodHint -eq 'working') { return 'working' }
      return 'thinking'
    }
    'file' {
      $script:IdleSince = $now
      return 'working'
    }
    default {
      # Long idle → sleep (~4 min)
      if (($now - $script:IdleSince).TotalSeconds -ge 240) {
        return 'sleeping'
      }
      return 'idle'
    }
  }
}

function Get-CdsPetBubbleCopy([string]$Mood, $snap) {
  $line = $snap.Line
  $detail = $snap.Detail
  switch ($Mood) {
    'thinking'  { $line = PT '正在想' 'Thinking' }
    'working'   { $line = PT '正在写' 'Working on' }
    'happy'     { $line = PT '搞定啦' 'Nice!' }
    'attention' { $line = PT '忙完了，看一眼' 'Done — take a look' }
    'sleeping'  {
      if ($snap.Kind -eq 'offline') { $line = PT 'Cursor 还没打开' 'Cursor is closed' }
      else { $line = PT '在打盹' 'Napping' }
    }
    'error'     { $line = PT '出了点问题' 'Something went wrong' }
    'idle'      { $line = PT '待命中' 'Standing by' }
  }
  if (-not $detail -and $script:PetTheme -and $script:PetTheme.Motto -and $Mood -in @('idle', 'sleeping')) {
    $detail = $script:PetTheme.Motto
  }
  return [pscustomobject]@{ Line = $line; Detail = $detail }
}

function New-CdsPetBubbleBitmap([string]$Line, [string]$Detail, [int]$Width) {
  $padX = 14
  $padY = 10
  $fontLine = New-Object System.Drawing.Font 'Segoe UI', 8.5, ([System.Drawing.FontStyle]::Bold)
  $fontDetail = New-Object System.Drawing.Font 'Segoe UI', 8.0, ([System.Drawing.FontStyle]::Regular)
  $bmpProbe = New-Object System.Drawing.Bitmap 10, 10, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $gProbe = [System.Drawing.Graphics]::FromImage($bmpProbe)
  $lineSize = $gProbe.MeasureString($Line, $fontLine, $Width - 2 * $padX)
  $detailSize = if ($Detail) {
    $gProbe.MeasureString($Detail, $fontDetail, $Width - 2 * $padX)
  } else {
    New-Object System.Drawing.SizeF 0, 0
  }
  $gProbe.Dispose()
  $bmpProbe.Dispose()

  $h = [int]([Math]::Ceiling($padY * 2 + $lineSize.Height + $(if ($Detail) { 4 + $detailSize.Height } else { 0 }) + 10))
  if ($h -lt 48) { $h = 48 }
  $bmp = New-Object System.Drawing.Bitmap $Width, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  $rect = New-Object System.Drawing.Rectangle 1, 1, ($Width - 3), ($h - 12)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $r = 14
  $path.AddArc($rect.X, $rect.Y, $r, $r, 180, 90)
  $path.AddArc($rect.Right - $r, $rect.Y, $r, $r, 270, 90)
  $path.AddArc($rect.Right - $r, $rect.Bottom - $r, $r, $r, 0, 90)
  $path.AddArc($rect.X, $rect.Bottom - $r, $r, $r, 90, 90)
  $path.CloseFigure()
  $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 32, 26, 22))
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 212, 154, 96)), 1.5
  $g.FillPath($brush, $path)
  $g.DrawPath($pen, $path)

  $tail = @(
    (New-Object System.Drawing.Point (($Width / 2) - 8), ($h - 12)),
    (New-Object System.Drawing.Point (($Width / 2) + 8), ($h - 12)),
    (New-Object System.Drawing.Point ($Width / 2), ($h - 2))
  )
  $g.FillPolygon($brush, $tail)

  $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 246, 239, 230))
  $mutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 212, 154, 96))
  $g.DrawString($Line, $fontLine, $mutedBrush, $padX, $padY)
  if ($Detail) {
    $g.DrawString($Detail, $fontDetail, $textBrush, $padX, ($padY + $lineSize.Height + 2))
  }

  $path.Dispose(); $brush.Dispose(); $pen.Dispose()
  $textBrush.Dispose(); $mutedBrush.Dispose()
  $fontLine.Dispose(); $fontDetail.Dispose()
  $g.Dispose()
  return $bmp
}

function Load-CdsPetArtBitmap([string]$ArtPath) {
  if (-not $ArtPath -or -not (Test-Path -LiteralPath $ArtPath)) { return $null }
  $src = [System.Drawing.Image]::FromFile($ArtPath)
  try {
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gg = [System.Drawing.Graphics]::FromImage($bmp)
    $gg.Clear([System.Drawing.Color]::Transparent)
    $gg.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $gg.Dispose()
    Convert-CdsBitmapMagentaToAlpha $bmp
    return $bmp
  } finally {
    $src.Dispose()
  }
}

function Get-CdsBitmapOpaqueBounds([System.Drawing.Bitmap]$Bmp) {
  if (-not $Bmp) { return $null }
  $w = $Bmp.Width; $h = $Bmp.Height
  $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
  $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
  $data = $Bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  try {
    $stride = $data.Stride
    $bytes = New-Object byte[] ($stride * $h)
    [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    # Sample every 2px for speed
    for ($y = 0; $y -lt $h; $y += 2) {
      $row = $y * $stride
      for ($x = 0; $x -lt $w; $x += 2) {
        if ($bytes[$row + $x * 4 + 3] -lt 24) { continue }
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  } finally {
    $Bmp.UnlockBits($data)
  }
  if ($maxX -lt $minX) {
    return (New-Object System.Drawing.Rectangle 0, 0, $w, $h)
  }
  # Pad 2px
  $minX = [Math]::Max(0, $minX - 2)
  $minY = [Math]::Max(0, $minY - 2)
  $maxX = [Math]::Min($w - 1, $maxX + 2)
  $maxY = [Math]::Min($h - 1, $maxY + 2)
  return (New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

function Compose-CdsPetFrame([System.Drawing.Bitmap]$Art, [System.Drawing.Bitmap]$Bubble, [int]$Width, [int]$Height) {
  $frame = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($frame)
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  # Fixed art box so every mood is the same on-screen size
  $artMaxW = [int]($Width * 0.92)
  $artMaxH = [int]($Height * 0.62)
  if ($artMaxW -lt 96) { $artMaxW = 96 }
  if ($artMaxH -lt 110) { $artMaxH = 110 }

  $bubbleH = 0
  if ($Bubble) {
    $bx = [int](($Width - $Bubble.Width) / 2)
    if ($bx -lt 0) { $bx = 0 }
    $g.DrawImage($Bubble, $bx, 2, $Bubble.Width, $Bubble.Height)
    $bubbleH = $Bubble.Height
  }

  if ($Art) {
    $srcRect = Get-CdsBitmapOpaqueBounds $Art
    if (-not $srcRect) {
      $srcRect = New-Object System.Drawing.Rectangle 0, 0, $Art.Width, $Art.Height
    }
    $scale = [Math]::Min($artMaxW / [double]$srcRect.Width, $artMaxH / [double]$srcRect.Height)
    # Cap so huge canvases don't blow up; keep character ~compact
    if ($scale -gt 1.0) { $scale = 1.0 }
    $dw = [Math]::Max(1, [int]($srcRect.Width * $scale))
    $dh = [Math]::Max(1, [int]($srcRect.Height * $scale))
    $dx = [int](($Width - $dw) / 2)
    $dy = $bubbleH + [int](($Height - $bubbleH - $dh) / 2)
    if ($dy -lt ($bubbleH + 2)) { $dy = $bubbleH + 2 }
    $dest = New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh
    $g.DrawImage($Art, $dest, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  }
  $g.Dispose()
  return $frame
}

function Show-CdsPetFrame {
  if (-not $script:Form -or $script:Form.IsDisposed) { return }
  $w = $script:Form.Width
  $h = $script:Form.Height
  $frame = Compose-CdsPetFrame -Art $script:ArtImage -Bubble $script:BubbleBmp -Width $w -Height $h
  try {
    [CdsLayered]::Paint($script:Form, $frame)
  } finally {
    $frame.Dispose()
  }
}

function Get-CdsDeskPetPosPath {
  return (Join-Path $script:CdsStateRoot 'deskpet-pos.txt')
}

function Restore-CdsDeskPetPosition {
  $path = Get-CdsDeskPetPosPath
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  try {
    $raw = (Get-Content -LiteralPath $path -Raw -Encoding ASCII).Trim()
    if ($raw -notmatch '^(-?\d+)\s*,\s*(-?\d+)$') { return $false }
    $x = [int]$Matches[1]
    $y = [int]$Matches[2]
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $maxX = $wa.Right - 80
    $maxY = $wa.Bottom - 80
    if ($x -lt ($wa.Left - 40)) { $x = $wa.Left + 8 }
    if ($y -lt ($wa.Top - 40)) { $y = $wa.Top + 8 }
    if ($x -gt $maxX) { $x = $maxX }
    if ($y -gt $maxY) { $y = $maxY }
    $script:Form.Left = $x
    $script:Form.Top = $y
    return $true
  } catch { return $false }
}

function Save-CdsDeskPetPosition {
  if (-not $script:Form -or $script:Form.IsDisposed) { return }
  Ensure-CdsStateRoot
  $line = '{0},{1}' -f $script:Form.Left, $script:Form.Top
  Set-Content -LiteralPath (Get-CdsDeskPetPosPath) -Value $line -Encoding ASCII
}

function Invoke-CdsFocusOrLaunchCursor {
  # Prefer main Cursor window
  try {
    $procs = @(Get-CdsCursorAppProcesses)
    foreach ($cim in $procs) {
      $proc = Get-Process -Id $cim.ProcessId -ErrorAction SilentlyContinue
      if ($proc -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
        [CdsLayered]::FocusWindow($proc.MainWindowHandle)
        return 'focused'
      }
    }
  } catch { }

  $any = Get-Process -Name 'Cursor' -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
    Select-Object -First 1
  if ($any) {
    [CdsLayered]::FocusWindow($any.MainWindowHandle)
    return 'focused'
  }

  $exe = $null
  try { $exe = Find-CdsCursorExe } catch { }
  if (-not $exe) {
    $hit = Try-CdsFindCursorExe
    if ($hit -and $hit.Path) { $exe = $hit.Path }
  }
  if ($exe -and (Test-Path -LiteralPath $exe)) {
    Start-Process -FilePath $exe | Out-Null
    return 'launched'
  }

  # Fallback: open manager so user can locate Cursor
  Start-Process -FilePath 'wscript.exe' -ArgumentList ("`"{0}`"" -f (Join-Path $PSScriptRoot 'launch-gui.vbs')) | Out-Null
  return 'manager'
}

function Invoke-CdsPetLeftClick {
  $result = Invoke-CdsFocusOrLaunchCursor
  # Brief happy flash as feedback
  $script:OverlayMood = 'happy'
  $script:MoodUntil = [datetime]::UtcNow.AddSeconds(1.6)
  try { Update-CdsPetTask } catch { }
  return $result
}

function Switch-CdsDeskPetById([string]$PetId) {
  if (-not $PetId -or $PetId -eq 'none') {
    Set-CdsActivePet -ThemeDir 'none'
    $script:CurrentArtPath = $null
    Update-CdsPetTask
    return
  }
  $dir = Resolve-CdsThemeDir -ThemeArg $PetId
  if (-not (Test-CdsThemeIsPet -ThemeDir $dir)) { return }
  Set-CdsActivePet -ThemeDir $dir
  $script:CurrentArtPath = $null
  $script:PetTheme = $null
  Update-CdsPetTask
}

function Build-CdsDeskPetMenu {
  $menu = New-Object System.Windows.Forms.ContextMenuStrip
  $menu.ShowImageMargin = $false

  $focus = New-Object System.Windows.Forms.ToolStripMenuItem (PT '唤起 Cursor' 'Bring Cursor to front')
  $focus.add_Click({ Invoke-CdsFocusOrLaunchCursor | Out-Null })
  [void]$menu.Items.Add($focus)

  $openGui = New-Object System.Windows.Forms.ToolStripMenuItem (PT '打开管理界面' 'Open manager')
  $openGui.add_Click({
    Start-Process -FilePath 'wscript.exe' -ArgumentList ("`"{0}`"" -f (Join-Path $PSScriptRoot 'launch-gui.vbs')) | Out-Null
  })
  [void]$menu.Items.Add($openGui)

  [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

  $pets = New-Object System.Windows.Forms.ToolStripMenuItem (PT '换桌宠' 'Switch desk pet')
  $none = New-Object System.Windows.Forms.ToolStripMenuItem (PT '不显示桌宠' 'Hide desk pet')
  $none.add_Click({
    Switch-CdsDeskPetById 'none'
    $script:Form.Close()
  })
  [void]$pets.DropDownItems.Add($none)
  foreach ($theme in (Get-CdsFeaturedThemeEntries -Kind pet)) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem $theme.name
    $item.Tag = $theme.id
    $active = Get-CdsActivePetDir
    if ($active -and ((Split-Path -Leaf $active) -eq $theme.id)) {
      $item.Checked = $true
    }
    $item.add_Click({
      param($sender, $e)
      Switch-CdsDeskPetById ([string]$sender.Tag)
    })
    [void]$pets.DropDownItems.Add($item)
  }
  [void]$menu.Items.Add($pets)

  $refresh = New-Object System.Windows.Forms.ToolStripMenuItem (PT '刷新任务' 'Refresh task')
  $refresh.add_Click({ Update-CdsPetTask })
  [void]$menu.Items.Add($refresh)

  [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

  $resetPos = New-Object System.Windows.Forms.ToolStripMenuItem (PT '复位到右下角' 'Reset to bottom-right')
  $resetPos.add_Click({
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $script:Form.Left = $wa.Right - $script:Form.Width - 14
    $script:Form.Top = $wa.Bottom - $script:Form.Height - 14
    Save-CdsDeskPetPosition
    Show-CdsPetFrame
  })
  [void]$menu.Items.Add($resetPos)

  $hide = New-Object System.Windows.Forms.ToolStripMenuItem (PT '隐藏桌宠' 'Hide pet')
  $hide.add_Click({ $script:Form.Close() })
  [void]$menu.Items.Add($hide)

  return $menu
}

function Set-CdsPetArtFromPath([string]$ArtPath, [string]$Name) {
  if (-not $ArtPath -or -not (Test-Path -LiteralPath $ArtPath)) {
    if ($script:ArtImage) { $script:ArtImage.Dispose(); $script:ArtImage = $null }
    $script:CurrentArtPath = $null
    return
  }
  if ($script:CurrentArtPath -eq $ArtPath -and $script:ArtImage) { return }
  try {
    if ($script:ArtImage) { $script:ArtImage.Dispose() }
    $script:ArtImage = Load-CdsPetArtBitmap $ArtPath
    $script:CurrentArtPath = $ArtPath
    if ($Name) { $script:Form.Text = "Dream Skin · $Name" }
  } catch {
    $script:ArtImage = $null
    $script:CurrentArtPath = $null
  }
}

function Update-CdsPetTask {
  $info = Get-CdsPetThemeMeta
  if (-not $info) {
    # No pet selected — hide frame
    if ($script:ArtImage) { $script:ArtImage.Dispose(); $script:ArtImage = $null }
    if ($script:BubbleBmp) { $script:BubbleBmp.Dispose(); $script:BubbleBmp = $null }
    $script:PetTheme = $null
    Show-CdsPetFrame
    return
  }
  if (-not $script:PetTheme -or $script:PetTheme.Dir -ne $info.Dir) {
    $script:PetTheme = $info
    $script:CurrentArtPath = $null
  }

  $snap = Get-CdsCursorTaskSnapshot
  $mood = Update-CdsPetMoodFromSnapshot $snap
  $script:PetMood = $mood
  $copy = Get-CdsPetBubbleCopy -Mood $mood -snap $snap

  $art = Resolve-CdsPetArtPath $info $mood
  Set-CdsPetArtFromPath -ArtPath $art -Name $info.Name

  $bw = $script:Form.Width - 12
  if ($bw -lt 100) { $bw = 100 }
  $old = $script:BubbleBmp
  $script:BubbleBmp = New-CdsPetBubbleBitmap -Line $copy.Line -Detail $copy.Detail -Width $bw
  if ($old) { $old.Dispose() }

  Show-CdsPetFrame
}

# ---- UI (layered form; no TransparencyKey) ----
$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = 'Dream Skin Pet'
$script:Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$script:Form.ShowInTaskbar = $false
$script:Form.TopMost = $true
$script:Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$script:Form.Width = 168
$script:Form.Height = 236
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$script:Form.Left = $wa.Right - $script:Form.Width - 14
$script:Form.Top = $wa.Bottom - $script:Form.Height - 14
$null = Restore-CdsDeskPetPosition

# If restored position was for the old huge window, nudge back into screen
$wa2 = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if (($script:Form.Left + $script:Form.Width) -gt ($wa2.Right + 20) -or ($script:Form.Top + $script:Form.Height) -gt ($wa2.Bottom + 20)) {
  $script:Form.Left = $wa2.Right - $script:Form.Width - 14
  $script:Form.Top = $wa2.Bottom - $script:Form.Height - 14
}

$script:ArtImage = $null
$script:BubbleBmp = $null
$script:CurrentArtPath = $null
$script:PetTheme = $null
$script:PetMood = 'idle'
$script:PrevKind = 'idle'
$script:IdleSince = [datetime]::UtcNow
$script:LastDetail = ''
$script:MoodUntil = $null
$script:OverlayMood = $null

# Drag + click (click = focus Cursor; drag = move & remember)
$script:Drag = $false
$script:DidDrag = $false
$script:DragOrigin = New-Object System.Drawing.Point 0, 0
$script:DragStartScreen = New-Object System.Drawing.Point 0, 0
$script:Form.add_MouseDown({
  param($sender, $e)
  if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
    $script:Drag = $true
    $script:DidDrag = $false
    $script:DragOrigin = New-Object System.Drawing.Point $e.X, $e.Y
    $script:DragStartScreen = [System.Windows.Forms.Cursor]::Position
  }
})
$script:Form.add_MouseMove({
  param($sender, $e)
  if (-not $script:Drag) { return }
  $cur = [System.Windows.Forms.Cursor]::Position
  $dx = [Math]::Abs($cur.X - $script:DragStartScreen.X)
  $dy = [Math]::Abs($cur.Y - $script:DragStartScreen.Y)
  if ($dx -gt 5 -or $dy -gt 5) { $script:DidDrag = $true }
  if (-not $script:DidDrag) { return }
  $script:Form.Left = $script:Form.Left + $e.X - $script:DragOrigin.X
  $script:Form.Top = $script:Form.Top + $e.Y - $script:DragOrigin.Y
  Show-CdsPetFrame
})
$script:Form.add_MouseUp({
  param($sender, $e)
  if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  $wasDrag = $script:DidDrag
  $script:Drag = $false
  $script:DidDrag = $false
  if ($wasDrag) {
    Save-CdsDeskPetPosition
    Show-CdsPetFrame
  } else {
    Invoke-CdsPetLeftClick | Out-Null
  }
})

$script:Form.ContextMenuStrip = (Build-CdsDeskPetMenu)

$script:Form.add_HandleCreated({
  [CdsLayered]::EnsureLayered($script:Form)
  Update-CdsPetTask
})
$script:Form.add_LocationChanged({
  if (-not $script:Drag) { Show-CdsPetFrame }
})
$script:Form.add_Shown({
  [CdsLayered]::EnsureLayered($script:Form)
  Update-CdsPetTask
})
$script:Form.add_FormClosing({
  Save-CdsDeskPetPosition
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2500
$timer.add_Tick({
  try { Update-CdsPetTask } catch { }
})
$timer.Start()

Set-Content -LiteralPath (Join-Path $script:CdsStateRoot 'deskpet.pid') -Value $PID -Encoding ASCII

try {
  [System.Windows.Forms.Application]::Run($script:Form)
} finally {
  $timer.Stop()
  $timer.Dispose()
  Save-CdsDeskPetPosition
  if ($script:ArtImage) { $script:ArtImage.Dispose() }
  if ($script:BubbleBmp) { $script:BubbleBmp.Dispose() }
  $pidFile = Join-Path $script:CdsStateRoot 'deskpet.pid'
  if (Test-Path -LiteralPath $pidFile) {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
  }
  try { $mutex.ReleaseMutex() } catch { }
  $mutex.Dispose()
}
