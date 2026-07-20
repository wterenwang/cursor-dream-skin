@echo off
REM Cursor Dream Skin — one-click install (shortcuts) + open GUI
setlocal
cd /d "%~dp0"

echo.
echo  Cursor Dream Skin — installing shortcuts...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-dream-skin.ps1"
if errorlevel 1 (
  echo.
  echo  Install failed. See messages above.
  pause
  exit /b 1
)

echo.
echo  Opening Dream Skin GUI...
wscript.exe "%~dp0scripts\launch-gui.vbs"
exit /b 0
