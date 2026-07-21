' Launch Cursor Dream Skin desk pet (no console).
Option Explicit
Dim sh, fso, root, ps1, cmd, savedExe, envPath
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
ps1 = root & "\scripts\deskpet-dream-skin.ps1"
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

cmd = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1 & """ -Silent"
sh.Run cmd, 0, False
