# Changelog

All notable public changes to Codex Bell will be documented here.

## [1.0.1] - 2026-09-06

### 中文

- 修复内部子代理结束时误播主任务「已完成」的问题，并清理读取到的旧子代理任务记录。
- 结束事件优先检查错误和明确的重试状态；服务过载、额度不足等错误不会再被空结果掩盖而误判成功。
- 明确的重连/重试保持运行；无法确认成功的空结果显示「结果未确认」，不触发完成播报。
- 读取到旧的错误完成记录时安静纠正；忽略已被新状态取代的排队提醒，保留正常完成的去重行为。
- 「最近完成」可见数量从 5 条减少为 3 条，内部历史保留。

### English

- Filter internal subagent lifecycle events so their turns cannot announce completion of the user's main task; remove old subagent rows when identified.
- Prioritize structured terminal errors and explicit retry states. Capacity and usage-limit errors can no longer become successful completions through empty output.
- Keep explicit reconnect/retry states running. Show unconfirmed empty outcomes as “Result unconfirmed” without a completion announcement.
- Silently correct historical false-success records when read and skip superseded queued alerts while preserving normal completion deduplication.
- Reduce Recent from five visible terminal rows to three; retain internal history.

## [1.0.0] - Initial public release

### 中文

首个公开版本。

- 原生 macOS Codex 任务状态伴侣
- 中文 / English 双语 UI 与语音
- Running / Completed / Failed / Interrupted 等生命周期状态展示
- Active 默认 4 条，多任务可展开并局部滚动
- Recent 最多 5 条
- 左侧 / 右侧停靠
- 收起后保留紫色边缘把手
- Dock 图标默认关闭，可在设置中打开
- 独立 Bell 音量
- 音量快速连续调整采用 trailing debounce，只试听一次最终音量
- 可选任务运行时保持 Mac 唤醒
- 脱敏诊断
- 本地、隐私优先的生命周期读取

### English

Initial public release.

- Native macOS companion for Codex task state
- Chinese / English UI and voice
- Lifecycle states including Running, Completed, Failed, and Interrupted
- Four active rows by default with expandable local scrolling
- Up to five recent terminal rows
- Left / Right docking
- Persistent purple edge handle when collapsed
- Dock icon off by default, optional in Settings
- Independent Bell volume
- Trailing-debounced volume preview
- Optional keep-awake while tasks run
- Sanitized diagnostics
- Local, privacy-bounded lifecycle integration
