# 番茄钟 Interface Spec

> 版本：v1.1
> 最后更新：2026-03-24
> 适用范围：`AppController`、`UIWidgets`、`MainStage` 当前番茄钟相关接线与后续实现约束

---

## 1. 目标与范围

本文档用于澄清当前仓库中番茄钟相关接口的**真实现状**与**目标契约**。

当前代码里，番茄钟展示存在两套来源：
- 一部分状态来自 `AppController`
- 另一部分进度展示仍来自 `UIWidgets` 内部的本地假动画

因此，本规范的目的有两个：
1. 准确记录当前代码实际如何工作，避免把占位逻辑误认为正式契约。
2. 明确后续实现时应遵守的边界：**`AppController` 是番茄钟状态的单一事实源（Single Source of Truth）**。

本文档只覆盖番茄钟接口，不扩展到对话系统、Live2D、统计持久化实现细节。

---

## 2. 当前实现现状

### 2.1 当前控制器暴露的番茄钟相关接口

当前 `lib/app_controller.dart` 已暴露以下状态与方法：

#### 状态
- `remainingSeconds: ValueNotifier<int>`
  - 倒计时秒数
  - 默认值来自 `kDefaultPomodoroSeconds`
- `isActive: ValueNotifier<bool>`
  - 计时器是否处于运行态
- `isDrawerOpen: ValueNotifier<bool>`
  - 与番茄钟主逻辑无直接关系，但仍属于当前控制器公开状态
- `currentDate: ValueNotifier<String>`
  - 当前日期字符串

#### 方法
- `toggleTimer()`
- `resetTimer()`
- `fetchHistoryData()`

### 2.2 当前真实行为

当前仓库中，番茄钟相关行为是“部分 controller 驱动 + 部分 UI 本地占位”的混合状态：

1. **时间文本来自 controller**
   - `UIWidgets` 底部时间文本监听 `controller.remainingSeconds`
   - 当前显示格式为 `MM:SS`

2. **播放/暂停按钮态来自 controller**
   - `DockBar` 的图标与按钮颜色依赖 `controller.isActive`

3. **角色 active/idle 展示来自 controller**
   - `UIWidgets` 中角色占位区监听 `controller.isActive`

4. **顶部进度条不是真实番茄钟进度**
   - 顶部 `LinearProgressIndicator` 当前绑定的是 `_fakeProgress`
   - `_fakeProgress` 与 `remainingSeconds` 没有直接换算关系

5. **UI 内存在本地假进度动画**
   - `UIWidgets` 内部维护：
     - `Timer? _fakeTimer`
     - `double _fakeProgress`
   - 当 `controller.isActive` 变为 `true` 时，`_activeListener` 会调用 `_startFakeProgress()`
   - 当 `controller.isActive` 变为 `false` 时，`_activeListener` 会调用 `_stopFakeProgress()`

6. **假进度的计算方式仅用于 MVP 演示**
   - `_fakeProgress` 每 `100ms` 增加 `0.002`
   - 到达 `1.0` 后直接回绕到 `0.0`
   - 该行为形成一个循环动画，不代表真实 25 分钟番茄钟进度

7. **重置当前是双路径**
   - Reset 按钮先调用 `controller.resetTimer()`
   - 然后 UI 再额外调用 `_resetFakeProgress()`
   - 这说明当前进度显示并未完全由 controller 接管

8. **controller 的核心计时方法尚未实现**
   - `toggleTimer()` 目前是 TODO
   - `resetTimer()` 目前是 TODO
   - `fetchHistoryData()` 目前是 TODO

结论：当前代码还**没有形成完整的 controller 单一事实源番茄钟实现**。

---

## 3. 当前 UI -> Controller 接线关系

### 3.1 入口与注入

- `lib/main.dart` 中，`MainStage` 创建单个 `AppController`
- `MainStage` 将该 controller 注入 `UIWidgets(controller: controller)`
- 当前默认应用入口是 `lib/main.dart`

这意味着当前页面上的番茄钟展示都应围绕这一份 `AppController` 实例运作。

### 3.2 `UIWidgets` 当前消费方式

#### 状态监听
- `ValueListenableBuilder<bool>` 监听 `controller.isActive`
  - 用于 `DockBar` 播放/暂停按钮态
  - 用于角色 active/idle 占位展示
- `ValueListenableBuilder<int>` 监听 `controller.remainingSeconds`
  - 用于底部倒计时文本
- `ValueListenableBuilder<String>` 监听 `controller.currentDate`
  - 用于底部日期显示

#### 方法调用
- 点击播放/暂停：`controller.toggleTimer()`
- 点击重置：`controller.resetTimer()`
- 点击统计：`controller.fetchHistoryData()`
- 点击分享：直接读取 `controller.remainingSeconds.value` 计算展示文案

### 3.3 当前不一致点

虽然 UI 已经通过 controller 获取部分状态，但顶部进度条仍然是 UI 本地状态：
- `controller.isActive` 只负责触发 `_fakeTimer` 的开始/停止
- 真正用于绘制进度条的值仍是 `_fakeProgress`
- Reset 也需要同时处理 controller 方法和 UI 本地状态

这是一条临时的 MVP 演示路径，不应视为长期接口设计。

---

## 4. 目标番茄钟契约

### 4.1 单一事实源原则

后续真实番茄钟实现应满足：

- `AppController` 独占番茄钟状态
- UI 只负责：
  - 监听 controller 状态
  - 调用 controller 方法表达用户意图
- UI 不再维护第二套计时真相

也就是说，一旦真实番茄钟逻辑实现完成：
- `UIWidgets` 不应再依赖 `_fakeTimer`
- `UIWidgets` 不应再依赖 `_fakeProgress`
- Reset 不应再需要 `_resetFakeProgress()` 之类的 UI 本地补丁

### 4.2 冻结状态契约

本节定义**番茄钟后端与前端共享的冻结状态接口**。后续实现应以此为准；如果需要新增字段，应视为接口升级，而不是在现有语义上漂移。

#### 4.2.1 必需状态

- `remainingSeconds: ValueNotifier<int>`
  - 表示**当前阶段**剩余秒数
  - 取值范围：`>= 0`
  - 为倒计时文本展示的唯一时间来源
  - 当阶段切换时，应切换为新阶段对应的剩余秒数

- `isActive: ValueNotifier<bool>`
  - 表示当前番茄钟是否正在运行
  - `true`：当前阶段正在倒计时
  - `false`：当前阶段未运行、已暂停或已重置
  - 为播放/暂停态与角色运行态的唯一布尔来源

- `pomodoroState: ValueNotifier<PomodoroState>`
  - 表示当前业务阶段
  - 冻结枚举值：
    - `PomodoroState.resting`
    - `PomodoroState.studying`
  - 冷启动默认值：`PomodoroState.resting`
  - 语义约束：
    - focus 阶段对应 `studying`
    - rest 阶段对应 `resting`
    - 不额外引入第三个 `idle` 枚举；“未运行”由 `isActive = false` 表达

- `focusDurationSeconds: ValueNotifier<int>`
  - 当前专注阶段总时长（秒）
  - 默认值：`1500`
  - 必须支持修改

- `restDurationSeconds: ValueNotifier<int>`
  - 当前休息阶段总时长（秒）
  - 默认值：`300`
  - 必须支持修改

- `cycleCount: ValueNotifier<int?>`
  - 专注循环次数配置
  - 默认值：`null`
  - 语义：
    - `null` 表示“不循环”
    - 正整数 `N` 表示最多执行 `N` 轮专注阶段
    - 不允许 `<= 0`
    - 不支持无限循环

- `completedFocusCycles: ValueNotifier<int>`
  - 已完成的专注轮次
  - 默认值：`0`
  - 仅在专注阶段自然结束时递增
  - 手动暂停、手动重置、进入休息时不额外递增

- `currentDate: ValueNotifier<String>`
  - 当前日期字符串
  - 保持现有语义，不作为番茄钟核心状态，但仍属于当前 controller 对 UI 的稳定输出

- `isDrawerOpen: ValueNotifier<bool>`
  - 与番茄钟主流程无直接关系
  - 保持现有语义，不纳入番茄钟业务判断

#### 4.2.2 派生状态约束

以下语义无需要求单独持久化，但实现结果必须满足：

- 当前阶段总时长：
  - 当 `pomodoroState = studying` 时，阶段总时长取 `focusDurationSeconds.value`
  - 当 `pomodoroState = resting` 时，阶段总时长取 `restDurationSeconds.value`

- 当前进度：
  - 顶部进度条必须由“当前阶段总时长”和 `remainingSeconds` 推导
  - UI 不得维护与其独立的本地循环进度

- 当前是否可进入下一轮：
  - 当 `cycleCount = null` 时，不自动开启下一轮专注
  - 当 `cycleCount = N` 时，仅当 `completedFocusCycles < N` 时允许继续后续流程

#### 4.2.3 持久化状态约束

至少应支持持久化以下信息：
- 当前阶段开始时间
- 当前 `pomodoroState`
- 当前阶段总时长
- `isActive` 对应的运行/暂停状态
- 专注/休息时长配置
- 循环次数配置
- 已完成专注轮次（如历史/流程恢复需要）

其中，“开始时间”是必须持久化的核心字段，因为 `docs/番茄钟功能简要.md` 已明确要求通过持久化开始时间恢复剩余时间。

### 4.3 冻结方法契约

本节定义冻结方法语义。后续实现可以补内部依赖、异步存储和私有辅助方法，但不应随意改变这些公开入口的行为边界。

#### 4.3.1 `toggleTimer()`

```dart
void toggleTimer()
```

职责：切换当前番茄钟的运行 / 暂停状态。

输入：
- 无

行为：
- 当 `isActive.value == false` 时：
  - 启动或恢复当前阶段的倒计时
  - 不改变当前 `pomodoroState`
- 当 `isActive.value == true` 时：
  - 暂停当前阶段的倒计时
  - 保留当前 `remainingSeconds`
  - 不改变当前 `pomodoroState`

副作用：
- 更新 `isActive`
- 必要时写入/更新当前阶段开始时间与持久化快照
- 不应要求 UI 额外维护假进度或补状态

保证：
- 该方法本身不切换 `studying/resting` 阶段；阶段切换只能由倒计时自然结束触发

#### 4.3.2 `resetTimer()`

```dart
void resetTimer()
```

职责：将当前番茄钟恢复到初始待开始状态。

输入：
- 无

行为：
- 停止当前计时
- 清除当前活跃阶段的运行状态
- 将 `isActive.value` 置为 `false`
- 将 `pomodoroState.value` 置为 `PomodoroState.resting`
- 将 `remainingSeconds.value` 重置为 `focusDurationSeconds.value`
- 将 `completedFocusCycles.value` 重置为 `0`

副作用：
- 清理当前会话的持久化运行快照
- 不依赖 UI 层执行额外 reset 补丁

保证：
- Reset 后界面应仅通过监听 controller 状态得到一致结果
- Reset 不写入新的历史完成记录

#### 4.3.3 `fetchHistoryData()`

```dart
void fetchHistoryData()
```

职责：读取历史统计数据，并更新 controller 内部可供 UI 消费的历史结果状态。

输入：
- 无

行为：
- 从本地存储或后续约定的数据源读取历史统计数据
- 刷新 controller 中的历史结果状态

副作用：
- 不改变当前倒计时流程状态：
  - 不修改 `pomodoroState`
  - 不修改 `isActive`
  - 不修改 `remainingSeconds`

保证：
- 该方法属于统计数据入口，不参与当前计时核心状态机

#### 4.3.4 配置更新方法

为冻结专注/休息/循环配置接口，后端应提供以下公开方法：

```dart
void updateFocusDuration(int seconds)
void updateRestDuration(int seconds)
void updateCycleCount(int? count)
```

##### `updateFocusDuration(int seconds)`
- 更新专注阶段总时长配置
- `seconds` 必须为正整数
- 默认目标值为 `1500`
- 若当前不处于运行中，且当前阶段尚未开始下一轮，应允许同步刷新默认展示值

##### `updateRestDuration(int seconds)`
- 更新休息阶段总时长配置
- `seconds` 必须为正整数
- 默认目标值为 `300`

##### `updateCycleCount(int? count)`
- 更新循环次数配置
- 允许值：
  - `null`：不循环
  - 正整数：最多执行对应轮次专注
- 不允许：
  - `0`
  - 负数
  - 表示无限循环的特殊值

这些方法的共同保证：
- 配置变更必须持久化
- 配置接口不直接写入历史数据
- 配置接口不应偷偷触发阶段切换

### 4.4 冻结状态流转契约

- 冷启动默认状态：
  - `pomodoroState = resting`
  - `isActive = false`
  - `remainingSeconds = focusDurationSeconds`
  - `completedFocusCycles = 0`

- 专注开始：
  - 当用户在默认待开始状态触发 `toggleTimer()`，应启动一轮专注倒计时
  - 此时：
    - `pomodoroState = studying`
    - `isActive = true`

- 专注完成：
  - 当专注阶段 `remainingSeconds` 自然归零时：
    - `completedFocusCycles += 1`
    - `pomodoroState` 切换为 `resting`
    - `remainingSeconds` 切换为 `restDurationSeconds`
    - `isActive` 是否继续为 `true`，取决于是否进入自动休息阶段；若实现采用自动衔接休息，则保持运行；若实现采用停在阶段边界等待用户确认，则应在接口升级时明确。当前冻结方案默认**自动进入休息并继续运行**。

- 休息完成：
  - 当休息阶段 `remainingSeconds` 自然归零时：
    - 若 `cycleCount == null`，则停止计时并回到待开始状态
    - 若 `cycleCount != null` 且 `completedFocusCycles < cycleCount`，则进入下一轮专注
    - 若 `cycleCount != null` 且 `completedFocusCycles >= cycleCount`，则停止计时并回到待开始状态

- 回到待开始状态时必须满足：
  - `pomodoroState = resting`
  - `isActive = false`
  - `remainingSeconds = focusDurationSeconds`

### 4.5 进度契约

后续正式实现中，顶部进度条应由番茄钟真实状态推导，而不是由本地循环动画推导。

冻结语义：
- 进度条表示“当前阶段完成比例”
- 其值应由“当前阶段总时长”与 `remainingSeconds` 推导
- UI 不应自行维护与倒计时无关的循环进度

无论后续最终采用：
- 直接在 UI 中通过 `remainingSeconds` 计算进度，还是
- 由 controller 额外暴露正式进度状态

都必须满足一个前提：**进度与倒计时必须来自同一套事实来源**。

---

## 5. 当前实现与目标契约的差距

### 5.1 已满足的部分
- 主页面已经通过单个 `AppController` 注入 UI
- 时间文本已经依赖 `remainingSeconds`
- 播放/暂停按钮态已经依赖 `isActive`
- UI 已通过 controller 方法表达用户操作意图

### 5.2 尚未满足的部分
- `pomodoroState`、阶段时长配置、循环配置、已完成轮次等冻结状态尚未落地到当前 `AppController`
- 进度条仍由 `_fakeProgress` 驱动，不是正式番茄钟进度
- `toggleTimer()` 尚未真正驱动计时行为
- `resetTimer()` 尚未真正重建完整初始状态
- `fetchHistoryData()` 尚未接入真实数据
- 冻结的配置更新方法尚未实现
- UI 仍保留本地进度状态与本地 reset 补丁逻辑

### 5.3 当前推荐实现路径

基于当前仓库与本轮任务边界，推荐按以下顺序推进：
1. 先在 `AppController` 中补齐真实计时、状态机、持久化恢复
2. 再让 `main.dart` 负责最小生命周期恢复接线
3. 最后替换 `UIWidgets` 中的 `_fakeTimer` / `_fakeProgress` 路径
4. `fetchHistoryData()` 先提供最小历史摘要，满足统计面板和分享卡片即可

### 5.4 迁移要求

后续实现真实番茄钟逻辑时，应遵循以下迁移方向：
1. 让 controller 成为倒计时和进度的唯一状态来源
2. 在 `AppController` 中补齐冻结状态与冻结方法
3. 移除 `UIWidgets` 中与正式计时无关的 `_fakeTimer` / `_fakeProgress` 路径
4. 让 reset 只依赖 `controller.resetTimer()` 即可得到完整一致的 UI 结果
5. 保证时间文本、按钮态、角色态、进度条彼此一致

---

## 6. 非目标项

本文档不定义以下内容：
- 对话系统接口（如 `isTalking`、`nextDialogue()`、`skipDialogue()`）
- Live2D 动画实现细节
- 历史统计数据的数据模型、存储结构、图表渲染方案
- 长休息 / 短休息 / 多阶段番茄工作流
- 网络接口或后端同步协议

这些内容可以在独立文档中另行定义。

---

## 7. 与旧文档的关系

`docs/interface_spec.md` 可作为历史背景参考，但其内容包含部分当前仓库未落地或已过时的设计，例如：
- `ui_widget.dart` 旧文件名
- 更大范围的 `ChangeNotifier` / 对话系统设计
- 超出当前番茄钟任务范围的模块协作描述

因此，**番茄钟相关实现应以本文档和当前代码为准**，不应直接把旧文档中的未来设计视为当前事实。

---

## 8. 代码来源

本文档依据以下当前代码与项目约束整理：
- `lib/main.dart`
- `lib/app_controller.dart`
- `lib/ui_widgets.dart`
- `CLAUDE.md`
- `docs/interface_spec.md`（仅作历史对照）
