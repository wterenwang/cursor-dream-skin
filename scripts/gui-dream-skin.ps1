# Deprecated WinForms GUI — redirects to the unified Edge web GUI.
# Kept so old shortcuts / habits still open the current product surface.

$ErrorActionPreference = 'Stop'
$vbs = Join-Path $PSScriptRoot 'launch-gui.vbs'
if (-not (Test-Path -LiteralPath $vbs)) {
  throw "Missing launcher: $vbs"
}
Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$vbs`"" | Out-Null
