# ✨ Cursor Dream Skin

<p align="center">
  <strong>给每天写代码的地方，换一张会呼吸的脸。</strong><br/>
  <sub>Windows · 不改 Cursor 安装包 · 本机即可使用</sub>
</p>

<p align="center">
  <a href="#-快速开始"><img src="https://img.shields.io/badge/平台-Windows-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/许可-MIT-22c55e?style=flat-square" alt="MIT" /></a>
  <a href="#-安全与隐私"><img src="https://img.shields.io/badge/安装包-不修改-f59e0b?style=flat-square" alt="Non-invasive" /></a>
  <a href="#-内置主题"><img src="https://img.shields.io/badge/壁纸+桌宠-精选-a855f7?style=flat-square" alt="Themes" /></a>
</p>

> [!NOTE]
> **非 Cursor 官方产品。** 灵感来自 [Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)；Cursor 换肤思路参考 [KinGao294/cursor-dream-skin](https://github.com/KinGao294/cursor-dream-skin)（macOS）。桌宠状态思路参考 [LLMPET](https://github.com/myunwang/LLMPET)（原创角色与真透明渲染，未使用其素材）。

---

## 🎯 它是什么

Cursor Dream Skin 是一个 **换肤 + 桌宠** 小工具：给官方 Cursor 加上壁纸氛围，并在桌面放一只会报状态的小角色，**不改装 Cursor 本身**。

- **壁纸主题**：铺满 Cursor 窗口，面板半透明透出氛围  
- **桌宠**：独立于壁纸；表情跟随 Agent / 编辑活动；气泡显示简短状态  

---

## ✨ 功能亮点

- 🎎 **桌宠** — 星屑 / 墨点 / 电波，七种表情；真透明分层窗口（不用品红抠图）  
- 📡 **更准的活动感知** — 只读本机 Agent Transcript（`~\.cursor\projects\...\agent-transcripts`），**不安装 Cursor Hooks**  
- 🖼️ **壁纸与桌宠分开** — 管理界面两个选择器；应用皮肤只换壁纸  
- 🛎️ **右下角小助手** — 换壁纸、换桌宠、应用、还原、打开管理界面  
- 🖱️ **桌宠交互** — 左键唤起 Cursor；拖动记住位置；右键换桌宠  
- ⭐ **精选默认** — 默认壁纸「樱夜湖畔」、默认桌宠「星屑」  
- 🎛️ **微调** — 暗角、编辑区清晰度、背景位置  
- 🧭 **第一次引导** — 帮你找到 Cursor  
- ♻️ **一键还原** — 回到官方样子  
- 📦 **便携安装** — 双击 `Install.cmd`  

---

## 🚀 快速开始

### 方式一：一键安装（推荐）

1. 下载或克隆本仓库  
2. 双击根目录的 **`Install.cmd`**  
3. 会帮你：选好推荐壁纸与桌宠、放好桌面快捷方式、打开小助手和管理界面  
4. 小助手右键 → **应用当前皮肤**（或在管理界面里点应用）

```powershell
git clone https://github.com/wterenwang/cursor-dream-skin.git
cd cursor-dream-skin
.\Install.cmd
```

桌面快捷方式：

| 快捷方式 | 作用 |
|----------|------|
| **Cursor Dream Skin** | 打开小助手（日常入口） |
| **Cursor Dream Skin - 管理界面** | 选壁纸、桌宠、微调、应用 |
| **Cursor Dream Skin - 还原外观** | 回到官方样子 |

### 方式二：命令行

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-dream-skin.ps1
wscript .\scripts\launch-gui.vbs
```

### 第一次用要注意

| 步骤 | 说明 |
|------|------|
| ① 找到 Cursor | 若没自动找到，向导里浏览一次即可 |
| ② 可能要重启一次 | Cursor 已经开着时，第一次应用会请你确认重启 |
| ③ 配色更清晰 | 深色皮肤建议把 Cursor 的 Color Theme 也切到深色（`Ctrl+K` 再 `Ctrl+T`）；**我们不会改你的设置文件** |

> 💡 想打成压缩包带走：运行 `scripts\pack-portable.ps1`，桌面会得到 zip，解压后再双击 `Install.cmd`。

---

## 🖥️ 管理界面能做什么

| 区域 | 你可以做 |
|------|----------|
| 状态 | 看 Cursor、壁纸、桌宠、皮肤是否挂上 |
| 壁纸主题 | 选推荐 / 自定义壁纸并预览（★ 为精选） |
| 桌宠 | 单独选择星屑 / 墨点 / 电波，或不显示 |
| 微调 | 暗角 · 编辑区清晰度 · 背景位置 → 保存 |
| 自定义 | 选图 → 起名 → 生成壁纸主题 |
| 应用 / 还原 | 挂上壁纸皮肤，或恢复官方外观 |

---

## 🎎 桌宠说明

装好后默认桌宠是 **星屑**。表情与气泡优先根据本机 **Agent Transcript** 判断（例如 `Agent · Read` / `Agent · Write`）；标题仅作兜底。

| 表情 | 常见触发 |
|------|----------|
| 思考 | Transcript 里出现 Read / Grep / Task 等，或刚提问 |
| 干活 | Write / Shell / StrReplace 等，或窗口标题像在编辑文件 |
| 看一眼 → 开心 | Agent 刚停一会儿 |
| 待命 / 睡觉 | 空闲；久无活动或 Cursor 未开 |
| 出错 | 标题里出现失败类字样 |

**交互：** 左键唤起 Cursor；拖动记住位置；右键可换桌宠 / 打开管理界面 / 隐藏。

更多设计说明见 [`themes/PETS.md`](themes/PETS.md)。

---

## 🎭 内置主题

默认壁纸 **樱夜湖畔**，默认桌宠 **星屑**。小助手里「精选壁纸」和「桌宠」可分别切换。

### 桌宠

| 名称 | 气质 |
|------|------|
| 星屑 | 暖琥珀发 · 星发夹 |
| 墨点 | 青墨短发 · 墨滴饰 |
| 电波 | 浅紫粉发 · 天线夹 |

旧版真人看板娘主题已隐藏（勾选「显示额外 / 测试主题」仍可找到）。

### 氛围壁纸

| | |
|------|------|
| Dream Night | 樱夜湖畔 |
| 雨窗咖啡馆 | 霓虹雨街 |
| 夏夜灯火 | 雾中鸟居 |
| 极光峡湾 | 铜尘星云 |
| 青岚山色 | 金岸午后（浅色） |

---

## 🔒 安全与隐私

- 🔐 只在本机工作，不上传你的代码  
- 📡 桌宠会**只读**本机 Agent Transcript 尾部（工具名等），**不安装 Hooks**，气泡不展示对话正文  
- 🖱️ 装饰层与桌宠不抢正常编辑（桌宠可点可拖）  
- 🚫 **不修改** Cursor 安装目录  
- 🚫 **不写入** 你的设置 / API Key  
- ⚠️ 换肤期间，尽量不要在本机跑来路不明的程序  

个别区域（比如某些终端画面）可能透不出壁纸——这是界面限制，不是皮肤坏了。

---

## ❓ 常见问题

**Q: 小助手在哪？怎么换壁纸 / 桌宠？**  
A: 点桌面 **Cursor Dream Skin**，右下角通知区会出现图标。右键 → **精选壁纸** 或 **桌宠**；双击打开管理界面。

**Q: 桌宠一直显示「正在想」？**  
A: 旧版会把窗口标题「Cursor Agents」误判成思考。请用最新版：已忽略该面板名，并以 Transcript 为准。

**Q: 点快捷方式没反应？**  
A: 小助手可能已经在跑；管理界面再点一次。还可看 `%LOCALAPPDATA%\CursorDreamSkin\gui-launch.log`。

**Q: 皮肤挂上了但字发灰 / 看不清？**  
A: 把 Cursor Color Theme 切成与皮肤明暗一致；或在管理界面调高「编辑区清晰度」。

**Q: 还原之后感觉还没完全干净？**  
A: 完全退出 Cursor，再用平时的方式打开即可。

**Q: 支持 Mac / Linux 吗？**  
A: 现在是 **Windows 版**。Mac 可参考上面提到的 KinGao 项目。

---

## 🗺️ 接下来想做的

- [x] Windows 换肤 + 管理界面  
- [x] 壁纸 / 桌宠分离 + 小助手  
- [x] 真透明桌宠 + Transcript 活动感知  
- [x] 桌宠交互（唤起 Cursor、记住位置、换角色）  
- [ ] README 真实效果截图  
- [ ] 可选：开机自启  
- [ ] 可选：Cursor Hooks 更实时感知（默认仍不用）  
- [ ] 主题打包带走 / 导入  
- [ ] Mac 版（长期）  

---

## 🙏 致谢

- [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)  
- [KinGao294/cursor-dream-skin](https://github.com/KinGao294/cursor-dream-skin)  
- [myunwang/LLMPET](https://github.com/myunwang/LLMPET)（桌宠状态灵感）  
- Cursor® 及相关标识归 [Anysphere](https://cursor.com) 所有  

---

## 📄 License

[MIT](LICENSE) © 贡献者们

如果这个项目让你的编辑器好看了一点，欢迎 ⭐ Star——那是对开源最好的咖啡。

---

<details>
<summary>给想改代码的人：目录与脚本（可折叠）</summary>

```text
cursor-dream-skin/
├── Install.cmd
├── assets/
├── gui/
├── scripts/          # 小助手、桌宠、安装、换肤服务等
├── themes/
│   ├── catalog.json  # 精选壁纸 / 桌宠默认
│   ├── PETS.md
│   ├── pet-*/        # 桌宠包
│   └── <壁纸主题>/
└── references/
```

| 脚本 | 用途 |
|------|------|
| `scripts/launch-tray.vbs` | 打开小助手 |
| `scripts/launch-gui.vbs` | 打开管理界面 |
| `scripts/launch-deskpet.vbs` | 打开桌宠 |
| `scripts/tray-dream-skin.ps1` | 小助手 |
| `scripts/deskpet-dream-skin.ps1` | 桌宠窗口 |
| `scripts/cds-transcript-sense.ps1` | Transcript 活动感知 |
| `scripts/chroma-pet.exe` | 绿幕/品红 → 真透明 PNG |
| `scripts/start-dream-skin.ps1` | 命令行挂上皮肤 |
| `scripts/switch-theme.ps1` | 换壁纸主题 |
| `scripts/restore-dream-skin.ps1` | 还原 |
| `scripts/make-theme.mjs` | 从图片生成主题 |
| `scripts/pack-portable.ps1` | 打便携包 |

换肤原理简述：用本机调试通道把背景层挂到 Cursor 窗口上；还原后正常重开 Cursor 即可。状态目录：`%LOCALAPPDATA%\CursorDreamSkin`。

默认壁纸：`themes/catalog.json` → `featuredDefault`；默认桌宠：`featuredDefaultPet`。

</details>
