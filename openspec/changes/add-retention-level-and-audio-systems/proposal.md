## Why
当前 `improve-pomodoro-functionality` 已经把番茄钟核心状态机稳定下来，而留存增强相关能力更适合以并行 change 独立演进：

- 后台监管提醒：提升用户从后台回流的概率
- XP / 等级：把专注完成转成可持续成长反馈
- 全局音乐 / 阶段音效：增强陪伴感与启动反馈

根据当前仓库实现，这三条能力已经以 controller 扩展、服务抽象、持久化键和针对性测试的形式落地；本次文档更新的目标是把变更说明收敛到**当前真实实现范围**，同时保留尚未完成的手工验证项。

## What Changes

- 新增后台监管能力：仅在 `studying + running` 切后台时开启监管，同一后台会话按 180 秒和 360 秒调度两段提醒；恢复前台、暂停、重置或离开专注阶段时取消监管。
- 新增 XP / 等级能力：专注阶段自然完成后结算 XP，执行每日 2000 XP 上限、按固定阈值升等级，并提供严格按等级的对话解锁判定与锁定文案。
- 新增全局音乐能力：应用初始化后按持久化偏好自动播放背景音乐，支持上一首 / 下一首 / 播放暂停 / 静音切换，并在阶段切换时触发启动 / 鼓励音效。
- 新增本地持久化恢复：`pomodoro`、`xp`、`music`、`supervisor` 四类状态均通过 `SharedPreferences` 恢复。
- 新增面向 controller 的测试：覆盖后台监管、XP 结算、音乐自动播放 / 生命周期恢复等关键链路。
- 明确保留范围外内容：历史统计 / 留存分析面板仍未重建，`fetchHistoryData()` 仍为占位实现，不属于本 change 已完成部分。

## Capabilities

### New Capabilities

- `pomodoro-background-supervisor-notifications`: 后台监管会话、3 分钟 / 6 分钟提醒、取消与失败降级。
- `focus-xp-level-and-dialogue-unlock`: XP 结算、每日上限、固定等级阈值、严格等级解锁。
- `global-background-music-and-phase-sfx`: 全局背景音乐自动播放、用户覆盖持久化、阶段音效与生命周期暂停 / 恢复。

### Modified Capabilities

- None.

## Impact

- Affected code:
  - `lib/app_controller.dart`
  - `lib/main.dart`
  - `lib/ui_widgets.dart`
  - `lib/services/audio_service.dart`
  - `lib/services/supervisor_notification_service.dart`
  - `android/app/src/main/kotlin/com/example/mvp_app/MainActivity.kt`
  - `android/app/src/main/kotlin/com/example/mvp_app/SupervisorNotificationDebugReceiver.kt`
  - `test/app_controller_audio_test.dart`
  - `test/app_controller_supervisor_test.dart`
  - `test/app_controller_xp_test.dart`
- Dependencies:
  - `just_audio`
  - `flutter_local_notifications`
  - `timezone`
  - `shared_preferences`
- Systems:
  - Android 生命周期回调
  - 本地通知调度与权限请求
  - 本地 key-value 持久化键空间扩展（`pomodoro` / `xp` / `music` / `supervisor`）
- APIs/contracts:
  - controller 暴露等级解锁、音乐控制、生命周期处理接口
  - UI 通过 `ValueNotifier` 消费 XP / 等级 / 音乐状态
