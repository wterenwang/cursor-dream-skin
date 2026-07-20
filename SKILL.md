---
name: cursor-dream-skin
description: Apply, launch, verify, switch, or restore a full decorative skin for the Windows Cursor IDE. Use when the user asks for a Cursor theme beyond official color settings, wants a wallpaper / glassmorphism interface, needs the skin reapplied after a Cursor update, or needs a safe rollback without modifying Cursor.exe or app.asar.
---

# Cursor Dream Skin (Windows)

Apply a reversible renderer skin through Chromium DevTools Protocol while launching the official Cursor executable. Never replace or take ownership of files under the Cursor install directory.

All commands assume this skill directory as the working directory (`SKILL_DIR`).

## Install once

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\install-dream-skin.ps1"
```

If Cursor is not auto-detected:

```powershell
$env:CURSOR_EXE = 'E:\cursor\Cursor.exe'
```

## Apply / start

1. Prefer checking status first:

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\status.ps1"
```

2. If `cdpReady` is false and Cursor is already running, warn the user that Cursor must restart once (this conversation may interrupt), then:

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\start-dream-skin.ps1" -PromptRestart
```

3. If Cursor is not running:

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\start-dream-skin.ps1"
```

## Switch theme (hot)

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\switch-theme.ps1" default
```

## Create theme from an image

```powershell
$env:ELECTRON_RUN_AS_NODE = '1'
& $env:CURSOR_EXE "$SKILL_DIR\scripts\make-theme.mjs" --image C:\path\to\art.png --id my-theme --name "My Theme"
Remove-Item Env:ELECTRON_RUN_AS_NODE
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\switch-theme.ps1" my-theme
```

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\verify-dream-skin.ps1"
```

Optional screenshot:

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\verify-dream-skin.ps1" -Screenshot "$env:TEMP\cds-verify.png"
```

## Restore

```powershell
powershell -ExecutionPolicy Bypass -File "$SKILL_DIR\scripts\restore-dream-skin.ps1"
```

## Guardrails

- Never modify `Cursor.exe`, `app.asar`, or code signatures.
- CDP must stay on `127.0.0.1`. Scripts validate the port belongs to Cursor.
- Never restart Cursor without user consent (`-PromptRestart` dialog or explicit chat confirmation).
- Keep decoration layers non-interactive (`pointer-events: none`).
- Do not auto-edit the user's `settings.json` unless asked.

## Key files

- `scripts/injector.mjs` — CDP connect / inject / remove / verify / watch
- `scripts/make-theme.mjs` — image → palette → theme directory
- `scripts/start-dream-skin.ps1` / `restore-dream-skin.ps1` / `switch-theme.ps1` / `verify-dream-skin.ps1` / `status.ps1`
- `assets/dream-skin.css` + `assets/renderer-inject.js` — injected payload
- `themes/default` — bundled Dream Night theme
- `references/runtime-notes.md` — Cursor DOM / CDP notes
