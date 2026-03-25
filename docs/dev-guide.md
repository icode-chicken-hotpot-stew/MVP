# 开发指引 - 基于当前仓库状态

> 本文档面向 Flutter 初学者，帮助你基于当前代码库快速上手开发。内容已按仓库现状更新，旧的分工说明、本地绝对路径和过时实现已移除。

## 1. 先理解当前项目是什么

这是一个横屏陪伴学习类 Flutter MVP 项目。

当前默认入口是 `lib/main.dart`：

- `main()` 启动 `MyApp`
- `MyApp` 打开 `MainStage`
- `MainStage` 创建并注入 `AppController`
- `UIWidgets` 负责主界面展示与交互

当前代码并不是“完整功能版”，而是“可运行的 MVP + 若干占位实现”。开始改代码前，先接受这几个现状：

1. `lib/app_controller.dart` 已经定义了状态接口，但核心方法仍是空实现：
   - `toggleTimer()`
   - `resetTimer()`
   - `fetchHistoryData()`
2. `lib/ui_widgets.dart` 承担了当前大部分可见 UI 和交互。
3. 顶部进度条目前使用 UI 内部的假进度动画驱动，不等于真实番茄钟进度。
4. `lib/character_view.dart` 目前还是 stub，还没有真正接入角色动画。
5. `lib/live2d.dart` 是独立实验原型，不是默认应用入口。
6. Android 端已经被锁定为横屏。

## 2. 环境准备

### 安装 Flutter

先按 Flutter 官方文档完成安装：

- Windows: https://docs.flutter.dev/get-started/install/windows

安装后在终端执行：

```bash
flutter doctor
```

建议至少保证以下能力可用：

- Flutter SDK
- Android toolchain
- 一个可用编辑器（VS Code 或 Android Studio）
- 一台设备或模拟器

### 安装编辑器插件

推荐二选一：

- VS Code：安装 `Flutter` 和 `Dart` 插件
- Android Studio：安装 `Flutter` 插件（会自动带上 Dart）

### 可选：安装 Python 工具链

仓库里有图片处理和 pre-commit 相关脚本，建议安装：

1. 安装 `uv`
2. 安装 `pre-commit`
3. 在仓库根目录执行：

```bash
pre-commit install
```

如果你使用 `uv` 安装工具，常见方式如下：

```bash
uv tool install pre-commit
pre-commit install
```

## 3. 运行项目

所有命令都在仓库根目录执行，不要再使用旧文档里的本地绝对路径。

```bash
flutter pub get
flutter run
```

如果你已经连接了多个设备，可以指定设备：

```bash
flutter run -d <device-id>
```

常用热更新：

- 热重载：终端按 `r`
- 热重启：终端按 `R`

## 4. 当前项目结构

```text
lib/
├── main.dart            # 默认应用入口，负责注入 AppController
├── app_controller.dart  # 状态中枢，暴露 ValueNotifier 和行为接口
├── ui_widgets.dart      # 当前主界面和大部分交互逻辑
├── character_view.dart  # 角色动画层占位文件，当前基本未实现
└── live2d.dart          # 独立实验性 Live2D 原型，不是默认入口
```

此外还要知道：

- `assets/background.webp` 已在 `pubspec.yaml` 中注册
- `android/app/src/main/AndroidManifest.xml` 中当前 Activity 被设置为横屏
- `analysis_options.yaml` 目前只启用了 `flutter_lints`

## 5. 先掌握这个项目的状态流

当前项目采用轻量的 controller / view 分层。

### Controller 负责什么

`lib/app_controller.dart` 负责集中暴露状态，当前已有这些 `ValueNotifier`：

- `remainingSeconds`
- `isActive`
- `isDrawerOpen`
- `currentDate`

原则上：

- View 层只负责监听和展示
- 状态修改应通过 Controller 方法触发
- 不要在 UI 层直接把业务状态当成“单一事实来源”去改写

### UI 目前是什么状态

`lib/ui_widgets.dart` 是当前最重要的文件，因为大部分界面都在这里。

它目前包含：

- 底部 Dock 操作栏
- 角色舞台占位
- 顶部线性进度条
- 统计弹窗占位
- 若干硬编码文案和占位按钮

特别注意：

- 顶部 `LinearProgressIndicator` 当前绑定的是 `_fakeProgress`
- `_fakeProgress` 由 `_fakeTimer` 每 100ms 增长一次
- 它只是演示动画，不代表真实 25 分钟进度
- Reset 按钮现在同时重置 controller 和 UI 假进度

如果你后续要实现真实计时逻辑，应该让 `AppController` 成为单一事实来源，并协调或移除这条假进度路径。

## 6. 各核心文件应该怎么改

### `lib/main.dart`

这个文件现在主要做两件事：

1. 创建 `AppController`
2. 把它传给 `UIWidgets`

一般不建议把大量业务逻辑继续堆到这里。

### `lib/app_controller.dart`

如果你负责逻辑层，优先在这里实现：

- 开始/暂停计时
- 重置计时
- 历史数据读取
- 后续对话状态或统计状态的统一管理

当前这几个方法还是 TODO：

- `toggleTimer()`
- `resetTimer()`
- `fetchHistoryData()`

如果你当前在补番茄钟后端，先看这几份权威材料再动手：
- `openspec/changes/improve-pomodoro-functionality/proposal.md`
- `openspec/changes/improve-pomodoro-functionality/design.md`
- `openspec/changes/improve-pomodoro-functionality/specs/pomodoro-persistence-and-remaining-time/spec.md`
- `openspec/changes/improve-pomodoro-functionality/specs/pomodoro-state-transitions/spec.md`
- `openspec/changes/improve-pomodoro-functionality/specs/pomodoro-duration-and-cycle-settings/spec.md`
- `openspec/changes/improve-pomodoro-functionality/tasks.md`

如需确认当前已合入实现，再结合 `lib/main.dart`、`lib/app_controller.dart`、`lib/ui_widgets.dart` 一起看。

### `lib/ui_widgets.dart`

如果你负责界面层，优先在这里处理：

- 布局与样式
- `ValueListenableBuilder` 监听状态后的渲染
- 按钮点击后调用 controller 方法
- 假数据/占位 UI 的逐步替换

注意：

- 不要把副作用写进 `build()`
- 计时器、监听器的注册和销毁应放在生命周期里处理
- 不要直接在 UI 层偷偷改 Controller 内部状态

### `lib/character_view.dart`

这个文件现在还没有实际角色动画实现。

如果后续接入角色动画，建议方式是：

- 由 `controller.isActive` 决定角色状态
- 在 View 层根据状态切换待机 / 学习中动画

### `lib/live2d.dart`

这是实验性原型，当前需要特别注意：

- 它不是默认入口
- 它使用了 `webview_flutter` 和 `webview_flutter_android`
- 但这两个依赖目前没有在 `pubspec.yaml` 中声明
- Live2D 相关资源目前也没有注册到 `flutter.assets`

因此，如果你运行 `flutter analyze` 或尝试切到这个原型，报错不一定和你当前正在改的主界面有关。

## 7. 常用 Flutter 概念：只记本项目真正用到的

### Widget

Flutter 里界面都是 Widget 组成的。

本项目里你最常看到的是：

- `StatelessWidget`
- `StatefulWidget`
- `ValueListenableBuilder`

### `ValueNotifier` + `ValueListenableBuilder`

这是当前项目正在使用的状态管理方式。

示例模式如下：

```dart
ValueListenableBuilder<bool>(
  valueListenable: controller.isActive,
  builder: (context, isActive, _) {
    return Text(isActive ? '暂停中' : '未开始');
  },
)
```

可以这样理解：

- `ValueNotifier` 保存状态
- `ValueListenableBuilder` 监听状态变化并刷新 UI

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

当前仓库还没有成熟的测试目录，测试命令更像是后续补充测试时的基础入口。

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
- `docs/talking_interface_spec.md`：对话相关接口设想

如果某份旧文档和代码冲突，请以当前代码实现为准。

## 12. 新同学最容易踩的坑

1. 以为番茄钟已经有完整逻辑：其实 `AppController` 里的核心行为还是 TODO。
2. 以为顶部进度条是真实倒计时：其实现在还是 UI 假动画。
3. 以为 `character_view.dart` 已经能接角色动画：其实还没有正式实现。
4. 以为 `live2d.dart` 是主入口：其实默认入口仍然是 `lib/main.dart`。
5. 以为文档里的旧绝对路径还能直接用：现在统一以仓库根目录为准。

## 13. 一句话总结

如果你只想快速开始：先运行 `flutter pub get && flutter run`，然后优先阅读 `lib/main.dart`、`lib/app_controller.dart`、`lib/ui_widgets.dart` 这三个文件。
