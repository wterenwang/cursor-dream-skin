// Cursor Dream Skin injector — CDP connect / inject / remove / verify / screenshot / watch.
// Runs on Cursor's own Electron binary via ELECTRON_RUN_AS_NODE (Node 22+, native fetch/WebSocket).
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
export const SKIN_VERSION = "1.1.0";
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]"]);
const MAX_ART_BYTES = 20 * 1024 * 1024;

function parseArgs(argv) {
  const options = { port: 9666, mode: "watch", timeoutMs: 30000, screenshot: null, themeDir: null };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--port") options.port = Number(argv[++i]);
    else if (arg === "--once") options.mode = "once";
    else if (arg === "--watch") options.mode = "watch";
    else if (arg === "--verify") options.mode = "verify";
    else if (arg === "--remove") options.mode = "remove";
    else if (arg === "--check-payload") options.mode = "check";
    else if (arg === "--timeout-ms") options.timeoutMs = Number(argv[++i]);
    else if (arg === "--screenshot") options.screenshot = path.resolve(argv[++i]);
    else if (arg === "--theme-dir") options.themeDir = path.resolve(argv[++i]);
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!Number.isInteger(options.port) || options.port < 1024 || options.port > 65535) {
    throw new Error(`Invalid port: ${options.port}`);
  }
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs < 250 || options.timeoutMs > 180000) {
    throw new Error(`Invalid timeout: ${options.timeoutMs}`);
  }
  return options;
}

function validatedDebuggerUrl(target, port) {
  const url = new URL(target.webSocketDebuggerUrl);
  if (url.protocol !== "ws:" || !LOOPBACK_HOSTS.has(url.hostname) || Number(url.port) !== port) {
    throw new Error(`Rejected non-loopback CDP WebSocket URL: ${url.href}`);
  }
  return url.href;
}

class CdpSession {
  constructor(target, port) {
    this.target = target;
    this.ws = new WebSocket(validatedDebuggerUrl(target, port));
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    this.closed = false;
  }

  async open() {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("CDP WebSocket open timed out")), 5000);
      this.ws.addEventListener("open", () => { clearTimeout(timeout); resolve(); }, { once: true });
      this.ws.addEventListener("error", () => { clearTimeout(timeout); reject(new Error("CDP WebSocket open failed")); }, { once: true });
    });
    this.ws.addEventListener("message", (event) => this.onMessage(event));
    this.ws.addEventListener("close", () => {
      this.closed = true;
      for (const waiter of this.pending.values()) {
        clearTimeout(waiter.timeout);
        waiter.reject(new Error("CDP socket closed"));
      }
      this.pending.clear();
    });
    await this.send("Runtime.enable");
    await this.send("Page.enable");
    return this;
  }

  onMessage(event) {
    const message = JSON.parse(String(event.data));
    if (message.id) {
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      clearTimeout(waiter.timeout);
      this.pending.delete(message.id);
      if (message.error) waiter.reject(new Error(`${message.error.message} (${message.error.code})`));
      else waiter.resolve(message.result);
      return;
    }
    for (const listener of this.listeners.get(message.method) ?? []) listener(message.params ?? {});
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) ?? [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }

  send(method, params = {}) {
    if (this.closed) return Promise.reject(new Error("CDP session is closed"));
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP command timed out: ${method}`));
      }, 15000);
      this.pending.set(id, { resolve, reject, timeout });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
      userGesture: false,
    });
    if (result.exceptionDetails) {
      const detail = result.exceptionDetails.exception?.description ?? result.exceptionDetails.text;
      throw new Error(`Renderer evaluation failed: ${detail}`);
    }
    return result.result?.value;
  }

  close() {
    if (!this.closed) this.ws.close();
    this.closed = true;
  }
}

async function listWorkbenchTargets(port) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const targets = await response.json();
    return targets.filter((item) => {
      if (item.type !== "page" || !item.webSocketDebuggerUrl) return false;
      if (!item.url?.startsWith("vscode-file://vscode-app/")) return false;
      if (!item.url.includes("/workbench/workbench")) return false;
      try {
        validatedDebuggerUrl(item, port);
        return true;
      } catch {
        return false;
      }
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function probeSession(session) {
  return session.evaluate(`(() => {
    const markers = {
      workbench: Boolean(document.querySelector('.monaco-workbench')),
      statusbar: Boolean(document.querySelector('.part.statusbar')),
      editorPart: Boolean(document.querySelector('.part.editor')),
      // Agents window: React shell, .monaco-workbench exists but stays hidden.
      agentPanel: Boolean(document.querySelector('.agent-panel')),
      agentSidebar: Boolean(document.querySelector('nav.ui-sidebar')),
    };
    const cursorWorkbench = markers.workbench && (markers.statusbar || markers.editorPart);
    const cursorAgents = markers.workbench && !cursorWorkbench && (markers.agentPanel || markers.agentSidebar);
    return {
      title: document.title,
      href: location.href,
      markers,
      kind: cursorWorkbench ? "workbench" : cursorAgents ? "agents" : null,
      cursorWorkbench,
      skinnable: cursorWorkbench || cursorAgents,
    };
  })()`);
}

async function connectCursorTargets(port, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const targets = await listWorkbenchTargets(port);
      const connected = [];
      for (const target of targets) {
        let session;
        try {
          session = await new CdpSession(target, port).open();
          const probe = await probeSession(session);
          if (probe?.skinnable) connected.push({ target, session, probe });
          else session.close();
        } catch (error) {
          session?.close();
          lastError = error;
        }
      }
      if (connected.length) return connected;
      lastError = new Error("No page matched the Cursor workbench markers");
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error(`No verified Cursor workbench on 127.0.0.1:${port}: ${lastError?.message ?? "timed out"}`);
}

const HEX_COLOR = /^#[0-9a-f]{6}([0-9a-f]{2})?$/i;
const FUNC_COLOR = /^rgba?\([0-9., %]+\)$/i;

function sanitizeColor(value, fallback) {
  if (typeof value !== "string") return fallback;
  const normalized = value.trim();
  return HEX_COLOR.test(normalized) || FUNC_COLOR.test(normalized) ? normalized : fallback;
}

/** Raise rgba()/rgb() alpha so busy wallpapers cannot wash out glyphs. */
function ensureMinAlpha(value, minAlpha) {
  const raw = String(value || "").trim();
  const m = /^rgba?\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)(?:\s*,\s*([0-9.]+))?\s*\)$/i.exec(raw);
  if (!m) return value;
  const r = Number(m[1]);
  const g = Number(m[2]);
  const b = Number(m[3]);
  const a = m[4] === undefined ? 1 : Number(m[4]);
  if (![r, g, b, a].every((n) => Number.isFinite(n))) return value;
  const next = Math.min(1, Math.max(a, minAlpha));
  if (next === a) return raw.startsWith("rgb(") && m[4] === undefined ? raw : `rgba(${r}, ${g}, ${b}, ${a})`;
  return `rgba(${r}, ${g}, ${b}, ${Number(next.toFixed(3))})`;
}

function ensureReadableColors(colors, mode, artMode) {
  const dark = String(mode || "dark").toLowerCase() !== "light";
  const mascot = String(artMode || "").toLowerCase() === "mascot";
  // Mascot themes are not wallpapers: panels stay nearly solid so the figure only peeks from the corner.
  let floors;
  if (mascot) {
    floors = dark
      ? { dim: 0.08, chrome: 0.92, sidebar: 0.94, editor: 0.97, aiPane: 0.95, input: 0.96, widget: 0.98 }
      : { dim: 0.06, chrome: 0.90, sidebar: 0.92, editor: 0.96, aiPane: 0.94, input: 0.96, widget: 0.98 };
  } else {
    floors = dark
      ? { dim: 0.32, chrome: 0.82, sidebar: 0.84, editor: 0.94, aiPane: 0.88, input: 0.94, widget: 0.97 }
      : { dim: 0.18, chrome: 0.78, sidebar: 0.80, editor: 0.92, aiPane: 0.86, input: 0.94, widget: 0.97 };
  }
  return {
    ...colors,
    dim: ensureMinAlpha(colors.dim, floors.dim),
    chrome: ensureMinAlpha(colors.chrome, floors.chrome),
    sidebar: ensureMinAlpha(colors.sidebar, floors.sidebar),
    editor: ensureMinAlpha(colors.editor, floors.editor),
    aiPane: ensureMinAlpha(colors.aiPane, floors.aiPane),
    input: ensureMinAlpha(colors.input, floors.input),
    widget: ensureMinAlpha(colors.widget, floors.widget),
  };
}

function sanitizeText(value, fallback, max) {
  return typeof value === "string" && value.trim() ? value.trim().slice(0, max) : fallback;
}

function sanitizeMotto(value) {
  if (typeof value !== "string") return "";
  return value.replace(/[\\"\n\r<>]/g, "").trim().slice(0, 18);
}

function sanitizeArtMode(value) {
  const v = String(value || "wallpaper").toLowerCase();
  return ["wallpaper", "mascot", "atmosphere"].includes(v) ? v : "wallpaper";
}

export async function loadTheme(themeDir) {
  const assetsRoot = themeDir ?? path.join(root, "themes", "default");
  const configPath = path.join(assetsRoot, "theme.json");
  const raw = JSON.parse(await fs.readFile(configPath, "utf8"));
  if (raw.schemaVersion !== 1 || typeof raw.image !== "string" || !raw.image) {
    throw new Error(`${configPath} has an unsupported schema or missing image field`);
  }
  if (path.basename(raw.image) !== raw.image) {
    throw new Error("Theme image must live inside its theme directory (no path segments)");
  }
  const colors = raw.colors ?? {};
  const decor = raw.decor && typeof raw.decor === "object" ? raw.decor : {};
  const theme = {
    schemaVersion: 1,
    id: sanitizeText(raw.id, "custom", 80),
    name: sanitizeText(raw.name, "Cursor Dream Skin", 80),
    mode: sanitizeText(raw.mode, "dark", 10),
    image: raw.image,
    artMode: sanitizeArtMode(raw.artMode),
    artFit: sanitizeText(raw.artFit, "cover", 20),
    artPosition: sanitizeText(raw.artPosition, "center", 40),
    artFilter: sanitizeText(raw.artFilter, "none", 120),
    backdrop: sanitizeText(raw.backdrop, "transparent", 420),
    mascotWidth: sanitizeText(raw.mascotWidth, "min(26vw, 320px)", 40),
    mascotHeight: sanitizeText(raw.mascotHeight, "min(58vh, 560px)", 40),
    mascotOpacity: sanitizeText(String(raw.mascotOpacity ?? "0.95"), "0.95", 8),
    flavor: sanitizeText(raw.flavor, "", 40),
    decor: {
      statusStripe: Boolean(decor.statusStripe),
      activityGlow: Boolean(decor.activityGlow),
      sidebarBloom: Boolean(decor.sidebarBloom),
      tabPearl: Boolean(decor.tabPearl),
      aipaneRibbon: Boolean(decor.aipaneRibbon),
      motto: sanitizeMotto(decor.motto),
    },
    colors: ensureReadableColors({
      dim: sanitizeColor(colors.dim, "rgba(8, 6, 18, 0.32)"),
      chrome: sanitizeColor(colors.chrome, "rgba(16, 12, 34, 0.82)"),
      sidebar: sanitizeColor(colors.sidebar, sanitizeColor(colors.chrome, "rgba(16, 12, 34, 0.84)")),
      editor: sanitizeColor(colors.editor, "rgba(12, 10, 26, 0.94)"),
      aiPane: sanitizeColor(colors.aiPane, "rgba(16, 12, 34, 0.88)"),
      input: sanitizeColor(colors.input, "rgba(28, 22, 52, 0.94)"),
      widget: sanitizeColor(colors.widget, "rgba(20, 16, 40, 0.97)"),
      foreground: sanitizeColor(colors.foreground, "#eae6f5"),
      mutedForeground: sanitizeColor(colors.mutedForeground, "rgba(234, 230, 245, 0.72)"),
      accent: sanitizeColor(colors.accent, "#c792ea"),
      line: sanitizeColor(colors.line, "rgba(199, 146, 234, 0.25)"),
    }, raw.mode, raw.artMode),
  };
  const imagePath = path.join(assetsRoot, theme.image);
  const imageStat = await fs.stat(imagePath);
  if (!imageStat.isFile() || imageStat.size < 1 || imageStat.size > MAX_ART_BYTES) {
    throw new Error(`Theme image must be a non-empty file no larger than ${MAX_ART_BYTES} bytes`);
  }
  const extension = path.extname(theme.image).toLowerCase();
  if (![".png", ".jpg", ".jpeg", ".webp"].includes(extension)) {
    throw new Error(`Unsupported theme image format: ${extension || "missing"}`);
  }
  let extraCss = "";
  const extraCssPath = path.join(assetsRoot, "theme.css");
  try {
    extraCss = await fs.readFile(extraCssPath, "utf8");
  } catch {
    extraCss = "";
  }
  return { assetsRoot, imagePath, imageStat, theme, extraCss };
}

const MIME_BY_EXT = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp" };

export async function loadPayload(themeDir) {
  const loaded = await loadTheme(themeDir);
  const [css, template, art] = await Promise.all([
    fs.readFile(path.join(root, "assets", "dream-skin.css"), "utf8"),
    fs.readFile(path.join(root, "assets", "renderer-inject.js"), "utf8"),
    fs.readFile(loaded.imagePath),
  ]);
  const mime = MIME_BY_EXT[path.extname(loaded.theme.image).toLowerCase()];
  const artDataUrl = `data:${mime};base64,${art.toString("base64")}`;
  const cssBundle = loaded.extraCss ? `${css}\n/* ---- theme.css ---- */\n${loaded.extraCss}` : css;
  const payload = template
    .replace("__CDS_CSS_JSON__", JSON.stringify(cssBundle))
    .replace("__CDS_ART_JSON__", JSON.stringify(artDataUrl))
    .replace("__CDS_THEME_JSON__", JSON.stringify(loaded.theme))
    .replace("__CDS_VERSION_JSON__", JSON.stringify(SKIN_VERSION));
  return { imageBytes: art.length, payload, theme: loaded.theme };
}

async function removeFromSession(session) {
  return session.evaluate(`(() => {
    window.__CURSOR_DREAM_SKIN_DISABLED__ = true;
    const state = window.__CURSOR_DREAM_SKIN_STATE__;
    if (state?.cleanup) return state.cleanup();
    const html = document.documentElement;
    html.classList.remove('cursor-dream-skin');
    [
      'cdsMode', 'cdsArtMode', 'cdsFlavor', 'cdsStripe', 'cdsActivityGlow',
      'cdsSidebarBloom', 'cdsTabPearl', 'cdsAipaneRibbon', 'cdsMotto',
    ].forEach((k) => delete html.dataset[k]);
    document.getElementById('cursor-dream-skin-style')?.remove();
    document.getElementById('cursor-dream-skin-art')?.remove();
    delete window.__CURSOR_DREAM_SKIN_STATE__;
    return true;
  })()`);
}

async function verifyRemovedSession(session) {
  return session.evaluate(`(() =>
    !document.documentElement.classList.contains('cursor-dream-skin') &&
    !document.getElementById('cursor-dream-skin-style') &&
    !document.getElementById('cursor-dream-skin-art') &&
    !window.__CURSOR_DREAM_SKIN_STATE__
  )()`);
}

async function verifySession(session) {
  return session.evaluate(`(() => {
    const box = (node) => {
      if (!node) return null;
      const r = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      return {
        width: Math.round(r.width), height: Math.round(r.height),
        visible: r.width > 0 && r.height > 0 && style.display !== 'none' && style.visibility !== 'hidden',
      };
    };
    const art = document.getElementById('cursor-dream-skin-art');
    const wb = document.querySelector('.monaco-workbench');
    const result = {
      colorThemeKind: wb?.classList.contains('vs-dark') || wb?.classList.contains('hc-black') ? 'dark' : 'light',
      installed: document.documentElement.classList.contains('cursor-dream-skin'),
      version: window.__CURSOR_DREAM_SKIN_STATE__?.version ?? null,
      themeId: window.__CURSOR_DREAM_SKIN_STATE__?.themeId ?? null,
      stylePresent: Boolean(document.getElementById('cursor-dream-skin-style')),
      artPresent: Boolean(art),
      artPointerEvents: art ? getComputedStyle(art).pointerEvents : null,
      statusbar: box(document.querySelector('.part.statusbar')),
      editorPart: box(document.querySelector('.part.editor')),
      sidebar: box(document.querySelector('.part.sidebar')),
      agentPanel: box(document.querySelector('.agent-panel')),
      viewport: { width: innerWidth, height: innerHeight },
      documentOverflow: {
        x: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        y: document.documentElement.scrollHeight > document.documentElement.clientHeight,
      },
    };
    result.kind = result.statusbar?.visible || result.editorPart?.visible ? 'workbench' : 'agents';
    const surfacesOk = result.kind === 'workbench'
      ? Boolean(result.statusbar?.visible && result.editorPart?.visible)
      : Boolean(result.agentPanel?.visible);
    result.pass = Boolean(
      result.installed && result.stylePresent && result.artPresent &&
      result.artPointerEvents === 'none' &&
      surfacesOk &&
      !result.documentOverflow.x
    );
    return result;
  })()`);
}

async function waitForVerifiedSession(session, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastResult;
  while (Date.now() < deadline) {
    lastResult = await verifySession(session);
    if (lastResult.pass) return lastResult;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return lastResult;
}

async function capture(session, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await new Promise((resolve) => setTimeout(resolve, 250));
  const result = await session.send("Page.captureScreenshot", { format: "png", fromSurface: true });
  await fs.writeFile(outputPath, Buffer.from(result.data, "base64"));
}

function screenshotPathFor(base, index) {
  if (index === 0) return base;
  const parsed = path.parse(base);
  return path.join(parsed.dir, `${parsed.name}-${index + 1}${parsed.ext}`);
}

async function runOneShot(options) {
  const connected = await connectCursorTargets(options.port, options.timeoutMs);
  const payload = options.mode === "once" ? (await loadPayload(options.themeDir)).payload : null;
  const results = [];
  let screenshotCount = 0;

  for (const { target, session, probe } of connected) {
    try {
      if (options.mode === "remove") await removeFromSession(session);
      else if (options.mode === "once") await session.evaluate(payload);

      const result = options.mode === "remove"
        ? await verifyRemovedSession(session)
        : await waitForVerifiedSession(session, options.timeoutMs);
      const entry = { targetId: target.id, title: target.title, url: target.url, probe, result };

      if (options.screenshot) {
        entry.screenshot = screenshotPathFor(options.screenshot, screenshotCount++);
        await capture(session, entry.screenshot);
      }
      results.push(entry);
    } finally {
      session.close();
    }
  }

  console.log(JSON.stringify({ mode: options.mode, version: SKIN_VERSION, port: options.port, targets: results }, null, 2));
  const failed = results.length === 0 || results.some((item) => options.mode === "remove" ? item.result !== true : !item.result?.pass);
  if (failed) process.exitCode = 2;
}

async function runWatch(options) {
  const { payload } = await loadPayload(options.themeDir);
  const sessions = new Map();
  let stopping = false;
  const stop = () => { stopping = true; };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);

  while (!stopping) {
    let targets = [];
    try {
      targets = await listWorkbenchTargets(options.port);
    } catch (error) {
      console.error(`[dream-skin] ${new Date().toISOString()} ${error.message}`);
      await new Promise((resolve) => setTimeout(resolve, 1200));
      continue;
    }

    const activeIds = new Set(targets.map((target) => target.id));
    for (const [id, session] of sessions) {
      if (!activeIds.has(id) || session.closed) {
        session.close();
        sessions.delete(id);
      }
    }

    for (const target of targets) {
      if (sessions.has(target.id)) continue;
      let session;
      try {
        session = await new CdpSession(target, options.port).open();
        const probe = await probeSession(session);
        if (!probe?.skinnable) {
          session.close();
          continue;
        }
        session.on("Page.loadEventFired", () => {
          setTimeout(() => session.evaluate(payload).catch((error) => {
            console.error(`[dream-skin] reinject failed: ${error.message}`);
          }), 400);
        });
        await session.evaluate(payload);
        sessions.set(target.id, session);
        console.log(`[dream-skin] injected target ${target.id} (${target.title || target.url})`);
      } catch (error) {
        session?.close();
        console.error(`[dream-skin] inject failed for ${target.id}: ${error.message}`);
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  for (const session of sessions.values()) session.close();
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.mode === "check") {
      const loaded = await loadPayload(options.themeDir);
      console.log(JSON.stringify({
        pass: true,
        version: SKIN_VERSION,
        themeId: loaded.theme.id,
        themeName: loaded.theme.name,
        imageBytes: loaded.imageBytes,
        payloadBytes: Buffer.byteLength(loaded.payload),
      }, null, 2));
    } else if (options.mode === "watch") await runWatch(options);
    else await runOneShot(options);
  } catch (error) {
    console.error(`[dream-skin] ${error.stack || error.message}`);
    process.exitCode = 1;
  }
}
