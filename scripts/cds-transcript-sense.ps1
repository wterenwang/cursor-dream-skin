# Cursor Dream Skin — Agent transcript sensing (read-only, no hooks).
# Watches ~/.cursor/projects/*/agent-transcripts/**/*.jsonl

$script:CdsTranscriptCachePath = $null
$script:CdsTranscriptScanAt = [datetime]::MinValue
$script:CdsTranscriptLastTools = @()
$script:CdsTranscriptLastRole = ''

function Get-CdsTranscriptProjectsRoot {
  Join-Path $env:USERPROFILE '.cursor\projects'
}

function Find-CdsNewestTranscriptPath {
  $root = Get-CdsTranscriptProjectsRoot
  if (-not (Test-Path -LiteralPath $root)) { return $null }
  $newest = $null
  $newestTime = [datetime]::MinValue
  Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $at = Join-Path $_.FullName 'agent-transcripts'
    if (-not (Test-Path -LiteralPath $at)) { return }
    Get-ChildItem -LiteralPath $at -Recurse -Filter '*.jsonl' -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.LastWriteTime -gt $newestTime) {
        $newestTime = $_.LastWriteTime
        $newest = $_.FullName
      }
    }
  }
  return $newest
}

function Resolve-CdsActiveTranscriptPath {
  $now = Get-Date
  $cachedOk = $false
  if ($script:CdsTranscriptCachePath -and (Test-Path -LiteralPath $script:CdsTranscriptCachePath)) {
    $mtime = (Get-Item -LiteralPath $script:CdsTranscriptCachePath).LastWriteTime
    $age = ($now - $mtime).TotalSeconds
    $sinceScan = ($now - $script:CdsTranscriptScanAt).TotalSeconds
    # Hot file: keep; re-scan occasionally in case Agent moved to another chat
    if ($age -lt 120 -and $sinceScan -lt 25) { $cachedOk = $true }
    elseif ($age -lt 15) { $cachedOk = $true }
  }
  if ($cachedOk) { return $script:CdsTranscriptCachePath }

  if (($now - $script:CdsTranscriptScanAt).TotalSeconds -lt 6 -and $script:CdsTranscriptCachePath) {
    return $script:CdsTranscriptCachePath
  }

  $script:CdsTranscriptScanAt = $now
  $found = Find-CdsNewestTranscriptPath
  if ($found) { $script:CdsTranscriptCachePath = $found }
  return $script:CdsTranscriptCachePath
}

function Read-CdsTranscriptTailLines {
  param(
    [Parameter(Mandatory)][string]$Path,
    [int]$MaxLines = 40,
    [int]$MaxBytes = 196608
  )
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  try {
    $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
      $len = $fs.Length
      if ($len -le 0) { return @() }
      $take = [Math]::Min([int64]$MaxBytes, $len)
      $null = $fs.Seek(-$take, [IO.SeekOrigin]::End)
      $buf = New-Object byte[] $take
      $read = $fs.Read($buf, 0, $take)
      $text = [Text.Encoding]::UTF8.GetString($buf, 0, $read)
    } finally { $fs.Close() }
  } catch {
    try {
      return @(Get-Content -LiteralPath $Path -Tail $MaxLines -ErrorAction Stop)
    } catch { return @() }
  }
  $lines = $text -split '\r?\n'
  if ($lines.Count -gt $MaxLines) {
    return @($lines[($lines.Count - $MaxLines)..($lines.Count - 1)])
  }
  return @($lines)
}

function Get-CdsToolBucket([string]$Name) {
  if (-not $Name) { return 'other' }
  switch -Regex ($Name) {
    '^(Write|StrReplace|Delete|EditNotebook|Edit|Shell|Bash)$' { return 'edit' }
    '^(Read|Grep|Glob|WebFetch|WebSearch|SemanticSearch|FetchMcpResource)$' { return 'read' }
    '^(Task|TodoWrite|SwitchMode|AwaitShell|GenerateImage)$' { return 'think' }
    default { return 'other' }
  }
}

function Read-CdsTranscriptActivity {
  $path = Resolve-CdsActiveTranscriptPath
  if (-not $path) {
    return [pscustomobject]@{
      Active = $false
      AgeSec = [double]::PositiveInfinity
      Path   = $null
      Tools  = @()
      Bucket = 'none'
      Role   = ''
    }
  }

  $item = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
  if (-not $item) {
    return [pscustomobject]@{
      Active = $false
      AgeSec = [double]::PositiveInfinity
      Path   = $null
      Tools  = @()
      Bucket = 'none'
      Role   = ''
    }
  }

  $age = ((Get-Date) - $item.LastWriteTime).TotalSeconds
  $lines = Read-CdsTranscriptTailLines -Path $path -MaxLines 36
  $tools = New-Object System.Collections.Generic.List[string]
  $lastRole = ''
  $hasAssistantText = $false

  foreach ($line in $lines) {
    if (-not $line -or $line.Trim().Length -lt 8) { continue }
    # Skip obviously truncated JSON
    if ($line.TrimStart()[0] -ne '{') { continue }
    try {
      $obj = $line | ConvertFrom-Json -ErrorAction Stop
    } catch { continue }

    $role = $null
    if ($obj.role) { $role = [string]$obj.role }
    elseif ($obj.message -and $obj.message.role) { $role = [string]$obj.message.role }
    if ($role) { $lastRole = $role }

    $content = $null
    if ($obj.message -and $obj.message.content) { $content = $obj.message.content }
    elseif ($obj.content) { $content = $obj.content }
    if (-not $content) { continue }

    $parts = @($content)
    foreach ($part in $parts) {
      if ($null -eq $part) { continue }
      $ptype = $null
      try { $ptype = [string]$part.type } catch { }
      if ($ptype -eq 'tool_use' -or $ptype -eq 'tool_call') {
        $name = $null
        try { $name = [string]$part.name } catch { }
        if ($name) { [void]$tools.Add($name) }
      } elseif ($ptype -eq 'text' -and $role -eq 'assistant') {
        $hasAssistantText = $true
      } elseif (($part -is [string]) -and $role -eq 'assistant') {
        $hasAssistantText = $true
      }
    }
  }

  $toolArr = @($tools | Select-Object -Last 12)
  $script:CdsTranscriptLastTools = $toolArr
  $script:CdsTranscriptLastRole = $lastRole

  $bucket = 'none'
  foreach ($t in $toolArr) {
    $b = Get-CdsToolBucket $t
    if ($b -eq 'edit') { $bucket = 'edit'; break }
  }
  if ($bucket -eq 'none') {
    foreach ($t in $toolArr) {
      $b = Get-CdsToolBucket $t
      if ($b -eq 'think') { $bucket = 'think'; break }
    }
  }
  if ($bucket -eq 'none') {
    foreach ($t in $toolArr) {
      $b = Get-CdsToolBucket $t
      if ($b -eq 'read') { $bucket = 'read'; break }
    }
  }
  if ($bucket -eq 'none' -and $hasAssistantText -and $lastRole -eq 'assistant') {
    $bucket = 'think'
  }

  # Fresh writes = Agent is live (30s window)
  $active = ($age -lt 30) -and ($bucket -ne 'none' -or $lastRole -eq 'assistant' -or $lastRole -eq 'user')
  if ($age -lt 30 -and $toolArr.Count -eq 0 -and $lastRole -eq 'user') {
    # User just sent a prompt — treat as thinking
    $bucket = 'think'
    $active = $true
  }

  return [pscustomobject]@{
    Active = [bool]$active
    AgeSec = [double]$age
    Path   = $path
    Tools  = $toolArr
    Bucket = $bucket
    Role   = $lastRole
  }
}

function Convert-CdsTranscriptToSnapshot($Activity) {
  if (-not $Activity -or -not $Activity.Active) { return $null }

  $tool = $null
  if ($Activity.Tools -and $Activity.Tools.Count -gt 0) {
    $tool = [string]$Activity.Tools[-1]
  }

  $detail = if ($tool) { "Agent · $tool" } else { 'Agent' }
  switch ($Activity.Bucket) {
    'edit' {
      return [pscustomobject]@{
        Line     = $null  # filled by caller i18n
        Detail   = $detail
        Kind     = 'agent'
        MoodHint = 'working'
        Source   = 'transcript'
      }
    }
    'read' {
      return [pscustomobject]@{
        Line     = $null
        Detail   = $detail
        Kind     = 'agent'
        MoodHint = 'thinking'
        Source   = 'transcript'
      }
    }
    'think' {
      return [pscustomobject]@{
        Line     = $null
        Detail   = $detail
        Kind     = 'agent'
        MoodHint = 'thinking'
        Source   = 'transcript'
      }
    }
    default {
      return [pscustomobject]@{
        Line     = $null
        Detail   = $detail
        Kind     = 'agent'
        MoodHint = 'thinking'
        Source   = 'transcript'
      }
    }
  }
}
