## Summary

本变更用于把番茄钟能力收敛为 `AppController` 驱动的单一事实源，并为后续联调、验证与归档提供权威契约。根据当前仓库现状，番茄钟核心状态机、快照持久化、启动恢复、配置更新与真实进度推导已经大部分落地；本 change 现阶段的重点已从“补齐核心实现”转为“对齐文档 / OpenSpec 与当前代码，并补完归档所需验证证据”。

## Why

### Background

番茄钟是 APP 的核心闭环之一，直接影响 `studying` / `resting` 的业务状态流转、UI 控制态、恢复逻辑与陪伴行为。当前仓库应优先以 `lib/` 下已合入代码为准，而不是继续沿用立项初期的旧文档判断现状。

截至当前仓库状态：
- `lib/app_controller.dart` 已提供 `pomodoroState`、`phaseStatus`、阶段快照持久化、`initialize()`、`startTimer()`、`pauseTimer()`、`resetTimer()`、配置更新方法与恢复逻辑。
- `lib/main.dart` 已在 `MainStage` 初始化阶段触发 `controller.initialize()`，并用 `FutureBuilder` 保护首帧恢复。
- `lib/ui_widgets.dart` 已使用 `remainingSeconds` 与 `currentPhaseDurationSeconds` 推导真实进度，并接入专注/休息/循环三个配置输入。

### Remaining Problem

虽然核心实现已基本落地，但当前仍有两类问题阻塞归档：

- OpenSpec 与项目文档中仍保留大量“实现前现状”的旧描述，例如：`toggleTimer()` / `resetTimer()` 仍是占位、UI 仍依赖 `_fakeProgress`、主入口尚未接初始化。
- 规范与实现尚未完全闭环：`tasks.md` 第 6 节验证项仍未完成，且当前 UI 仍保留 `toggleTimer()` + `isActive` 驱动的单播放/暂停按钮，尚未完全对齐为 OpenSpec 目标中的显式“开始 / 暂停 / 重置”控制语义。

## Current Implementation Status

### Already Landed

- controller 已成为番茄钟主要状态源，包含业务阶段、运行阶段、时长配置、循环配置与 session 计数。
- 使用 `shared_preferences` 风格本地 key-value 存储持久化 pomodoro snapshot 与配置。
- 启动恢复、后台恢复、过期阶段推进与 ready-state snapshot 已实现。
- 顶部进度与倒计时文本已消费同一套 controller 状态。
- 专注时长、休息时长、循环次数三个配置入口已接线到 controller 更新方法。

### Remaining Gaps Before Archive

- 还缺少 OpenSpec `tasks.md` 第 6 节要求的测试与人工验证证据。
- UI 控制区尚未完全收敛到 `startTimer()` / `pauseTimer()` / `resetTimer()` 三个显式控制入口；当前仍存在 `toggleTimer()` 兼容入口和 `isActive` 驱动的按钮态。
- 旧文档仍会误导后续开发者对当前实现状态的判断，需要同步校准。

## What Changes

### Capabilities Covered by This Change

- `pomodoro-persistence-and-remaining-time`：保存番茄钟运行快照，并在恢复时由 controller 统一计算剩余时间。
- `pomodoro-state-transitions`：定义 `resting` / `studying` 与 `ready` / `running` / `paused` 的组合语义，以及开始、暂停、恢复、重置与自然阶段推进规则。
- `pomodoro-duration-and-cycle-settings`：定义专注时长、休息时长和有限循环次数的配置能力，默认专注 `1500` 秒、休息 `300` 秒、默认不循环。

### Authority Boundary

- `openspec/changes/improve-pomodoro-functionality/` 负责定义目标 contract。
- 当前仓库 `lib/` 下的已合入实现负责反映实际落地状态。
- 归档判断必须同时满足“规范完成”与“实现/验证完成”，不能只看任一方。

## Success Criteria

- 番茄钟运行快照与配置可被稳定恢复。
- controller 为倒计时文本与进度展示提供同一套真实状态来源。
- `pomodoroState` 与 `phaseStatus` 的职责边界保持清晰。
- 三个配置输入与 controller 配置方法保持一致。
- 文档、OpenSpec 与当前实现状态保持一致。
- 归档前补齐测试、人工验证，以及剩余的 UI 控制语义差距。

## Scope

- **In Scope**
  - 番茄钟状态机、恢复、配置与 UI 消费 contract
  - OpenSpec 与项目文档的现状校准
  - 归档 readiness 判断

- **Out of Scope**
  - 对话系统新增能力
  - Live2D 正式接入
  - 历史统计正式建模
  - 云端同步、网络接口与整体 UI 重做

## Archive Readiness

**当前不能归档。**

阻塞项：
1. `openspec/changes/improve-pomodoro-functionality/tasks.md` 第 6 节验证任务未完成；
2. UI 控制语义尚未完全对齐为显式“开始 / 暂停 / 重置”三按钮；
3. 若现在归档，会把“核心实现已大部分落地”与“验证/规范闭环未完成”混为一谈。

## References

- `lib/app_controller.dart`
- `lib/ui_widgets.dart`
- `lib/main.dart`
- `openspec/changes/improve-pomodoro-functionality/design.md`
- `openspec/changes/improve-pomodoro-functionality/specs/`
- `openspec/changes/improve-pomodoro-functionality/tasks.md`
