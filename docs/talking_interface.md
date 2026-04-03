# 对话与 Tips 系统实现说明（当前代码版）

> 更新日期: 2026-04-03  
> 适用文件: `lib/main.dart`、`lib/app_controller.dart`、`lib/ui_widgets.dart`、`assets/dialogues/dialogues.json`

---

## 1. 这套系统现在已经实现了什么

当前仓库已完成基础对话链路，不再是纯规划状态。

已生效能力：

- 对话触发：`clicked`、`start_focus`、`completed`、`resume`、`idle`
- 对话仲裁：支持中断、排队、忽略
- 文案来源：资产 JSON + 内置 fallback
- 等级解锁：按候选句 `requiredLevel` 解锁
- UI 展示：右下角气泡、打字机、跳过、自动下一句
- 生命周期恢复：App 回前台后同步计时并触发 `resume`/`completed`

---

## 2. 模块职责

### 2.1 `lib/main.dart`

- 创建 `AppController`
- 启动时调用 `controller.initialize()`
- 监听 `WidgetsBindingObserver`
- App 回前台时调用 `controller.synchronizeWithCurrentTime()`

### 2.2 `lib/app_controller.dart`

状态与行为单一事实源，负责：

- 对话状态管理（是否说话、当前文本、当前类型、队列）
- 触发可用性判断（按 `pomodoroState` 和 `phaseStatus`）
- 触发仲裁（打断/排队/忽略）
- 文案加载与清洗
- idle 计时管理

### 2.3 `lib/ui_widgets.dart`

负责渲染和交互：

- 空白区域点击前进对话
- 角色点击触发 `clicked`
- `ChatBubble` 打字机展示、skip、自动下一句

---

## 3. 关键接口（实际可调用）

### 3.1 对话相关 getter

- `controller.isTalking`
- `controller.currentDialogue`
- `controller.currentDialogueType`

### 3.2 对话相关方法

- `Future<void> triggerDialogue(String type)`
- `void nextDialogue()`
- `void skipDialogue()`
- `void registerUserInteraction()`

### 3.3 生命周期方法

- `Future<void> initialize()`
- `Future<void> synchronizeWithCurrentTime()`
- `void handleAppBackgrounded()`
- `Future<void> handleLifecycleStateChanged(AppLifecycleState state)`

---

## 4. 触发规则（按当前实现）

### 4.1 触发类型

- `completed`（最高）
- `start_focus`
- `resume`
- `clicked`
- `idle`（最低）

### 4.2 触发前置条件

- `resume` 仅在 `studying + running`
- `start_focus` 仅在 `studying`
- 其余类型在 `studying` 时拒绝

### 4.3 正在对话时的仲裁

- 同优先级：忽略
- 更低优先级：排队
- `clicked`/`idle` 不打断当前对话（统一排队）
- `completed`/`start_focus`/`resume` 可打断低优先级对话

排队列表会去重，同类型只保留一份待处理请求。

---

## 5. Idle 提示机制

- 超时阈值：60 秒
- 仅在前台 + resting + 非对话状态下启用
- 用户操作（点击、按钮调用）会刷新 idle 计时

---

## 6. 文案资源与加载

### 6.1 真实路径

- `assets/dialogues/dialogues.json`
- 目录已在 `pubspec.yaml` 注册：`assets/dialogues/`

### 6.2 支持格式

每个触发类型下支持：

- 字符串：`"一条文案"`
- 数组：`[2, "line1", "line2"]`
- 对象：`{"level": 2, "lines": ["line1", "line2"]}`

### 6.3 兜底顺序

1. 对应类型文案
2. `_fallback.default`
3. 控制器内置文案
4. 最终兜底：`先继续当前节奏吧。`

---

## 7. 气泡交互细节

`ChatBubble` 当前行为：

- 打字机速度：80ms/字
- 文本未展示完时点击气泡：立刻补全本句
- 本句展示完后 8 秒自动 `onNext`
- 点击快进图标执行 `onSkip`

这部分已有测试覆盖（`test/chat_bubble_test.dart`）。

---

## 8. 与历史文档的口径说明

以下旧口径已失效：

- “对话系统尚未实现”
- “对话资源路径未冻结”
- “仅有 `remainingSeconds/isActive/...` 四个基础状态”

如与旧文档冲突，以以下文件为准：

1. `lib/app_controller.dart`
2. `lib/ui_widgets.dart`
3. `lib/main.dart`
4. `assets/dialogues/dialogues.json`

---

## 9. 后续扩展建议

可在不破坏当前契约的前提下继续扩展：

- 在 `character_view.dart` 完成角色动作联动
- 增加对话冷却和频控策略
- 将触发统计埋点化（类型、等级命中、跳过率）

扩展前先同步更新 `docs/talking_interface_spec.md`。
