## Summary

本变更用于把当前 MVP 中仍处于“前端占位 + controller 未完成”状态的番茄钟能力补齐为可联调、可恢复的真实功能实现。目标是在当前前端与占位后端基础上，先完成开始时间持久化、剩余时间计算与对前端输出、`resting` / `studying` 状态流转、专注/休息时长修改，以及有限轮次循环支持。

## Why

### Background

番茄钟是 APP 的核心功能，倒计时是否由用户启动直接决定关键的 `studying` / `resting` 业务状态流转。当前仓库已具备主界面、基础 controller 接口和一组番茄钟相关文档，但最新判断应以 `lib/` 下实际代码为准；现阶段代码仍处于“可运行 MVP + 部分占位实现”的状态。

根据当前 `lib/` 中的真实实现，番茄钟展示仍分裂为两套来源：时间文本、按钮态部分来自 `AppController`，顶部进度条和部分重置行为仍依赖 `UIWidgets` 内部的 `_fakeTimer` / `_fakeProgress` 演示逻辑。同时，`toggleTimer()`、`resetTimer()` 仍未完成，统计面板与分享卡片也仍是 UI 占位，因此真实业务流转、持久化恢复与前后端联调都缺乏稳定实现。

### Problem Statement

当前实现还没有形成番茄钟单一事实源，导致以下问题：

- `studying` / `resting` 的真实流转尚未由稳定状态机托管。
- 倒计时文本与顶部进度条不来自同一套真实状态，UI 仍存在本地假进度。
- 开始、暂停、恢复、重置的业务语义没有被完整实现。
- App 切后台、恢复、重启后，当前阶段与剩余时间无法可靠恢复。
- 专注时长、休息时长和循环次数还缺少完整、稳定的配置能力。

这使得当前番茄钟逻辑无法作为前后端联调、测试验证和后续功能扩展的稳定契约继续推进。

## What Changes

### New Resources Added

- `openspec/changes/improve-pomodoro-functionality/proposal.md`
- 后续将新增与本变更对应的设计、specs 和任务工件

### New Capabilities

- `pomodoro-persistence-and-remaining-time`：使用简单的本地数据库或等价轻量持久化方案保存番茄钟开始时间，并由 controller 统一计算剩余时间后通过接口提供给前端。
- `pomodoro-state-transitions`：定义番茄钟状态变化如何驱动 `resting` / `studying` 业务状态流转，以及开始、暂停、恢复、重置和阶段自然结束后的行为。
- `pomodoro-duration-and-cycle-settings`：定义专注时间、休息时间和有限循环次数的配置能力，默认专注 `25min`、休息 `5min`，默认不循环，不支持无限循环。


## Success Criteria

- 番茄钟开始时间能够被持久化保存，并可在恢复时用于重新计算当前阶段剩余时间。
- controller 能通过稳定接口向前端提供剩余时间，作为倒计时文本与进度展示的共同来源。
- 番茄钟状态变化能够正确驱动 `resting` / `studying` 的业务状态流转。
- 专注时间与休息时间支持修改，默认值分别为 `1500` 秒和 `300` 秒。
- 专注循环支持有限正整数轮次，默认不循环，不支持无限循环。
- UI 不再依赖 `_fakeProgress` 作为正式番茄钟进度来源。

## Scope

- **In Scope**
  - `AppController` 中的真实番茄钟状态机与公开方法实现
  - 开始时间持久化、剩余时间恢复与对前端的状态输出
  - 专注时长、休息时长、循环次数的配置能力
  - `UIWidgets` 对番茄钟真实状态的消费替换
  - 与主入口相关的必要初始化/恢复接线

- **Out of Scope**
  - 对话系统完整实现
  - Live2D 正式接入
  - 完整历史明细、图表系统或复杂数据库设计
  - 云端同步、网络接口与整体 UI 重做

## Timeline

- 当前阶段：完成 proposal，冻结问题定义、采用方案与能力边界
- 下一阶段：补 design，明确状态机、持久化模型、UI 接线和恢复策略
- 再下一阶段：编写 specs 与 tasks，进入实现与联调

## References

- `docs/dev-guide.md`
- `docs/interface_spec.md`
- `docs/pomodoro/pomodoro_interface_spec.md`
- `docs/pomodoro/pomodoro_state_flow.md`
- `docs/pomodoro/pomodoro_integration_rules.md`
- `docs/pomodoro/番茄钟功能简要.md`
- `lib/app_controller.dart`
- `lib/ui_widgets.dart`
- `lib/main.dart`
