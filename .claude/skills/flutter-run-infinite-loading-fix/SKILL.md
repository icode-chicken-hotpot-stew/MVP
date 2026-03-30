---
name: flutter-run-infinite-loading-fix
description: Diagnose and fix Flutter Android startup hangs during flutter run -v, especially long dependency downloads, Gradle repository issues, plugin version drift, and Android build config mismatches.
license: MIT
compatibility: Flutter Android projects using Gradle.
metadata:
  author: repo-local
  version: "1.0"
  generatedBy: "manual"
---

Solve Flutter startup infinite loading or pseudo-hang issues in a deterministic way.

This skill targets cases where flutter run -v appears stuck for a long time in dependency download or Gradle tasks, and eventually fails or times out.

---

## Use When

- flutter run -v stays for a long time on Downloading lines.
- Gradle fails after long waits on dependency resolution.
- You see recurring issues across branches with similar symptoms.

Typical log hints:
- Downloading https://repo.maven.apache.org/...
- Could not find io.flutter:flutter_embedding_debug
- kotlin-gradle-plugin/2.3.0 download or resolution problems
- requires core library desugaring to be enabled for :app
- checkDebugAarMetadata failed

---

## Primary Goal

Get from unknown hang to reproducible root cause, apply minimal fixes, and verify that app reaches runtime (Flutter run key commands / VM service available).

---

## Fast Workflow

1. Capture full verbose log to file

Windows PowerShell:

flutter run -v > run.log 2>&1

2. Extract first real failure point

Use one search for all common blockers:

Select-String -Path run.log -Pattern "FAILURE: Build failed|Error: Gradle task assembleDebug failed|checkDebugAarMetadata|Could not find io.flutter|kotlin-gradle-plugin|desugaring|repo.maven.apache.org"

3. Classify and fix by pattern (table below)

4. Re-run and verify success signals

- Flutter run key commands
- A Dart VM Service on ... is available
- No new terminal build failure

5. If using background run, stop process after verification

---

## Pattern -> Fix Map

### A) Stuck on repo.maven.apache.org downloads

Symptom:
- Long Downloading https://repo.maven.apache.org/... lines

Root cause:
- Buildscript repositories in plugins still hit Maven Central directly.

Fix:
- In android/settings.gradle.kts:
  - Use mirror repositories in pluginManagement.repositories.
  - Add dependencyResolutionManagement with RepositoriesMode.PREFER_SETTINGS.
  - Add Flutter repos:
    - flutterSdkPath/bin/cache/artifacts/engine
    - https://storage.googleapis.com/download.flutter.io
  - Add gradle.beforeProject hook to inject mirrored buildscript.repositories for all subprojects.

Recommended mirrors used in this repo:
- https://maven.aliyun.com/repository/google
- https://maven.aliyun.com/repository/central
- https://maven.aliyun.com/repository/public

Optional consistency:
- Keep android/build.gradle.kts allprojects.repositories aligned with same mirrors.

### B) Could not find io.flutter:flutter_embedding_debug or io.flutter:x86_64_debug

Symptom:
- checkDebugAarMetadata failure with missing io.flutter artifacts

Root cause:
- Missing Flutter engine repository path and/or Flutter hosted repository.

Fix:
- Ensure dependencyResolutionManagement.repositories includes:
  - local Flutter engine repo from flutter.sdk path
  - https://storage.googleapis.com/download.flutter.io

### C) kotlin-gradle-plugin 2.3.0 pulled by webview plugin

Symptom:
- Log shows kotlin-gradle-plugin/2.3.0 downloads or failures

Root cause:
- webview_flutter_android newer version includes Kotlin 2.3.0 in plugin buildscript.

Fix:
- Pin dependency versions in pubspec.yaml (no caret):
  - webview_flutter: 4.11.0
  - webview_flutter_android: 4.10.11
- Run flutter pub get and re-verify lock file.

### D) :app requires core library desugaring

Symptom:
- Dependency ':flutter_local_notifications' requires core library desugaring to be enabled for :app

Fix in android/app/build.gradle.kts:
- compileOptions: isCoreLibraryDesugaringEnabled = true
- dependencies: coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

### E) Kotlin incremental cache close errors with different roots

Symptom:
- Could not close incremental caches ... different roots ... pub cache path vs project path

Interpretation:
- Often noisy/transient during Kotlin incremental compile in mixed source roots.

Action:
- First check if app still reaches runtime markers.
- If build truly fails, then run:
  - flutter clean
  - Remove project build directory
  - Re-run flutter pub get and flutter run -v
- Do not patch third-party pub cache plugin source unless absolutely necessary.

---

## Repo-Specific Stable Baseline

When this repo regresses on startup hangs, verify these files first:

- android/settings.gradle.kts
  - mirrors configured
  - dependencyResolutionManagement present
  - Flutter engine + storage repo present
  - gradle.beforeProject buildscript repo injection present

- android/app/build.gradle.kts
  - core library desugaring enabled
  - desugar_jdk_libs dependency present

- pubspec.yaml
  - webview_flutter and webview_flutter_android pinned to stable versions

---

## Validation Checklist

After fixes, run:

flutter pub get
flutter run -v

Success criteria:
- No blocking downloads from repo.maven.apache.org
- No checkDebugAarMetadata failure
- Flutter run key commands appears
- Dart VM Service URL appears

---

## Guardrails

- Prefer minimal, targeted edits.
- Never edit files under pub cache unless no alternative exists.
- Do not use destructive git commands.
- Keep repository strategy centralized in settings when possible.
- Always report exact root cause and exact files changed.

---

## Output Template (for future runs)

1) Root cause identified:
- <single primary blocker>

2) Changes applied:
- <file path + key change>

3) Verification:
- <what command was run>
- <what success marker was observed>

4) Residual warnings (non-blocking):
- <if any>
