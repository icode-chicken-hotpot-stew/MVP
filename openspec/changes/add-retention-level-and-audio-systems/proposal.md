## Why
当前 `improve-pomodoro-functionality` 已聚焦番茄钟核心状态机稳定化，但留存与体验增强需求（后台提醒、XP成长、全局音乐）已明确，不应继续挤入主变更导致范围膨胀。

在当前 1 周开发窗口，采用并行变更可把“核心计时可靠性”和“增长体验能力”拆分推进，降低回归复杂度并提高交付确定性。

## What Changes

- 新增后台监管能力：仅在 `studying + running` 切后台时开启监管，同一后台会话按 180 秒和 360 秒触发两段提醒。
- 新增 XP/等级能力：专注完成后结算 XP、执行日上限与等级晋升，并提供严格按等级的对话解锁判定。
- 新增全局音乐能力：应用初始化后自动播放背景音乐，阶段切换触发音效，音频故障不阻塞计时主流程。
- 新增上述能力的本地持久化约束与恢复行为。
- 新增针对监管、XP、音乐三条链路的测试与手工验证任务。

## Capabilities

### New Capabilities

- `pomodoro-background-supervisor-notifications`: 定义后台监管会话、3分钟/6分钟分段提醒、去重与取消规则。
- `focus-xp-level-and-dialogue-unlock`: 定义 XP 结算、每日上限、等级阈值与严格等级解锁。
- `global-background-music-and-phase-sfx`: 定义全局背景音乐自动播放、用户覆盖持久化与阶段音效触发。

### Modified Capabilities

- None.

## Impact

- Affected code:
  - `lib/app_controller.dart`（新增监管、XP、音乐状态与行为）
  - `lib/main.dart`（初始化阶段接入音频/监管准备逻辑）
  - `lib/ui_widgets.dart`（音乐控制与等级解锁提示消费 controller 状态）
- Dependencies:
  - 新增本地通知插件（用于 3m/6m 提醒）
  - 新增音频播放插件（用于 BGM + SFX）
- Systems:
  - Android 生命周期回调与通知权限链路
  - 本地 key-value 持久化键空间扩展（supervisor/xp/music）
- APIs/contracts:
  - controller 增加等级解锁判定接口与音乐控制接口
  - 对话层解锁判定改为严格 level-only contract
