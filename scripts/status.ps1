[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$cursorExe = $null
try { $cursorExe = Find-CdsCursorExe } catch { $cursorExe = $null }

$state = Read-CdsState
$port = if ($state -and $state.port) { [int]$state.port } else { $script:CdsDefaultPort }
$themeDir = Get-CdsActiveThemeDir

$injectorAlive = $false
if ($state -and $state.injectorPid) {
  $injectorAlive = $null -ne (Get-Process -Id ([int]$state.injectorPid) -ErrorAction SilentlyContinue)
}

$cdpReady = $false
$portOwned = $false
if ($cursorExe) {
  $script:CdsCursorExe = $cursorExe
  $cdpReady = Test-CdsCdpHttpReady -Port $port
  $portOwned = Test-CdsPortBelongsToCursor -Port $port
}

$status = [ordered]@{
  skinVersion   = $script:CdsSkinVersion
  projectRoot   = $script:CdsProjectRoot
  stateRoot     = $script:CdsStateRoot
  cursorExe     = $cursorExe
  cursorRunning = if ($cursorExe) { Test-CdsCursorRunning } else { $false }
  port          = $port
  cdpHttpReady  = $cdpReady
  portOwnedByCursor = $portOwned
  cdpReady      = ($cdpReady -and $portOwned)
  injectorPid   = if ($state) { $state.injectorPid } else { $null }
  injectorAlive = $injectorAlive
  activeTheme   = $themeDir
  state         = $state
}

$status | ConvertTo-Json -Depth 6
