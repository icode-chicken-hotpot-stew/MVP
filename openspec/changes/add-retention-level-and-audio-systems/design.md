## Context

本设计基于一个前提：番茄钟主状态机继续由 `improve-pomodoro-functionality` 负责，当前变更只挂载扩展能力。

三条扩展能力分别消费以下既有状态：

- 后台监管消费 `pomodoroState + phaseStatus + lifecycle`
- XP/等级消费 `focus completion` 事件
- 音乐/音效消费 `app startup` 与 `phase transition` 事件

## Goals / Non-Goals

**Goals:**

- 在不破坏现有番茄钟主状态机的前提下，增量接入监管、XP、音乐三条能力链路。
- 将“3分钟/6分钟后台提醒”“严格等级解锁”“全局自动背景音乐”固化为可测试契约。
- 保持控制器单一事实源，UI 仅消费状态与方法，不新增本地业务真相。
- 明确失败降级策略，保证音频/通知故障不影响番茄钟主流程。

**Non-Goals:**

- 不重构 `improve-pomodoro-functionality` 已定义的核心状态机。
- 不引入云端同步、推荐算法、复杂成就系统。
- 不在本变更内完成历史统计系统重建。
- 不在本变更内做大规模 UI 视觉改版。

## Architecture Sketch

```text
                App Lifecycle
                     |
                     v
+------------------------------------------------+
|                 AppController                  |
|                                                |
|   Pomodoro Core (existing change)              |
|      |- phase state machine                    |
|      |- snapshot persistence                   |
|      |- completion transitions                 |
|                                                |
|   Extensions (this change)                     |
|      |- Background Supervisor (3m/6m notify)   |
|      |- XP/Level Engine                        |
|      |- Global BGM + Phase SFX                |
+------------------------------------------------+
                     |
                     v
           UI consume notifiers only
```

## Decision 1: Use a parallel change boundary

采用方案B：新增并行change，不继续扩写现有主change。

理由：

1. 主change聚焦计时核心稳定性，扩展能力另行迭代更可控。
2. QA可以按能力分桶验收，减少交叉回归成本。
3. 回滚时可以按能力回退，不影响主状态机契约。

备选方案：继续把需求并入主 change。

不采用原因：主 change 的目标是“计时核心可靠性”，继续并入将显著扩大评审面与测试矩阵。

## Decision 2: Background supervisor as a session-based scheduler

### Model

- 一次后台会话定义为：从前台离开到下一次回前台。
- 每个后台会话只允许两个通知节点：
  - Stage A: +180秒
  - Stage B: +360秒

### Trigger Gate

仅当进入后台瞬间满足以下条件才创建监管会话：

1. `pomodoroState == studying`
2. `phaseStatus == running`

### Cancellation

出现任一事件立即取消未触发节点：

1. 回前台
2. pause
3. reset
4. 阶段离开 studying/running 组合

备选方案：使用一次性 6 分钟单提醒。

不采用原因：与已确认 PRD（3m/6m 双提醒）不一致，且无法覆盖“中途回流用户”的提醒节奏。

## Decision 3: XP and level as completion-driven accounting

### Grant timing

仅在专注阶段自然完成时发放 XP，不做每秒累计。

### Formula

- `xpGain = floor(focusMinutes) * 10 * multiplier`
- 默认 `multiplier = 1.0`
- 单次有效专注小于5分钟，发放0
- 每日上限2000 XP

### Level thresholds

沿用PRD中的 LV1-LV10 阶梯，累计上限 36000 XP。

### Dialogue unlock

严格按等级：`currentLevel >= requiredLevel`。

备选方案：等级 + 任务条件混合解锁。

不采用原因：当前产品已确认“严格等级”策略，混合条件会引入额外解释成本与策略分歧。

## Decision 4: Global BGM decoupled from pomodoro phase

### Policy

- App 完成启动初始化后自动播放背景音乐
- 自动播放与 `resting/studying/ready` 解耦
- 用户手动暂停/恢复可覆盖自动播放状态，并持久化

### Phase SFX

- `ready -> studying/running`: 启动音效
- `studying/running -> resting/running`: 鼓励音效
- `resting/running -> studying/running`: 启动音效

### Failure mode

任意音频播放失败均记录日志并静默降级，不影响计时链路。

备选方案：仅在 studying 时播放背景音乐。

不采用原因：与“App 背景音乐全局自动播放”决策冲突，且会造成状态切换时听感不连续。

## Data Persistence

建议键：

- 后台监管
  - `supervisor.lastBackgroundAt`
  - `supervisor.stage3mSent`
  - `supervisor.stage6mSent`
- XP/等级
  - `xp.total`
  - `xp.daily`
  - `xp.lastDate`
  - `xp.level`
- 音乐
  - `music.autoPlayEnabled`
  - `music.isPlaying`
  - `music.trackIndex`
  - `music.volume`

## Migration Plan

1. 基线确认：以 `improve-pomodoro-functionality` 当前已稳定状态为基线，冻结核心计时行为。
2. 监管接入：先落生命周期监听与本地通知调度，完成 3m/6m 双节点和取消逻辑。
3. XP 接入：接入专注完成结算、日上限、等级判定与持久化恢复。
4. 音频接入：接入 BGM 自动播放、用户覆盖持久化与阶段 SFX。
5. UI 对齐：替换 UI 本地音乐状态为 controller 状态消费，并补对话锁定提示。
6. 验证与回滚：按能力分桶执行测试；若异常可按能力回退，不触碰主状态机。

## Testing Strategy

1. 监管链路：3m/6m触发、会话取消、快速前后台抖动去重。
2. XP链路：阈值、日上限、等级晋升、日切重置。
3. 音频链路：自动播放、手动覆盖、重启恢复、SFX触发。
4. 回归链路：扩展能力开启后不破坏现有番茄钟主流程。

## Rollout Strategy

1. 先在开发环境打开扩展能力并跑单测。
2. 真机手测后台通知与音频前后台行为。
3. 合并后观察崩溃日志与关键事件埋点再扩大验证范围。

## Open Questions

1. 本地通知插件选型是 `flutter_local_notifications` 还是等价方案（以 Android 生命周期兼容性为优先）。
2. BGM 与 SFX 是否使用同一播放引擎实例，或采用双通道策略（避免抢占与中断）。
3. XP 日切依据是否以设备本地日期为准，是否需要防设备时间回拨策略。
