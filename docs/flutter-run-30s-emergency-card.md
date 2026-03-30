# Flutter Run 30秒应急卡片

## 10秒极速排查

1. 运行一键诊断脚本：

```powershell
pwsh ./scripts/diagnose_flutter_run.ps1
```

2. 打开生成的 `build/diagnostics/*.summary.md` 摘要文件。
3. 优先按照“主嫌疑”部分的修复建议操作。

## 症状 → 快速操作

- 症状：卡在 `repo.maven.apache.org` 下载。
  - 操作：在 `android/settings.gradle.kts` 里使用镜像仓库，并强制 settings 级仓库模式。

- 症状：提示 `Could not find io.flutter:flutter_embedding_debug`。
  - 操作：在 settings 仓库配置中添加 Flutter engine 仓库和 `https://storage.googleapis.com/download.flutter.io`。

- 症状：日志出现 `kotlin-gradle-plugin-2.3.0`。
  - 操作：将 `webview_flutter` 固定为 4.11.0，`webview_flutter_android` 固定为 4.10.11，并执行 `flutter pub get`。

- 症状：提示 `requires core library desugaring to be enabled`。
  - 操作：在 `android/app/build.gradle.kts` 启用 desugaring，并添加 `desugar_jdk_libs` 依赖。

## 黄金验证

```bash
flutter clean
flutter pub get
flutter run -v
```

成功标志：

- 出现 `Flutter run key commands.`
- 出现 `A Dart VM Service on ...`

## 仍未解决？

1. 重新运行诊断，并附上以下文件：
   - `build/diagnostics/*.log`
   - `build/diagnostics/*.summary.md`
2. 检查 `assembleDebug failed` 前的第一个上游报错。
3. 每次只修一个根因，再次运行验证。
