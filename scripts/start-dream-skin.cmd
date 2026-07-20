@echo off
setlocal
cd /d "%~dp0.."
title Cursor Dream Skin
echo.
echo Cursor Dream Skin launcher
echo Working directory: %CD%
echo.
if defined CURSOR_EXE goto run
if exist "E:\cursor\Cursor.exe" set "CURSOR_EXE=E:\cursor\Cursor.exe"
if exist "%LOCALAPPDATA%\Programs\cursor\Cursor.exe" set "CURSOR_EXE=%LOCALAPPDATA%\Programs\cursor\Cursor.exe"
if exist "%LOCALAPPDATA%\Programs\Cursor\Cursor.exe" set "CURSOR_EXE=%LOCALAPPDATA%\Programs\Cursor\Cursor.exe"
:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-dream-skin.ps1" -PromptRestart
set "EC=%ERRORLEVEL%"
echo.
if not "%EC%"=="0" (
  echo Exit code: %EC%
)
echo Press any key to close...
pause >nul
exit /b %EC%
