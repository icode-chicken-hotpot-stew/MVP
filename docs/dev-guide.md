# Flutter Project

## 项目概述
- 横屏陪伴学习类 Flutter 项目。
- 默认应用入口是 `lib/main.dart`，会创建 `MainStage` 并注入 `AppController`。
- 项目已进入正式快速开发阶段，当前开发窗口为 1 周。
- 当前阶段以“前端 + 基础后端”交付为主，复杂后端能力为次优先级。
- 当前仓库仍有部分占位实现和未完成功能，不要把现状误判为“当前还在 MVP”或“功能已齐全”。

## 技术栈
- Flutter / Dart
- 状态管理：`ValueNotifier` + `ValueListenableBuilder`
- Android：Kotlin DSL（`build.gradle.kts`）
- Lint：`flutter_lints`
- 辅助工具：`uv`、`pre-commit`

## 项目结构
```text
MVP/
├── android/
├── assets/
├── docs/
├── lib/
│   ├── main.dart            # 默认入口，负责 MainStage 生命周期与启动恢复接线
│   ├── app_controller.dart  # 状态中枢，维护番茄钟/对话/XP/音频等核心逻辑
│   ├── ui_widgets.dart      # 当前主界面与大部分交互逻辑
│   ├── character_view.dart  # 角色动画层占位文件，当前基本未正式接入
│   └── live2d.dart          # 独立实验性 Live2D 原型，不是默认入口
└── test/
```

此外还要知道：
- `assets/background.webp` 已在 `pubspec.yaml` 中注册
- `android/app/src/main/AndroidManifest.xml` 中当前 Activity 被设置为横屏
- `analysis_options.yaml` 目前只启用了 `flutter_lints`

## 5. 先掌握这个项目的状态流

当前项目采用轻量的 controller / view 分层。

### Controller 负责什么

`lib/app_controller.dart` 负责集中暴露状态，并维护番茄钟、对话、XP、音频与监督提醒等逻辑。当前番茄钟相关核心状态至少包括：

- `remainingSeconds`
- `pomodoroState`
- `phaseStatus`
- `focusDurationSeconds`
- `restDurationSeconds`
- `cycleCount`
- `completedFocusCycles`
- `isDrawerOpen`
- `currentDate`

原则上：
- View 层只负责监听和展示
- 状态修改应通过 Controller 方法触发
- 不要在 UI 层直接把业务状态当成“单一事实来源”去改写
- 番茄钟运行控制语义优先看 `phaseStatus`
- 陪伴 / 动画业务阶段语义优先看 `pomodoroState`

### UI 目前是什么状态

`lib/ui_widgets.dart` 是当前最重要的文件，因为大部分界面都在这里。

它目前包含：
- 底部 Dock 操作栏
- 角色舞台占位
- 顶部番茄钟进度与时间展示
- 统计弹窗入口与占位内容
- 配置面板、音量面板与若干交互入口

特别注意：
- 顶部番茄钟进度展示基于 `remainingSeconds` 与 `currentPhaseDurationSeconds` 计算
- 时间与阶段切换的单一事实源在 `AppController`
- UI 层主要负责展示和交互转发，不应重复维护计时状态
- 当前 UI 已接入专注 / 休息 / 循环三个配置入口
- 当前控制区仍保留 `toggleTimer()` + `isActive` 驱动的单播放/暂停按钮兼容实现，尚未完全收敛为 OpenSpec 目标中的显式“开始 / 暂停 / 重置”三按钮

## 6. 各核心文件应该怎么改

### `lib/main.dart`

这个文件现在主要做三件事：
1. 创建 `AppController`
2. 在 `MainStage.initState()` 里触发 `controller.initialize()`
3. 通过 `FutureBuilder` 确保恢复完成后再渲染正常 UI

一般不建议把大量业务逻辑继续堆到这里。

### `lib/app_controller.dart`

如果你负责逻辑层，优先在这里扩展：
- 番茄钟状态机、恢复与持久化
- 对话触发策略和文案解锁规则
- 音频、监督提醒与生命周期联动
- 与 UI 的状态契约稳定性

当前与番茄钟相关的关键公开方法包括：
- `initialize()`
- `startTimer()`
- `pauseTimer()`
- `resetTimer()`
- `updateFocusDuration(int seconds)`
- `updateRestDuration(int seconds)`
- `updateCycleCount(int? count)`
- `fetchHistoryData()`（当前仍是统计相关占位接口）

说明：
- `toggleTimer()` 当前仍存在，但更适合视为 `startTimer()` / `pauseTimer()` 的兼容封装，不应再作为番茄钟正式目标契约。
- 如需补番茄钟后端，先看以下权威材料：
  - `openspec/changes/improve-pomodoro-functionality/proposal.md`
  - `openspec/changes/improve-pomodoro-functionality/design.md`
  - `openspec/changes/improve-pomodoro-functionality/specs/pomodoro-persistence-and-remaining-time/spec.md`
  - `openspec/changes/improve-pomodoro-functionality/specs/pomodoro-state-transitions/spec.md`
  - `openspec/changes/improve-pomodoro-functionality/specs/pomodoro-duration-and-cycle-settings/spec.md`
  - `openspec/changes/improve-pomodoro-functionality/tasks.md`

### `lib/ui_widgets.dart`

如果你负责界面层，优先在这里处理：
- 布局与样式
- `ValueListenableBuilder` 监听状态后的渲染
- 按钮点击后调用 controller 方法
- 配置面板与占位 UI 的逐步替换

注意：
- 不要把副作用写进 `build()`
- 计时器、监听器的注册和销毁应放在生命周期里处理
- 不要直接在 UI 层偷偷改 Controller 内部状态
- 番茄钟正式进度不要再回退到本地假状态
- 新的番茄钟按钮态逻辑应优先依赖 `phaseStatus`，不要继续扩大 `isActive` 的正式职责

### `lib/character_view.dart`

这个文件现在还没有实际角色动画实现。

如果后续接入角色动画，建议方式是：
- 优先由 `controller.pomodoroState` 决定学习 / 休息主状态
- 需要区分待开始占位态与真实休息态时，再结合 `phaseStatus`

### `lib/live2d.dart`

这是实验性原型，当前需要特别注意：
- 它不是默认入口
- 它使用了 `webview_flutter` 和 `webview_flutter_android`
- 相关依赖和资源目录可能与主流程演进不同步

因此，如果你运行 `flutter analyze` 或尝试切到这个原型，报错不一定和你当前正在改的主界面有关。

## 7. 常用 Flutter 概念：只记本项目真正用到的

### Widget

Flutter 里界面都是 Widget 组成的。

本项目里你最常看到的是：
- `StatelessWidget`
- `StatefulWidget`
- `ValueListenableBuilder`
- `ListenableBuilder`

### `ValueNotifier` + `ValueListenableBuilder`

这是当前项目正在使用的主要状态管理方式。

更贴近当前仓库的示例模式如下：

```dart
ValueListenableBuilder<PomodoroPhaseStatus>(
  valueListenable: controller.phaseStatus,
  builder: (context, phaseStatus, _) {
    return Text(
      phaseStatus == PomodoroPhaseStatus.running ? '运行中' : '未运行',
    );
  },
)
```

可以这样理解：
- `ValueNotifier` 保存状态
- `ValueListenableBuilder` 监听状态变化并刷新 UI
- 业务语义和运行控制语义不要混成一个字段使用

## 8. 调试与检查

### 静态检查

```bash
flutter analyze
```

但请注意：当前仓库里可能存在历史遗留问题，尤其是 `lib/live2d.dart` 的依赖与资源声明不一致。因此 analyze 报错时，要先判断是不是你的改动引起的。

### 测试

```bash
flutter test
```

仓库已有 `test/` 目录，并包含 `app_controller_*` 与 `chat_bubble_test.dart` 等测试。
如果你修改了计时、对话、音频或等级逻辑，建议至少本地执行一次 `flutter test`。

### 构建 APK

```bash
flutter build apk
```

## 9. 图片资源与提交流程

项目里对图片资源有一套明确约束。

### 当前已知情况
- 主背景资源是 `assets/background.webp`
- 仓库中配置了 pre-commit 图片检查流程
- 已暂存的 PNG/JPG 可能会在提交时被自动转换为 WebP

### 提交图片时要知道的事

如果你把 PNG/JPG 放进 `assets/` 并提交，pre-commit 可能会：
1. 自动转成 WebP
2. 删除原始 PNG/JPG
3. 重新加入暂存区
4. 故意让本次 commit 失败一次

这时不要慌，通常再执行一次 `git commit` 即可。

### 手动处理图片

```bash
uv run scripts/compress_images.py --to-webp --dry-run
uv run scripts/compress_images.py --to-webp --delete
uv run scripts/compress_images.py
```

### 新增资源别忘了注册

新增 Flutter 资源后，记得检查 `pubspec.yaml` 是否已经注册；否则运行时可能找不到资源。

## 10. Git 协作建议

一个更贴近当前仓库的基本流程如下：

```bash
git pull origin main
git checkout -b feat/your-change
flutter pub get
# 开发并自测
git add <相关文件>
git commit -m "feat: 简述改动"
git push origin feat/your-change
```

注意：
- 尽量只暂存你本次真正修改的文件
- 不要沿用旧文档里的固定本地路径
- 如果 pre-commit 改写了图片资源，检查结果后再重新提交

## 11. 推荐优先看的文档

开始开发前，建议优先阅读：
- `CLAUDE.md`：仓库级开发说明，和当前代码状态最一致
- `openspec/changes/improve-pomodoro-functionality/design.md`：番茄钟权威设计边界
- `openspec/changes/improve-pomodoro-functionality/specs/`：番茄钟冻结行为契约
- `docs/talking_interface.md`：对话系统当前实现口径

如果某份旧文档和代码冲突，请以当前代码实现为准。

## 12. 新同学最容易踩的坑

1. 以为对话系统还没接入：当前对话触发、仲裁、文案加载已经在 `AppController` 生效。
2. 以为顶部进度条还是演示动画：当前进度已和 controller 状态联动。
3. 以为 `character_view.dart` 已经能接角色动画：其实还没有正式实现。
4. 以为 `live2d.dart` 是主入口：其实默认入口仍然是 `lib/main.dart`。
5. 以为番茄钟已经完全可归档：其实验证任务和显式三按钮控制语义还未完全闭环。

## 13. 一句话总结

如果你只想快速开始：先运行 `flutter pub get && flutter run`，然后优先阅读 `lib/main.dart`、`lib/app_controller.dart`、`lib/ui_widgets.dart`，再结合 `openspec/changes/improve-pomodoro-functionality/` 判断番茄钟当前实现与目标契约。