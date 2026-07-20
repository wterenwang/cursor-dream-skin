(() => {
  "use strict";

  const state = {
    lang: "zh",
    i18n: null,
    themes: [],
    busy: false,
    status: null,
    wizardOpen: false,
    showHidden: false,
  };

  const $ = (id) => document.getElementById(id);

  function t(key) {
    const bag = state.i18n?.[state.lang] || state.i18n?.en || {};
    return bag[key] || state.i18n?.en?.[key] || key;
  }

  function tf(key, ...args) {
    const fmt = t(key);
    return fmt.replace(/\{(\d+)\}/g, (_, i) => String(args[Number(i)] ?? ""));
  }

  function log(message, level = "info") {
    const el = $("log");
    const ts = new Date().toLocaleTimeString("en-GB", { hour12: false });
    const prefix = level === "ok" ? "[ok] " : level === "warn" ? "[!]  " : level === "error" ? "[x]  " : "     ";
    el.textContent += `${ts}  ${prefix}${message}\n`;
    el.scrollTop = el.scrollHeight;
  }

  function applyI18n() {
    document.documentElement.lang = state.lang === "zh" ? "zh-CN" : "en";
    document.title = t("appTitle");
    document.querySelectorAll("[data-i18n]").forEach((node) => {
      const key = node.getAttribute("data-i18n");
      if (node.tagName === "OPTION") node.textContent = t(key);
      else node.textContent = t(key);
    });
    document.querySelectorAll("[data-i18n-placeholder]").forEach((node) => {
      node.setAttribute("placeholder", t(node.getAttribute("data-i18n-placeholder")));
    });
    $("btn-en").classList.toggle("is-active", state.lang === "en");
    $("btn-zh").classList.toggle("is-active", state.lang === "zh");
    if (state.status) renderStatus(state.status);
  }

  async function api(path, options = {}) {
    const res = await fetch(path, {
      headers: { "Content-Type": "application/json", ...(options.headers || {}) },
      ...options,
    });
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = { raw: text }; }
    if (!res.ok) {
      throw new Error(data?.error || data?.message || `HTTP ${res.status}`);
    }
    return data;
  }

  function setBusy(busy) {
    state.busy = busy;
    [
      "btn-apply", "btn-restore", "btn-refresh", "theme-select",
      "btn-en", "btn-zh", "btn-create", "btn-pick", "btn-open-themes",
      "custom-name", "custom-mode", "btn-change-cursor",
      "wizard-browse", "wizard-continue", "wizard-path",
      "chk-show-hidden", "chk-pair-color",
      "tune-dim", "tune-editor", "tune-position",
      "btn-save-tune", "btn-delete-theme",
    ].forEach((id) => {
      const el = $(id);
      if (el) el.disabled = busy;
    });
  }

  function slugify(name) {
    let base = String(name || "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 40);
    if (!base || !/^[a-z0-9]/.test(base)) {
      base = `theme-${Date.now().toString(36)}`;
    }
    return base;
  }

  function statusHeadline(s) {
    const found = s.cursorFound ?? Boolean(s.cursorExe);
    if (!found) return t("cursorMissing");
    if (s.skinActive) return t("skinActive");
    if (s.cdpReady) return t("cdpIdle");
    if (s.cursorRunning) return t("restartNeeded");
    return t("readyLaunch");
  }

  function renderStatus(s) {
    state.status = s;
    const text = $("status-text");
    const rail = $("status-rail");
    const hint = $("status-hint");
    const found = s.cursorFound ?? Boolean(s.cursorExe);
    const tone = s.statusTone || (s.skinActive ? "ok" : found ? (s.cursorRunning && !s.cdpReady ? "warn" : "idle") : "danger");
    text.textContent = statusHeadline(s);
    rail.dataset.tone = tone;
    const hintKey = s.hintKey || (found ? (s.skinActive ? "hintSkinActive" : "hintReady") : "hintNeedCursor");
    hint.textContent = t(hintKey);

    const list = $("status-checks");
    list.innerHTML = "";
    const checks = s.checks || [
      { ok: found, key: "checkCursor" },
      { ok: Boolean(s.cursorRunning), key: "checkRunning" },
      { ok: Boolean(s.cdpReady), key: "checkCdp" },
      { ok: Boolean(s.injectorAlive), key: "checkInjector" },
      { ok: Boolean(s.skinActive), key: "checkSkin" },
    ];
    checks.forEach((check) => {
      const li = document.createElement("li");
      li.className = check.ok ? "is-ok" : "is-off";
      li.textContent = t(check.key);
      list.appendChild(li);
    });

    $("meta-cursor").textContent = s.cursorExe || t("cursorMissing");
    $("meta-cursor").title = s.cursorExe || "";
    $("meta-theme").textContent = s.themeName || t("none");
    $("meta-port").textContent = String(s.port ?? "-");

    $("btn-apply").disabled = state.busy || !found;
  }

  function maybeShowWizard(s) {
    if (!s?.needsSetup) return;
    if (state.wizardOpen) return;
    const dialog = $("wizard");
    $("wizard-path").value = s.cursorExe || "";
    state.wizardOpen = true;
    if (!dialog.open) dialog.showModal();
  }

  function closeWizard() {
    const dialog = $("wizard");
    if (dialog.open) dialog.close();
    state.wizardOpen = false;
  }

  function renderThemes(themes, activeId) {
    state.themes = themes;
    const sel = $("theme-select");
    const prev = sel.value;
    sel.innerHTML = "";
    themes.forEach((theme) => {
      const opt = document.createElement("option");
      opt.value = theme.id;
      const tag = theme.hidden ? " · dev" : (theme.custom ? " · custom" : "");
      opt.textContent = `${theme.name}  -  ${theme.id}${tag}`;
      if (theme.id === activeId || theme.id === prev) opt.selected = true;
      sel.appendChild(opt);
    });
    if (activeId && [...sel.options].some((o) => o.value === activeId)) {
      sel.value = activeId;
    }
    updatePreview();
    syncTuneFromSelected();
  }

  function selectedTheme() {
    const id = $("theme-select").value;
    return state.themes.find((x) => x.id === id) || null;
  }

  function syncTuneFromSelected() {
    const theme = selectedTheme();
    const del = $("btn-delete-theme");
    if (!theme) {
      if (del) del.disabled = true;
      return;
    }
    const dim = Math.round((theme.dimAlpha ?? 0.2) * 100);
    const ed = Math.round((theme.editorAlpha ?? 0.9) * 100);
    $("tune-dim").value = String(Math.max(0, Math.min(60, dim)));
    $("tune-editor").value = String(Math.max(50, Math.min(100, ed)));
    $("tune-dim-val").textContent = (Number($("tune-dim").value) / 100).toFixed(2);
    $("tune-editor-val").textContent = (Number($("tune-editor").value) / 100).toFixed(2);
    const pos = theme.artPosition || "center";
    const posSel = $("tune-position");
    if (![...posSel.options].some((o) => o.value === pos)) {
      const opt = document.createElement("option");
      opt.value = pos;
      opt.textContent = pos;
      posSel.appendChild(opt);
    }
    posSel.value = pos;
    if (del) del.disabled = state.busy || !theme.deletable;
  }

  function updatePreview() {
    const id = $("theme-select").value;
    const theme = state.themes.find((x) => x.id === id);
    const img = $("preview-img");
    const cap = $("preview-cap");
    const box = $("preview");
    if (!theme) {
      img.hidden = true;
      box.classList.remove("has-art");
      cap.textContent = t("previewEmpty");
      return;
    }
    img.src = `/api/theme-art/${encodeURIComponent(theme.id)}?t=${Date.now()}`;
    img.hidden = false;
    box.classList.add("has-art");
    cap.textContent = theme.name;
    img.onerror = () => {
      img.hidden = true;
      box.classList.remove("has-art");
      cap.textContent = t("previewEmpty");
    };
  }

  function askConfirm(title, body) {
    return new Promise((resolve) => {
      const dialog = $("confirm");
      $("confirm-title").textContent = title;
      $("confirm-body").textContent = body;
      const onClose = () => {
        dialog.removeEventListener("close", onClose);
        resolve(dialog.returnValue === "ok");
      };
      dialog.addEventListener("close", onClose);
      dialog.showModal();
    });
  }

  async function refreshAll() {
    const q = state.showHidden ? "?showHidden=1" : "";
    const [status, themesPayload] = await Promise.all([
      api("/api/status"),
      api("/api/themes" + q),
    ]);
    if (status.lang) state.lang = status.lang;
    applyI18n();
    renderStatus(status);
    renderThemes(themesPayload.themes || [], status.themeId);
    maybeShowWizard(status);
  }

  async function setLang(lang) {
    state.lang = lang;
    applyI18n();
    await api("/api/lang", { method: "POST", body: JSON.stringify({ lang }) });
    const status = await api("/api/status");
    renderStatus(status);
    maybeShowWizard(status);
    log(t("welcome"));
  }

  async function browseCursor() {
    setBusy(true);
    try {
      const result = await api("/api/browse-cursor", { method: "POST", body: "{}" });
      if (result.cancelled || !result.ok) {
        log(t("wizardCancelled"), "warn");
        return null;
      }
      if (result.cursorExe) $("wizard-path").value = result.cursorExe;
      if (result.status) renderStatus(result.status);
      log(t("wizardSaved"), "ok");
      return result.cursorExe;
    } finally {
      setBusy(false);
    }
  }

  async function finishWizard(ev) {
    if (ev) ev.preventDefault();
    const path = ($("wizard-path").value || "").trim();
    if (!path) {
      log(t("wizardNeedPath"), "warn");
      return;
    }
    setBusy(true);
    try {
      const result = await api("/api/set-cursor", {
        method: "POST",
        body: JSON.stringify({ path, completeSetup: true }),
      });
      log(t("wizardSaved"), "ok");
      closeWizard();
      if (result.status) {
        renderStatus(result.status);
      } else {
        await refreshAll();
      }
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  }

  async function onChangeCursor() {
    $("wizard-path").value = state.status?.cursorExe || "";
    state.wizardOpen = true;
    $("wizard").showModal();
  }

  async function onCreateTheme() {
    const name = ($("custom-name").value || "").trim();
    const file = $("custom-file").files?.[0];
    const mode = $("custom-mode").value || "auto";
    if (!file) {
      log(t("needImage"), "warn");
      return;
    }
    if (!name) {
      log(t("needName"), "warn");
      return;
    }
    if (file.size > 20 * 1024 * 1024) {
      log(t("imageTooBig"), "error");
      return;
    }

    const ext = (file.name.split(".").pop() || "png").toLowerCase();
    if (!["png", "jpg", "jpeg", "webp"].includes(ext)) {
      log(t("needImage"), "warn");
      return;
    }

    setBusy(true);
    try {
      log(t("creating"));
      const id = slugify(name);
      const res = await fetch("/api/create-theme", {
        method: "POST",
        headers: {
          "Content-Type": file.type || "application/octet-stream",
          "X-Theme-Id": id,
          "X-Theme-Name": encodeURIComponent(name),
          "X-Theme-Mode": mode,
          "X-Image-Ext": ext === "jpeg" ? "jpg" : ext,
        },
        body: file,
      });
      const text = await res.text();
      let result = null;
      try { result = text ? JSON.parse(text) : null; } catch { result = { error: text }; }
      if (!res.ok) throw new Error(result?.error || result?.message || `HTTP ${res.status}`);
      log(tf("createdOk", result.themeId || id), "ok");
      $("custom-file").value = "";
      $("file-name").textContent = "-";
      await refreshAll();
      if (result.themeId) {
        $("theme-select").value = result.themeId;
        updatePreview();
      }
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  }

  async function onApply() {
    const themeId = $("theme-select").value;
    if (!themeId) {
      log(t("selectTheme"), "warn");
      return;
    }
    if (!(state.status?.cursorFound ?? Boolean(state.status?.cursorExe))) {
      maybeShowWizard({ needsSetup: true, cursorExe: "" });
      log(t("wizardNeedPath"), "warn");
      return;
    }
    setBusy(true);
    try {
      const status = await api("/api/status");
      let allowRestart = false;
      if (status.cursorRunning && !status.cdpReady) {
        const ok = await askConfirm(t("restartTitle"), t("restartBody"));
        if (!ok) {
          log(t("applyCancelled"), "warn");
          return;
        }
        allowRestart = true;
      }
      log(tf("applying", themeId));
      const result = await api("/api/apply", {
        method: "POST",
        body: JSON.stringify({ themeId, allowRestart }),
      });
      (result.logs || []).forEach((line) => log(line.message, line.level || "info"));
      if (result.softVerify) log(t("softVerifyWarn"), "warn");
      else log(t("appliedOk"), "ok");
      await refreshAll();
      if ($("chk-pair-color").checked) {
        const mode = (result.themeMode || selectedTheme()?.mode || "dark").toLowerCase();
        const body = mode === "light" ? t("pairBodyLight") : t("pairBodyDark");
        await askConfirm(t("pairTitle"), body);
      }
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  }

  async function onSaveTune() {
    const theme = selectedTheme();
    if (!theme) return;
    setBusy(true);
    try {
      const result = await api("/api/update-theme", {
        method: "POST",
        body: JSON.stringify({
          themeId: theme.id,
          dimAlpha: Number($("tune-dim").value) / 100,
          editorAlpha: Number($("tune-editor").value) / 100,
          artPosition: $("tune-position").value,
          reapply: true,
        }),
      });
      log(t("tuneSaved"), "ok");
      if (result.hot?.hot) log(t("tuneHot"), "ok");
      await refreshAll();
      $("theme-select").value = theme.id;
      syncTuneFromSelected();
      updatePreview();
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  }

  async function onDeleteTheme() {
    const theme = selectedTheme();
    if (!theme) return;
    if (!theme.deletable) {
      log(t("deleteBlocked"), "warn");
      return;
    }
    const ok = await askConfirm(t("deleteTitle"), tf("deleteBody", theme.name));
    if (!ok) return;
    setBusy(true);
    try {
      await api("/api/delete-theme", {
        method: "POST",
        body: JSON.stringify({ themeId: theme.id }),
      });
      log(tf("deleteOk", theme.id), "ok");
      await refreshAll();
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  }

  async function onRestore() {
    const ok = await askConfirm(t("restoreTitle"), t("restoreBody"));
    if (!ok) return;
    setBusy(true);
    try {
      log(t("restoring"));
      const result = await api("/api/restore", { method: "POST", body: "{}" });
      (result.logs || []).forEach((line) => log(line.message, line.level || "info"));
      log(t("restoreOk"), "ok");
      await refreshAll();
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  }

  async function boot() {
    try {
      const i18n = await api("/api/i18n");
      state.i18n = i18n;
      const status = await api("/api/status");
      state.lang = status.lang || "zh";
      applyI18n();
      await refreshAll();
      log(t("welcome"));
    } catch (err) {
      $("status-text").textContent = err.message || String(err);
      log(err.message || String(err), "error");
    }
  }

  $("btn-en").addEventListener("click", () => setLang("en"));
  $("btn-zh").addEventListener("click", () => setLang("zh"));
  $("btn-refresh").addEventListener("click", async () => {
    setBusy(true);
    try {
      await refreshAll();
      log(t("refreshed"));
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  });
  $("btn-apply").addEventListener("click", onApply);
  $("btn-restore").addEventListener("click", onRestore);
  $("theme-select").addEventListener("change", () => {
    updatePreview();
    syncTuneFromSelected();
  });
  $("tune-dim").addEventListener("input", () => {
    $("tune-dim-val").textContent = (Number($("tune-dim").value) / 100).toFixed(2);
  });
  $("tune-editor").addEventListener("input", () => {
    $("tune-editor-val").textContent = (Number($("tune-editor").value) / 100).toFixed(2);
  });
  $("btn-save-tune").addEventListener("click", onSaveTune);
  $("btn-delete-theme").addEventListener("click", onDeleteTheme);
  $("chk-show-hidden").addEventListener("change", async () => {
    state.showHidden = $("chk-show-hidden").checked;
    setBusy(true);
    try {
      await refreshAll();
    } catch (err) {
      log(err.message || String(err), "error");
    } finally {
      setBusy(false);
    }
  });
  $("btn-pick").addEventListener("click", () => $("custom-file").click());
  $("custom-file").addEventListener("change", () => {
    const file = $("custom-file").files?.[0];
    $("file-name").textContent = file ? file.name : "-";
    if (file && !$("custom-name").value.trim()) {
      $("custom-name").value = file.name.replace(/\.[^.]+$/, "").slice(0, 40);
    }
  });
  $("btn-create").addEventListener("click", onCreateTheme);
  $("btn-open-themes").addEventListener("click", async () => {
    try {
      await api("/api/open-themes", { method: "POST", body: "{}" });
    } catch (err) {
      log(err.message || String(err), "error");
    }
  });
  $("btn-change-cursor").addEventListener("click", onChangeCursor);
  $("wizard-browse").addEventListener("click", (ev) => {
    ev.preventDefault();
    browseCursor();
  });
  $("wizard-form").addEventListener("submit", finishWizard);
  $("wizard").addEventListener("cancel", (ev) => {
    // Allow Esc only when Cursor is already known; otherwise keep guiding.
    if (!state.status?.cursorFound) {
      ev.preventDefault();
      return;
    }
    state.wizardOpen = false;
  });
  $("wizard").addEventListener("close", () => {
    state.wizardOpen = false;
  });

  boot();
})();
