## Context

本设计建立在一个明确边界上：番茄钟核心状态机继续由 `improve-pomodoro-functionality` 提供，本 change 只在其上挂接三条留存 / 体验增强链路：

- 后台监管：消费 `pomodoroState + phaseStatus + lifecycle`
- XP / 等级：消费专注阶段自然完成事件
- 音乐 / 音效：消费应用初始化、生命周期变化、阶段切换与 UI 打开/返回事件

当前仓库中，这三条链路已经进入“代码落地 + 单测覆盖 + 文档补齐”状态；仍未完成的主要是音频资源实装与 Android 真机验收。

## Goals / Non-Goals

**Goals**

- 在不破坏现有番茄钟状态机的前提下，扩展后台监管、XP / 等级、全局音乐三条能力。
- 保持 controller 作为单一事实源，UI 只消费 `ValueNotifier` 和 controller 方法。
- 让音频 / 通知失败静默降级，不阻塞专注计时主流程。
- 让能力边界与当前实现一致，避免 OpenSpec 文档继续描述已变更或未落地的方案。

**Non-Goals**

- 不重写番茄钟核心状态机。
- 不引入云端同步、成就系统、推荐算法。
- 不在本变更内完成历史统计 / 留存分析系统重建。
- 不在本变更内做大规模 UI 视觉重构。

## Architecture Sketch

```text
                App Lifecycle / Startup
                         |
                         v
+------------------------------------------------------+
|                    AppController                     |
|                                                      |
|  Pomodoro Core                                       |
|    |- phase state machine                            |
|    |- snapshot persistence                           |
|    |- studying/resting transitions                   |
|                                                      |
|  Extension State                                     |
|    |- XP / daily XP / level                          |
|    |- music autoplay / playing / track / volume      |
|    |- supervisor session / background timestamp      |
|                                                      |
|  Extension Services                                  |
|    |- SupervisorNotificationService                  |
|    |- AudioService                                   |
+------------------------------------------------------+
                         |
                         v
              UI consumes ValueNotifier only
```

## Decision 1: Keep this as a parallel change

采用并行 change，而不是继续把需求并入番茄钟核心 change。

原因：

1. 核心计时可靠性与体验增强的回归面不同，拆开更利于验收与回滚。
2. 当前代码已经以 service 抽象和独立测试文件完成分层，天然适合独立维护文档边界。
3. 历史统计 / 留存分析仍未实现，保持并行 change 可以避免误把“陪伴增强”与“统计系统重建”混为一谈。

## Decision 2: Background supervisor uses session-based scheduling

### Model

- 一次后台监管会话定义为：从进入后台到下一次回前台或会话失效。
- 仅在 `pomodoroState == studying && phaseStatus == running` 时允许创建会话。
- 每个有效会话最多调度两个节点：
  - `+180s`
  - `+360s`

### Current implementation choices

- `MainStage` 通过 `WidgetsBindingObserver` 将生命周期事件转发到 `AppController.handleLifecycleStateChanged(...)`。
- `AppController` 通过 `SupervisorNotificationService` 抽象调度本地通知，默认实现为 `LocalSupervisorNotificationService`。
- Flutter 层使用 `flutter_local_notifications` + `timezone` 调度 3 分钟 / 6 分钟通知。
- Android 侧额外保留 `MethodChannel + AlarmManager + BroadcastReceiver` 调试链路，用于辅助观察监管节点触发。
- 调度成功后持久化 `sessionId / lastBackgroundAt / stage flags`；回前台、暂停、重置、离开专注阶段时调用取消逻辑。

### Important nuance

- 当前去重的主机制是“已有 active session 时不再重复调度”。
- 当一次调度失败时，不会建立 active session，因此后续新的后台回调仍允许重试；这是当前实现的有意降级策略。

## Decision 3: XP and level are completion-driven

### Grant timing

- 仅在专注阶段自然完成时发放 XP。
- XP 结算发生在相位推进副作用阶段，而不是逐秒累计。

### Formula

- `xpGain = floor(focusMinutes) * 10`
- 单次有效专注 < 5 分钟，发放 0 XP
- 每日上限 `2000 XP`

### Level thresholds

当前实现使用固定阈值表：

- Lv.1: `0`
- Lv.2: `50`
- Lv.3: `600`
- Lv.4: `2000`
- Lv.5: `4500`
- Lv.6: `8000`
- Lv.7: `13000`
- Lv.8: `19500`
- Lv.9: `27000`
- Lv.10: `36000`

### Dialogue unlock

- 对话解锁严格按等级：`currentLevel >= requiredLevel`
- controller 同时提供布尔判定与可直接展示的锁定原因文本

### Accounting date

- 日切以设备本地日期为准，通过 `yyyy-MM-dd` key 判定。
- 当前实现未额外处理设备时间回拨。

## Decision 4: Audio uses a dedicated service with separate BGM/SFX players

### Policy

- 应用初始化完成后，如果 `musicAutoPlayEnabled` 和 `isMusicPlaying` 为真，则自动播放 BGM。
- 用户播放 / 暂停会覆盖自动播放意图，并持久化 `autoplay / isPlaying / track / volume`。
- 应用切后台时，若当前处于自动播放链路，会暂停 BGM；回前台后尝试恢复。
- SFX 采用语义事件映射，统一维护四类短音效：`study_start`、`study_end`、`button_open`、`button_back`。

### Current implementation choices

- controller 依赖 `AudioService` 抽象，默认实现为 `JustAudioService`。
- `JustAudioService` 使用两个 `AudioPlayer`：
  - 一个负责循环 BGM
  - 一个负责短音效
- 阶段音效规则：
  - `ready -> studying/running`: 播放 `study_start`
  - `studying/running -> resting/running`: 播放 `study_end`
  - `resting/running -> studying/running`: 播放 `study_start`
- 按钮音效规则（本次补充范围）：
  - 触发“打开”语义动作时播放 `button_open`（如打开配置面板、展开面板、打开弹窗）
  - 触发“返回”语义动作时播放 `button_back`（如取消、关闭、`Navigator.pop`）
  - UI 不直接驱动底层音频播放器，仅触发 controller 语义方法
- 防重复播放保护（新增）：
  - controller 级：对 UI SFX 增加短窗口抑制（any-type cooldown + same-type dedup），拦截同次交互链路内的连发
  - audio service 级：增加 SFX 启动并发锁、短冷却、同资源去重，并在每次新播放前 `stop` 上一次 SFX，降低底层重复 `baseStart` 概率

### Failure mode

- 任意 BGM / SFX 播放失败都只记录日志，不阻塞 timer 状态推进。
- 如果生命周期恢复 BGM 失败，controller 会把 `isMusicPlaying` 置为 false 并持久化，避免 UI 与实际状态继续偏离。
- 若检测到短时间重复的 UI SFX 请求，系统会静默丢弃重复请求并输出调试日志，不影响主流程。

## UI Alignment

当前 UI 已完成以下对齐：

- 留声机控件改为消费 `controller.isMusicPlaying` 并调用 controller 的上一首 / 下一首 / 播放暂停 / 静音接口。
- 经验卷轴改为消费 `controller.level`、`controller.totalXp` 和 `minutesToNextLevel`。
- 对话气泡锁定文案改为直接消费 `dialogueLockReason(...)`。
- 黑板统计面板已切到 `dailyXp / totalXp`，但完整历史统计仍未实现，`fetchHistoryData()` 仍是占位。

## Data Persistence

当前已使用的持久化键：

- Pomodoro
  - `pomodoro.snapshot`
- XP / 等级
  - `xp.total`
  - `xp.daily`
  - `xp.lastDate`
  - `xp.level`
- 音乐
  - `music.autoPlayEnabled`
  - `music.isPlaying`
  - `music.trackIndex`
  - `music.volume`
- 后台监管
  - `supervisor.sessionId`
  - `supervisor.lastBackgroundAt`
  - `supervisor.stage3mSent`
  - `supervisor.stage6mSent`

## Testing Strategy

当前已有测试覆盖：

1. `test/app_controller_supervisor_test.dart`
   - 生命周期调度
   - 非专注态不调度
   - resume / pause / reset 取消逻辑
   - 调度失败时的非阻塞重试
2. `test/app_controller_xp_test.dart`
   - 25 分钟 XP 结算
   - <5 分钟 0 XP
   - 每日上限
   - 日切重置
   - 严格等级解锁与锁定文案
3. `test/app_controller_audio_test.dart`
   - 初始化自动播放
   - 手动暂停 / 恢复持久化意图
   - 前后台暂停 / 恢复
   - 恢复失败降级
  - 阶段 SFX 不阻塞 timer 迁移
  - 按钮打开/返回 SFX 触发与失败降级
  - rapid repeated UI SFX（同类型/跨类型）去重回归

## Remaining Gaps

1. Android 真机手工验证尚未完成，尤其是通知权限、前后台切换、真实音频播放链路。
2. 当前仓库已存在四类 SFX 资源并完成命名对齐：`study_start.mp3`、`study_end.mp3`、`button_open.mp3`、`button_back.mp3`；仍需真机验证实际播放链路。
3. `pubspec.yaml` 已声明 `assets/sfx/`，仍需通过真机流程验证打包后资源加载与回放稳定性。
4. 按钮打开 / 返回音效已统一通过 controller 语义入口触发，仍需在真机场景中补齐交互覆盖率验证。
5. 当前防重复策略基于时间窗口与并发锁，已覆盖已知双响路径；不同设备音频栈仍需真机回归验证窗口参数是否需要微调。
6. 历史统计 / 留存分析面板仍未实现，当前 change 的“retention”范围主要体现为后台回流提醒与成长反馈，不包含完整历史分析系统。
