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
- 让倒计时文本、进度展示、播放/暂停按钮态全部来自同一套 controller 状态。
- 去掉 `UIWidgets` 内部对正式番茄钟流程的本地假实现。
- 在应用启动恢复场景下，避免 UI 先展示错误默认值、再跳变到恢复值。

### 非目标
- 不在本任务中实现 `AppController` 的完整状态机。
- 不在本任务中定义 `fetchHistoryData()` 的正式数据契约。
- 不在本任务中完成设置面板最终交互设计。
- 不在本任务中扩展聊天气泡、Live2D 或其他陪伴系统。

---

## 1. 当前前端现状确认

- `lib/ui_widgets.dart` 仍维护 `_fakeTimer`、`_fakeProgress`、`_activeListener`，属于本地假计时逻辑。
- 当前番茄钟圆形进度条消费 `_fakeProgress`，而倒计时文本消费 `controller.remainingSeconds`，存在双真相。
- Reset 按钮仍额外调用 `_resetFakeProgress()`，说明 UI 仍在补 controller 未实现的逻辑缺口。
- `lib/main.dart` 当前仅创建 `AppController()` 并注入 `UIWidgets`，尚未接恢复初始化入口。

前端本批次工作的核心是：**移除这些假状态职责，改为只消费 controller 的真实状态。**

---

## 2. 前后端并行开发的最小接口清单

本项目的前后端协作方式是：**先冻结接口契约，再各自独立实现，最后合并联调**。

因此，这里的接口清单不是“前端等后端做完再开始”的前置条件，而是**前端开发时必须共同遵守的 contract**。前端可以基于这些已冻结的字段、方法签名和语义先行完成 UI 改造；最终合并时，只要 controller 实现与约定一致，前端不应再补第二套本地逻辑。

前端开发与联调时，应以 `AppController` 的以下状态或等价接口为契约面：

- `remainingSeconds`
- `isActive`
- `tomatoState`
- `focusDurationSeconds`
- `restDurationSeconds`
- `cycleCount`
- `completedFocusCycles`
- `toggleTimer()`
- `resetTimer()`
- `fetchHistoryData()`
- `initialize()` 或等价启动恢复入口

### 前端消费规则
- UI 只读 controller 状态。
- UI 只能通过公共方法表达用户意图。
- UI 不得自行维护“真实剩余时间”或“真实进度”。
- UI 不得通过本地 `Timer` 补正式番茄钟逻辑。
- 若联调前需要本地验证 UI，可使用符合上述契约的临时 stub / mock controller，但不得把 stub 行为写成新的产品语义。

### 并行开发约束
- 前端与 controller 实现可以并行推进，但都必须服从同一份 OpenSpec 契约。
- 前端不得因为对方尚未提交实现，就在 UI 层新增正式业务语义。
- 若 contract 需要调整，应先更新 OpenSpec，再同步双方实现，不允许各自口头漂移。

---

## 3. UIWidgets 番茄钟区改造任务

### 3.1 移除正式假进度依赖
- [ ] 删除或停用 `_fakeTimer` 的正式职责。
- [ ] 删除或停用 `_fakeProgress` 的正式职责。
- [ ] 删除或停用 `_activeListener` 对假进度动画的联动职责。
- [ ] 删除或停用 `_resetFakeProgress()` 的正式职责。

说明：
- 如果为了过渡保留字段，也不得再作为正式渲染来源。
- 最终正式状态必须全部来自 controller。

### 3.2 改造倒计时进度展示
- [ ] 将当前番茄钟进度组件改为根据 controller 状态推导真实进度。
- [ ] 根据当前阶段选择总时长：
  - `studying` → `focusDurationSeconds`
  - `resting` → `restDurationSeconds`
- [ ] 使用统一公式推导进度值：`(total - remainingSeconds) / total`
- [ ] 对进度值做边界保护，确保结果始终落在 `0.0 ~ 1.0`。
- [ ] 不允许继续使用 `_fakeProgress` 作为正式进度来源。

验收标准：
- 倒计时文本变化时，进度展示与之同步。
- App 恢复后，文本与进度来自同一恢复值，不出现“时间是真、进度是假”。

### 3.3 保持按钮只驱动 controller
- [ ] 播放/暂停按钮只调用 `controller.toggleTimer()`。
- [ ] 重置按钮只调用 `controller.resetTimer()`。
- [ ] UI 不再在点击后追加任何本地补丁逻辑。
- [ ] 播放/暂停按钮图标态仅由 `controller.isActive` 推导。

验收标准：
- 点击播放、暂停、恢复、重置后，UI 只等待 controller 状态更新并自动重建。
- Reset 后不再需要 `_resetFakeProgress()` 一类本地辅助方法。

### 3.4 统一阶段展示语义
- [ ] 若 UI 需要展示“专注中 / 休息中 / 待开始”等文案，只能由 `tomatoState + isActive` 组合推导。
- [ ] 不新增本地阶段变量，不新增 UI 私有状态机。

---

## 4. MainStage 启动恢复接线任务

### 4.1 接入 controller 初始化入口
- [ ] 在 `lib/main.dart` 中于 `MainStage` 生命周期尽早触发 `controller.initialize()` 或等价恢复入口。
- [ ] 确保正常 UI 交互前，controller 已完成最基本的配置恢复与运行快照恢复。

### 4.2 处理恢复首帧展示
- [ ] 避免页面先展示默认 `1500` 秒，再跳变为恢复值。
- [ ] 若 controller 初始化为异步，前端采用最小必要的首帧保护方案。
- [ ] 首帧保护不得演变为第二套状态源。

建议验收：
- 冷启动无快照时，正常显示待开始默认值。
- 冷启动有快照时，首个可交互状态即与恢复后的 `remainingSeconds` 一致。

---

## 5. 统计面板与分享卡片的前端边界调整

### 5.1 统计面板边界
- [ ] 保留统计按钮触发 `fetchHistoryData()` 的入口。
- [ ] 确保统计操作不影响当前番茄钟计时状态。
- [ ] 若真实历史结果尚未接通，可继续保留视觉占位，但不得伪造会影响番茄钟主流程的状态。

### 5.2 分享卡片边界
- [ ] 不再把 `kDefaultPomodoroSeconds - remainingSeconds` 视为“今日学习时长”的正式来源。
- [ ] 若真实统计摘要尚未接通，应把当前分享卡片明确视为占位展示，而非真实数据展示。

说明：
- 这两块在本次 change 中不是核心闭环，不应反向拖住番茄钟单一事实源改造。

---

## 6. 设置入口相关前端约束

- [ ] 本批次不强制落设置面板最终位置。
- [ ] 若已有入口占位，保持占位即可。
- [ ] 后续设置 UI 接入时，只能调用：
  - `updateFocusDuration(int seconds)`
  - `updateRestDuration(int seconds)`
  - `updateCycleCount(int? count)`
- [ ] 不允许把配置值临时保存在 `UIWidgets` 本地作为正式来源。

---

## 7. 联调禁止事项

前端联调期间禁止：

- [ ] 继续用 `_fakeProgress` 顶住真实进度展示。
- [ ] 用本地 `Timer` 递减 `remainingSeconds` 的视觉替身。
- [ ] 因 controller 尚未完成而在 UI 层新增一套阶段流转逻辑。
- [ ] 播放/暂停/重置后在 UI 中额外补业务状态。
- [ ] 默认值与 controller 契约不一致（focus=1500, rest=300, cycle=null）。

---

## 8. 前端验收清单

### 8.1 基础交互
- [ ] 点击播放：UI 进入真实专注态展示。
- [ ] 点击暂停：仅暂停当前阶段，不改变错误阶段。
- [ ] 点击恢复：从当前剩余时间继续。
- [ ] 点击重置：恢复到待开始状态，不需要本地补丁。

### 8.2 展示一致性
- [ ] 倒计时文本与进度展示始终来自同一套 controller 状态。
- [ ] 播放/暂停按钮态始终只由 `isActive` 推导。
- [ ] 不出现负数秒、不出现越界进度。

### 8.3 恢复场景
- [ ] App 切后台再回来后，前端不参与恢复计算，只消费恢复后的 controller 状态。
- [ ] App 重启后，若存在运行快照，前端可直接展示恢复后的剩余时间与对应进度。
- [ ] 恢复后若阶段已推进，前端显示的阶段文案、按钮态、进度值保持一致。

### 8.4 非核心区块
- [ ] 打开统计面板不会打断计时主流程。
- [ ] 分享卡片不会再伪装成真实学习统计结果。

---

## 9. 建议提交顺序（前端视角）

1. 先按已冻结接口完成前端消费层改造；本地验证可使用契约一致的 stub / mock controller。
2. 再移除 `UIWidgets` 假进度正式职责。
3. 接入真实进度推导与按钮纯消费逻辑。
4. 最后接 `MainStage` 启动恢复入口与首帧保护。
5. 统计面板、分享卡片、设置入口保持边界内最小调整。
---

## 10. 完成定义（Frontend DoD）

满足以下条件即可视为前端任务完成：

- UI 不再依赖 `_fakeProgress`、`_fakeTimer`、`_resetFakeProgress()` 作为正式番茄钟逻辑来源。
- 倒计时文本、进度展示、播放/暂停按钮态全部由 controller 单一事实源驱动。
- `MainStage` 已接入初始化/恢复入口，恢复场景下 UI 不再先展示错误默认值。
- 分享卡片与统计面板未再破坏番茄钟主流程语义。
- 前端不存在第二套正式计时或阶段状态。
