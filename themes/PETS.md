# 桌宠设计说明

灵感来自 [myunwang/LLMPET](https://github.com/myunwang/LLMPET)：**同一角色、多表情、气泡报任务**。  
角色为 Cursor Dream Skin **原创二次元 Q 版**，未使用 LLMPET 素材。

## 三款皮肤

| ID | 名称 | 设定 |
|----|------|------|
| `pet-spark` | 星屑 | 暖琥珀发色、星发夹的 Q 版女孩 |
| `pet-inkdot` | 墨点 | 青黑短发、墨滴饰物的 Q 版少年感角色 |
| `pet-byte` | 电波 | 浅紫粉发、天线夹的赛博 Q 版女孩 |

## 表情（状态机）

| 文件 | 状态 | 何时出现 |
|------|------|----------|
| `idle.png` | 待命 | 有 Cursor，无 Agent / 文件信号 |
| `working.png` | 干活 | Transcript：Write/Shell 等；或窗口标题像在编辑文件 |
| `thinking.png` | 思考 | Transcript：Read/Grep/Task 或刚发提问；标题启发式兜底 |
| `happy.png` | 开心 | Agent 刚结束庆祝，或刚换了文件 |
| `attention.png` | 看一眼 | Agent 信号刚消失，提醒你看结果 |
| `sleeping.png` | 睡觉 | Cursor 未开，或约 4 分钟无变化 |
| `error.png` | 出错 | 标题里出现失败 / 错误类字样 |

### 活动感知（优先 Transcript，不做 Hooks）

只读 `%USERPROFILE%\.cursor\projects\*\agent-transcripts\**\*.jsonl` 尾部：

- 最近约 30 秒内有写入 → 视为 Agent 活跃  
- 工具名映射：`Write`/`Shell`…→干活；`Read`/`Grep`/`Task`…→思考  
- 气泡详情形如 `Agent · Read`（不含对话正文）  
- 标题 / CDP 仅作兜底（Cursor 是否打开、普通文件名）

实现：`scripts/cds-transcript-sense.ps1`（桌宠启动时加载）。

## 交互

- **左键点击**：唤起 Cursor（未打开则启动；找不到安装时打开管理界面）；点一下会闪开心表情
- **拖动**：移动桌宠；松手后记住位置（下次启动还原）
- **右键菜单**：唤起 Cursor · 打开管理界面 · 换桌宠 · 刷新任务 · 复位到右下角 · 隐藏

## 透明规范

- 素材必须是 **真透明 PNG（alpha）**，禁止品红底 `#FF00FF` 当最终文件。
- 生成稿可用绿幕 `#00FF00` 或品红底，再用 `scripts/chroma-pet.exe` 做**边缘洪水填充**抠成 alpha（不会全局抹掉紫色头发）。
- 桌宠窗口用 `UpdateLayeredWindow` 按像素 alpha 合成，**不再使用** WinForms `TransparencyKey`。
- 管理界面预览对宠物图走去品红/绿幕处理，并用棋盘底 + `object-fit: contain`。
