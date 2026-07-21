[CmdletBinding()]
param(
  [int]$Port
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$null = Find-CdsCursorExe

$resolvedPort = $Port
if (-not $resolvedPort) {
  $state = Read-CdsState
  if ($state -and $state.port) { $resolvedPort = [int]$state.port }
}

Stop-CdsRecordedInjector
Stop-CdsStrayInjectors

$removed = 'skipped'
if ($resolvedPort -and (Test-CdsCdpHttpReady -Port $resolvedPort)) {
  $result = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--remove', '--port', "$resolvedPort", '--timeout-ms', '10000'
  ) -PassThru
  if ($result.ExitCode -eq 0) {
    $removed = 'ok'
  } else {
    $removed = 'partial'
  }
}

if (Test-Path -LiteralPath $script:CdsStatePath) {
  Remove-Item -LiteralPath $script:CdsStatePath -Force
}

if ($removed -eq 'ok') {
  Write-Host '已还原：皮肤已从当前窗口去掉。'
} elseif ($removed -eq 'partial') {
  Write-Host '已尽量还原；若外观还在，请重新加载一下 Cursor 窗口。'
} else {
  Write-Host '本地状态已清理（当时没有可卸的皮肤窗口）。'
}
Write-Host '若想更干净：完全退出 Cursor，再用平常方式打开。'
[CmdletBinding()]
param(
  [int]$Port
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$null = Find-CdsCursorExe

$resolvedPort = $Port
if (-not $resolvedPort) {
  $state = Read-CdsState
  if ($state -and $state.port) { $resolvedPort = [int]$state.port }
}

Stop-CdsRecordedInjector
Stop-CdsStrayInjectors

$removed = 'skipped'
if ($resolvedPort -and (Test-CdsCdpHttpReady -Port $resolvedPort)) {
  $result = Invoke-CdsNode -ArgumentList @(
    $script:CdsInjector, '--remove', '--port', "$resolvedPort", '--timeout-ms', '10000'
  ) -PassThru
  if ($result.ExitCode -eq 0) {
    $removed = 'ok'
  } else {
    $removed = 'partial'
  }
}

if (Test-Path -LiteralPath $script:CdsStatePath) {
  Remove-Item -LiteralPath $script:CdsStatePath -Force
}

if ($removed -eq 'ok') {
  Write-Host '已还原：皮肤已从当前窗口去掉。'
} elseif ($removed -eq 'partial') {
  Write-Host '已尽量还原；若外观还在，请重新加载一下 Cursor 窗口。'
} else {
  Write-Host '本地状态已清理（当时没有可卸的皮肤窗口）。'
}
Write-Host '若想更干净：完全退出 Cursor，再用平常方式打开。'
