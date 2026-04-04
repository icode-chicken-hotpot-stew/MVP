## Context

当前默认入口仍为 `lib/main.dart`，由 `MainStage` 创建单个 `AppController` 并注入 `UIWidgets`。本设计继续以 `lib/` 下当前已合入实现为准，并将 OpenSpec 视为目标契约。

与最初立项时相比，当前仓库已有明显进展：
- `lib/app_controller.dart` 已暴露 `pomodoroState`、`phaseStatus`、`focusDurationSeconds`、`restDurationSeconds`、`cycleCount`、`completedFocusCycles` 等番茄钟状态；
- `initialize()`、`startTimer()`、`pauseTimer()`、`resetTimer()` 与基于 `shared_preferences` 的快照持久化 / 恢复逻辑已经落地；
- `lib/main.dart` 已在启动阶段调用 `controller.initialize()`，并通过 `FutureBuilder` 保护首帧恢复；
- `lib/ui_widgets.dart` 已使用 controller 的真实剩余时间与当前阶段时长推导顶部进度，并接入专注 / 休息 / 循环三个配置输入。

因此，本设计文档不再描述“controller 仍只有四个 notifier、`toggleTimer()` / `resetTimer()` 为空实现、UI 仍依赖 `_fakeProgress`”的旧现状，而是用于冻结当前目标契约，并明确剩余未闭环项。

## Current Status and Remaining Gaps

当前 change 已大部分实现，但仍有两类差距需要明确保留：

1. **验证闭环未完成**：`tasks.md` 第 6 节中的测试、命令验证和人工验证仍未全部完成，当前不能据此直接归档。
2. **UI 控制语义未完全对齐目标**：OpenSpec 目标要求显式“开始 / 暂停 / 重置”控制与由 `pomodoroState + phaseStatus` 推导的展示语义；但当前 UI 仍保留 `toggleTimer()` + `isActive` 驱动的单播放/暂停按钮兼容实现。

## Source of Truth Policy

自本次改造起，番茄钟开发的权威依据固定为两部分：
- `openspec/changes/improve-pomodoro-functionality/` 中的 `proposal.md`、`design.md`、`specs/`、`tasks.md`
- 当前仓库 `lib/` 下已经合入的实现代码

若 OpenSpec 与当前代码冲突，应区分两类问题：
- 需要定义目标行为时，以 OpenSpec 为准；
- 需要确认“现在仓库已经做到什么”时，以已合入代码为准；
- 若二者出现偏差且尚未补齐验证，不应贸然归档，而应先修正文档或实现。

## Goals / Non-Goals

**Goals:**
- 建立以 `AppController` 为中心的番茄钟单一事实源
- 用稳定状态表示当前阶段、运行状态、配置项和循环进度
- 通过持久化的开始时间与阶段快照支持切后台、恢复与重启恢复
- 让前端的倒计时文本与顶部进度条消费同一套真实状态
- 为后续 specs、验证和归档提供明确的技术决策边界

**Non-Goals:**
- 不实现对话系统、Live2D 或其他陪伴交互能力
- 不引入复杂数据库 schema、repository 分层或云端同步
- 不在本次设计中覆盖完整历史明细、图表系统或分享卡片最终样式
- 不做超出番茄钟需求的 UI 重构

## Decisions

### 1. 在 `AppController` 内维护番茄钟状态与显式控制方法

采用方案：继续以 `AppController` 为唯一业务入口，在其中维护番茄钟所需状态、公开控制方法与私有计时 / 恢复逻辑。当前实现已经包含至少以下状态：
- `pomodoroState: ValueNotifier<PomodoroState>`
- `focusDurationSeconds: ValueNotifier<int>`
- `restDurationSeconds: ValueNotifier<int>`
- `phaseStatus: ValueNotifier<PomodoroPhaseStatus>`
- `cycleCount: ValueNotifier<int?>`
- `completedFocusCycles: ValueNotifier<int>`

并继续保留：
- `remainingSeconds`
- `currentDate`
- `isDrawerOpen`

公开控制方法以显式语义为准：
- `startTimer()`：待开始时开启专注；暂停时恢复当前阶段
- `pauseTimer()`：仅暂停当前运行中的阶段
- `resetTimer()`：回到默认待开始状态
- `updateFocusDuration(int seconds)`
- `updateRestDuration(int seconds)`
- `updateCycleCount(int? count)`
- `initialize()` 或等价恢复入口

`toggleTimer()` 在当前代码中仍存在，但对目标契约而言仅是兼容性入口：它本质上只是 `startTimer()` / `pauseTimer()` 的包装，不应再作为 OpenSpec 的正式目标交互。

理由：当前代码结构已经将 controller 作为主入口。若把计时恢复、剩余时间计算或阶段流转继续放在 `UIWidgets`，会重新引入双真相；若在当前 1 周快速开发窗口内过早拆出新的 service / repository 体系，则会放大本批次改动范围。

### 1.5 冻结 `pomodoroState` 与 `phaseStatus` 的职责边界

采用方案：将两个状态字段的职责严格拆开，并把消费约束直接写入 contract：
- `pomodoroState` 只表达业务阶段语义，供动画、对话、陪伴行为消费
- `phaseStatus` 只表达运行控制语义，供计时器控制、按钮态、恢复逻辑、持久化消费

固定解释如下：
- `pomodoroState = studying`：学习动画、禁用对话
- `pomodoroState = resting`：休息动画、允许休息对话
- `phaseStatus = ready`：默认待开始，尚未进入当前轮专注倒计时
- `phaseStatus = running`：当前阶段运行中
- `phaseStatus = paused`：当前阶段暂停中

特别说明：Ready 态虽然编码为 `pomodoroState = resting` + `phaseStatus = ready`，但其业务含义不是“当前正在休息”，而是“待开始 / 下一轮专注尚未开始”。因此任何需要区分“真正休息中”与“Ready 占位态”的逻辑，都必须同时判断 `phaseStatus`，不能只看 `pomodoroState`。

推荐的固定映射表：
- `resting + ready` = 待开始 / 下一轮专注未开始
- `studying + running` = 学习中
- `studying + paused` = 学习暂停
- `resting + running` = 休息中
- `resting + paused` = 休息暂停

### 2. 使用轻量 snapshot 持久化与恢复

采用方案：持久化一个轻量快照对象，至少包括：
- 当前阶段 `pomodoroState`
- 当前阶段状态 `phaseStatus`
- 当前阶段开始时间 `startedAt`（仅 `phaseStatus == running` 时必填）
- 当前阶段总时长 `phaseDurationSeconds`
- 当前剩余秒数（`paused` / `ready` 恢复时作为直接基准）
- `focusDurationSeconds`
- `restDurationSeconds`
- `cycleCount`
- `completedFocusCycles`

恢复时规则：
- 若 `phaseStatus == running`，以 `startedAt + phaseDurationSeconds` 与当前时间重新计算剩余时间
- 若阶段已过期，则根据状态机自动推进到下一阶段，直到落到一个未过期阶段或待开始状态
- 若 `phaseStatus == paused` 或 `phaseStatus == ready`，优先恢复最后一次保存的 `remainingSeconds`
- Ready 态持久化时固定保存：`startedAt = null`、`phaseDurationSeconds = focusDurationSeconds`、`remainingSeconds = focusDurationSeconds`

理由：用户明确要求保存“开始时间”。只保存剩余秒数无法处理切后台和重启期间的自然流逝，也无法判断阶段是否已过期。

### 3. 持久化层采用 `shared_preferences` 风格本地存储

采用方案：本次 change 固定以 `shared_preferences` 这一类 key-value 本地持久化实现番茄钟快照与配置保存；不引入 SQLite / Drift / Hive 作为本批次正式契约的一部分。

理由：当前仓库已经接入 `shared_preferences`，且本批次只需要持久化少量标量配置与单份运行快照。轻量 key-value 方案足以覆盖需求，也符合当前快速开发阶段的最小实现原则。

### 4. 用显式阶段状态消除 `resting` / Ready 的语义歧义

采用方案：保留两态业务状态：
- `PomodoroState.resting`
- `PomodoroState.studying`

同时新增显式阶段状态：
- `PomodoroPhaseStatus.ready`
- `PomodoroPhaseStatus.running`
- `PomodoroPhaseStatus.paused`

关键流转：
- 初次开始：`resting/ready` → `studying/running`
- 专注暂停：`studying/running` → `studying/paused`
- 专注恢复：`studying/paused` → `studying/running`
- 专注结束：`studying/running` → `resting/running`，并 `completedFocusCycles += 1`
- 休息暂停：`resting/running` → `resting/paused`
- 休息恢复：`resting/paused` → `resting/running`
- 休息结束且 `cycleCount == null`：回到 `resting/ready` 且 `remainingSeconds = focusDurationSeconds`，并将 `completedFocusCycles` 清零
- 休息结束且 `completedFocusCycles < cycleCount`：进入下一轮 `studying/running`
- 休息结束且 `completedFocusCycles >= cycleCount`：回到 `resting/ready`，并将 `completedFocusCycles` 清零
- 重置：统一回到默认 `resting/ready`，并将 `completedFocusCycles` 清零

补充规则：
- `completedFocusCycles` 只表示当前一轮 pomodoro session 中已完成的专注轮数，不跨 session 累积
- 非法时机调用公共方法时统一执行 no-op：
  - `startTimer()` 在 `phaseStatus == running` 时不改变状态
  - `pauseTimer()` 在 `phaseStatus == ready` 或 `phaseStatus == paused` 时不改变状态
  - `resetTimer()` 在 `phaseStatus == ready` 时允许幂等执行

### 5. 前端进度以 controller 状态推导，但控制语义仍待完全对齐

采用方案：前端正式进度已经改为从 controller 状态推导：
- 若 `phaseStatus == ready`，总时长取 `focusDurationSeconds.value`，进度固定为 `0.0`
- 若 `pomodoroState == studying`，总时长取当前专注阶段时长
- 若 `pomodoroState == resting` 且 `phaseStatus != ready`，总时长取当前休息阶段时长
- 进度值 = `(total - remainingSeconds) / total`，并做 0 到 1 的边界保护

当前仍需保留的差距说明：
- OpenSpec 目标是显式“开始 / 暂停 / 重置”三控制按钮；
- 但现有 UI 仍保留 `toggleTimer()` + `isActive` 的单播放/暂停按钮兼容接法；
- 因此本节只能认定“真实进度消费已落地”，不能认定“显式三按钮交互已完全实现”。

### 6. 配置更新通过 controller 显式方法暴露

采用方案：在 `AppController` 中通过以下显式方法统一更新配置：
- `updateFocusDuration(int seconds)`
- `updateRestDuration(int seconds)`
- `updateCycleCount(int? count)`

前端以三个输入区承载配置输入：
- 专注时长输入 → `updateFocusDuration`
- 休息时长输入 → `updateRestDuration`
- 循环次数输入 → `updateCycleCount`

约束：
- 默认专注时长为 `1500` 秒，默认休息时长为 `300` 秒
- UI 展示层冻结为“分钟输入”，controller contract 冻结为“秒存储/秒传参”
- `focusDurationSeconds` 与 `restDurationSeconds` 只接受正整数秒值
- `cycleCount == null` 表示不循环
- `cycleCount` 只接受 `null` 或正整数，不支持无限循环
- 若 `phaseStatus == ready`，更新专注时长应同步刷新默认展示的 `remainingSeconds`
- 运行中或暂停中更新配置时，只更新后续阶段配置，不偷偷重写当前阶段剩余时间

### 7. `MainStage` 负责尽早触发恢复初始化

采用方案：`MainStage` 在创建 `AppController` 后尽早调用 `initialize()` 恢复入口。该方法负责：
- 读取本地持久化快照
- 恢复配置项
- 恢复运行中或暂停中的番茄钟状态
- 在必要时启动内部计时器

UI 在 controller 输出稳定后再被动消费状态，不参与恢复逻辑计算。

### 8. `fetchHistoryData()` 在本次 change 中仍属非核心边界

采用方案：本次 change 不定义 `fetchHistoryData()` 的正式返回结构，也不要求实现真实历史统计持久化。该方法仍可保留为统计面板占位接口，但不属于番茄钟主闭环 contract，也不应阻塞本 change 的核心实现判断。

## Archive Readiness Note

当前 **不建议归档**。

阻塞原因：
1. `tasks.md` 第 6 节验证项仍未完成；
2. UI 控制语义尚未完全对齐为显式“开始 / 暂停 / 重置”三按钮；
3. 若此时归档，会把“核心实现已大部分落地”与“验证 / 规范闭环仍未完成”混为一谈。
