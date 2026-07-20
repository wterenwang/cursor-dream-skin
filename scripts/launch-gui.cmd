@echo off
REM Unified entry: same reliable launcher as the desktop shortcut.
setlocal
cd /d "%~dp0.."
wscript.exe "%~dp0launch-gui.vbs"
exit /b 0
