# ✨ Cursor Dream Skin

<p align="center">
  <strong>给每天写代码的地方，换一张会呼吸的脸。</strong><br/>
  <sub>Windows · 本机 CDP 注入 · 不改 Cursor 安装包</sub>
</p>

<p align="center">
  <a href="#-快速开始"><img src="https://img.shields.io/badge/平台-Windows-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/许可-MIT-22c55e?style=flat-square" alt="MIT" /></a>
  <a href="#-安全边界"><img src="https://img.shields.io/badge/安装包-不修改-f59e0b?style=flat-square" alt="Non-invasive" /></a>
  <a href="#-内置主题"><img src="https://img.shields.io/badge/主题-14+-a855f7?style=flat-square" alt="Themes" /></a>
</p>

> [!NOTE]
> **非 Cursor 官方产品。** 灵感来自 [Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)；Cursor DOM / 注入思路参考 [KinGao294/cursor-dream-skin](https://github.com/KinGao294/cursor-dream-skin)（macOS）。

---

## 🎯 它是什么

Cursor Dream Skin 是一个 **外部换肤工具**：用本机调试端口把壁纸、看板娘角色和玻璃质感面板「挂」到官方 Cursor 上。侧栏、编辑器、Agent、状态栏仍是 **原生可交互控件**——皮肤只是一层装饰，不是假 UI。

---

## ✨ 功能亮点

- 🖼️ **真背景层** — 壁纸铺满整窗，半透明面板透出氛围  
- 🎎 **看板娘模式** — 角色可贴右下角；状态栏色带、侧栏光晕、页签珠点、个性短句  
- 🎨 **一键换主题** — 内置多套成品；也可导入图片自动抽色生成主题  
- 🎛️ **GUI 微调** — 暗角、编辑器不透明度、背景位置，保存后可热应用  
- 🧭 **首次向导** — 自动找 / 手动选 `Cursor.exe`，路径会记住  
- 📊 **清晰状态** — Cursor / CDP / 注入 / 皮肤是否挂上，一眼看懂  
- ♻️ **一键还原** — 去掉皮肤，回到官方外观  
- 📦 **便携安装** — 双击 `Install.cmd` 创建快捷方式并打开 GUI  

---

## 🚀 快速开始

### 方式一：一键安装（推荐）

1. 克隆或下载本仓库  
2. 双击根目录 **`Install.cmd`**  
3. 在打开的 GUI 里选主题 → **应用皮肤**

```powershell
git clone https://github.com/wterenwang/cursor-dream-skin.git
cd cursor-dream-skin
.\Install.cmd
```

### 方式二：命令行

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-dream-skin.ps1
wscript .\scripts\launch-gui.vbs
```

### 第一次用要注意

| 步骤 | 说明 |
|------|------|
| ① 选 Cursor | 若未自动找到，向导里浏览一次 `Cursor.exe` |
| ② 可能重启 | Cursor 若已在跑且没开调试口，首次应用会请你确认重启一次 |
| ③ 配对配色 | 深色皮肤建议再把 Cursor Color Theme 切到深色（`Ctrl+K` `Ctrl+T`），**默认不改 settings** |

> 💡 打便携包：`powershell -File .\scripts\pack-portable.ps1` → 桌面得到 zip，解压后同样双击 `Install.cmd`。

---

## 🖥️ GUI 能做什么

打开 **Cursor Dream Skin** 后：

| 区域 | 操作 |
|------|------|
| 状态卡 | 看 Cursor 路径、端口、注入是否存活 |
| 主题列表 | 选成品 / 自定义主题并预览 |
| 主题微调 | 暗角 · 编辑器透明度 · 背景位置 → 保存 |
| 自定义主题 | 选图 → 起名 → 生成（可删除自定义主题） |
| 应用 / 还原 | 挂上皮肤或恢复官方外观 |

演示 / smoke 主题默认隐藏；勾选「显示演示 / 开发主题」可查看。

---

## 🎭 内置主题

### 看板娘（角色贴图）

| ID | 名称 | 气质 |
|----|------|------|
| `ink-clerk` | 墨台小书吏 | 靛青文员 · 安静待命 |
| `neon-operator` | 霓虹接线员 | 品红赛博 · 随时接线 |
| `tea-host` | 午后茶役 | 暖茶杏黄 · 慢慢写 |
| `storm-watch` | 观星哨 | 星空青蓝 · 静候 |

### 氛围壁纸

| ID | 名称 | ID | 名称 |
|----|------|----|------|
| `default` | Dream Night | `sakura-night` | 樱夜湖畔 |
| `rain-cafe` | 雨窗咖啡馆 | `neon-rain` | 霓虹雨街 |
| `lantern-eve` | 夏夜灯火 | `shrine-mist` | 雾中鸟居 |
| `aurora-fjord` | 极光峡湾 | `copper-nebula` | 铜尘星云 |
| `ink-mountains` | 青岚山色 | `coastal-gold` | 金岸午后（浅色） |

主题文件在 `themes/<id>/`：`theme.json` + `art.jpg`（可选 `theme.css`）。

---

## ⚙️ 工作原理

```text
Install / GUI
    │
    ▼
Cursor  --remote-debugging-port=127.0.0.1:xxxx
    │
    ▼
injector.mjs  (CDP)  ──►  workbench / Agents 窗口
    │
    ├─ 注入 CSS + 不可点击的背景层
    ├─ 映射 VS Code / Cursor 设计令牌
    └─ 窗口刷新后自动重注
    │
    ▼
还原：停注入 → 卸皮肤 →（正常重开 Cursor 后调试口消失）
```

状态目录：`%LOCALAPPDATA%\CursorDreamSkin`

---

## 🔒 安全边界

- 🔐 CDP **仅绑定** `127.0.0.1`  
- 🖱️ 装饰层 `pointer-events: none`，不抢点击  
- 🚫 **不修改** 安装目录与签名  
- 🚫 **不写入** 你的 settings / API Key（除非你自己点配对提示去改 Color Theme）  
- ⚠️ 主题运行期间，尽量不要在本机跑来路不明的程序（本地调试口仍是敏感能力）  

部分 canvas 表面（如终端 WebGL、minimap）可能无法完全透出壁纸——这是技术限制，不是漏注入。

---

## 📁 目录结构

```text
cursor-dream-skin/
├── Install.cmd          # 一键安装 + 打开 GUI
├── assets/              # 注入用 CSS / JS
├── gui/                 # Edge 应用壳（中英双语）
├── scripts/             # PowerShell + injector + 打包
├── themes/              # 主题包
└── references/          # 运行时笔记
```

常用脚本：

| 脚本 | 用途 |
|------|------|
| `scripts/launch-gui.vbs` | 打开 GUI |
| `scripts/start-dream-skin.ps1` | 命令行启动并注入 |
| `scripts/switch-theme.ps1` | 热切换主题 |
| `scripts/restore-dream-skin.ps1` | 还原外观 |
| `scripts/make-theme.mjs` | 从图片生成主题 |
| `scripts/pack-portable.ps1` | 打便携 zip |

---

## ❓ 常见问题

**Q: 点快捷方式没反应？**  
A: 多半是旧 GUI 进程占着端口。再点一次（启动器会复用或回收）；或看 `%LOCALAPPDATA%\CursorDreamSkin\gui-launch.log`。

**Q: 皮肤挂上了但字发灰 / 看不清？**  
A: 把 Cursor 的 Color Theme 切到与皮肤明暗一致的一套；并在 GUI 里略调「编辑器不透明度」。

**Q: 还原后调试端口还在？**  
A: 正常。完全退出 Cursor，再用平常方式打开即可去掉调试口。

**Q: 支持 macOS / Linux 吗？**  
A: 当前是 **Windows 第一版**。macOS 可参考上游 KinGao 项目。

---

## 🗺️ 路线图

- [x] Windows CDP 注入 + Edge GUI  
- [x] 主题热切换 / 自定义从图片生成  
- [x] 看板娘布局与 chrome 装饰  
- [x] 首次向导 + 状态清单  
- [ ] 托盘常驻 / 开机自启（可选）  
- [ ] 主题包导入导出（zip）  
- [ ] macOS 产品化（长期）  

---

## 🙏 致谢

- [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) — Windows CDP 换肤思路  
- [KinGao294/cursor-dream-skin](https://github.com/KinGao294/cursor-dream-skin) — Cursor 注入与 DOM 参考  
- Cursor® 及相关标识归 [Anysphere](https://cursor.com) 所有  

---

## 📄 License

[MIT](LICENSE) © 贡献者们

如果这个项目让你的编辑器好看了一点，欢迎 ⭐ Star——那是对开源最好的咖啡。
