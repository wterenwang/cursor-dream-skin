# ✨ Cursor Dream Skin

<p align="center">
  <strong>给每天写代码的地方，换一张会呼吸的脸。</strong><br/>
  <sub>Windows · 不动你的 Cursor 安装 · 本机就能用</sub>
</p>

<p align="center">
  <a href="#-快速开始"><img src="https://img.shields.io/badge/平台-Windows-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/许可-MIT-22c55e?style=flat-square" alt="MIT" /></a>
  <a href="#-安全与隐私"><img src="https://img.shields.io/badge/安装包-不修改-f59e0b?style=flat-square" alt="Safe" /></a>
  <a href="#-内置主题"><img src="https://img.shields.io/badge/壁纸+桌宠-精选-a855f7?style=flat-square" alt="Themes" /></a>
</p>

> [!NOTE]
> **不是 Cursor 官方产品。** 灵感来自 [Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)；Cursor 换肤思路参考 [KinGao294/cursor-dream-skin](https://github.com/KinGao294/cursor-dream-skin)（Mac）；桌宠状态灵感来自 [LLMPET](https://github.com/myunwang/LLMPET)（角色和画是我们自己做的）。

---

## 🎯 它是什么

给你用的 Cursor **换一张好看的壁纸**，并在桌面上放一只 **会跟着你干活的小角色**。

平时怎么写代码、怎么用 Agent，都不用改——只是多了一点氛围感。

- **壁纸**：铺在 Cursor 窗口后面，面板会透出一点氛围感  
- **桌宠**：跟壁纸分开选；忙的时候会换表情，旁边有一句短状态 

---

## ✨ 你可以做什么

- 🎎 **养一只桌宠** — 星屑 / 墨点 / 电波，七种表情，边缘干净透明  
- 📡 **桌宠懂你在干嘛** — 自动根据本机 Cursor 的对话记录猜状态（不用额外装东西）  
- 🖼️ **壁纸和桌宠分开选** — 想换背景不用动桌宠，想换桌宠也不用动背景  
- 🛎️ **右下角小助手** — 换壁纸、换桌宠、应用、还原、打开管理界面  
- 🖱️ **桌宠好用** — 左键唤起 Cursor；拖到哪记住哪；右键换角色  
- ⭐ **装好就能用** — 默认壁纸「樱夜湖畔」、默认桌宠「星屑」  
- 🎛️ **看不清可以调** — 暗角、编辑区清晰度、背景位置  
- 🧭 **第一次有向导** — 帮你找到本机的 Cursor  
- ♻️ **一键还原** — 不想用了，回到原来的样子  
- 📦 **双击安装** — `Install.cmd` 搞定  

---

## 🚀 快速开始

### 方式一：一键安装（推荐）

1. 下载或克隆本仓库  
2. 双击根目录的 **`Install.cmd`**  
3. 它会帮你选好推荐壁纸与桌宠、放好桌面快捷方式、打开小助手和管理界面  
4. 小助手右键 → **应用当前皮肤**（或在管理界面里点应用）

```powershell
git clone https://github.com/wterenwang/cursor-dream-skin.git
cd cursor-dream-skin
.\Install.cmd
```

桌面上会有这些快捷方式：

| 快捷方式 | 作用 |
|----------|------|
| **Cursor Dream Skin** | 打开小助手（平时用这个） |
| **Cursor Dream Skin - 管理界面** | 选壁纸、桌宠、微调、应用 |
| **Cursor Dream Skin - 还原外观** | 回到原来的样子 |

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
| 状态 | 看 Cursor 是否就绪、当前壁纸 / 桌宠、皮肤是否已应用 |
| 壁纸主题 | 选推荐或自定义壁纸并预览（★ 为精选） |
| 桌宠 | 单独选择星屑 / 墨点 / 电波，或不显示 |
| 微调 | 暗角 · 编辑区清晰度 · 背景位置 → 保存 |
| 自定义 | 选一张图 → 起名 → 生成壁纸主题 |
| 应用 / 还原 | 用上当前壁纸，或恢复原来的外观 |

---

## 🎎 桌宠说明

装好后默认是 **星屑**。它会尽量根据你在 Cursor 里和 Agent 的互动换表情，并在旁边显示一句短状态（例如「正在读文件」「正在改代码」）。猜不准时，再看窗口标题兜底。

| 表情 | 大致什么时候 |
|------|----------------|
| 思考 | Agent 在查资料、读文件、规划任务，或你刚提问 |
| 干活 | Agent 在改代码、跑命令、写文件，或你在认真编辑 |
| 看一眼 → 开心 | Agent 刚忙完一会儿 |
| 待命 / 睡觉 | 空闲；很久没动静，或 Cursor 没开 |
| 出错 | 看起来像失败了 |

**交互：** 左键唤起 Cursor；拖动记住位置；右键可换桌宠 / 打开管理界面 / 隐藏。

想了解角色设计，见 [`themes/PETS.md`](themes/PETS.md)。

---

## 🎭 内置主题

默认壁纸 **樱夜湖畔**，默认桌宠 **星屑**。小助手里「精选壁纸」和「桌宠」可以分别切换。

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

- 🔐 只在你这台电脑上工作，不上传你的代码  
- 📡 桌宠会**只读**本机 Cursor 对话记录的一小段（用来认「在读 / 在写」这类状态），**气泡里不会出现你的对话正文**  
- 🖱️ 正常点选、打字不受影响；桌宠可以点、可以拖  
- 🚫 **不修改** Cursor 安装目录  
- 🚫 **不写入** 你的设置 / API Key  
- ⚠️ 换肤期间，尽量不要在本机跑来路不明的程序  

个别区域（比如某些终端画面）可能透不出壁纸——是界面本身的限制，不是皮肤坏了。

---

## ❓ 常见问题

**Q: 小助手在哪？怎么换壁纸 / 桌宠？**  
A: 点桌面 **Cursor Dream Skin**，右下角通知区会出现图标。右键 → **精选壁纸** 或 **桌宠**；双击打开管理界面。

**Q: 桌宠一直显示「正在想」？**  
A: 旧版会误判。请用最新版：状态主要跟着你的 Agent 活动走，不会再被「Cursor Agents」这种面板名骗住。

**Q: 点快捷方式没反应？**  
A: 小助手可能已经在跑；管理界面再点一次。还可看 `%LOCALAPPDATA%\CursorDreamSkin\gui-launch.log`。

**Q: 皮肤用上了但字发灰 / 看不清？**  
A: 把 Cursor Color Theme 切成与皮肤明暗一致；或在管理界面调高「编辑区清晰度」。

**Q: 还原之后感觉还没完全干净？**  
A: 完全退出 Cursor，再用平时的方式打开即可。

**Q: 支持 Mac / Linux 吗？**  
A: 现在是 **Windows 版**。Mac 可参考上面提到的 KinGao 项目。

---

## 🗺️ 接下来想做的

- [x] Windows 换肤 + 管理界面  
- [x] 壁纸 / 桌宠分开选 + 小助手  
- [x] 透明桌宠 + 跟 Agent 活动换表情  
- [x] 桌宠交互（唤起 Cursor、记住位置、换角色）  
- [ ] README 真实效果截图  
- [ ] 可选：开机自启  
- [ ] 可选：更实时的活动感知（默认仍保持简单）  
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
| `scripts/cds-transcript-sense.ps1` | 根据本机对话记录感知活动 |
| `scripts/chroma-pet.exe` | 绿幕/品红 → 透明 PNG |
| `scripts/start-dream-skin.ps1` | 命令行应用皮肤 |
| `scripts/switch-theme.ps1` | 换壁纸主题 |
| `scripts/restore-dream-skin.ps1` | 还原 |
| `scripts/make-theme.mjs` | 从图片生成主题 |
| `scripts/pack-portable.ps1` | 打便携包 |

状态目录：`%LOCALAPPDATA%\CursorDreamSkin`。  
默认壁纸 / 桌宠见 `themes/catalog.json` 的 `featuredDefault`、`featuredDefaultPet`。

</details>
