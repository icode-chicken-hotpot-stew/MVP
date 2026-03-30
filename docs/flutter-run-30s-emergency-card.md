# Flutter Run 30s Emergency Card

## 10s Quick Triage

1. Run one-click diagnosis:

```powershell
pwsh ./scripts/diagnose_flutter_run.ps1
```

2. Open generated summary in `build/diagnostics/*.summary.md`.
3. Follow the `Primary Suspect` fixes first.

## Symptom -> Action

- Symptom: Stuck downloading from `repo.maven.apache.org`.
  - Action: Use mirror repos in `android/settings.gradle.kts` and enforce settings-level repository mode.

- Symptom: `Could not find io.flutter:flutter_embedding_debug`.
  - Action: Add Flutter engine repo and `https://storage.googleapis.com/download.flutter.io` in settings repositories.

- Symptom: `kotlin-gradle-plugin-2.3.0` appears unexpectedly.
  - Action: Pin `webview_flutter: 4.11.0` and `webview_flutter_android: 4.10.11`, then `flutter pub get`.

- Symptom: `requires core library desugaring to be enabled`.
  - Action: Enable desugaring in `android/app/build.gradle.kts` and add `desugar_jdk_libs` dependency.

## Golden Verify

```bash
flutter clean
flutter pub get
flutter run -v
```

Success markers:

- `Flutter run key commands.`
- `A Dart VM Service on ...`

## If still blocked

1. Re-run diagnosis and attach both files:
   - `build/diagnostics/*.log`
   - `build/diagnostics/*.summary.md`
2. Check first upstream error before `assembleDebug failed`.
3. Fix one root cause at a time, then rerun.
