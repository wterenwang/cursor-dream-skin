@echo off
REM Cursor Dream Skin — one-click install
setlocal
cd /d "%~dp0"

echo.
echo  Cursor Dream Skin — 正在安装推荐主题，并准备小助手...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-dream-skin.ps1"
if errorlevel 1 (
  echo.
  echo  安装没有完成，请看上面的说明。
  pause
  exit /b 1
)

echo.
echo  正在打开管理界面（小助手图标已在右下角通知区）...
wscript.exe "%~dp0scripts\launch-gui.vbs"
exit /b 0
