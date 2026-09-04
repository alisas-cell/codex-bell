# Contributing to Codex Bell / 参与贡献

# 中文

感谢你愿意改进 Codex Bell。

## 提交 Issue

请优先提供：

- macOS 版本
- Mac 架构
- Codex 版本
- Codex Bell 版本
- 复现步骤
- 预期结果
- 实际结果

请不要提交真实 Prompt、源码、Token、私有 URL、绝对项目路径或未经脱敏的日志。

## 提交 PR

1. Fork / 创建分支
2. 尽量保持一个 PR 只处理一个问题
3. 行为改动必须补充相应测试
4. 运行 `swift test`
5. 如涉及 macOS UI，请说明你实际验证过的系统版本
6. 如涉及 Codex 生命周期读取，请说明是否改变隐私边界
7. 不要把真实用户数据写进 fixture

## 产品原则

贡献应尽量维持 Codex Bell 的核心定位：

- 小
- 快
- 安静
- 原生 macOS 风格
- 不把 Bell 变成复杂 Dashboard
- 不要求用户持续盯着它
- 隐私边界优先

---

# English

Thanks for helping improve Codex Bell.

## Issues

Please include:

- macOS version
- Mac architecture
- Codex version
- Codex Bell version
- reproduction steps
- expected result
- actual result

Do not post real prompts, source code, tokens, private URLs, absolute project paths, or unredacted logs.

## Pull requests

1. Fork / create a branch
2. Keep each PR focused
3. Add tests for behavioral changes
4. Run `swift test`
5. For macOS UI changes, state the macOS version you actually tested
6. For Codex lifecycle changes, explain whether the privacy boundary changed
7. Never use real user data in fixtures

## Product principles

Contributions should preserve the core product idea:

- small
- fast
- quiet
- native to macOS
- not another complex AI dashboard
- no constant babysitting
- privacy boundary first
