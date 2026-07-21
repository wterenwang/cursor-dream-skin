(() => {
  "use strict";
  // Injected via CDP Runtime.evaluate. Placeholders are replaced by injector.mjs.
  const CSS = __CDS_CSS_JSON__;
  const ART_DATA_URL = __CDS_ART_JSON__;
  const THEME = __CDS_THEME_JSON__;
  const VERSION = __CDS_VERSION_JSON__;

  const STYLE_ID = "cursor-dream-skin-style";
  const ART_ID = "cursor-dream-skin-art";
  const ROOT_CLASS = "cursor-dream-skin";

  // An explicit (re)apply always wins over a previous remove.
  delete window.__CURSOR_DREAM_SKIN_DISABLED__;

  const previous = window.__CURSOR_DREAM_SKIN_STATE__;
  if (previous && previous.cleanup) {
    try { previous.cleanup(); } catch (e) { /* replaced below */ }
  }

  const html = document.documentElement;
  const colors = THEME.colors;
  const decor = THEME.decor || {};
  const artMode = THEME.artMode || "wallpaper";

  // Light foreground => dark skin (and vice versa). Used for code-block contrast.
  const fgLum = (() => {
    const m = /^#([0-9a-f]{6})$/i.exec(String(colors.foreground || ""));
    if (!m) return 0.9;
    const n = parseInt(m[1], 16);
    const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  })();
  const darkSkin = fgLum > 0.55;
  html.dataset.cdsMode = darkSkin ? "dark" : "light";
  html.dataset.cdsArtMode = artMode;
  if (THEME.flavor) html.dataset.cdsFlavor = THEME.flavor;
  else delete html.dataset.cdsFlavor;
  html.dataset.cdsStripe = decor.statusStripe ? "1" : "0";
  html.dataset.cdsActivityGlow = decor.activityGlow ? "1" : "0";
  html.dataset.cdsSidebarBloom = decor.sidebarBloom ? "1" : "0";
  html.dataset.cdsTabPearl = decor.tabPearl ? "1" : "0";
  html.dataset.cdsAipaneRibbon = decor.aipaneRibbon ? "1" : "0";
  html.dataset.cdsMotto = decor.motto ? "1" : "0";

  // Remap VS Code color tokens so every native surface inherits the skin.
  const tokenGroups = [
    [colors.chrome, [
      "titleBar-activeBackground", "titleBar-inactiveBackground",
      "activityBar-background", "statusBar-background", "statusBar-noFolderBackground",
      "panel-background", "terminal-background",
      "editorGroupHeader-tabsBackground", "editorGroupHeader-noTabsBackground",
      "breadcrumb-background", "editorStickyScroll-background", "banner-background",
      "sideBarSectionHeader-background", "sideBarTitle-background", "tab-inactiveBackground",
    ]],
    [colors.sidebar, ["sideBar-background"]],
    [colors.editor, ["editor-background", "tab-activeBackground", "editorGutter-background"]],
    [colors.input, ["input-background", "dropdown-background", "settings-textInputBackground", "keybindingLabel-background"]],
    [colors.widget, [
      "editorWidget-background", "quickInput-background", "notifications-background",
      "menu-background", "editorSuggestWidget-background", "editorHoverWidget-background",
      "peekViewEditor-background", "peekViewResult-background",
      "textCodeBlock-background", "textBlockQuote-background", "textPreformat-background",
    ]],
  ];
  const fgGroups = [
    [colors.foreground, [
      "foreground", "editor-foreground", "sideBar-foreground", "statusBar-foreground",
      "titleBar-activeForeground", "tab-activeForeground", "editorWidget-foreground",
      "input-foreground", "dropdown-foreground", "menu-foreground", "quickInput-foreground",
      "panelTitle-activeForeground", "icon-foreground", "list-hoverForeground",
      "list-activeSelectionForeground", "breadcrumb-foreground", "sideBarTitle-foreground",
      "sideBarSectionHeader-foreground", "terminal-foreground", "notifications-foreground",
      "textPreformat-foreground",
    ]],
    [colors.mutedForeground, [
      "descriptionForeground", "tab-inactiveForeground", "titleBar-inactiveForeground",
      "breadcrumb-foreground", "editorLineNumber-foreground", "panelTitle-inactiveForeground",
      "disabledForeground", "editorWatermark-foreground", "keybindingLabel-foreground",
      "input-placeholderForeground", "editorGhostText-foreground",
    ]],
    [colors.accent, [
      "focusBorder", "progressBar-background", "textLink-foreground",
      "button-background", "activityBarBadge-background", "badge-background",
      "panelTitle-activeBorder", "tab-activeBorderTop", "statusBarItem-remoteBackground",
    ]],
  ];

  let tokenCss = "";
  for (const [value, names] of [...tokenGroups, ...fgGroups]) {
    if (!value) continue;
    for (const name of names) tokenCss += `--vscode-${name}: ${value} !important;\n`;
  }

  // The Agents window (and the shared "glass" chat UI) reads --cursor-* design
  // tokens whose values are precomputed color-mix() literals, so they don't
  // follow the --vscode-* remap above and need their own overrides.
  const mix = (color, pct) => `color-mix(in srgb, ${color} ${pct}%, transparent)`;
  const fg = colors.foreground;
  const agentTokens = {
    "cursor-foreground": fg,
    "cursor-base": fg,
    "cursor-text-primary": mix(fg, 94),
    "cursor-text-secondary": mix(fg, 74),
    "cursor-text-tertiary": mix(fg, 54),
    "cursor-text-quaternary": mix(fg, 36),
    "cursor-text-active": mix(fg, 94),
    "cursor-text-focused": mix(fg, 94),
    "cursor-icon-primary": mix(fg, 86),
    "cursor-icon-secondary": mix(fg, 66),
    "cursor-icon-tertiary": mix(fg, 46),
    "cursor-icon-quaternary": mix(fg, 28),
    "cursor-text-accent": colors.accent,
    "cursor-text-link": colors.accent,
    "cursor-text-link-active": colors.accent,
    "cursor-bg-primary": mix(fg, 20),
    "cursor-bg-secondary": mix(fg, 14),
    "cursor-bg-tertiary": mix(fg, 8),
    "cursor-bg-quaternary": mix(fg, 6),
    "cursor-bg-quinary": mix(fg, 4),
    "cursor-bg-active": mix(fg, 16),
    "cursor-bg-focused": mix(fg, 22),
    "cursor-bg-card": mix(fg, 6),
    "cursor-bg-elevated": colors.widget,
    "cursor-bg-input": colors.input,
    "cursor-bg-chrome": colors.chrome,
    "cursor-bg-editor": colors.editor,
    "cursor-bg-sidebar": colors.sidebar,
    "cursor-input-border": colors.line,
    "cursor-input-placeholder-foreground": mix(fg, 36),
    "cursor-button-secondary-background": mix(fg, 8),
    "cursor-button-secondary-hover-background": mix(fg, 14),
    "cursor-button-secondary-foreground": mix(fg, 94),
    "cursor-toolbar-hover-background": mix(fg, 8),
    "cursor-titlebar-active-foreground": mix(fg, 74),
    "cursor-titlebar-inactive-foreground": mix(fg, 54),
    "cursor-scrollbar-thumb-background": mix(fg, 14),
    "cursor-scrollbar-thumb-hover-background": mix(fg, 22),
    "cursor-scrollbar-thumb-active-background": mix(fg, 26),
  };
  let agentTokenCss = "";
  for (const [name, value] of Object.entries(agentTokens)) {
    if (value) agentTokenCss += `--${name}: ${value} !important;\n`;
  }

  const mottoCss = decor.motto ? JSON.stringify(decor.motto) : '""';
  const surfaceVars = [
    `--cds-chrome: ${colors.chrome}`,
    `--cds-sidebar: ${colors.sidebar}`,
    `--cds-editor: ${colors.editor}`,
    `--cds-aipane: ${colors.aiPane}`,
    `--cds-input: ${colors.input}`,
    `--cds-widget: ${colors.widget}`,
    `--cds-accent: ${colors.accent}`,
    `--cds-line: ${colors.line}`,
    `--cds-dim: ${colors.dim}`,
    `--cds-fg: ${colors.foreground}`,
    `--cds-muted: ${colors.mutedForeground}`,
    `--cds-code-bg: color-mix(in srgb, ${colors.widget} 75%, ${darkSkin ? "#0c0a12" : "#ffffff"} 25%)`,
    `--cds-code-fg: ${colors.foreground}`,
    `--cds-art-fit: ${THEME.artFit}`,
    `--cds-art-position: ${THEME.artPosition}`,
    `--cds-art-filter: ${THEME.artFilter}`,
    `--cds-backdrop: ${THEME.backdrop || "transparent"}`,
    `--cds-mascot-width: ${THEME.mascotWidth || "min(26vw, 320px)"}`,
    `--cds-mascot-height: ${THEME.mascotHeight || "min(58vh, 560px)"}`,
    `--cds-mascot-opacity: ${THEME.mascotOpacity || "0.95"}`,
    `--cds-motto: ${mottoCss}`,
  ].join("; ");

  const dynamicCss = [
    `.${ROOT_CLASS} { ${surfaceVars}; }`,
    `.${ROOT_CLASS} .monaco-workbench {\n${tokenCss}}`,
    `.${ROOT_CLASS} body, .${ROOT_CLASS} body * {\n${agentTokenCss}}`,
    `.${ROOT_CLASS} body { background: transparent !important; }`,
  ].join("\n");

  document.getElementById(STYLE_ID)?.remove();
  const style = document.createElement("style");
  style.id = STYLE_ID;
  style.textContent = `${dynamicCss}\n${CSS}`;
  document.head.appendChild(style);

  document.getElementById(ART_ID)?.remove();
  const art = document.createElement("div");
  art.id = ART_ID;
  const backdrop = document.createElement("div");
  backdrop.className = "cds-backdrop";
  const image = document.createElement("div");
  image.className = "cds-image";
  image.style.backgroundImage = `url(${JSON.stringify(ART_DATA_URL)})`;
  const dim = document.createElement("div");
  dim.className = "cds-dim";
  // Wallpaper: art under dim. Mascot: solid backdrop + dim, character on top (never a full-bleed wallpaper).
  if (artMode === "mascot") {
    art.append(backdrop, dim, image);
  } else {
    art.append(backdrop, image, dim);
  }
  document.body.prepend(art);
  html.classList.add(ROOT_CLASS);

  const syncRootFlags = () => {
    if (!html.classList.contains(ROOT_CLASS)) html.classList.add(ROOT_CLASS);
    html.dataset.cdsMode = darkSkin ? "dark" : "light";
    html.dataset.cdsArtMode = artMode;
    if (THEME.flavor) html.dataset.cdsFlavor = THEME.flavor;
    html.dataset.cdsStripe = decor.statusStripe ? "1" : "0";
    html.dataset.cdsActivityGlow = decor.activityGlow ? "1" : "0";
    html.dataset.cdsSidebarBloom = decor.sidebarBloom ? "1" : "0";
    html.dataset.cdsTabPearl = decor.tabPearl ? "1" : "0";
    html.dataset.cdsAipaneRibbon = decor.aipaneRibbon ? "1" : "0";
    html.dataset.cdsMotto = decor.motto ? "1" : "0";
  };

  const observer = new MutationObserver(() => {
    if (window.__CURSOR_DREAM_SKIN_DISABLED__) return;
    if (!document.getElementById(STYLE_ID)) document.head.appendChild(style);
    if (!document.getElementById(ART_ID)) document.body.prepend(art);
    syncRootFlags();
  });
  observer.observe(html, { childList: true, subtree: false });
  observer.observe(document.body, { childList: true, subtree: false });
  observer.observe(document.head, { childList: true, subtree: false });

  const clearFlags = () => {
    [
      "cdsMode", "cdsArtMode", "cdsFlavor", "cdsStripe", "cdsActivityGlow",
      "cdsSidebarBloom", "cdsTabPearl", "cdsAipaneRibbon", "cdsMotto",
    ].forEach((k) => delete html.dataset[k]);
  };

  const state = {
    version: VERSION,
    themeId: THEME.id,
    themeName: THEME.name,
    alive: () => Boolean(document.getElementById(STYLE_ID) && document.getElementById(ART_ID)),
    cleanup: () => {
      observer.disconnect();
      document.getElementById(STYLE_ID)?.remove();
      document.getElementById(ART_ID)?.remove();
      html.classList.remove(ROOT_CLASS);
      clearFlags();
      delete window.__CURSOR_DREAM_SKIN_STATE__;
      return true;
    },
  };
  window.__CURSOR_DREAM_SKIN_STATE__ = state;

  return { applied: true, version: VERSION, themeId: THEME.id, artMode };
})();
