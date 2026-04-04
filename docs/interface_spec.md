# 陪伴学习软件 - 项目接口规范手册

> **版本**: v5.2
> **最后更新**: 2026.04.04
> **适用对象**: 开发团队成员、AI 助手 (Claude)
> **协作原则**: 接口契约优先，模块内部实现自治
>
> **状态说明**: 本文档保留为跨模块协作说明，但番茄钟当前权威契约请优先参考 `openspec/changes/improve-pomodoro-functionality/` 下的 proposal / design / specs / tasks 与当前代码实现。

---

## 1. 项目概述

这是一个以横屏陪伴学习场景为核心的 Flutter 应用。默认入口是 `lib/main.dart`，由 `MainStage` 创建共享 `AppController`，并将其注入 UI 与其他消费方。

当前仓库应优先相信以下事实：
- 番茄钟核心状态、恢复与配置逻辑以 `lib/app_controller.dart` 为准。
- 主界面交互与番茄钟消费逻辑以 `lib/ui_widgets.dart` 为准。
- 主入口初始化与生命周期恢复以 `lib/main.dart` 为准。
- 角色动画层 `lib/character_view.dart` 仍是轻量占位实现。

---

## 2. 当前权威来源

### 2.1 番茄钟

以下文件共同构成当前番茄钟权威来源：
- `openspec/changes/improve-pomodoro-functionality/proposal.md`
- `openspec/changes/improve-pomodoro-functionality/design.md`
- `openspec/changes/improve-pomodoro-functionality/specs/`
- `openspec/changes/improve-pomodoro-functionality/tasks.md`
- `lib/app_controller.dart`
- `lib/ui_widgets.dart`
- `lib/main.dart`

### 2.2 对话系统

以下文件构成当前对话系统主要依据：
- `lib/app_controller.dart`
- `lib/ui_widgets.dart`
- `assets/dialogues/dialogues.json`
- `docs/talking_interface.md`

---

## 3. 当前架构职责

### 3.1 `lib/main.dart`
- 创建共享 `AppController`
- 在 `MainStage.initState()` 中尽早调用 `controller.initialize()`
- 用 `FutureBuilder` 保证恢复完成后再进入正常 UI
- 转发生命周期事件到 controller

### 3.2 `lib/app_controller.dart`
- 维护番茄钟、对话、XP、音乐、监督提醒等状态
- 负责番茄钟状态机、持久化、恢复与时间同步
- 通过 `ValueNotifier` 暴露高频/简单状态，通过 `ChangeNotifier` 暴露复合状态
- 对外提供显式行为接口，UI 不应直接改内部状态

### 3.3 `lib/ui_widgets.dart`
- 负责主界面展示与交互转发
- 通过 `ValueListenableBuilder` / `ListenableBuilder` 消费 controller 状态
- 顶部进度、倒计时、配置输入与控制按钮都应尽量只消费 controller contract

### 3.4 `lib/character_view.dart`
- 当前仍是轻量占位实现
- 正式角色动作建议优先读取 `pomodoroState`
- 若未来要区分“待开始占位态”与“真实休息态”，需再结合 `phaseStatus`

---

## 4. 当前番茄钟状态契约

### 4.1 核心状态

当前番茄钟相关核心状态包括：

| 状态 | 类型 | 说明 |
| :--- | :--- | :--- |
| `remainingSeconds` | `ValueNotifier<int>` | 当前阶段剩余秒数 |
| `pomodoroState` | `ValueNotifier<PomodoroState>` | 业务阶段语义：`resting` / `studying` |
| `phaseStatus` | `ValueNotifier<PomodoroPhaseStatus>` | 运行控制语义：`ready` / `running` / `paused` |
| `focusDurationSeconds` | `ValueNotifier<int>` | 专注时长配置，默认 `1500` |
| `restDurationSeconds` | `ValueNotifier<int>` | 休息时长配置，默认 `300` |
| `cycleCount` | `ValueNotifier<int?>` | 有限循环次数，`null` 表示不循环 |
| `completedFocusCycles` | `ValueNotifier<int>` | 当前 session 已完成的专注轮数 |
| `isDrawerOpen` | `ValueNotifier<bool>` | UI 抽屉/面板状态 |
| `currentDate` | `ValueNotifier<String>` | 顶部日期显示 |

### 4.2 状态职责边界

- `pomodoroState`：只表达业务阶段语义，供动画、对话、陪伴行为消费。
- `phaseStatus`：只表达运行控制语义，供按钮态、恢复、持久化与控制逻辑消费。
- `remainingSeconds`：表达当前阶段剩余时间。
- `isActive`：当前代码中仍存在，但对番茄钟正式控制 contract 来说属于兼容性状态；新逻辑应优先依赖 `phaseStatus`。

### 4.3 固定组合解释

| 组合 | 语义 |
| :--- | :--- |
| `resting + ready` | 待开始 / 下一轮专注未开始 |
| `studying + running` | 学习中 |
| `studying + paused` | 学习暂停 |
| `resting + running` | 休息中 |
| `resting + paused` | 休息暂停 |

---

## 5. 当前番茄钟公开接口

### 5.1 核心方法

| 方法 | 说明 |
| :--- | :--- |
| `initialize()` | 启动时恢复配置与番茄钟运行快照 |
| `startTimer()` | 从 ready 启动专注，或从 paused 恢复当前阶段 |
| `pauseTimer()` | 暂停当前运行阶段 |
| `resetTimer()` | 回到默认 ready 状态 |
| `updateFocusDuration(int seconds)` | 更新专注时长配置 |
| `updateRestDuration(int seconds)` | 更新休息时长配置 |
| `updateCycleCount(int? count)` | 更新循环次数配置 |
| `restoreDefaultDurations()` | 恢复默认 25/5 配置 |
| `synchronizeWithCurrentTime()` | 生命周期恢复后同步时间与阶段 |
| `handleLifecycleStateChanged(...)` | 处理应用生命周期变化 |
| `handleAppBackgrounded()` | 标记后台态并停止前台相关行为 |
| `fetchHistoryData()` | 统计面板占位接口，非本次番茄钟核心 contract |

### 5.2 兼容性方法

| 方法 | 说明 |
| :--- | :--- |
| `toggleTimer()` | 兼容性封装：运行中时委托 `pauseTimer()`，否则委托 `startTimer()` |

---

## 6. 当前 UI / Controller 协作规则

- UI 只读 controller 状态。
- UI 只通过 controller 公共方法表达用户意图。
- UI 不应再维护第二套“真实剩余时间”或“真实进度”。
- 顶部进度应由 `remainingSeconds` 与 `currentPhaseDurationSeconds` 推导。
- 配置输入应统一走 `updateFocusDuration` / `updateRestDuration` / `updateCycleCount`。
- 按钮态与恢复语义应优先读取 `phaseStatus`，不要再把 `isActive` 作为新 contract 的唯一依据。

---

## 7. 当前启动与恢复路径

### 7.1 启动

```dart
class _MainStageState extends State<MainStage> with WidgetsBindingObserver {
  late final AppController controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    controller = AppController();
    _initialization = controller.initialize();
  }
}
```

### 7.2 首帧保护

```dart
FutureBuilder<void>(
  future: _initialization,
  builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    return UIWidgets(controller: controller);
  },
)
```

### 7.3 生命周期恢复

- app 切回前台后，`MainStage` 会把生命周期事件转发给 controller。
- controller 负责重新同步当前时间、剩余秒数和阶段，不由 UI 自己推算恢复值。

---

## 8. 当前对话与角色联动口径

- 对话触发、队列、仲裁与文案加载以 `lib/app_controller.dart` 为准。
- 角色主动作语义应优先读取 `pomodoroState`：
  - `studying` → 学习动作
  - `resting` → 休息/待机动作
- 若未来需要区分 `resting + ready` 与 `resting + running`，必须再结合 `phaseStatus`。

---

## 9. 当前已知非目标 / 非权威内容

以下内容当前不应被当作番茄钟正式 contract：
- `startFocus()` / `finishFocus()` 一类旧方法名
- `focusStartTime` 单字段式旧恢复模型
- `SharedPreferences / Hive` 并列作为当前正式持久化决策
- 用 `isActive` 单独表达全部番茄钟运行语义
- 历史统计、分享卡片最终数据模型

---

## 10. 快速参考

### 10.1 读取状态

```dart
controller.remainingSeconds.value;
controller.pomodoroState.value;
controller.phaseStatus.value;
controller.focusDurationSeconds.value;
controller.restDurationSeconds.value;
controller.cycleCount.value;
controller.completedFocusCycles.value;
```

### 10.2 调用接口

```dart
await controller.initialize();
controller.startTimer();
controller.pauseTimer();
controller.resetTimer();
controller.updateFocusDuration(25 * 60);
controller.updateRestDuration(5 * 60);
controller.updateCycleCount(4);
```

---

> 如需确认当前仓库真实状态，请直接回到 `lib/app_controller.dart`、`lib/ui_widgets.dart`、`lib/main.dart` 与 OpenSpec 变更目录核对。