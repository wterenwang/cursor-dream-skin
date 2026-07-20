# Cursor Dream Skin

给 Cursor IDE 换一张会呼吸的脸。  
外部主题 / 换肤工具 · 本机 CDP 注入 · 不改官方安装包

> Windows 第一版。灵感来自 [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)，Cursor DOM / 注入层参考 [KinGao294/cursor-dream-skin](https://github.com/KinGao294/cursor-dream-skin)（macOS）。

非 Cursor 官方产品。不修改 `Cursor.exe` / `app.asar` / 安装目录。

## 它能做什么

- **真·可交互**：侧栏、编辑器、Agent 面板、状态栏都是原生控件
- **真背景层**：一张壁纸铺满整窗，面板半透明透出氛围
- **可换主题**：用本地图片生成主题，或切换 `themes/` 下已有主题
- **看板娘风**：角色可贴在角落（不必铺满背景），并改状态栏色带、侧栏光晕、页签珠点、Agent 侧条与个性短句
- **可恢复**：一键去掉皮肤，回到官方外观
- **相对安全**：只绑 `127.0.0.1` 的 CDP，不改二进制与签名

## 快速开始（Windows）

**一键安装：** 双击项目根目录 `Install.cmd`（创建桌面快捷方式并打开 GUI）。

或解压便携包后同样双击 `Install.cmd`（用 `scripts\pack-portable.ps1` 可打 zip）。

首次打开若未找到 Cursor，会弹出向导让你选择一次 `Cursor.exe`（路径会记住）。状态区会标明：Cursor 是否找到、是否在跑、调试端口、注入进程、皮肤是否已挂上。

```powershell
cd C:\Users\MRXBOSS\Desktop\cursor-dream-skin
.\Install.cmd
# 或
powershell -ExecutionPolicy Bypass -File .\scripts\install-dream-skin.ps1
wscript .\scripts\launch-gui.vbs
```

## 工作原理

1. `start-dream-skin.ps1` 用 `--remote-debugging-port`（仅本机回环）启动 Cursor  
2. `injector.mjs` 通过 CDP 找到 workbench / Agents 窗口  
3. 注入 CSS + 不可点击的背景层，并映射 VS Code / Cursor 设计令牌  
4. 守护进程在窗口刷新或新开窗口后自动重注  
5. `restore-dream-skin.ps1` 停止守护并移除皮肤

## 安全边界

- CDP 只监听 `127.0.0.1`；主题运行期间不要跑来路不明的本机程序
- 首次启用若 Cursor 已在运行，必须重启一次才能打开调试端口（脚本会弹窗确认）
- 装饰层 `pointer-events: none`，不劫持原生控件
- **不会**改你的 settings / API Key

状态目录：`%LOCALAPPDATA%\CursorDreamSkin`

## 目录结构

```
assets/           注入用 CSS / JS
scripts/          Windows PowerShell + injector
themes/default/   默认主题 Dream Night
references/       运行时笔记
```

## 许可与致谢

- [MIT](LICENSE)
- 感谢 Codex Dream Skin 与 KinGao294/cursor-dream-skin 的公开实现
- Cursor 及相关标识归 Anysphere 所有
