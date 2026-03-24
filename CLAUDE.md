# Icode Project MVP

## 项目概述
- 横屏陪伴学习类 Flutter MVP 项目。
- 默认应用入口是 `lib/main.dart`，会创建 `MainStage` 并注入 `AppController`。
- 当前仓库属于“可运行 MVP + 部分占位实现”，不要假设所有功能已经完成。

## 技术栈
- Flutter / Dart
- 状态管理：`ValueNotifier` + `ValueListenableBuilder`
- Android：Kotlin DSL（`build.gradle.kts`）
- Lint：`flutter_lints`
- 辅助工具：`uv`、`pre-commit`

## 项目结构
- `lib/main.dart`：默认入口，创建并注入 `AppController`
- `lib/app_controller.dart`：状态中枢，暴露 `ValueNotifier` 和行为接口
- `lib/ui_widgets.dart`：当前主界面和大部分交互逻辑
- `lib/character_view.dart`：角色动画层占位，当前基本未实现
- `lib/live2d.dart`：独立 Live2D/WebView 原型，不是默认入口
- `docs/dev-guide.md`：面向新成员的开发说明
- `docs/pomodoro_interface_spec.md`：番茄钟 UI 现状与假进度说明
- `docs/talking_interface_spec.md`：对话接口设想

## 开发命令
```bash
flutter pub get
flutter run
flutter run -d <device-id>

flutter analyze
flutter test
flutter build apk

flutter clean
flutter pub get
```

## 编码规范
- 保持 controller / view 单向状态流。
- View 通过 `ValueListenableBuilder` 读取状态，通过 controller 方法触发变更。
- 不要在 UI 层直接修改 controller 中的 `ValueNotifier`。
- 新业务逻辑优先放在 `lib/app_controller.dart`。
- 避免在 `build()` 中写副作用；监听器和计时器放在生命周期中管理。
- 只做当前任务需要的最小改动，避免额外抽象和顺手重构。

## 测试规范
- 有改动时优先运行：
  ```bash
  flutter analyze
  flutter test
  ```
- 当前仓库暂无已提交的 `test/` 目录；新增逻辑时可补充针对性测试。
- 除自动检查外，默认还应手动跑一次主界面流程。

## Git 工作流
```bash
git pull origin main
git checkout -b feat/your-change

# 开发并自测

git add <相关文件>
git commit -m "feat: 简述改动"
git push origin feat/your-change
```

- 提交信息建议使用：`feat`、`fix`、`docs`、`refactor`、`test`、`chore`。
- 尽量只暂存本次实际修改的文件。
- 不要依赖旧文档中的本地绝对路径，统一在仓库根目录执行命令。

## 资源与图片规范
- 当前已注册的主背景资源是 `assets/background.webp`。
- 仓库配置了 pre-commit 图片检查流程，会处理已暂存的 PNG/JPG。
- 图片 hook 可能会自动转 WebP、更新暂存区，并故意让第一次 commit 失败；检查结果后重新提交即可。
- 手动处理图片可用：
  ```bash
  uv run scripts/compress_images.py --to-webp --dry-run
  uv run scripts/compress_images.py --to-webp --delete
  uv run scripts/compress_images.py
  ```

## 注意事项
- `lib/app_controller.dart` 中的 `toggleTimer()`、`resetTimer()`、`fetchHistoryData()` 目前仍是 TODO。
- `lib/ui_widgets.dart` 里仍有占位 UI 和硬编码内容。
- 顶部进度条当前由 `_fakeTimer` / `_fakeProgress` 驱动，只是演示动画，不代表真实番茄钟进度。
- `lib/character_view.dart` 还是 stub，未正式接入角色动画。
- `lib/live2d.dart` 不是默认入口，且其依赖与资源声明目前未完全对齐，可能影响仓库级 `flutter analyze` 结果。
- Android 应用当前被锁定为横屏（`android/app/src/main/AndroidManifest.xml`）。

## 参考优先级
- 优先相信当前代码实现。
- 需要整体背景时先看 `CLAUDE.md`。
- 需要上手说明时看 `docs/dev-guide.md`。
- 需要功能现状时看 `docs/pomodoro_interface_spec.md` 和 `docs/talking_interface_spec.md`。
