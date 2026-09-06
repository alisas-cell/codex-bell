# 🔔 Codex Bell

<p align="center">
  <strong>Hear when Codex needs you.</strong><br>
  <strong>Codex 干完活、出错或需要你时，让 Mac 主动叫你。</strong>
</p>

<p align="center">
  中文 · English
</p>

> **Unofficial community project / 非官方社区项目**  
> Codex Bell is an independent community project by **森虫虫进化中（全网同名）**. It is not affiliated with or endorsed by OpenAI.  
> Codex Bell 是由 **森虫虫进化中（全网同名）** 制作的独立社区项目，与 OpenAI 无隶属或认可关系。

---

# 中文

## v1.0.1 更新 · 2026-09-06

- **减少错误的完成提醒：** 内部子代理结束不再被当作主任务完成；服务过载、额度不足等错误结束会标记为失败。
- **重试和未知结果更清楚：** 明确正在重连或重试时继续保持运行；无法确认成功的空结果显示「结果未确认」，不播报完成。读取到的历史误判会安静纠正，已过期的排队提醒会跳过。
- **面板更紧凑：**「最近完成」最多显示最新 3 条，较早的脱敏历史仍保留在内部。

[下载 v1.0.1（Apple silicon）](https://github.com/alisas-cell/codex-bell/releases/download/v1.0.1/Codex-Bell-macOS-v1.0.1.zip) · [完整更新说明](https://github.com/alisas-cell/codex-bell/releases/tag/v1.0.1)

## Codex Bell 是什么？

我很喜欢用 Codex 跑长任务，但我一直有一个很具体的小痛点：

**任务跑起来以后，我不想一直盯着 Codex 看它到底结束了没有。**

所以我做了 **Codex Bell**。

它是一个轻量的 macOS Codex 伴侣工具。你可以把它停靠在屏幕左侧或右侧，让它安静地待在边缘；当 Codex 的任务状态发生变化时，Codex Bell 会用提示音、语音和系统通知告诉你。

核心目标只有一句话：

> **Stop babysitting Codex. 让 Codex 做事的时候，你去做别的。**

---

## ✨ 主要功能

### 🔔 任务完成后主动提醒

Codex Bell 会追踪 Codex 的任务生命周期，并在可识别的状态变化时给出提醒，例如：

- Running / 正在运行
- Completed / 已完成
- Failed / 失败
- Interrupted / 已中断
- Waiting / 等待你处理（在当前 Codex 表面可提供相应事件时）

不用隔几十秒切回 Codex 看一眼。

### 🗣️ 语音播报

打开 **「开启语音播报」** 后，Bell 会在任务状态变化时播放提示。

语音和提示音使用独立的 Bell 音量，不会修改 macOS 的系统输出音量。

调节 Bell 音量时，连续快速操作会被合并：停止操作约 500ms 后只播放一次最终试听，不会排队重复念很多遍。

### 🧠 多任务友好

主面板默认只显示最需要你关注的 4 个 Active 任务。

如果同时有更多任务：

- 默认保持紧凑
- 显示 `还有 N 个正在运行`
- 展开后只在 Active 区域内部滚动
- 等待你操作的任务会优先排在普通 Running 任务前面
- 普通 Running 任务按运行时间排序

Recent 区域只显示最近 3 条终态记录，让 280pt 的窄面板不会越用越长。

### ↔️ 左右停靠

Codex Bell 只保留两种停靠方式：

- 左侧
- 右侧

你可以拖动切换。

黄色按钮不是传统的“最小化到 Dock”，而是：

> **收起到边缘**

收起后，屏幕边缘会始终保留一个紫色悬浮把手，鼠标移过去或点击即可重新展开。

### 🟣 Dock 图标默认隐藏

Codex Bell 是一个常驻小工具，所以默认：

**不占用 Dock。**

你也可以在：

`设置 → 常规 → 在程序坞中显示图标`

随时打开 Dock 图标。

关闭 Dock 图标不会停止：

- Codex 任务同步
- 语音提醒
- 系统通知
- 边缘悬浮把手

### 🌏 中文 / English

底部可以直接切换：

`中文 | English`

中文模式下，应用自身的 UI、通知和语音使用中文；真实项目名和任务名保持原样。

英文模式同理。

### ☕ 任务运行时保持 Mac 唤醒

可在设置中打开：

`任务运行时保持 Mac 唤醒`

Codex 有任务运行时，Bell 可以请求系统暂时避免整机睡眠；屏幕仍然可以正常熄灭。任务结束后会释放对应的保持唤醒请求。

---

## 🔐 隐私设计

Codex Bell 的设计原则是：

> **只拿“任务生命周期”所需要的信息，不把你的工作内容变成 Bell 的数据。**

在当前已验证的 Codex 桌面集成中，Bell 从本机 Codex session 生命周期记录中识别任务状态。

Codex Bell 不会为了显示任务状态而持久化：

- 完整 Prompt
- 完整 Codex 回复
- Tool 参数和结果
- 源代码正文
- 原始 transcript
- 私有 URL
- 绝对项目路径
- Token / Secret

Bell 自己保存的是经过限制和脱敏的任务状态信息与应用设置。

更多信息见：

[`PRIVACY.md`](./PRIVACY.md)

> Codex 是一个持续快速更新的产品。Codex 内部事件格式或桌面应用行为发生变化时，Bell 的集成也可能需要同步更新。

---

## 📦 安装

### 方式一：GitHub Release

1. 打开本仓库右侧的 **Releases**
2. 下载最新的 macOS 安装包
3. 解压
4. 将 `Codex Bell.app` 放入 `Applications`
5. 打开 Codex Bell
6. 根据首次启动引导完成 Codex 集成检查
7. 启动一个 Codex 任务进行测试

> **v1.0.1 未经过 Apple 公证。** 当前二进制采用 hardened runtime 的本地 ad-hoc 签名，不是 Apple Developer ID 签名。macOS 可能会阻止首次启动；请先尝试按住 Control 点击应用并选择「打开」，或到「系统设置 → 隐私与安全性」确认「仍要打开」。不要关闭 Gatekeeper，也不要执行来源不明的 `xattr` 命令。你也可以从本仓库源码自行构建。

### 方式二：从源码构建

```bash
git clone https://github.com/alisas-cell/codex-bell.git
cd codex-bell
swift test
swift build -c release
```

实际 App 打包方式请参考仓库中的构建脚本。

---

## 🖥️ 系统要求

- **macOS：** 14 Sonoma 或更高版本
- **架构：** Apple silicon（arm64）；v1.0.1 未提供 Intel 构建
- **已验证 Codex：** `codex-cli 0.153.0-alpha.5`
- **构建验证环境：** macOS 15.3.2（arm64）
- **签名：** hardened runtime + ad-hoc；**未使用 Apple Developer ID，未经过 Apple 公证**

---

## 🚀 快速开始

1. 打开 **Codex Bell**
2. 选择左侧或右侧停靠
3. 打开 **开启语音播报**
4. 调整 Bell 音量
5. 打开 Codex，启动一个任务
6. 去做别的事情
7. 等 Bell 叫你回来

就这么简单。

---

## 🧩 当前设计原则

Codex Bell 不想成为另一个复杂的“AI Dashboard”。

它更像一个安静的 Mac 小工具：

- 需要的时候出现
- 不需要的时候缩在屏幕边缘
- 不占 Dock
- 不抢焦点
- 不要求你不断查看
- 真有事情再叫你

---

## 🛠️ 开发

### 本地测试

```bash
swift test
```

### Release 构建

```bash
./scripts/build-app.sh
./scripts/package-release.sh --skip-build
```

仓库还包含面向真实 macOS App bundle 的打包与签名脚本；发布前必须执行 Release 构建、签名检查和真实 Codex 生命周期 smoke test。

---

## 🐛 反馈问题

如果你发现问题，欢迎提交 GitHub Issue。

请尽量包含：

- macOS 版本
- Mac 芯片（Apple silicon / Intel）
- Codex 版本
- Codex Bell 版本
- 复现步骤
- 预期结果
- 实际结果

**请不要上传 Prompt、源码、Token、私有路径或未经脱敏的诊断信息。**

---

## 🤝 贡献

欢迎 PR。

在提交代码前，请：

1. 说明问题或目标
2. 保持改动范围尽量小
3. 为行为变更补充测试
4. 不在测试 fixture 中放真实 Prompt、密钥或私有路径
5. 确保 `swift test` 通过

详见 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。

---

## 📜 License

MIT License。详见 [`LICENSE`](./LICENSE)。

---

## 👤 作者

**森虫虫进化中（全网同名）**

如果你是在小红书、Bilibili 或其他平台看到这个项目，欢迎来 GitHub 留一个 Star，也欢迎告诉我你还希望 Codex Bell 增加什么。

---

# English

## v1.0.1 update · September 6, 2026

- **Fewer false completion alerts:** internal subagent turns no longer count as the main task finishing. Terminal errors, including capacity and usage-limit errors, are marked as failed.
- **Clearer retries and uncertain outcomes:** explicit reconnect/retry states remain running. Empty outcomes without confirmation of success show “Result unconfirmed” without a completion announcement. Historical misclassifications are corrected silently when read, and superseded queued alerts are skipped.
- **A more compact panel:** Recent now shows the latest three terminal tasks, while older redacted history remains stored internally.

[Download v1.0.1 for Apple silicon](https://github.com/alisas-cell/codex-bell/releases/download/v1.0.1/Codex-Bell-macOS-v1.0.1.zip) · [Full release notes](https://github.com/alisas-cell/codex-bell/releases/tag/v1.0.1)

## What is Codex Bell?

I love running long tasks in Codex, but I kept running into one very specific problem:

**once a task starts, I don't want to keep checking Codex just to see whether it's done.**

So I built **Codex Bell**.

Codex Bell is a lightweight macOS companion for Codex. It sits quietly on the left or right edge of your screen and lets you know when a Codex task changes state through a chime, voice announcement, and system notification.

The idea is simple:

> **Stop babysitting Codex. Let Codex work while you do something else.**

---

## ✨ Features

### 🔔 Get called back when a task changes state

Codex Bell follows the Codex task lifecycle and can surface recognizable states such as:

- Running
- Completed
- Failed
- Interrupted
- Waiting for you, when the current Codex surface exposes the relevant event

You no longer need to switch back to Codex every few seconds.

### 🗣️ Voice announcements

Turn on **Enable Voice Announcements** and Bell can speak when task state changes.

Bell has its own volume control and does not change your macOS system output volume.

Rapid volume adjustments are coalesced: after you stop interacting for about 500 ms, Bell plays one final preview instead of queuing the same sentence several times.

### 🧠 Built for multiple concurrent tasks

The compact panel shows up to four active tasks by default.

When more are running:

- the panel stays compact
- a `N more active` disclosure appears
- expanded tasks scroll inside the Active section only
- tasks needing your attention are prioritized above normal Running tasks
- normal Running tasks are ordered by elapsed time

Recent shows only the three latest terminal tasks.

### ↔️ Left or right edge docking

Codex Bell intentionally keeps docking simple:

- Left
- Right

The yellow control does not minimize to the Dock. It means:

> **Collapse to Edge**

When collapsed, a persistent purple handle remains visible at the screen edge. Hover or click it to bring Bell back.

### 🟣 Dock icon hidden by default

Codex Bell is meant to behave like a small persistent utility, so it does not occupy your Dock by default.

You can turn it on at:

`Settings → General → Show Codex Bell in Dock`

Turning the Dock icon off does not stop task monitoring, voice announcements, notifications, or the edge handle.

### 🌏 Chinese / English

Switch directly from the footer:

`中文 | English`

App-authored UI, notifications, and speech follow your selected language. Real project and task names are left unchanged.

### ☕ Keep your Mac awake while tasks run

Optional setting:

`Keep Mac awake while tasks are running`

Bell can request that macOS avoid full system sleep while Codex has active work. Your display can still turn off normally. The assertion is released when no running task remains.

---

## 🔐 Privacy by design

Codex Bell follows one rule:

> **Read the lifecycle signal, not your work.**

On the currently verified Codex desktop integration, Bell derives task state from local Codex session lifecycle records.

For its task UI, Codex Bell is designed not to persist:

- full prompts
- full Codex responses
- tool arguments or results
- source-code bodies
- raw transcripts
- private URLs
- absolute project paths
- tokens or secrets

Bell stores only limited, sanitized task-state information and app settings.

Read more in:

[`PRIVACY.md`](./PRIVACY.md)

> Codex is a fast-moving product. If its local lifecycle format or desktop behavior changes, Codex Bell may need an integration update.

---

## 📦 Installation

### Option 1: GitHub Release

1. Open **Releases** on this repository
2. Download the latest macOS build
3. Unzip it
4. Move `Codex Bell.app` to `Applications`
5. Open Codex Bell
6. Follow the first-run integration check
7. Start a Codex task to verify the connection

> **v1.0.1 is NOT NOTARIZED.** Its binary has a local ad-hoc signature with hardened runtime, not an Apple Developer ID signature. macOS may block the first launch. First try Control-clicking the app and choosing **Open**, or use **System Settings → Privacy & Security → Open Anyway**. Do not disable Gatekeeper or run untrusted `xattr` commands. You can also build directly from this repository's source.

### Option 2: Build from source

```bash
git clone https://github.com/alisas-cell/codex-bell.git
cd codex-bell
swift test
swift build -c release
```

See the repository build scripts for the final macOS app-bundle packaging flow.

---

## 🖥️ Requirements

- **macOS:** 14 Sonoma or later
- **Architecture:** Apple silicon (arm64); v1.0.1 does not include an Intel build
- **Verified Codex:** `codex-cli 0.153.0-alpha.5`
- **Build verification host:** macOS 15.3.2 (arm64)
- **Signing:** hardened runtime + ad-hoc; **not Apple Developer ID signed and NOT NOTARIZED**

---

## 🚀 Quick start

1. Open **Codex Bell**
2. Dock it Left or Right
3. Turn on **Enable Voice Announcements**
4. Set Bell volume
5. Start a task in Codex
6. Go do something else
7. Let Bell call you back

That's it.

---

## 🧩 Product philosophy

Codex Bell is not trying to become another AI dashboard.

It is meant to feel like a quiet native Mac utility:

- visible when useful
- tucked away when not
- no Dock clutter by default
- no unnecessary focus stealing
- no constant checking
- it calls you only when something matters

---

## 🛠️ Development

### Tests

```bash
swift test
```

### Release build

```bash
./scripts/build-app.sh
./scripts/package-release.sh --skip-build
```

Before a public release, the project should also pass app-bundle packaging, signing verification, and a real Codex lifecycle smoke test.

---

## 🐛 Bug reports

GitHub Issues are welcome.

Please include:

- macOS version
- Mac architecture
- Codex version
- Codex Bell version
- reproduction steps
- expected behavior
- actual behavior

**Do not post prompts, source code, tokens, private paths, or unredacted diagnostics.**

---

## 🤝 Contributing

Pull requests are welcome.

Before opening a PR:

1. explain the problem or goal
2. keep the change focused
3. add tests for behavioral changes
4. never put real prompts, secrets, or private paths in fixtures
5. make sure `swift test` passes

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).

---

## 📜 License

MIT License. See [`LICENSE`](./LICENSE).

---

## 👤 Author

**森虫虫进化中 (same handle across platforms)**

If you found Codex Bell through a video or social post, a GitHub Star is always appreciated — and I'd love to hear what you want Bell to do next.

---

## Disclaimer

Codex Bell is an independent, unofficial community project. It is not affiliated with or endorsed by OpenAI. OpenAI trademarks and product names belong to their respective owner(s). Codex Bell uses its own independent icon and branding.
