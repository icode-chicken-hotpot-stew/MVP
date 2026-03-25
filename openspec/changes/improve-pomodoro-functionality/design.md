## Context

当前默认入口为 `lib/main.dart`，由 `MainStage` 创建单个 `AppController` 并注入 `UIWidgets`。本设计以 `lib/` 下当前实现为准，现有文档只作为背景与目标边界参考；若文档与代码不一致，应优先相信代码。现状中，`lib/app_controller.dart` 只暴露了 `remainingSeconds`、`isActive`、`isDrawerOpen`、`currentDate` 四个 `ValueNotifier`，而 `toggleTimer()` 与 `resetTimer()` 仍是空实现。与此同时，`lib/ui_widgets.dart` 仍维护 `_fakeTimer` 与 `_fakeProgress`，顶部 `LinearProgressIndicator` 直接消费 `_fakeProgress`，Reset 按钮还会额外调用 `_resetFakeProgress()`，统计面板和分享卡片也仍是 UI 占位，形成“controller 提供部分状态 + UI 维护本地假进度与占位展示”的双真相结构。

本次 change 的 proposal 已将目标收敛为五项核心需求：
- 使用简单的数据库或等价轻量本地持久化保存番茄钟开始时间
- 由 controller 统一计算剩余时间并通过接口给前端消费
- 通过番茄钟状态变化驱动 `resting` / `studying` 的业务状态流转
- 支持专注时间、休息时间修改，默认分别为 25 分钟和 5 分钟
- 支持有限轮次循环，默认不循环，不支持无限循环

现有文档 `docs/pomodoro/pomodoro_interface_spec.md`、`docs/pomodoro/pomodoro_state_flow.md`、`docs/pomodoro/pomodoro_integration_rules.md` 与 `docs/pomodoro/番茄钟功能简要.md` 提供了目标方向，但由于文档可能滞后，以下约束仅在与当前 `lib/` 实现不冲突时作为设计边界：
- `AppController` 必须成为番茄钟唯一状态源
- `resting` / `studying` 是冻结的两态业务状态，不引入第三个 `idle`
- 未运行由 `isActive = false` 表达，而不是独立状态
- UI 只能读 controller 状态并调用公共方法，不能继续维护正式计时逻辑
- 冷启动默认显示下一轮专注时长，但业务状态默认是 `resting + inactive`

此外，当前 `pubspec.yaml` 没有番茄钟持久化依赖，因此设计需要兼顾两点：一是允许引入轻量持久化依赖，二是避免为了 MVP 把持久化层抽象得过重。

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

### 1. 在 `AppController` 内扩展番茄钟状态，而不是把逻辑分散到 UI 或新建大规模模块

采用方案：继续以 `AppController` 为唯一业务入口，在其中新增番茄钟所需 `ValueNotifier` 与私有计时/恢复逻辑。建议新增至少以下状态：
- `pomodoroState: ValueNotifier<PomodoroState>`
- `focusDurationSeconds: ValueNotifier<int>`
- `restDurationSeconds: ValueNotifier<int>`
- `cycleCount: ValueNotifier<int?>`
- `completedFocusCycles: ValueNotifier<int>`

并保留现有：
- `remainingSeconds`
- `isActive`
- `currentDate`
- `isDrawerOpen`

理由：当前代码结构已经将 controller 作为主入口，文档也已冻结“controller 是唯一状态源”的原则。若把计时恢复、剩余时间计算或阶段流转继续放在 `UIWidgets`，会延续双真相问题；若为 MVP 过早拆出新的 service / repository 体系，则会放大本批次改动范围。

备选方案：
- 把计时器和恢复逻辑放到 `UIWidgets`：违背单一事实源原则，放弃。
- 新建独立 `PomodoroManager` 再由 `AppController` 代理：长期可行，但对当前 MVP 属于额外抽象，暂不采用。

### 2. 使用“阶段快照 + 开始时间”做持久化模型，而不是只保存剩余秒数

采用方案：持久化一个轻量快照对象，至少包括：
- 当前阶段 `pomodoroState`
- 当前阶段开始时间 `startedAt`
- 当前阶段总时长 `phaseDurationSeconds`
- 当前是否运行 `isActive`
- 当前剩余秒数（仅在暂停或重置后作为恢复基准）
- `focusDurationSeconds`
- `restDurationSeconds`
- `cycleCount`
- `completedFocusCycles`

恢复时规则：
- 若 `isActive == true`，以 `startedAt + phaseDurationSeconds` 与当前时间重新计算剩余时间
- 若阶段已过期，则根据状态机自动推进到下一阶段，直到落到一个未过期阶段或待开始状态
- 若 `isActive == false`，优先恢复最后一次暂停/重置时保存的 `remainingSeconds`

理由：用户明确要求保存“开始时间”，而现有文档也把开始时间列为恢复的核心字段。只保存剩余秒数无法处理切后台和重启期间的自然流逝，也无法判断阶段是否已过期。

备选方案：
- 只保存 `remainingSeconds`：简单，但不能可靠恢复经过的时间。
- 保存完整历史明细表：能力过剩，不符合当前 MVP 范围。

### 3. 持久化层采用轻量本地存储实现，接口上按“简单数据库”要求表述

采用方案：在实现层允许使用 SharedPreferences / Hive / 等价轻量本地持久化方案保存番茄钟快照与配置；在 specs 和对外描述中将其归类为“简单数据库或等价本地持久化”。

理由：proposal 里的需求是“简单数据库实现开始时间持久化”，但项目文档 `docs/pomodoro/番茄钟功能简要.md` 已明确当前 MVP 重点是“可靠本地持久化”，不要求先上复杂数据库。对当前数据规模来说，标量配置和单份运行快照更适合轻量方案。

备选方案：
- 直接引入 SQLite / Drift：更像传统数据库，但对当前状态量来说偏重。
- 完全不加依赖，用内存变量：无法满足恢复需求，放弃。

### 4. 用单一状态机驱动 `resting` / `studying` 与运行态，不引入第三业务状态

采用方案：遵循现有文档，业务状态保持两态：
- `PomodoroState.resting`
- `PomodoroState.studying`

运行中 / 暂停 / 待开始通过 `isActive` 与 `remainingSeconds` 组合表达：
- `resting + inactive + remainingSeconds == focusDurationSeconds` 表示 Ready
- `studying + active` 表示专注运行中
- `studying + inactive` 表示专注暂停中
- `resting + active` 表示休息运行中
- `resting + inactive + remainingSeconds < restDurationSeconds` 可表达休息暂停中

关键流转：
- 初次开始：`resting/inactive` → `studying/active`
- 专注结束：`studying/active` → `resting/active`，并 `completedFocusCycles += 1`
- 休息结束且 `cycleCount == null`：回到 `resting/inactive` 且 `remainingSeconds = focusDurationSeconds`
- 休息结束且 `completedFocusCycles < cycleCount`：进入下一轮 `studying/active`
- 休息结束且达到轮次上限：回到待开始状态
- 重置：统一回到默认待开始状态

理由：该状态组合已经被文档冻结，能够表达需求所需的全部业务流转，同时避免再引入 `idle` 等新概念造成接口漂移。

备选方案：
- 新增 `ready` / `paused` 独立业务状态枚举：更直观，但会偏离现有接口契约。

### 5. 前端不再维护 `_fakeTimer` / `_fakeProgress`，进度由剩余时间与当前阶段总时长推导

采用方案：删除 `UIWidgets` 中的 `_fakeTimer`、`_fakeProgress`、`_activeListener` 和 `_resetFakeProgress()` 的正式职责，顶部进度条改为从 controller 状态推导：
- 若 `pomodoroState == studying`，总时长取 `focusDurationSeconds.value`
- 若 `pomodoroState == resting`，总时长取 `restDurationSeconds.value`
- 进度值 = `(total - remainingSeconds) / total`，并做 0 到 1 的边界保护

倒计时文本继续消费 `remainingSeconds`。播放/暂停按钮继续消费 `isActive`。若后续需要展示文案“学习中 / 休息中”，由 `pomodoroState + isActive` 组合推导。

理由：当前最大不一致点就是进度条来自 `_fakeProgress`，而文本来自 `remainingSeconds`。要满足“通过接口把剩余时间给前端处理”，最佳做法是 controller 提供状态，UI 做纯推导展示，而不是再引入另一套时间源。

备选方案：
- controller 额外暴露 `progress` 字段：可行，但当前需求中 `remainingSeconds` 已足够，先不新增派生状态。

### 6. 配置更新在 controller 中作为显式方法暴露，并限定运行中的更新行为

采用方案：在 `AppController` 中增加显式方法：
- `updateFocusDuration(int seconds)`
- `updateRestDuration(int seconds)`
- `updateCycleCount(int? count)`

约束：
- 默认专注时长为 `1500` 秒，默认休息时长为 `300` 秒
- `cycleCount == null` 表示不循环
- `cycleCount` 只接受 `null` 或正整数，不支持无限循环
- 未运行且处于待开始状态时，更新专注时长应同步刷新默认展示的 `remainingSeconds`
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

## Risks / Trade-offs

- [轻量持久化并非真正关系型数据库] → 在 design/specs 中明确“简单数据库”对当前 MVP 的语义是可靠的本地持久化，不承诺复杂查询能力。
- [运行中恢复需要处理阶段过期与连续推进] → 将恢复逻辑设计为纯函数化的阶段推进计算，先根据快照得出目标状态，再一次性回写 notifier，减少分支错误。
- [配置更新与当前阶段的关系容易引起歧义] → 明确规则：运行中修改只影响后续阶段；待开始状态下修改专注时长同步刷新默认展示。
- [UI 从假进度切换到真状态后，可能暴露 controller 计时误差] → 使用阶段结束时间而不是简单每秒减一作为恢复基准，降低后台切换带来的累计误差。
- [当前仓库尚无测试目录] → 在后续 tasks 中优先拆出 controller 层的状态流转与恢复测试，降低回归风险。

## Migration Plan

1. 在 `AppController` 中补齐状态字段、配置方法和内部计时器/恢复逻辑。
2. 接入轻量本地持久化，完成快照读写与初始化恢复入口。
3. 将 `UIWidgets` 的顶部进度条、重置路径和按钮交互切换为纯消费 controller 状态。
4. 验证冷启动、开始、暂停、恢复、重置、专注结束、休息结束和重启恢复路径。
5. 若联调出现问题，可临时回退到未移除 UI 结构但保留 controller 新状态的版本；避免只回退部分状态字段，导致再次出现双真相。

## Open Questions

- “简单数据库”在当前实现中是否有明确偏好：SharedPreferences、Hive，还是其他本地持久化方案？
- 是否需要在本次 change 中一并定义 `fetchHistoryData()` 的最小返回结构，还是把它降级为非本批次核心？
- 设置入口 UI 是否已经有确定承载位置，还是本次仅先落 controller 能力与默认值契约？
