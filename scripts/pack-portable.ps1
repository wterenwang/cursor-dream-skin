# Build a portable zip: extract anywhere, double-click Install.cmd
param(
  [string]$OutDir = ([Environment]::GetFolderPath('Desktop'))
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'common-windows.ps1')

$stamp = Get-Date -Format 'yyyyMMdd'
$zipName = "CursorDreamSkin-portable-$stamp.zip"
$zipPath = Join-Path $OutDir $zipName
$stage = Join-Path $env:TEMP ("cds-portable-" + [Guid]::NewGuid().ToString('N'))
$payload = Join-Path $stage 'CursorDreamSkin'

New-Item -ItemType Directory -Force -Path $payload | Out-Null

$excludeDirs = @('.git', 'node_modules', '.cursor')
Get-ChildItem -LiteralPath $root -Force | ForEach-Object {
  if ($excludeDirs -contains $_.Name) { return }
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $payload $_.Name) -Recurse -Force
}

# Ensure Install.cmd exists in package root
$installCmd = Join-Path $payload 'Install.cmd'
if (-not (Test-Path -LiteralPath $installCmd)) {
  throw "Missing Install.cmd in package"
}

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path $payload -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stage -Recurse -Force

Write-Host "Portable zip ready:"
Write-Host "  $zipPath"
Write-Host "Extract, then double-click Install.cmd"
