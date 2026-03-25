# 番茄钟 Integration Rules

> 版本：v1.0
> 最后更新：2026-03-24
> 适用范围：番茄钟 controller、UI、启动恢复、持久化、统计读取的协作边界
> 依赖契约：`docs/pomodoro_interface_spec.md`、`docs/pomodoro_state_flow.md`

---

## 1. 目标

本文档用于冻结番茄钟模块的**集成规则**，避免前后端在开发中各自维护一套隐式约定。

本文重点回答：
- 谁拥有状态
- 谁只能读，谁可以写
- UI、controller、持久化层如何协作
- 哪些行为是允许的，哪些行为是禁止的

---

## 2. 模块职责边界

### 2.1 `AppController`

`AppController` 是番茄钟唯一状态源。

负责：
- 持有番茄钟公开状态
- 驱动计时
- 管理 `studying/resting` 状态流转
- 与持久化层同步快照和配置
- 向 UI 暴露历史统计结果

不负责：
- 在 UI 层做局部补丁
- 依赖 Widget 本地变量来完成正式业务逻辑

### 2.2 `UIWidgets`

`UIWidgets` 是状态消费者，不是状态源。

负责：
- 监听 `AppController` 的状态
- 将用户操作转发给 `AppController` 公共方法
- 根据 controller 状态渲染按钮、时间、进度、统计面板

不负责：
- 自行维护第二套番茄钟进度
- 自行递减剩余时间
- 直接修改 controller 内部字段
- 通过本地 `Timer` 实现正式番茄钟逻辑

### 2.3 `MainStage` / 应用入口

负责：
- 创建单个 `AppController`
- 负责 controller 生命周期
- 如有需要，负责启动时触发 controller 初始化/恢复

不负责：
- 分散地维护番茄钟状态
- 绕过 controller 直接给 UI 注入独立状态

### 2.4 持久化层

负责：
- 保存当前运行快照
- 保存番茄钟配置
- 保存/读取历史统计数据

不负责：
- 主导状态机
- 直接操作 UI
- 直接驱动 Widget 重建

---

## 3. 单一事实源规则

### 3.1 唯一写入口

以下公开方法是允许修改番茄钟状态的稳定入口：

```dart
void toggleTimer()
void resetTimer()
void fetchHistoryData()
void updateFocusDuration(int seconds)
void updateRestDuration(int seconds)
void updateCycleCount(int? count)
```

除此之外：
- UI 不得直接改 `ValueNotifier.value`
- 其他模块不得绕开 `AppController` 写入番茄钟核心状态

### 3.2 UI 只读规则

UI 可以读取：
- `remainingSeconds`
- `isActive`
- `pomodoroState`
- `focusDurationSeconds`
- `restDurationSeconds`
- `cycleCount`
- `completedFocusCycles`
- 历史统计结果状态

UI 不可以：
- 自己缓存一份“真实剩余时间”
- 自己缓存一份“真实进度”
- 在 `build()` 中写业务副作用

---

## 4. 状态消费规则

### 4.1 时间展示规则

- 倒计时文本只能来自 `remainingSeconds`
- 不允许 UI 用本地计数器替代它

### 4.2 进度展示规则

- 进度条必须由“当前阶段总时长”和 `remainingSeconds` 推导
- 不允许继续使用 `_fakeProgress` 作为正式进度
- 若未来 controller 暴露专门进度字段，该字段也必须由同一套状态推导

### 4.3 按钮状态规则

- 播放/暂停按钮态只能由 `isActive` 推导
- 阶段文案/角色状态只能由 `pomodoroState` 与 `isActive` 组合推导

### 4.4 分享与统计规则

- 分享卡片不应再通过 `kDefaultPomodoroSeconds - remainingSeconds` 推导“今日学习时长”
- 统计面板必须依赖历史统计结果状态，而不是硬编码占位文本

---

## 5. 方法集成规则

### 5.1 `toggleTimer()` 集成规则

调用方：
- UI 播放/暂停按钮

调用后期望：
- UI 不需要补额外逻辑
- UI 不需要手动重置进度
- UI 只等待 controller 状态更新后自动重建

### 5.2 `resetTimer()` 集成规则

调用方：
- UI 重置按钮

调用后期望：
- UI 不应再调用 `_resetFakeProgress()` 一类本地补丁
- controller 应一次性恢复一致状态

### 5.3 `fetchHistoryData()` 集成规则

调用方：
- UI 统计按钮

调用后期望：
- 该方法只影响历史数据结果
- 不影响当前计时状态
- 可与弹窗展示联动，但弹窗内容必须消费真实结果状态

### 5.4 配置方法集成规则

调用方：
- 设置面板或后续设置页面

调用后期望：
- 配置更新后应持久化
- 未运行时可以同步刷新默认展示值
- 运行中不应偷偷切阶段

---

## 6. 生命周期集成规则

### 6.1 启动阶段

应用启动时必须满足：
- controller 是单例注入到当前主界面树中的唯一实例
- 在 UI 消费状态前，controller 应尽早完成配置和快照恢复

### 6.2 恢复阶段

如果存在持久化快照：
- controller 必须自己恢复 `remainingSeconds`
- controller 必须自己判断当前阶段是否已过期
- UI 不参与时间恢复计算

### 6.3 销毁阶段

controller `dispose()` 时必须清理：
- 内部计时器
- notifier
- 临时监听器

UI `dispose()` 时只负责清理自己的订阅，不负责结束番茄钟业务流程。

---

## 7. 持久化集成规则

### 7.1 必存信息

至少需要持久化：
- 当前阶段开始时间
- 当前阶段类型
- 当前阶段总时长
- 当前是否运行
- 专注/休息时长配置
- 循环次数配置
- 已完成专注轮次

### 7.2 存储写入时机

建议至少在以下时机写入：
- 开始专注
- 暂停当前阶段
- 恢复当前阶段
- 专注完成进入休息
- 休息完成进入下一轮或回到待开始
- 更新配置
- 重置

### 7.3 存储读取时机

建议至少在以下时机读取：
- controller 初始化
- 用户主动查看统计时

---

## 8. 历史统计集成规则

### 8.1 历史写入边界

只有“专注阶段自然完成”时，才应新增一次有效专注记录。

以下情况不应写入完成记录：
- 手动暂停
- 手动重置
- 只进入休息但专注尚未完成
- 只是打开统计面板

### 8.2 历史读取边界

`fetchHistoryData()`：
- 可以刷新今日专注时长、累计天数、完成轮次等摘要
- 不应反向修改番茄钟流程状态

---

## 9. 前后端联调规则

### 9.1 联调最小字段集

前端接番茄钟 UI 时，最少依赖以下字段：
- `remainingSeconds`
- `isActive`
- `pomodoroState`
- `focusDurationSeconds`
- `restDurationSeconds`
- `completedFocusCycles`
- 历史摘要结果

### 9.2 联调禁止事项

联调期间禁止：
- 前端先用本地假状态“顶着跑”，再让后端去适配假状态
- 后端根据某个页面的临时渲染技巧改变核心语义
- 两边分别维护不同的默认值

### 9.3 默认值统一规则

默认值必须统一为：
- focus：`1500`
- rest：`300`
- cycle：`null`
- 初始业务状态：`resting`
- 初始运行状态：`false`

---

## 10. 错误与边界规则

### 10.1 配置输入校验

- `updateFocusDuration(int seconds)`：必须 `> 0`
- `updateRestDuration(int seconds)`：必须 `> 0`
- `updateCycleCount(int? count)`：只能是 `null` 或正整数

### 10.2 非法输入处理原则

对于非法输入：
- 不更新现有配置
- 不推进状态机
- 不写坏持久化数据

### 10.3 阶段边界处理原则

当阶段自然结束时：
- 不允许出现负数秒展示
- 不允许同一阶段重复结算多次
- 不允许既写历史又回滚阶段

---

## 11. 测试联动建议

实现完成后，至少应联合验证：

1. UI 点击播放后，controller 进入 `studying + active`
2. UI 点击暂停后，controller 只改变 `isActive`
3. UI 点击重置后，不需要任何本地补丁即可恢复一致界面
4. App 重启后，controller 能独立恢复剩余时间
5. 统计面板展示真实历史结果，而不是写死文案
6. 进度条与倒计时文本永远来自同一套状态
7. App 切后台再回来后，controller 能独立推进过期阶段并同步 UI
8. 分享卡片不再通过 `kDefaultPomodoroSeconds - remainingSeconds` 推导“今日学习时长”

---

## 12. 风险提醒

1. `docs/interface_spec.md` 与当前仓库现状不完全一致，联调时要以前三份番茄钟专用文档和代码为准。
2. 若先实现 controller 但未移除 `_fakeProgress`，会出现“时间是真、进度是假”的 UI 不一致。
3. `fetchHistoryData()` 当前只有方法入口，没有既定返回模型，建议先冻结最小历史摘要字段。
4. “简单数据库”需求在当前 MVP 中应理解为可靠本地持久化，避免为少量标量状态过度引入复杂数据层。

---

## 13. 参考文档

- `docs/pomodoro_interface_spec.md`
- `docs/pomodoro_state_flow.md`
- `docs/番茄钟功能简要.md`
- `lib/app_controller.dart`
- `lib/ui_widgets.dart`
- `lib/main.dart`
