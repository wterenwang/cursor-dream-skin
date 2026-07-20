' Launch Cursor Dream Skin web GUI (no console). Single product entry.
' Delegates to launch-gui.ps1 which reuses a healthy server or restarts a dead one.
Option Explicit
Dim sh, fso, root, ps1, cmd, savedExe, envPath
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
ps1 = root & "\scripts\launch-gui.ps1"
envPath = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%LOCALAPPDATA%")
savedExe = envPath & "\CursorDreamSkin\cursor-exe.txt"
Set sh = CreateObject("WScript.Shell")
sh.CurrentDirectory = root

If fso.FileExists(savedExe) Then
  Dim raw
  raw = Trim(fso.OpenTextFile(savedExe, 1, False, 0).ReadAll)
  If Len(raw) > 0 And fso.FileExists(raw) Then
    sh.Environment("Process")("CURSOR_EXE") = raw
  End If
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """"
sh.Run cmd, 0, False
