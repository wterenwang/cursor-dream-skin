# Runtime Notes — Cursor Dream Skin (macOS)

勘察日期：2026-07-16 · Cursor 3.7.42 · Electron 39.8.1 · Chrome 142 · macOS darwin 25.5.0

## 应用信息

- Bundle: `/Applications/Cursor.app`，bundle id `com.todesktop.230313mzl4w4u92`，可执行文件 `Contents/MacOS/Cursor`。
- `ELECTRON_RUN_AS_NODE=1 <Cursor 可执行文件>` 可当 Node 用：v22.22.1，原生 `fetch` 与 `WebSocket` 均可用 → 注入器零外部依赖。
- Node 的 `fetch` 不读取 `http_proxy` 环境变量，直连回环没问题；但 **curl 必须加 `--noproxy '*'`**（本机常见配置 `http_proxy=127.0.0.1:8001` 会把回环请求吞掉返回 503）。

## CDP

- `open -na Cursor --args --user-data-dir=<dir> --remote-debugging-port=<port>` 启动后，约 5-15 秒在 `127.0.0.1:<port>` 出现 DevTools HTTP 端点。
- workbench 页面目标特征：`type === "page"`，URL 为
  `vscode-file://vscode-app/Applications/Cursor.app/Contents/Resources/app/out/vs/code/electron-sandbox/workbench/workbench.html`，title 为工作区名。
- 隔离实例（独立 `--user-data-dir`）与正式实例互不影响，是安全的开发/测试沙盒。

## Workbench DOM（换肤锚点）

- 根节点 `body > .monaco-workbench`（class 还携带 `vs` / `vs-dark` 主题标记、`mac`、`macos-tahoe` 等）。
- 结构件：`.part.titlebar`、`.part.activitybar`（Cursor 默认隐藏，可能不存在）、`.part.sidebar`、`.part.auxiliarybar`（AI 聊天面板宿主）、`.part.editor`、`.part.panel`、`.part.statusbar`。
- **AI 聊天面板（auxiliary bar / composer）是原生 DOM，不是 webview/iframe**（Cmd+L 打开后 `iframes: []`、`webviews: 0`）→ 普通 CSS 即可覆盖，无需第二层注入。
- AI 面板内部自带不透明背景的元素：`.composite.title`、`.composer-bar`、`.monaco-inputbox`、`.ai-input-full-input-box`，需要单独压成半透明。
- `.part.editor` 自身背景透明，实际不透明层在 `.editor-group-container` / `.monaco-editor`。

## Agents 窗口（独立 Agent 窗口模式）

- 标题栏「Agents Window ↗」打开的独立窗口，是**同一 CDP 端点下的独立 page 目标**：URL 仍是 workbench.html，title 为 `Cursor Agents`。
- UI 不是 workbench DOM，而是 React 应用：`body > div.flex.flex-col.size-full…`；`.monaco-workbench` 存在但藏在 `div.hidden` 里（无 `.part.statusbar` / `.part.editor`）→ 探测须用 `.agent-panel` 或 `nav.ui-sidebar`。
- 表面背景由 `--glass-*` 变量驱动（声明在 adopted stylesheets 里，`document.styleSheets` 扫不到）：根容器 `--glass-surface-background`、侧栏 `.glass-sidebar-docked` 用 `--glass-sidebar-surface-background`、主面板 `.agent-panel` 用 `--glass-chat/editor-surface-background`。用 `.cursor-dream-skin body, .cursor-dream-skin body *` 选择器加 `!important` 重declare 即可覆盖（必须匹配声明变量的同一元素才能赢得级联）。
- 文字/图标/悬停色是预计算的 `--cursor-text-*` / `--cursor-icon-*` / `--cursor-bg-*` 令牌（color-mix 字面量，声明在 body 上，**不跟随 --vscode-\* 重映射**）→ renderer-inject.js 里按主题前景色用 color-mix 重新生成。`--cursor-syntax-*` 不要动（跟随用户语法主题）。
- 该窗口与主窗口共享注入 payload；watch 守护进程轮询 /json/list 自动覆盖后开的 Agents 窗口。

## 注入验证结论

- `Runtime.evaluate` 注入 `<style>` + `position:fixed; inset:0; z-index:-1; pointer-events:none` 装饰层即可生效；把 `.monaco-workbench` 背景改 transparent 后装饰层可透出。已截图确认。
- `Page.captureScreenshot` 可用于验收截图。
- `Input.dispatchKeyEvent`（modifiers=4 即 cmd）可驱动 Cmd+L 打开 AI 面板。

## 其他

- minimap 与终端（xterm webgl）背景画在 canvas 里，CSS 无法完全穿透；终端可尝试覆盖 `.xterm-viewport`，minimap 接受原样。
- 皮肤的明暗需与用户 color theme 配合：深色皮肤 + 浅色语法主题会导致可读性差，SKILL.md 中要求 agent 提示用户或配合切换。
