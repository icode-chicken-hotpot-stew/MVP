# Frontend Tasks for Pomodoro Integration

> 范围：仅针对前端接线与 UI 消费，不覆盖 controller 内部状态机、持久化实现细节与历史统计正式建模。
>
> 权威来源：
> - `openspec/changes/improve-pomodoro-functionality/proposal.md`
> - `openspec/changes/improve-pomodoro-functionality/design.md`
> - `openspec/changes/improve-pomodoro-functionality/specs/`
> - 当前已合入代码：`lib/ui_widgets.dart`、`lib/main.dart`
>
> 历史参考但非权威：无

---

## 0. 前端目标与边界

### 目标
- 让番茄钟 UI 成为 `AppController` 的纯消费者。
- 让倒计时文本、进度展示、按钮态全部来自同一套 controller 状态。
- 目标交互为开始、暂停、重置三个显式控制入口，不在 UI 层补业务状态。
- 前端提供专注时长、休息时长、循环次数三个配置输入区，并只通过 controller 配置接口提交。
- 去掉 `UIWidgets` 内部对正式番茄钟流程的本地假实现。
- 在应用启动恢复场景下，避免 UI 先展示错误默认值、再跳变到恢复值。

### 非目标
- 不在本任务中实现 `AppController` 的完整状态机。
- 不在本任务中定义 `fetchHistoryData()` 的正式数据契约。
- 不在本任务中完成设置面板最终视觉设计。
- 不在本任务中扩展聊天气泡、Live2D 或其他陪伴系统。

---

## 1. 当前前端现状确认

### 已落地部分
- `lib/ui_widgets.dart` 已不再维护 `_fakeTimer`、`_fakeProgress`、`_activeListener` 或 `_resetFakeProgress()` 作为正式番茄钟逻辑来源。
- 顶部番茄钟进度已基于 `controller.remainingSeconds` 与 `controller.currentPhaseDurationSeconds` 推导，不再依赖本地假进度。
- `lib/main.dart` 已接入 `controller.initialize()`，并通过 `FutureBuilder` 处理恢复前首帧保护。
- UI 已提供专注时长、休息时长、循环次数三个配置输入区，并直接调用 controller 配置方法。

### 尚未完全对齐目标的部分
- 当前代码仍保留一个播放/暂停复用按钮，通过 `controller.toggleTimer()` 与 `controller.isActive` 驱动；尚未完全收敛为显式“开始 / 暂停 / 重置”三控制入口。
- 当前 UI 尚未把所有阶段展示语义都显式收敛为由 `pomodoroState + phaseStatus` 组合推导的文案 / 按钮态。
- 统计面板与分享卡片仍保留占位语义，虽不阻塞主闭环，但不应被误读为已完成的正式统计 contract。

因此，前端当前最核心的状态是：**真实进度与恢复接线已基本完成，但显式三按钮控制语义仍未完全闭环。**

---

## 2. 前后端并行开发的最小接口清单

前端开发与联调时，应以 `AppController` 的以下状态或等价接口为契约面：

- `remainingSeconds`
- `pomodoroState`
- `phaseStatus`
- `focusDurationSeconds`
- `restDurationSeconds`
- `cycleCount`
- `completedFocusCycles`
- `startTimer()`
- `pauseTimer()`
- `resetTimer()`
- `updateFocusDuration(int seconds)`
- `updateRestDuration(int seconds)`
- `updateCycleCount(int? count)`
- `initialize()` 或等价启动恢复入口

说明：
- `isActive` 在当前代码中仍存在，但对目标契约属于过时的重复设计；前端正式联调与展示规则应以 `phaseStatus` 为准。
- `toggleTimer()` 在当前实现中仍可作为兼容入口存在，但不应继续作为最终 OpenSpec 目标交互。
- `fetchHistoryData()` 可作为现有统计占位接口继续保留，但不属于本次前端主闭环 contract。

---

## 3. UIWidgets 番茄钟区改造任务

### 3.1 移除正式假进度依赖
- [x] 删除或停用 `_fakeTimer` 的正式职责。
- [x] 删除或停用 `_fakeProgress` 的正式职责。
- [x] 删除或停用 `_activeListener` 对假进度动画的联动职责。
- [x] 删除或停用 `_resetFakeProgress()` 的正式职责。

### 3.2 改造倒计时进度展示
- [x] 将当前番茄钟进度组件改为根据 controller 状态推导真实进度。
- [x] 若 `phaseStatus == ready`，总时长取当前专注阶段时长，进度显示为 `0.0`。
- [x] 若当前阶段为 `studying`，总时长取当前专注阶段时长。
- [x] 若当前阶段为 `resting` 且 `phaseStatus != ready`，总时长取当前休息阶段时长。
- [x] 使用统一公式推导进度值：`(total - remainingSeconds) / total`。
- [x] 对进度值做边界保护，确保结果始终落在 `0.0 ~ 1.0`。
- [x] 不再使用 `_fakeProgress` 作为正式进度来源。

### 3.3 明确开始 / 暂停 / 重置三个按钮
- [ ] 前端提供开始、暂停、重置三个显式控制入口。
- [ ] `phaseStatus == ready` 时，开始按钮可用，暂停按钮不可用。
- [ ] `phaseStatus == running` 时，暂停按钮可用，开始按钮不可用。
- [ ] `phaseStatus == paused` 时，开始按钮作为“继续当前阶段”入口可用，暂停按钮不可用。
- [ ] 重置按钮在非 ready 状态可用；若产品上决定 ready 态也可点，行为仍只能是幂等重置。
- [ ] 开始按钮只调用 `controller.startTimer()`。
- [ ] 暂停按钮只调用 `controller.pauseTimer()`。
- [x] 重置按钮只调用 `controller.resetTimer()`。
- [ ] UI 不再在点击后追加任何本地补丁逻辑。
- [ ] 不再以 `toggleTimer()` 作为正式主交互入口。

### 3.4 统一阶段展示语义
- [ ] 若 UI 需要展示“待开始 / 学习中 / 学习暂停 / 休息中 / 休息暂停”等文案，只能由 `pomodoroState + phaseStatus` 组合推导。
- [x] `pomodoroState` 的正式职责是业务阶段语义：给动画、对话、陪伴行为使用。
- [ ] `phaseStatus` 的正式职责是运行控制语义：给计时器控制、按钮态、恢复逻辑、持久化使用，并在 UI 按钮态中成为唯一正式依据。
- [ ] 不再使用 `isActive` 作为正式按钮态来源。

---

## 4. 配置输入区任务

### 4.1 固定三个输入区
- [x] 前端提供专注时长输入区。
- [x] 前端提供休息时长输入区。
- [x] 前端提供循环次数输入区。
- [x] 本批次只冻结这三个输入项，不额外扩展无限循环、预设模式等控制项。

### 4.2 输入区与 controller 方法绑定
- [x] 专注时长输入以分钟展示与编辑，提交前换算成秒后再调用 `controller.updateFocusDuration(int seconds)`。
- [x] 休息时长输入以分钟展示与编辑，提交前换算成秒后再调用 `controller.updateRestDuration(int seconds)`。
- [x] 循环次数输入只调用 `controller.updateCycleCount(int? count)`。
- [x] UI 不把配置值保存在本地状态里作为正式来源。

### 4.3 输入展示与当前阶段关系
- [x] Ready 态更新专注时长后，倒计时展示同步刷新为新的专注默认值。
- [x] 运行中或暂停中更新配置时，UI 只反映配置值变化，不伪造当前倒计时已被重算。
- [x] 若循环次数被清空，当前 UI 语义为“不循环 / 0 显示占位”，controller 仍以 `null` 存储该语义。

---

## 5. MainStage 启动恢复接线任务

### 5.1 接入 controller 初始化入口
- [x] 在 `lib/main.dart` 中于 `MainStage` 生命周期尽早触发 `controller.initialize()` 或等价恢复入口。
- [x] 确保正常 UI 交互前，controller 已完成最基本的配置恢复与运行快照恢复。

### 5.2 处理恢复首帧展示
- [x] 避免页面先展示默认 `1500` 秒，再跳变为恢复值。
- [x] 若 controller 初始化为异步，前端采用最小必要的首帧保护方案。
- [x] 首帧保护不得演变为第二套状态源。

---

## 6. 统计面板与分享卡片的前端边界调整

### 6.1 统计面板边界
- [x] 可继续保留统计入口作为 UI 占位。
- [x] 若仍保留 `fetchHistoryData()` 调用，明确它不属于本次主 contract。
- [x] 统计入口不应影响当前番茄钟计时主流程。

### 6.2 分享卡片边界
- [x] 当前分享/统计展示已不再用 `kDefaultPomodoroSeconds - remainingSeconds` 伪装为正式学习时长。
- [ ] 若真实统计摘要尚未接通，仍应继续明确其为占位展示，而非最终正式统计 contract。

---

## 7. 当前结论

前端相关工作 **部分完成但尚未完全满足归档条件**：
- 真实进度来源、配置输入与启动恢复接线已基本完成；
- 但显式三按钮控制与以 `phaseStatus` 作为唯一正式按钮态来源仍未完全落地；
- 因此该前端任务文档当前更适合作为“完成度对照表”，而不是归档完成证明。

---

## 8. 完成定义（Frontend DoD）

只有同时满足以下条件，前端任务才可视为完成并支撑归档：
- UI 不再依赖 `toggleTimer()` 作为正式主交互入口。
- 倒计时文本、进度展示、按钮态全部由 controller 单一事实源驱动。
- 前端已提供开始、暂停、重置三个显式控制入口，且仅通过 controller 显式方法驱动。
- 前端已提供专注时长、休息时长、循环次数三个输入区，且仅通过 controller 配置方法驱动。
- `MainStage` 已接入初始化 / 恢复入口，恢复场景下 UI 不再先展示错误默认值。
- 分享卡片与统计面板未再破坏番茄钟主流程语义。
- 前端不存在第二套正式计时、阶段状态或配置状态。
