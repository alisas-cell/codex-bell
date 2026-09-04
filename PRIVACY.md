# Codex Bell Privacy / 隐私说明

> 中文在前，English follows.

# 中文

Codex Bell 是一个本地 macOS 伴侣工具。它的隐私设计目标不是“收集更多信息来做更聪明的判断”，而是尽量只使用完成任务状态提醒所必须的生命周期信号。

## Bell 需要知道什么？

为了把 Codex 任务显示为 Running / Completed / Failed / Interrupted 等状态，Bell 可能处理经过限制的生命周期元数据，例如：

- 任务 / turn 的稳定标识
- 生命周期事件类型
- 时间戳
- 状态
- 为 UI 生成的脱敏短名称
- Bell 自己的设置

## Bell 不应该持久化什么？

Codex Bell 的生产实现和诊断设计不得为了任务状态 UI 而持久化：

- 完整 Prompt
- 完整回复
- 原始 transcript
- Tool 参数
- Tool 结果
- 源代码正文
- 私有 URL
- 绝对项目路径
- API Key / Token / Secret

## 当前 Codex 桌面集成

在目前已验证的 Codex 桌面环境中，Bell 使用本地 Codex session 中的生命周期记录来识别真实 GUI 任务。

实现应只解析支持的生命周期事件，不应把原始 JSONL 行、Prompt、工具调用或代码内容复制进 Bell 的持久化状态。

## 诊断信息

Settings → Connection 中提供：

- 打开诊断信息
- 复制脱敏诊断信息

诊断输出必须保持脱敏。

提交 Issue 前，请再次人工检查诊断文本，不要上传真实 Prompt、源码、Token 或私人路径。

## 网络

Codex Bell 的核心本地任务监控不需要由 Codex Bell 自建云端账户或服务端。

如果未来项目增加网络能力，必须在本文件中单独说明。

## 数据保留

主界面 Recent 只展示最近的少量终态任务。内部持久化仅用于恢复有限的脱敏任务状态和设置。

## 变化

Codex 本身是持续更新的产品。如果未来 Codex 的本地生命周期接口发生变化，Bell 的读取方式可能调整；任何扩大读取范围或新增网络传输的行为都应在 Release 和本隐私文件中明确说明。

---

# English

Codex Bell is a local macOS companion utility. Its privacy goal is not to collect more context for smarter inference; it is to use only the lifecycle signals needed to notify you about task state.

## What does Bell need to know?

To render states such as Running, Completed, Failed, and Interrupted, Bell may process limited lifecycle metadata such as:

- stable task / turn identifiers
- lifecycle event type
- timestamps
- state
- sanitized short labels for UI
- Bell's own settings

## What should Bell not persist?

The production implementation and diagnostics must not persist the following merely to power the task-state UI:

- full prompts
- full responses
- raw transcripts
- tool arguments
- tool results
- source-code bodies
- private URLs
- absolute project paths
- API keys, tokens, or secrets

## Current Codex desktop integration

In the currently verified Codex desktop environment, Bell identifies real GUI tasks from local Codex session lifecycle records.

The implementation should parse only supported lifecycle events and should not copy raw JSONL records, prompts, tool calls, or code content into Bell's persisted state.

## Diagnostics

Settings → Connection provides:

- Open Diagnostics
- Copy Redacted Diagnostics

Diagnostic output must remain sanitized.

Before posting diagnostics in a GitHub Issue, inspect the text yourself and do not upload real prompts, code, tokens, or private paths.

## Network

Core local task monitoring does not require a Codex Bell cloud account or Bell-operated backend.

If future versions add network capabilities, they must be documented here.

## Retention

The main UI only shows a small number of recent terminal tasks. Internal persistence is limited to what is needed for restoring sanitized task state and settings.

## Changes

Codex is a fast-moving product. If its local lifecycle interface changes, Bell's integration may need to change. Any future expansion of data access or network transmission should be explicitly documented in both release notes and this file.
