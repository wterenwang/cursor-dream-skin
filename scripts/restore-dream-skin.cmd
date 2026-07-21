@echo off
setlocal
cd /d "%~dp0.."
title Cursor Dream Skin - Restore
echo.
echo Restoring official Cursor look...
echo 正在还原 Cursor 官方外观...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore-dream-skin.ps1"
set "EC=%ERRORLEVEL%"
echo.
if not "%EC%"=="0" echo Exit code: %EC%
echo Press any key to close...
pause >nul
exit /b %EC%
