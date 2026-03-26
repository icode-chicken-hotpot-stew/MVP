// 应用控制器模块 - 逻辑中枢（组员 C 维护）
library app_controller;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 默认番茄钟时长（秒）
const int kDefaultPomodoroSeconds = 1500;
const int kDefaultRestSeconds = 300;

const String _kPomodoroSnapshotKey = 'pomodoro.snapshot';

enum PomodoroState { resting, studying }
enum PomodoroPhaseStatus { ready, running, paused }

class _PomodoroSnapshot {
  const _PomodoroSnapshot({
    required this.pomodoroState,
    required this.phaseStatus,
    required this.phaseDurationSeconds,
    required this.remainingSeconds,
    required this.focusDurationSeconds,
    required this.restDurationSeconds,
    required this.cycleCount,
    required this.completedFocusCycles,
    this.startedAt,
  });

  final PomodoroState pomodoroState;
  final PomodoroPhaseStatus phaseStatus;
  final DateTime? startedAt;
  final int phaseDurationSeconds;
  final int remainingSeconds;
  final int focusDurationSeconds;
  final int restDurationSeconds;
  final int? cycleCount;
  final int completedFocusCycles;

  Map<String, Object?> toJson() => {
    'pomodoroState': pomodoroState.name,
    'phaseStatus': phaseStatus.name,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'phaseDurationSeconds': phaseDurationSeconds,
    'remainingSeconds': remainingSeconds,
    'focusDurationSeconds': focusDurationSeconds,
    'restDurationSeconds': restDurationSeconds,
    'cycleCount': cycleCount,
    'completedFocusCycles': completedFocusCycles,
  };

  static _PomodoroSnapshot? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final String? pomodoroStateName = decoded['pomodoroState'] as String?;
      final String? phaseStatusName = decoded['phaseStatus'] as String?;
      final int? phaseDurationSeconds = decoded['phaseDurationSeconds'] as int?;
      final int? remainingSeconds = decoded['remainingSeconds'] as int?;
      final int? focusDurationSeconds = decoded['focusDurationSeconds'] as int?;
      final int? restDurationSeconds = decoded['restDurationSeconds'] as int?;
      final int? completedFocusCycles = decoded['completedFocusCycles'] as int?;
      final int? cycleCount = decoded['cycleCount'] as int?;
      final String? startedAtRaw = decoded['startedAt'] as String?;

      if (pomodoroStateName == null ||
          phaseStatusName == null ||
          phaseDurationSeconds == null ||
          remainingSeconds == null ||
          focusDurationSeconds == null ||
          restDurationSeconds == null ||
          completedFocusCycles == null) {
        return null;
      }

      final PomodoroState? pomodoroState = PomodoroState.values.cast<PomodoroState?>().firstWhere(
        (PomodoroState? value) => value?.name == pomodoroStateName,
        orElse: () => null,
      );
      final PomodoroPhaseStatus? phaseStatus = PomodoroPhaseStatus.values
          .cast<PomodoroPhaseStatus?>()
          .firstWhere(
            (PomodoroPhaseStatus? value) => value?.name == phaseStatusName,
            orElse: () => null,
          );

      if (pomodoroState == null || phaseStatus == null) {
        return null;
      }

      return _PomodoroSnapshot(
        pomodoroState: pomodoroState,
        phaseStatus: phaseStatus,
        startedAt: startedAtRaw == null ? null : DateTime.tryParse(startedAtRaw)?.toLocal(),
        phaseDurationSeconds: phaseDurationSeconds,
        remainingSeconds: remainingSeconds,
        focusDurationSeconds: focusDurationSeconds,
        restDurationSeconds: restDurationSeconds,
        cycleCount: cycleCount,
        completedFocusCycles: completedFocusCycles,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// 中枢控制器：管理应用全局状态，通过 ValueNotifier 向 View 层广播
class AppController {
  AppController({
    int initialSeconds = kDefaultPomodoroSeconds,
    bool initialActive = false,
    bool initialDrawerOpen = false,
    String? initialDate,
  }) : remainingSeconds = ValueNotifier<int>(initialSeconds),
       isActive = ValueNotifier<bool>(initialActive),
       isDrawerOpen = ValueNotifier<bool>(initialDrawerOpen),
       currentDate = ValueNotifier<String>(initialDate ?? _formatCurrentDate()),
       pomodoroState = ValueNotifier<PomodoroState>(PomodoroState.resting),
       phaseStatus = ValueNotifier<PomodoroPhaseStatus>(PomodoroPhaseStatus.ready),
       focusDurationSeconds = ValueNotifier<int>(kDefaultPomodoroSeconds),
       restDurationSeconds = ValueNotifier<int>(kDefaultRestSeconds),
       cycleCount = ValueNotifier<int?>(null),
       completedFocusCycles = ValueNotifier<int>(0);

  final ValueNotifier<int> remainingSeconds;
  final ValueNotifier<bool> isActive;
  final ValueNotifier<bool> isDrawerOpen;
  final ValueNotifier<String> currentDate;
  final ValueNotifier<PomodoroState> pomodoroState;
  final ValueNotifier<PomodoroPhaseStatus> phaseStatus;
  final ValueNotifier<int> focusDurationSeconds;
  final ValueNotifier<int> restDurationSeconds;
  final ValueNotifier<int?> cycleCount;
  final ValueNotifier<int> completedFocusCycles;

  SharedPreferences? _preferences;
  Timer? _ticker;
  DateTime? _phaseStartedAt;
  int _phaseDurationSeconds = kDefaultPomodoroSeconds;
  Future<bool>? _persisting;

  /// 格式化当前日期
  static String _formatCurrentDate() {
    final now = DateTime.now();
    return '${now.year}年${now.month}月${now.day}日';
  }

  Future<void> initialize() async {
    currentDate.value = _formatCurrentDate();
    _preferences ??= await SharedPreferences.getInstance();

    final _PomodoroSnapshot? snapshot = _PomodoroSnapshot.fromJsonString(
      _preferences!.getString(_kPomodoroSnapshotKey),
    );

    if (snapshot == null) {
      await _persistSnapshot(_readySnapshot());
      return;
    }

    final int restoredFocus = _sanitizeDurationOrDefault(
      snapshot.focusDurationSeconds,
      kDefaultPomodoroSeconds,
    );
    final int restoredRest = _sanitizeDurationOrDefault(
      snapshot.restDurationSeconds,
      kDefaultRestSeconds,
    );
    final int? restoredCycles = _sanitizeCycleCount(snapshot.cycleCount);

    focusDurationSeconds.value = restoredFocus;
    restDurationSeconds.value = restoredRest;
    cycleCount.value = restoredCycles;

    final _PomodoroSnapshot recovered = _recoverSnapshot(
      snapshot: snapshot,
      now: DateTime.now(),
      focusSeconds: restoredFocus,
      restSeconds: restoredRest,
      cycles: restoredCycles,
    );

    _applySnapshot(recovered, startTickerIfRunning: true);

    if (!_sameSnapshot(recovered, snapshot)) {
      await _persistSnapshot(recovered);
    }
  }

  void toggleTimer() {
    if (phaseStatus.value == PomodoroPhaseStatus.running) {
      pauseTimer();
      return;
    }
    startTimer();
  }

  void startTimer() {
    if (phaseStatus.value == PomodoroPhaseStatus.running) {
      return;
    }

    if (phaseStatus.value == PomodoroPhaseStatus.ready) {
      pomodoroState.value = PomodoroState.studying;
      remainingSeconds.value = focusDurationSeconds.value;
      _phaseDurationSeconds = focusDurationSeconds.value;
    } else {
      _phaseDurationSeconds = _currentPhaseTotalSeconds;
    }

    phaseStatus.value = PomodoroPhaseStatus.running;
    isActive.value = true;
    _phaseStartedAt = DateTime.now().subtract(
      Duration(seconds: _phaseDurationSeconds - remainingSeconds.value),
    );
    _startTicker();
    unawaited(_persistSnapshot(_currentSnapshot()));
  }

  void pauseTimer() {
    final PomodoroPhaseStatus status = phaseStatus.value;
    if (status == PomodoroPhaseStatus.ready || status == PomodoroPhaseStatus.paused) {
      return;
    }

    _syncRemainingSeconds(DateTime.now());
    _stopTicker();
    phaseStatus.value = PomodoroPhaseStatus.paused;
    isActive.value = false;
    _phaseStartedAt = null;
    unawaited(_persistSnapshot(_currentSnapshot()));
  }

  /// 重置番茄钟至初始状态（由组员 C 填充逻辑）
  void resetTimer() {
    if (phaseStatus.value == PomodoroPhaseStatus.ready) {
      return;
    }

    _stopTicker();
    final _PomodoroSnapshot snapshot = _readySnapshot();
    _applySnapshot(snapshot, startTickerIfRunning: false);
    unawaited(_persistSnapshot(snapshot));
  }

  void updateFocusDuration(int seconds) {
    if (!_isValidDuration(seconds)) {
      return;
    }

    focusDurationSeconds.value = seconds;

    if (phaseStatus.value == PomodoroPhaseStatus.ready) {
      remainingSeconds.value = seconds;
      _phaseDurationSeconds = seconds;
    }

    unawaited(_persistSnapshot(_currentSnapshot()));
  }

  void updateRestDuration(int seconds) {
    if (!_isValidDuration(seconds)) {
      return;
    }

    restDurationSeconds.value = seconds;
    unawaited(_persistSnapshot(_currentSnapshot()));
  }

  void updateCycleCount(int? count) {
    final int? sanitized = _sanitizeCycleCount(count);
    if (count != sanitized) {
      return;
    }

    cycleCount.value = sanitized;
    unawaited(_persistSnapshot(_currentSnapshot()));
  }

  /// 从本地存储读取历史时长数据（由组员 C 填充逻辑）
  void fetchHistoryData() {
    // TODO: implement history fetch logic
  }

  int get currentPhaseDurationSeconds => _currentPhaseTotalSeconds;

  int get _currentPhaseTotalSeconds {
    if (phaseStatus.value == PomodoroPhaseStatus.ready) {
      return focusDurationSeconds.value;
    }
    if (pomodoroState.value == PomodoroState.studying) {
      return _phaseDurationSeconds > 0 ? _phaseDurationSeconds : focusDurationSeconds.value;
    }
    return _phaseDurationSeconds > 0 ? _phaseDurationSeconds : restDurationSeconds.value;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tick();
    });
    _tick();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (phaseStatus.value != PomodoroPhaseStatus.running || _phaseStartedAt == null) {
      return;
    }

    final DateTime now = DateTime.now();
    final int updatedRemaining = _remainingFromStart(
      startedAt: _phaseStartedAt!,
      phaseDurationSeconds: _phaseDurationSeconds,
      now: now,
    );

    if (updatedRemaining > 0) {
      remainingSeconds.value = updatedRemaining;
      currentDate.value = _formatCurrentDate();
      return;
    }

    _handlePhaseCompletion(now);
  }

  void _syncRemainingSeconds(DateTime now) {
    if (_phaseStartedAt == null) {
      return;
    }
    remainingSeconds.value = _remainingFromStart(
      startedAt: _phaseStartedAt!,
      phaseDurationSeconds: _phaseDurationSeconds,
      now: now,
    );
  }

  void _handlePhaseCompletion(DateTime now) {
    final _PomodoroSnapshot snapshot = _advanceSnapshotAfterElapsed(
      snapshot: _currentSnapshot(),
      elapsedSeconds: _currentPhaseTotalSeconds,
      now: now,
    );
    _applySnapshot(snapshot, startTickerIfRunning: true);
    unawaited(_persistSnapshot(snapshot));
  }

  _PomodoroSnapshot _recoverSnapshot({
    required _PomodoroSnapshot snapshot,
    required DateTime now,
    required int focusSeconds,
    required int restSeconds,
    required int? cycles,
  }) {
    final _PomodoroSnapshot normalized = _PomodoroSnapshot(
      pomodoroState: snapshot.phaseStatus == PomodoroPhaseStatus.ready
          ? PomodoroState.resting
          : snapshot.pomodoroState,
      phaseStatus: snapshot.phaseStatus,
      startedAt: snapshot.phaseStatus == PomodoroPhaseStatus.running ? snapshot.startedAt : null,
      phaseDurationSeconds: snapshot.phaseStatus == PomodoroPhaseStatus.ready
          ? focusSeconds
          : _sanitizeDurationOrDefault(
              snapshot.phaseDurationSeconds,
              snapshot.pomodoroState == PomodoroState.studying ? focusSeconds : restSeconds,
            ),
      remainingSeconds: snapshot.phaseStatus == PomodoroPhaseStatus.ready
          ? focusSeconds
          : _sanitizeDurationOrDefault(snapshot.remainingSeconds, focusSeconds),
      focusDurationSeconds: focusSeconds,
      restDurationSeconds: restSeconds,
      cycleCount: cycles,
      completedFocusCycles: snapshot.completedFocusCycles < 0 ? 0 : snapshot.completedFocusCycles,
    );

    if (normalized.phaseStatus != PomodoroPhaseStatus.running || normalized.startedAt == null) {
      return normalized.phaseStatus == PomodoroPhaseStatus.ready ? _readySnapshot() : normalized;
    }

    final int elapsedSeconds = now.difference(normalized.startedAt!).inSeconds;
    if (elapsedSeconds < normalized.phaseDurationSeconds) {
      return _PomodoroSnapshot(
        pomodoroState: normalized.pomodoroState,
        phaseStatus: PomodoroPhaseStatus.running,
        startedAt: normalized.startedAt,
        phaseDurationSeconds: normalized.phaseDurationSeconds,
        remainingSeconds: _remainingFromStart(
          startedAt: normalized.startedAt!,
          phaseDurationSeconds: normalized.phaseDurationSeconds,
          now: now,
        ),
        focusDurationSeconds: focusSeconds,
        restDurationSeconds: restSeconds,
        cycleCount: cycles,
        completedFocusCycles: normalized.completedFocusCycles,
      );
    }

    return _advanceSnapshotAfterElapsed(
      snapshot: normalized,
      elapsedSeconds: elapsedSeconds,
      now: now,
    );
  }

  _PomodoroSnapshot _advanceSnapshotAfterElapsed({
    required _PomodoroSnapshot snapshot,
    required int elapsedSeconds,
    required DateTime now,
  }) {
    PomodoroState state = snapshot.pomodoroState;
    PomodoroPhaseStatus status = snapshot.phaseStatus;
    int completedCycles = snapshot.completedFocusCycles;
    final int focusSeconds = snapshot.focusDurationSeconds;
    final int restSeconds = snapshot.restDurationSeconds;
    final int? cycles = snapshot.cycleCount;
    int remainingElapsed = elapsedSeconds;
    int phaseDuration = snapshot.phaseDurationSeconds;
    DateTime? startedAt = snapshot.startedAt;

    if (status != PomodoroPhaseStatus.running || startedAt == null) {
      return snapshot;
    }

    while (true) {
      if (remainingElapsed < phaseDuration) {
        final DateTime adjustedStart = now.subtract(Duration(seconds: remainingElapsed));
        return _PomodoroSnapshot(
          pomodoroState: state,
          phaseStatus: PomodoroPhaseStatus.running,
          startedAt: adjustedStart,
          phaseDurationSeconds: phaseDuration,
          remainingSeconds: phaseDuration - remainingElapsed,
          focusDurationSeconds: focusSeconds,
          restDurationSeconds: restSeconds,
          cycleCount: cycles,
          completedFocusCycles: completedCycles,
        );
      }

      remainingElapsed -= phaseDuration;

      if (state == PomodoroState.studying) {
        completedCycles += 1;
        state = PomodoroState.resting;
        status = PomodoroPhaseStatus.running;
        phaseDuration = restSeconds;
        startedAt = now.subtract(Duration(seconds: remainingElapsed));
        continue;
      }

      if (cycles == null || completedCycles >= cycles) {
        return _PomodoroSnapshot(
          pomodoroState: PomodoroState.resting,
          phaseStatus: PomodoroPhaseStatus.ready,
          startedAt: null,
          phaseDurationSeconds: focusSeconds,
          remainingSeconds: focusSeconds,
          focusDurationSeconds: focusSeconds,
          restDurationSeconds: restSeconds,
          cycleCount: cycles,
          completedFocusCycles: 0,
        );
      }

      state = PomodoroState.studying;
      status = PomodoroPhaseStatus.running;
      phaseDuration = focusSeconds;
      startedAt = now.subtract(Duration(seconds: remainingElapsed));
    }
  }

  void _applySnapshot(_PomodoroSnapshot snapshot, {required bool startTickerIfRunning}) {
    _stopTicker();
    pomodoroState.value = snapshot.pomodoroState;
    phaseStatus.value = snapshot.phaseStatus;
    focusDurationSeconds.value = snapshot.focusDurationSeconds;
    restDurationSeconds.value = snapshot.restDurationSeconds;
    cycleCount.value = snapshot.cycleCount;
    completedFocusCycles.value = snapshot.completedFocusCycles;
    remainingSeconds.value = snapshot.remainingSeconds;
    _phaseDurationSeconds = snapshot.phaseDurationSeconds;
    _phaseStartedAt = snapshot.startedAt;
    isActive.value = snapshot.phaseStatus == PomodoroPhaseStatus.running;
    currentDate.value = _formatCurrentDate();

    if (startTickerIfRunning && snapshot.phaseStatus == PomodoroPhaseStatus.running) {
      _startTicker();
    }
  }

  _PomodoroSnapshot _readySnapshot() {
    return _PomodoroSnapshot(
      pomodoroState: PomodoroState.resting,
      phaseStatus: PomodoroPhaseStatus.ready,
      startedAt: null,
      phaseDurationSeconds: focusDurationSeconds.value,
      remainingSeconds: focusDurationSeconds.value,
      focusDurationSeconds: focusDurationSeconds.value,
      restDurationSeconds: restDurationSeconds.value,
      cycleCount: cycleCount.value,
      completedFocusCycles: 0,
    );
  }

  _PomodoroSnapshot _currentSnapshot() {
    return _PomodoroSnapshot(
      pomodoroState: pomodoroState.value,
      phaseStatus: phaseStatus.value,
      startedAt: phaseStatus.value == PomodoroPhaseStatus.running ? _phaseStartedAt : null,
      phaseDurationSeconds: _currentPhaseTotalSeconds,
      remainingSeconds: phaseStatus.value == PomodoroPhaseStatus.running
          ? _remainingFromStart(
              startedAt: _phaseStartedAt ?? DateTime.now(),
              phaseDurationSeconds: _currentPhaseTotalSeconds,
              now: DateTime.now(),
            )
          : remainingSeconds.value,
      focusDurationSeconds: focusDurationSeconds.value,
      restDurationSeconds: restDurationSeconds.value,
      cycleCount: cycleCount.value,
      completedFocusCycles: completedFocusCycles.value,
    );
  }

  Future<void> _persistSnapshot(_PomodoroSnapshot snapshot) async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    _persisting = prefs.setString(_kPomodoroSnapshotKey, jsonEncode(snapshot.toJson()));
    await _persisting;
  }

  bool _sameSnapshot(_PomodoroSnapshot a, _PomodoroSnapshot b) {
    return a.pomodoroState == b.pomodoroState &&
        a.phaseStatus == b.phaseStatus &&
        a.phaseDurationSeconds == b.phaseDurationSeconds &&
        a.remainingSeconds == b.remainingSeconds &&
        a.focusDurationSeconds == b.focusDurationSeconds &&
        a.restDurationSeconds == b.restDurationSeconds &&
        a.cycleCount == b.cycleCount &&
        a.completedFocusCycles == b.completedFocusCycles &&
        a.startedAt?.millisecondsSinceEpoch == b.startedAt?.millisecondsSinceEpoch;
  }

  int _remainingFromStart({
    required DateTime startedAt,
    required int phaseDurationSeconds,
    required DateTime now,
  }) {
    final int elapsed = now.difference(startedAt).inSeconds;
    final int remaining = phaseDurationSeconds - elapsed;
    if (remaining <= 0) {
      return 0;
    }
    if (remaining > phaseDurationSeconds) {
      return phaseDurationSeconds;
    }
    return remaining;
  }

  bool _isValidDuration(int seconds) => seconds > 0;

  int _sanitizeDurationOrDefault(int seconds, int fallback) {
    return _isValidDuration(seconds) ? seconds : fallback;
  }

  int? _sanitizeCycleCount(int? count) {
    if (count == null) {
      return null;
    }
    if (count <= 0) {
      return null;
    }
    return count;
  }

  /// 释放所有 ValueNotifier 资源
  void dispose() {
    _stopTicker();
    remainingSeconds.dispose();
    isActive.dispose();
    isDrawerOpen.dispose();
    currentDate.dispose();
    pomodoroState.dispose();
    phaseStatus.dispose();
    focusDurationSeconds.dispose();
    restDurationSeconds.dispose();
    cycleCount.dispose();
    completedFocusCycles.dispose();
  }
}
