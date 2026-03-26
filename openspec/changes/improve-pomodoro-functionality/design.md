## Context

当前默认入口为 `lib/main.dart`，由 `MainStage` 创建单个 `AppController` 并注入 `UIWidgets`。本设计以 `lib/` 下当前实现为准。现状中，`lib/app_controller.dart` 只暴露了 `remainingSeconds`、`isActive`、`isDrawerOpen`、`currentDate` 四个 `ValueNotifier`，而 `toggleTimer()` 与 `resetTimer()` 仍是空实现。与此同时，`lib/ui_widgets.dart` 仍维护 `_fakeTimer` 与 `_fakeProgress`，顶部 `LinearProgressIndicator` 直接消费 `_fakeProgress`，Reset 按钮还会额外调用 `_resetFakeProgress()`，统计面板和分享卡片也仍是 UI 占位，形成“controller 提供部分状态 + UI 维护本地假进度与占位展示”的双真相结构。

本次 change 的 proposal 已将目标收敛为以下核心需求：
- 使用简单的数据库或等价轻量本地持久化保存番茄钟开始时间
- 由 controller 统一计算剩余时间并通过接口给前端消费
- 通过番茄钟状态变化驱动 `resting` / `studying` 的业务状态流转
- 前端提供开始、暂停、重置三个控制按钮
- 前端提供专注时间、休息时间、循环次数三个配置输入框
- 支持有限轮次循环，默认不循环，不支持无限循环

以下约束作为本次设计边界：
- `AppController` 必须成为番茄钟唯一状态源
- `resting` / `studying` 是冻结的两态业务状态，不引入第三个 `idle`
- 未运行态需要与业务阶段解耦，Ready / 暂停态由 `phaseStatus` 区分
- UI 只能读 controller 状态并调用公共方法，不能继续维护正式计时逻辑
- 冷启动默认显示下一轮专注时长，但默认 Ready 态编码为 `pomodoroState = resting` + `phaseStatus = ready`

此外，当前 `pubspec.yaml` 没有番茄钟持久化依赖，因此设计需要兼顾两点：一是允许引入轻量持久化依赖，二是避免在当前 1 周快速开发窗口内把持久化层抽象得过重。

## Source of Truth Policy

自本次改造起，番茄钟开发的权威依据固定为两部分：
- `openspec/changes/improve-pomodoro-functionality/` 中的 `proposal.md`、`design.md`、`specs/`、`tasks.md`
- 当前仓库 `lib/` 下已经合入的实现代码

若 OpenSpec 与当前代码冲突，应先核对是否为代码尚未完成对齐；在需要定义目标行为时，以 OpenSpec 为准；在需要确认当前已实现状态时，以已合入代码为准。

## Goals / Non-Goals

**Goals:**
- 建立以 `AppController` 为中心的番茄钟单一事实源
- 用稳定状态表示当前阶段、运行状态、配置项和循环进度
- 通过持久化的开始时间与阶段快照支持切后台、恢复与重启恢复
- 让前端的倒计时文本与顶部进度条消费同一套真实状态
- 为后续 specs 和实现提供足够明确的技术决策边界

**Non-Goals:**
- 不实现对话系统、Live2D 或其他陪伴交互能力
- 不引入复杂数据库 schema、repository 分层或云端同步
- 不在本次设计中覆盖完整历史明细、图表系统或分享卡片最终样式
- 不做超出番茄钟需求的 UI 重构

## Decisions

### 1. 在 `AppController` 内扩展番茄钟状态与显式控制方法，而不是把逻辑分散到 UI 或新建大规模模块

采用方案：继续以 `AppController` 为唯一业务入口，在其中新增番茄钟所需 `ValueNotifier`、公开控制方法与私有计时/恢复逻辑。建议新增至少以下状态：
- `pomodoroState: ValueNotifier<PomodoroState>`
- `focusDurationSeconds: ValueNotifier<int>`
- `restDurationSeconds: ValueNotifier<int>`
- `phaseStatus: ValueNotifier<PomodoroPhaseStatus>`
- `cycleCount: ValueNotifier<int?>`
- `completedFocusCycles: ValueNotifier<int>`

并保留现有：
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

`isActive` 在当前代码中仍存在，但对目标契约而言属于过时的重复设计：它与 `phaseStatus == running` 表达的是同一事实，继续保留会增加 UI 与持久化双写/漂移风险。因此本次 OpenSpec 以 `phaseStatus` 作为唯一运行态判定依据，不再把 `isActive` 视为正式目标字段。

理由：当前代码结构已经将 controller 作为主入口，文档也已冻结“controller 是唯一状态源”的原则。若把计时恢复、剩余时间计算或阶段流转继续放在 `UIWidgets`，会延续双真相问题；若在当前 1 周快速开发窗口内过早拆出新的 service / repository 体系，则会放大本批次改动范围。

备选方案：
- 把计时器和恢复逻辑放到 `UIWidgets`：违背单一事实源原则，放弃。
- 新建独立 `PomodoroManager` 再由 `AppController` 代理：长期可行，但对当前阶段属于额外抽象，暂不采用。

### 2. 使用“阶段快照 + 开始时间”做持久化模型，而不是只保存剩余秒数

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

理由：用户明确要求保存“开始时间”，而现有文档也把开始时间列为恢复的核心字段。只保存剩余秒数无法处理切后台和重启期间的自然流逝，也无法判断阶段是否已过期。

备选方案：
- 只保存 `remainingSeconds`：简单，但不能可靠恢复经过的时间。
- 保存完整历史明细表：能力过剩，不符合当前阶段范围。

### 3. 持久化层固定采用 SharedPreferences 风格的轻量本地存储，不把底层选择继续留空

采用方案：本次 change 固定以 `shared_preferences` 这一类 key-value 本地持久化实现番茄钟快照与配置保存；不引入 SQLite / Drift / Hive 作为本批次正式契约的一部分。OpenSpec 中对外仍可表述为“简单数据库或等价轻量本地持久化”，但当前仓库实现决策明确落在 `shared_preferences`。

持久化边界：
- 使用单份 pomodoro runtime snapshot 保存当前阶段运行态
- 使用单独 key 保存配置项，或与 snapshot 一起序列化保存
- 不设计多表结构，不引入 repository 分层

理由：当前 `pubspec.yaml` 尚无持久化依赖，而本批次只需要持久化少量标量配置与单份运行快照。`shared_preferences` 足以覆盖需求，接入成本最低，也最符合当前 1 周快速开发阶段的最小实现原则。若后续真的需要历史明细或更复杂查询，再单独发起新 change 讨论升级。

备选方案：
- Hive：也能满足需求，但会增加额外建模与初始化心智负担，本批次不采用。
- SQLite / Drift：对当前状态量偏重，不采用。
- 继续保持“待定”：会让实现与评审继续依赖口头约定，不再接受。

### 4. 用显式阶段状态消除 `resting` / `inactive` 的语义歧义

采用方案：保留两态业务状态：
- `PomodoroState.resting`
- `PomodoroState.studying`

同时新增显式阶段状态：
- `PomodoroPhaseStatus.ready`
- `PomodoroPhaseStatus.running`
- `PomodoroPhaseStatus.paused`

其中字段职责固定为：
- `pomodoroState` 只表达当前业务阶段是专注还是休息
- `phaseStatus` 只表达当前阶段处于待开始、运行中还是暂停中，是运行态的唯一判定来源
- `remainingSeconds` 表达当前阶段剩余时间，不再承担区分 Ready 与暂停态的职责

状态组合规则：
- Ready：`pomodoroState = resting` + `phaseStatus = ready` + `remainingSeconds = focusDurationSeconds`
- 专注运行中：`pomodoroState = studying` + `phaseStatus = running`
- 专注暂停中：`pomodoroState = studying` + `phaseStatus = paused`
- 休息运行中：`pomodoroState = resting` + `phaseStatus = running`
- 休息暂停中：`pomodoroState = resting` + `phaseStatus = paused`

关键流转：
- 初次开始：`resting/ready` → `studying/running`
- 专注暂停：`studying/running` → `studying/paused`
- 专注恢复：`studying/paused` → `studying/running`
- 专注结束：`studying/running` → `resting/running`，并 `completedFocusCycles += 1`
- 休息暂停：`resting/running` → `resting/paused`
- 休息恢复：`resting/paused` → `resting/running`
- 休息结束且 `cycleCount == null`：回到 `resting/ready` 且 `remainingSeconds = focusDurationSeconds`
- 休息结束且 `completedFocusCycles < cycleCount`：进入下一轮 `studying/running`
- 休息结束且 `completedFocusCycles >= cycleCount`：回到 `resting/ready`
- 重置：统一回到默认 `resting/ready`

仅靠 `pomodoroState + phaseStatus + remainingSeconds` 已足够区分 Ready、运行中与暂停中；旧设计里引入 `isActive` 只会制造重复状态与同步负担。把“阶段类型”和“阶段状态”拆开后，UI 可直接用 `pomodoroState + phaseStatus` 做确定性展示，同时保留 `remainingSeconds` 作为纯倒计时数据。

备选方案：
- 新增第三个业务状态如 `idle`：也能消歧，但会改变现有 `resting/studying` 业务语义边界，不如新增 `phaseStatus` 局部且清晰。

### 5. 前端不再维护 `_fakeTimer` / `_fakeProgress`，进度由剩余时间与当前阶段总时长推导

采用方案：删除 `UIWidgets` 中的 `_fakeTimer`、`_fakeProgress`、`_activeListener` 和 `_resetFakeProgress()` 的正式职责，顶部进度条改为从 controller 状态推导：
- 若 `phaseStatus == ready`，总时长取 `focusDurationSeconds.value`，进度固定为 `0.0`
- 若 `pomodoroState == studying`，总时长取 `focusDurationSeconds.value`
- 若 `pomodoroState == resting` 且 `phaseStatus != ready`，总时长取 `restDurationSeconds.value`
- 进度值 = `(total - remainingSeconds) / total`，并做 0 到 1 的边界保护

倒计时文本继续消费 `remainingSeconds`。开始/暂停/重置按钮由显式 controller 方法驱动；按钮可见态与可点态由 `phaseStatus` 推导。若需要展示文案“待开始 / 学习中 / 学习暂停 / 休息中 / 休息暂停”，由 `pomodoroState + phaseStatus` 组合推导，而不是依赖额外布尔字段。

理由：当前最大不一致点就是进度条来自 `_fakeProgress`，而文本来自 `remainingSeconds`。要满足“通过接口把剩余时间给前端处理”，最佳做法是 controller 提供状态，UI 做纯推导展示，而不是再引入另一套时间源。

备选方案：
- controller 额外暴露 `progress` 字段：可行，但当前需求中 `remainingSeconds` 已足够，先不新增派生状态。

### 6. 配置更新在 controller 中作为显式方法暴露，并限定运行中的更新行为

采用方案：在 `AppController` 中增加显式方法：
- `updateFocusDuration(int seconds)`
- `updateRestDuration(int seconds)`
- `updateCycleCount(int? count)`

前端以三个输入框承载配置输入：
- 专注时长输入框 → `updateFocusDuration`
- 休息时长输入框 → `updateRestDuration`
- 循环次数输入框 → `updateCycleCount`

约束：
- 默认专注时长为 `1500` 秒，默认休息时长为 `300` 秒
- `cycleCount == null` 表示不循环
- `cycleCount` 只接受 `null` 或正整数，不支持无限循环
- 若 `phaseStatus == ready`，更新专注时长应同步刷新默认展示的 `remainingSeconds`
- 运行中更新配置时，只更新后续阶段配置，不偷偷重写当前阶段剩余时间，避免当前阶段语义漂移

理由：用户需求已把配置能力列为核心范围。通过显式方法统一更新与持久化，可保持 UI 只表达意图、不直接写状态。

备选方案：
- 允许 UI 直接改 notifier：违背当前协作约束，放弃。
- 配置改动立即重算当前进行中阶段剩余时间：用户感知会混乱，不采用。

### 7. `MainStage` 负责尽早触发恢复初始化，避免 UI 先读取到过时默认值

采用方案：`MainStage` 在创建 `AppController` 后尽早调用一个初始化/恢复入口，例如 `initialize()` 或等价方法。该方法负责：
- 读取本地持久化快照
- 恢复配置项
- 恢复运行中或暂停中的番茄钟状态
- 在必要时启动内部计时器

UI 在 controller 输出稳定后再被动消费状态，不参与恢复逻辑计算。

理由：现有文档明确应用入口负责 controller 生命周期，并要求在 UI 消费状态前尽早完成恢复。这样可以减少页面首帧出现错误默认值或先渲染后跳变的问题。

备选方案：
- 让 `UIWidgets.initState()` 触发恢复：会把业务恢复耦合进 View 层，不采用。

### 8. `fetchHistoryData()` 在本次 change 中降级为非核心，不进入正式番茄钟契约范围

采用方案：本次 change 不定义 `fetchHistoryData()` 的正式返回结构，也不要求实现真实历史统计持久化。该方法保留为现有 UI 占位接口，可继续为空实现、占位实现，或在后续独立 change 中再补最小统计摘要契约。

边界：
- 本次 pomodoro 单一事实源改造不依赖 `fetchHistoryData()` 完成
- `tasks.md` 中的实现与验证范围不包含历史统计契约
- 统计面板与分享卡片当前仍可视为 UI 占位，不阻塞本次 source-of-truth 收口

理由：当前 proposal、specs、tasks 的核心都聚焦于计时、状态流转、恢复、配置和 UI 真状态接线。若在本次变更里临时补历史统计契约，会把范围从“单一事实源改造”扩散到另一组尚未建模的数据需求。

备选方案：
- 一并定义最小历史摘要结构：有价值，但会扩大范围，建议单独立项。

### 9. 设置入口 UI 不属于本次 change；本次只冻结 controller 能力与消费规则

采用方案：本次 change 只定义 controller 层应具备的 focus/rest/cycle 配置能力，以及 UI 消费这些状态与方法时应遵守的规则；不规定设置入口必须放在何处，不新增设置面板交互契约。

边界：
- 现有设置按钮可继续保持占位
- 后续若新增设置面板，应直接消费 `updateFocusDuration` / `updateRestDuration` / `updateCycleCount`
- 不允许因为设置入口未定而把配置状态临时下沉到 UI 本地

理由：当前需求重点是让 controller 先成为稳定单一事实源。设置入口的呈现位置属于后续 UI 设计问题，不影响本次 controller / persistence / runtime / recovery 契约成立。

## Risks / Trade-offs

- [轻量持久化并非真正关系型数据库] → 在 design/specs 中明确“简单数据库”对当前阶段的语义是可靠的本地持久化，不承诺复杂查询能力。
- [运行中恢复需要处理阶段过期与连续推进] → 将恢复逻辑设计为纯函数化的阶段推进计算，先根据快照得出目标状态，再一次性回写 notifier，减少分支错误。
- [配置更新与当前阶段的关系容易引起歧义] → 明确规则：仅 `phaseStatus == ready` 时同步刷新默认展示；运行中或暂停中更新只影响后续阶段配置。
- [UI 从假进度切换到真状态后，可能暴露 controller 计时误差] → 使用阶段结束时间而不是简单每秒减一作为恢复基准，降低后台切换带来的累计误差。
- [当前仓库尚无测试目录] → 在后续 tasks 中优先拆出 controller 层的状态流转与恢复测试，降低回归风险。

## Migration Plan

1. 在 `AppController` 中补齐状态字段、配置方法和内部计时器/恢复逻辑。
2. 接入轻量本地持久化，完成快照读写与初始化恢复入口。
3. 将 `UIWidgets` 的顶部进度条、重置路径和按钮交互切换为纯消费 controller 状态。
4. 验证冷启动、开始、暂停、恢复、重置、专注结束、休息结束和重启恢复路径。
5. 若联调出现问题，可临时回退到未移除 UI 结构但保留 controller 新状态的版本；避免只回退部分状态字段，导致再次出现双真相。

## Resolved Decisions

- 持久化方案已固定为 `shared_preferences` 风格的轻量本地 key-value 存储。
- `fetchHistoryData()` 不属于本次 change 的正式契约范围，后续如需真实统计能力应单独立项。
- 设置入口 UI 不属于本次 change；本次只冻结 controller 能力与 UI 消费规则。
