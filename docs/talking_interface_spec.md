# 对话与 Tips 系统 Interface Spec（当前实现基线）

> 版本: v6.0  
> 最后更新: 2026-04-03  
> 适用范围: `AppController` 对话状态、触发规则、UI 消费契约

---

## 1. 文档定位

本文档描述当前仓库中已经生效的对话系统契约，作为实现和联调基线。

- 代码事实优先于历史文档。
- 如后续修改接口，需同步更新本文件。

---

## 2. 入口与模块关系

默认入口链路：

1. `lib/main.dart` 创建 `AppController` 并调用 `initialize()`。
2. `MainStage` 在 `AppLifecycleState.resumed` 时调用 `synchronizeWithCurrentTime()`。
3. `UIWidgets` 读取 controller 状态并渲染 `ChatBubble`。

当前对话 UI 已在 `lib/ui_widgets.dart` 主界面内接入，不依赖独立 `DialogueUI` 页面。

---

## 3. 状态模型

### 3.1 公开对话状态

由 `AppController`（`ChangeNotifier`）公开：

- `bool get isTalking`
- `String get currentDialogue`
- `String get currentDialogueType`

### 3.2 私有对话状态（实现细节）

- `_currentDialogueQueue: List<String>`
- `_currentDialogueIndex: int`
- `_queuedDialogueTypes: List<String>`
- `_lastInteractionAt: DateTime?`
- `_idleTimer: Timer?`

### 3.3 与番茄钟状态的职责拆分

- `pomodoroState`：业务阶段语义（`resting` / `studying`），供对话与陪伴行为判断。
- `phaseStatus`：运行控制语义（`ready` / `running` / `paused`），供计时恢复与控制逻辑判断。

---

## 4. 触发类型与优先级

系统支持 6 种触发类型（字符串常量）：

- `completed`（优先级 1，最高）
- `start_focus`（优先级 2）
- `resume`（优先级 3）
- `cold_start`（优先级 4）
- `clicked`（优先级 5）
- `idle`（优先级 6，最低）

### 4.1 触发前置条件

- 未知类型：拒绝触发。
- `resume`：仅允许在 `pomodoroState == studying && phaseStatus == running`。
- `start_focus`：仅允许在 `pomodoroState == studying`。
- `cold_start`：仅允许在 `pomodoroState == resting`。
- 其他类型：当 `pomodoroState == studying` 时拒绝触发。

### 4.2 对话进行中仲裁规则

若当前已在说话（`isTalking == true`）：

1. 同级触发：忽略。
2. 更低优先级（数字更大）：排队。
3. `clicked` / `idle`（优先级大于 `resume`）统一排队，不打断当前对话。
4. `completed` / `start_focus` / `resume` 可打断较低优先级对话。

排队队列按类型去重，同一类型不会重复入队。

---

## 5. 公开接口契约

### 5.1 生命周期相关

- `Future<void> initialize()`
  - 恢复持久化状态。
  - 初始化音频与通知。
  - 启动 idle 计时。
  - 异步预热对话资产加载。
  - 不直接触发 `cold_start`。

- `Future<void> synchronizeWithCurrentTime()`
  - App 返回前台后同步计时状态。
  - 在专注中恢复时触发 `resume`；跨阶段则按恢复结果触发 `completed` 或继续专注。

- `void handleAppBackgrounded()`
  - 标记后台并停止 idle 计时器。

### 5.2 对话交互

- `Future<void> triggerDialogue(String type)`
  - 入口方法，做可触发判断、仲裁、加载文案、入场展示。

- `void nextDialogue()`
  - 若当前句未结束队列则切下一句；到尾句则结束对话并尝试消费排队触发。

- `void skipDialogue()`
  - 立即清空当前对话状态，随后尝试消费排队触发。

- `void registerUserInteraction()`
  - 刷新最后交互时间并重置 idle 计时。

- `void scheduleColdStartDialogueAfterEntrance({int? delaySeconds})`
  - 在检测到角色出场动画开始后，延迟触发 `cold_start`。
  - 默认延迟秒数由 `coldStartDialogueDelaySeconds` 控制（默认 5 秒）。

---

## 6. 文案资产契约

### 6.1 实际路径

- 资产路径：`assets/dialogues/dialogues.json`
- `pubspec.yaml` 已注册目录：`assets/dialogues/`

### 6.2 支持的数据格式

每个触发类型值可混用以下格式：

1. 字符串：`"line"`
2. 数组：`[level?, "line1", "line2"]`
3. 对象：`{"level": 2, "lines": ["line1", "line2"]}`
   - 兼容键：`lines` / `dialogue` / `content`

解析规则：

- `level` 缺省时默认为 1。
- 空字符串和非法项会被清洗。
- 候选句按 `requiredLevel <= 当前 level` 解锁。
- 每次触发会随机抽取一组可用候选。

### 6.3 fallback 规则

按顺序兜底：

1. 触发类型对应文案。
2. `_fallback.default`。
3. 内置文案（`_builtInDialogues`）。
4. 最终兜底：`先继续当前节奏吧。`

若候选存在但当前等级全部未解锁，返回空队列并不展示对话。

### 6.4 开发期刷新策略

`triggerDialogue` 内部会调用 `forceReload: true` 的资产读取逻辑。开发时修改 JSON 后，下一次触发会重新读取，不依赖重启应用。

---

## 7. Idle 对话规则

- 超时常量：`kIdleDialogueTimeout = 60s`。
- 仅在以下条件同时满足时启动 idle 计时：
  - 前台状态
  - `pomodoroState == resting`
  - 当前不在说话
- 触发后调用 `triggerDialogue('idle')`。
- 任意用户交互或状态变更会刷新/重置 idle 计时。

---

## 8. UI 消费契约

`UIWidgets` 当前行为：

- 空白区域点击：
  - 正在对话 -> `nextDialogue()`
  - 非对话 -> `registerUserInteraction()`
- 角色点击：`triggerDialogue('clicked')`
- 气泡展示：当 `isTalking == true` 时渲染 `ChatBubble`

`ChatBubble` 当前行为：

- 打字机速度：80ms/字。
- 文本未打完时点击：立即补全并开始自动下一句计时。
- 文本打完后 8 秒自动 `onNext()`。
- 右下角快进按钮执行 `onSkip()`。

---

## 9. 已知边界

- `character_view.dart` 仍为占位实现，对话触发入口当前以 `UIWidgets` 为准。
- 对话锁定文案按“候选句 level”解锁，不是按类型整体解锁。
- 对话系统不负责定义 Live2D 动作和口型策略。

---

## 10. 变更要求

若改动以下内容，必须同步更新本文档：

- 触发类型名称或优先级
- `triggerDialogue` 仲裁策略
- 文案 JSON 结构与路径
- `ChatBubble` 自动前进时序
- `synchronizeWithCurrentTime` 触发行为
