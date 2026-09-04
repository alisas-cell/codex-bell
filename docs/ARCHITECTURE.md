# Architecture / 架构概览

> This document intentionally stays high level and does not expose private user session content.

## 中文

Codex Bell 由几类职责组成：

1. **Lifecycle source**  
   从本机 Codex 可用的生命周期信号中识别任务开始、结束、中断等状态。

2. **Reducer / Task store**  
   根据稳定任务标识合并事件，避免同一个 turn 重复生成多行。

3. **Presentation**  
   Active / Recent 任务排序、4 条折叠展示、Recent 5 条上限。

4. **Announcement queue**  
   提示音、语音与优先级串行化，避免多任务提醒相互覆盖。

5. **macOS window layer**  
   AppKit + SwiftUI 负责窄面板、左右停靠、边缘 Handle、Settings 等。

6. **Privacy boundary**  
   生命周期解析和持久化层只保留任务状态所需的有限信息，不把完整 Prompt、Tool 结果或源代码复制进 Bell 状态。

## English

Codex Bell is split into a few responsibilities:

1. **Lifecycle source**  
   Detects supported task lifecycle signals from the local Codex environment.

2. **Reducer / task store**  
   Reconciles events by stable task identity so one turn does not become duplicate rows.

3. **Presentation**  
   Orders Active/Recent tasks, keeps the default Active list compact, and caps the main Recent view.

4. **Announcement queue**  
   Serializes chimes and speech so concurrent task events do not talk over one another.

5. **macOS window layer**  
   AppKit + SwiftUI provide the narrow panel, Left/Right docking, persistent edge handle, and Settings.

6. **Privacy boundary**  
   Lifecycle parsing and persistence retain only limited state needed by Bell, rather than copying full prompts, tool output, or source bodies.
