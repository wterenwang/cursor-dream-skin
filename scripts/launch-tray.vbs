' Launch Cursor Dream Skin system tray (no console).
Option Explicit
Dim sh, fso, root, ps1, cmd, savedExe, envPath, pidFile, pid
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
ps1 = root & "\scripts\tray-dream-skin.ps1"
envPath = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%")
savedExe = envPath & "\CursorDreamSkin\cursor-exe.txt"
pidFile = envPath & "\CursorDreamSkin\tray.pid"
Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = root

If fso.FileExists(savedExe) Then
  Dim raw
  raw = Trim(fso.OpenTextFile(savedExe, 1, False, 0).ReadAll)
  If Len(raw) > 0 And fso.FileExists(raw) Then
    sh.Environment("Process")("CURSOR_EXE") = raw
  End If
End If

' Tray script enforces its own single-instance mutex; just launch STA PowerShell.
cmd = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -Silent"
sh.Run cmd, 0, False
