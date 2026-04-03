import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mvp_app/services/audio_service.dart';
import 'package:mvp_app/services/supervisor_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kDefaultPomodoroSeconds = 1500;
const int kDefaultRestSeconds = 300;
const int kDailyXpCap = 2000;

const String _kPomodoroSnapshotKey = 'pomodoro.snapshot';
const String _kXpTotalKey = 'xp.total';
const String _kXpDailyKey = 'xp.daily';
const String _kXpLastDateKey = 'xp.lastDate';
const String _kXpLevelKey = 'xp.level';
const String _kMusicAutoPlayEnabledKey = 'music.autoPlayEnabled';
const String _kMusicIsPlayingKey = 'music.isPlaying';
const String _kMusicTrackIndexKey = 'music.trackIndex';
const String _kMusicVolumeKey = 'music.volume';
const String _kSupervisorSessionIdKey = 'supervisor.sessionId';
const String _kSupervisorLastBackgroundAtKey = 'supervisor.lastBackgroundAt';
const String _kSupervisorStage3mSentKey = 'supervisor.stage3mSent';
const String _kSupervisorStage6mSentKey = 'supervisor.stage6mSent';

const List<int> _kLevelThresholds = <int>[
  0,
  50,
  600,
  2000,
  4500,
  8000,
  13000,
  19500,
  27000,
  36000,
];

enum PomodoroState { resting, studying }
enum PomodoroPhaseStatus { ready, running, paused }

enum _PhaseSfxType { start, encouragement }

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

class _PhaseAdvanceResult {
  const _PhaseAdvanceResult({
    required this.snapshot,
    this.focusCompletionTimes = const <DateTime>[],
    this.sfxEvents = const <_PhaseSfxType>[],
    this.exitedStudyingRunning = false,
  });

  final _PomodoroSnapshot snapshot;
  final List<DateTime> focusCompletionTimes;
  final List<_PhaseSfxType> sfxEvents;
  final bool exitedStudyingRunning;
}

/// AppController 是整个应用的状态中枢。
///
/// 负责：
/// - 番茄钟运行状态（专注/休息、运行/暂停/就绪），
/// - 时间同步与倒计时逻辑，
/// - 专注时长与休息时长配置、循环次数，
/// - XP 统计与升级逻辑，
/// - 背景音乐与通知服务状态持久化，
/// - 以及与 SharedPreferences 的持久化读写。
class AppController {
  AppController({
    int initialSeconds = kDefaultPomodoroSeconds,
    bool initialActive = false,
    bool initialDrawerOpen = false,
    String? initialDate,
    SupervisorNotificationService? supervisorNotificationService,
    AudioService? audioService,
    DateTime Function()? now,
  }) : remainingSeconds = ValueNotifier<int>(initialSeconds),
       isActive = ValueNotifier<bool>(initialActive),
       isDrawerOpen = ValueNotifier<bool>(initialDrawerOpen),
       currentDate = ValueNotifier<String>(initialDate ?? _formatCurrentDate()),
       pomodoroState = ValueNotifier<PomodoroState>(PomodoroState.resting),
       phaseStatus = ValueNotifier<PomodoroPhaseStatus>(PomodoroPhaseStatus.ready),
       focusDurationSeconds = ValueNotifier<int>(kDefaultPomodoroSeconds),
       restDurationSeconds = ValueNotifier<int>(kDefaultRestSeconds),
       cycleCount = ValueNotifier<int?>(null),
       completedFocusCycles = ValueNotifier<int>(0),
       totalXp = ValueNotifier<int>(0),
       dailyXp = ValueNotifier<int>(0),
       level = ValueNotifier<int>(1),
       justLeveledUp = ValueNotifier<bool>(false),
       isMusicPlaying = ValueNotifier<bool>(true),
       musicAutoPlayEnabled = ValueNotifier<bool>(true),
       currentTrackIndex = ValueNotifier<int>(0),
       musicVolume = ValueNotifier<double>(1.0),
       _supervisorNotificationService =
           supervisorNotificationService ?? LocalSupervisorNotificationService(),
       _audioService = audioService ?? JustAudioService(),
       _now = now ?? DateTime.now;

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
  final ValueNotifier<int> totalXp;
  final ValueNotifier<int> dailyXp;
  final ValueNotifier<int> level;
  final ValueNotifier<bool> justLeveledUp;
  final ValueNotifier<bool> isMusicPlaying;
  final ValueNotifier<bool> musicAutoPlayEnabled;
  final ValueNotifier<int> currentTrackIndex;
  final ValueNotifier<double> musicVolume;

  final SupervisorNotificationService _supervisorNotificationService;
  final AudioService _audioService;
  final DateTime Function() _now;

  SharedPreferences? _preferences;
  Timer? _ticker;
  DateTime? _phaseStartedAt;
  int _phaseDurationSeconds = kDefaultPomodoroSeconds;
  String? _activeSupervisorSessionId;
  DateTime? _lastBackgroundAt;
  bool _stage3mSent = false;
  bool _stage6mSent = false;
  bool _musicPausedForLifecycle = false;

  static String _formatCurrentDate() {
    final DateTime now = DateTime.now();
    return '${now.year}年${now.month}月${now.day}日';
  }

  static String _dateKey(DateTime date) {
    final DateTime local = date.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Future<void> initialize() async {
    currentDate.value = _formatCurrentDate();
    _preferences ??= await SharedPreferences.getInstance();

    await _restoreXpState();
    await _restoreMusicState();
    await _restoreSupervisorState();

    try {
      await _supervisorNotificationService.initialize();
      final bool permissionGranted = await _supervisorNotificationService
          .requestPermissionIfNeeded();
      debugPrint(
        '[AppController] Supervisor notification permission ready=$permissionGranted',
      );
    } catch (error, stackTrace) {
      debugPrint('[AppController] Failed to initialize notifications: $error\n$stackTrace');
    }

    try {
      await _audioService.initialize(
        trackIndex: currentTrackIndex.value,
        volume: musicVolume.value,
      );
    } catch (error, stackTrace) {
      debugPrint('[AppController] Failed to initialize audio: $error\n$stackTrace');
    }

    final _PomodoroSnapshot? snapshot = _PomodoroSnapshot.fromJsonString(
      _preferences!.getString(_kPomodoroSnapshotKey),
    );

    if (snapshot == null) {
      await _persistSnapshot(_readySnapshot());
    } else {
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

      final _PhaseAdvanceResult recovered = _recoverSnapshot(
        snapshot: snapshot,
        now: _now(),
        focusSeconds: restoredFocus,
        restSeconds: restoredRest,
        cycles: restoredCycles,
      );

      _applySnapshot(recovered.snapshot, startTickerIfRunning: true);
      await _applyPhaseAdvanceSideEffects(recovered, replayAudio: false);

      if (!_sameSnapshot(recovered.snapshot, snapshot)) {
        await _persistSnapshot(recovered.snapshot);
      }
    }

    await _cancelSupervisorSession(clearState: true);

    if (musicAutoPlayEnabled.value && isMusicPlaying.value) {
      await _playBgmForCurrentState();
    }
  }

  Future<void> synchronizeWithCurrentTime() async {
    final _PomodoroSnapshot? snapshot = _syncRunningState(_now());
    if (snapshot != null) {
      await _persistSnapshot(snapshot);
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

    final bool wasReady = phaseStatus.value == PomodoroPhaseStatus.ready;
    if (wasReady) {
      pomodoroState.value = PomodoroState.studying;
      remainingSeconds.value = focusDurationSeconds.value;
      _phaseDurationSeconds = focusDurationSeconds.value;
    } else {
      _phaseDurationSeconds = _currentPhaseTotalSeconds;
    }

    phaseStatus.value = PomodoroPhaseStatus.running;
    isActive.value = true;
    _phaseStartedAt = _now().subtract(
      Duration(seconds: _phaseDurationSeconds - remainingSeconds.value),
    );
    _startTicker();
    unawaited(_persistSnapshot(_currentSnapshot()));

    if (wasReady) {
      unawaited(_audioService.playStartSfx());
    }
  }

  void pauseTimer() {
    final PomodoroPhaseStatus status = phaseStatus.value;
    if (status == PomodoroPhaseStatus.ready || status == PomodoroPhaseStatus.paused) {
      return;
    }

    _syncRemainingSeconds(_now());
    _stopTicker();
    phaseStatus.value = PomodoroPhaseStatus.paused;
    isActive.value = false;
    _phaseStartedAt = null;
    unawaited(_persistSnapshot(_currentSnapshot()));
    unawaited(_cancelSupervisorSession(clearState: true));
  }

  void resetTimer() {
    if (phaseStatus.value == PomodoroPhaseStatus.ready) {
      return;
    }

    _stopTicker();
    final _PomodoroSnapshot snapshot = _readySnapshot();
    _applySnapshot(snapshot, startTickerIfRunning: false);
    unawaited(_persistSnapshot(snapshot));
    unawaited(_cancelSupervisorSession(clearState: true));
  }

  void restoreDefaultDurations() {
    updateFocusDuration(kDefaultPomodoroSeconds);
    updateRestDuration(kDefaultRestSeconds);
  }

  void updateFocusDuration(int seconds) {
    if (!_isValidDuration(seconds)) {
      return;
    }
    if (focusDurationSeconds.value == seconds) {
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
    if (restDurationSeconds.value == seconds) {
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
    if (cycleCount.value == sanitized) {
      return;
    }

    cycleCount.value = sanitized;
    unawaited(_persistSnapshot(_currentSnapshot()));
  }

  void fetchHistoryData() {
    // 历史统计契约不在当前批次范围内，这里保留给 UI 的兼容入口。
  }

  Future<void> handleLifecycleStateChanged(AppLifecycleState state) async {
    debugPrint(
      '[AppController] Lifecycle changed: state=$state phaseStatus=${phaseStatus.value} pomodoroState=${pomodoroState.value} activeSession=$_activeSupervisorSessionId',
    );

    if (state == AppLifecycleState.resumed) {
      await _cancelSupervisorSession(clearState: true);
      if (_musicPausedForLifecycle && musicAutoPlayEnabled.value && isMusicPlaying.value) {
        final bool resumed = await _audioService.resumeBgm(volume: musicVolume.value);
        if (!resumed) {
          debugPrint('[AppController] Failed to resume lifecycle-paused BGM.');
          isMusicPlaying.value = false;
          await _persistMusicState();
        }
      }
      _musicPausedForLifecycle = false;
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (!_musicPausedForLifecycle && musicAutoPlayEnabled.value && isMusicPlaying.value) {
        await _audioService.pauseBgm();
        _musicPausedForLifecycle = true;
      }
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (phaseStatus.value != PomodoroPhaseStatus.running ||
          pomodoroState.value != PomodoroState.studying) {
        debugPrint(
          '[AppController] Skip supervisor scheduling: timer not in studying/running state.',
        );
        return;
      }
      if (_activeSupervisorSessionId != null) {
        debugPrint(
          '[AppController] Skip supervisor scheduling: session already active ($_activeSupervisorSessionId).',
        );
        return;
      }

      final DateTime backgroundedAt = _now();
      final String sessionId = backgroundedAt.microsecondsSinceEpoch.toString();
      debugPrint(
        '[AppController] Attempt supervisor scheduling session=$sessionId at ${backgroundedAt.toIso8601String()}',
      );
      final bool scheduled = await _supervisorNotificationService.scheduleSupervisorSession(
        backgroundedAt: backgroundedAt,
        sessionId: sessionId,
      );
      if (!scheduled) {
        debugPrint('[AppController] Supervisor reminders skipped.');
        return;
      }

      _activeSupervisorSessionId = sessionId;
      _lastBackgroundAt = backgroundedAt;
      _stage3mSent = false;
      _stage6mSent = false;
      await _persistSupervisorState();
      debugPrint(
        '[AppController] Supervisor session persisted: session=$sessionId',
      );
    }
  }

  Future<int> grantFocusXp({
    required int effectiveFocusSeconds,
    DateTime? occurredAt,
  }) async {
    final DateTime accountingDate = occurredAt ?? _now();
    await _resetDailyXpIfNeeded(accountingDate);

    final int focusMinutes = effectiveFocusSeconds ~/ 60;
    final int rawGain = focusMinutes < 5 ? 0 : focusMinutes * 10;
    final int availableCap = max(0, kDailyXpCap - dailyXp.value);
    final int grantedXp = min(rawGain, availableCap);

    if (grantedXp == 0) {
      justLeveledUp.value = false;
      await _persistXpState(accountingDate: accountingDate);
      return 0;
    }

    final int previousLevel = level.value;
    totalXp.value += grantedXp;
    dailyXp.value += grantedXp;
    level.value = _levelForXp(totalXp.value);
    justLeveledUp.value = level.value > previousLevel;
    await _persistXpState(accountingDate: accountingDate);
    return grantedXp;
  }

  bool canUnlockDialogue(int requiredLevel) => level.value >= requiredLevel;

  String dialogueLockReason(int requiredLevel) {
    if (canUnlockDialogue(requiredLevel)) {
      return 'Lv.$requiredLevel 对话已解锁';
    }
    return '达到 Lv.$requiredLevel 后解锁';
  }

  int get xpToNextLevel {
    final int current = level.value;
    if (current >= _kLevelThresholds.length) {
      return 0;
    }
    return max(0, _kLevelThresholds[current] - totalXp.value);
  }

  int get minutesToNextLevel {
    if (xpToNextLevel == 0) {
      return 0;
    }
    return (xpToNextLevel / 10).ceil();
  }

  Future<void> playOrPauseMusic() async {
    if (isMusicPlaying.value) {
      isMusicPlaying.value = false;
      musicAutoPlayEnabled.value = false;
      await _audioService.pauseBgm();
      await _persistMusicState();
      return;
    }

    musicAutoPlayEnabled.value = true;
    final bool started = await _playBgmForCurrentState();
    isMusicPlaying.value = started;
    await _persistMusicState();
  }

  Future<void> playNextTrack() async {
    final int trackCount = max(1, _audioService.trackCount);
    currentTrackIndex.value = (currentTrackIndex.value + 1) % trackCount;
    await _persistMusicState();
    if (isMusicPlaying.value || musicAutoPlayEnabled.value) {
      final bool started = await _playBgmForCurrentState();
      isMusicPlaying.value = started;
      await _persistMusicState();
    }
  }

  Future<void> playPreviousTrack() async {
    final int trackCount = max(1, _audioService.trackCount);
    currentTrackIndex.value =
        (currentTrackIndex.value - 1 + trackCount) % trackCount;
    await _persistMusicState();
    if (isMusicPlaying.value || musicAutoPlayEnabled.value) {
      final bool started = await _playBgmForCurrentState();
      isMusicPlaying.value = started;
      await _persistMusicState();
    }
  }

  Future<void> toggleMuteMusic() async {
    final double nextVolume = musicVolume.value <= 0 ? 1.0 : 0.0;
    await setMusicVolume(nextVolume);
  }

  Future<void> setMusicVolume(double volume) async {
    final double sanitized = volume.clamp(0.0, 1.0);
    musicVolume.value = sanitized;
    await _persistMusicState();
    if (isMusicPlaying.value || musicAutoPlayEnabled.value) {
      final bool started = await _playBgmForCurrentState();
      if (isMusicPlaying.value) {
        isMusicPlaying.value = started;
        await _persistMusicState();
      }
    }
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
    final _PomodoroSnapshot? snapshot = _syncRunningState(_now());
    if (snapshot != null) {
      unawaited(_persistSnapshot(snapshot));
    }
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

  _PomodoroSnapshot? _syncRunningState(DateTime now) {
    currentDate.value = _formatCurrentDate();

    if (phaseStatus.value != PomodoroPhaseStatus.running || _phaseStartedAt == null) {
      return null;
    }

    final int elapsedSeconds = now.difference(_phaseStartedAt!).inSeconds;
    if (elapsedSeconds < _phaseDurationSeconds) {
      final int updatedRemaining = _remainingFromStart(
        startedAt: _phaseStartedAt!,
        phaseDurationSeconds: _phaseDurationSeconds,
        now: now,
      );
      if (remainingSeconds.value != updatedRemaining) {
        remainingSeconds.value = updatedRemaining;
      }
      return null;
    }

    final _PhaseAdvanceResult result = _advanceSnapshotAfterElapsed(
      snapshot: _snapshotForTransition(),
      elapsedSeconds: elapsedSeconds,
      now: now,
    );
    _applySnapshot(result.snapshot, startTickerIfRunning: true);
    unawaited(_applyPhaseAdvanceSideEffects(result, replayAudio: true));
    return result.snapshot;
  }

  _PomodoroSnapshot _snapshotForTransition() {
    return _PomodoroSnapshot(
      pomodoroState: pomodoroState.value,
      phaseStatus: phaseStatus.value,
      startedAt: _phaseStartedAt,
      phaseDurationSeconds: _currentPhaseTotalSeconds,
      remainingSeconds: remainingSeconds.value,
      focusDurationSeconds: focusDurationSeconds.value,
      restDurationSeconds: restDurationSeconds.value,
      cycleCount: cycleCount.value,
      completedFocusCycles: completedFocusCycles.value,
    );
  }

  _PhaseAdvanceResult _recoverSnapshot({
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
          : _sanitizeRemainingSeconds(
              seconds: snapshot.remainingSeconds,
              phaseDurationSeconds: snapshot.phaseStatus == PomodoroPhaseStatus.ready
                  ? focusSeconds
                  : _sanitizeDurationOrDefault(
                      snapshot.phaseDurationSeconds,
                      snapshot.pomodoroState == PomodoroState.studying
                          ? focusSeconds
                          : restSeconds,
                    ),
              fallback: snapshot.pomodoroState == PomodoroState.studying ? focusSeconds : restSeconds,
            ),
      focusDurationSeconds: focusSeconds,
      restDurationSeconds: restSeconds,
      cycleCount: cycles,
      completedFocusCycles: snapshot.completedFocusCycles < 0 ? 0 : snapshot.completedFocusCycles,
    );

    if (normalized.phaseStatus != PomodoroPhaseStatus.running || normalized.startedAt == null) {
      return _PhaseAdvanceResult(
        snapshot: normalized.phaseStatus == PomodoroPhaseStatus.ready
            ? _readySnapshot()
            : normalized,
      );
    }

    final int elapsedSeconds = now.difference(normalized.startedAt!).inSeconds;
    if (elapsedSeconds < normalized.phaseDurationSeconds) {
      return _PhaseAdvanceResult(
        snapshot: _PomodoroSnapshot(
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
        ),
      );
    }

    return _advanceSnapshotAfterElapsed(
      snapshot: normalized,
      elapsedSeconds: elapsedSeconds,
      now: now,
    );
  }

  _PhaseAdvanceResult _advanceSnapshotAfterElapsed({
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
    final List<DateTime> focusCompletionTimes = <DateTime>[];
    final List<_PhaseSfxType> sfxEvents = <_PhaseSfxType>[];
    bool exitedStudyingRunning = false;

    if (status != PomodoroPhaseStatus.running || startedAt == null) {
      return _PhaseAdvanceResult(snapshot: snapshot);
    }

    while (true) {
      if (remainingElapsed < phaseDuration) {
        final DateTime adjustedStart = now.subtract(Duration(seconds: remainingElapsed));
        return _PhaseAdvanceResult(
          snapshot: _PomodoroSnapshot(
            pomodoroState: state,
            phaseStatus: PomodoroPhaseStatus.running,
            startedAt: adjustedStart,
            phaseDurationSeconds: phaseDuration,
            remainingSeconds: phaseDuration - remainingElapsed,
            focusDurationSeconds: focusSeconds,
            restDurationSeconds: restSeconds,
            cycleCount: cycles,
            completedFocusCycles: completedCycles,
          ),
          focusCompletionTimes: focusCompletionTimes,
          sfxEvents: sfxEvents,
          exitedStudyingRunning: exitedStudyingRunning,
        );
      }

      remainingElapsed -= phaseDuration;
      final DateTime completedAt = startedAt!.add(Duration(seconds: phaseDuration));

      if (state == PomodoroState.studying) {
        completedCycles += 1;
        focusCompletionTimes.add(completedAt);
        sfxEvents.add(_PhaseSfxType.encouragement);
        exitedStudyingRunning = true;
        state = PomodoroState.resting;
        status = PomodoroPhaseStatus.running;
        phaseDuration = restSeconds;
        startedAt = completedAt;
        continue;
      }

      if (cycles == null || completedCycles >= cycles) {
        return _PhaseAdvanceResult(
          snapshot: _PomodoroSnapshot(
            pomodoroState: PomodoroState.resting,
            phaseStatus: PomodoroPhaseStatus.ready,
            startedAt: null,
            phaseDurationSeconds: focusSeconds,
            remainingSeconds: focusSeconds,
            focusDurationSeconds: focusSeconds,
            restDurationSeconds: restSeconds,
            cycleCount: cycles,
            completedFocusCycles: 0,
          ),
          focusCompletionTimes: focusCompletionTimes,
          sfxEvents: sfxEvents,
          exitedStudyingRunning: true,
        );
      }

      sfxEvents.add(_PhaseSfxType.start);
      state = PomodoroState.studying;
      status = PomodoroPhaseStatus.running;
      phaseDuration = focusSeconds;
      startedAt = completedAt;
    }
  }

  Future<void> _applyPhaseAdvanceSideEffects(
    _PhaseAdvanceResult result, {
    required bool replayAudio,
  }) async {
    for (final DateTime completionTime in result.focusCompletionTimes) {
      await grantFocusXp(
        effectiveFocusSeconds: focusDurationSeconds.value,
        occurredAt: completionTime,
      );
    }

    if (result.exitedStudyingRunning) {
      await _cancelSupervisorSession(clearState: true);
    }

    if (!replayAudio) {
      return;
    }

    for (final _PhaseSfxType event in result.sfxEvents) {
      if (event == _PhaseSfxType.start) {
        await _audioService.playStartSfx();
      } else {
        await _audioService.playEncouragementSfx();
      }
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
              startedAt: _phaseStartedAt ?? _now(),
              phaseDurationSeconds: _currentPhaseTotalSeconds,
              now: _now(),
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
    await prefs.setString(_kPomodoroSnapshotKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> _restoreXpState() async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    totalXp.value = max(0, prefs.getInt(_kXpTotalKey) ?? 0);
    dailyXp.value = max(0, prefs.getInt(_kXpDailyKey) ?? 0);
    level.value = _levelForXp(totalXp.value);
    final int savedLevel = prefs.getInt(_kXpLevelKey) ?? level.value;
    if (savedLevel > level.value) {
      level.value = savedLevel;
    }
    await _resetDailyXpIfNeeded(_now(), persistIfChanged: false);
  }

  Future<void> _persistXpState({required DateTime accountingDate}) async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setInt(_kXpTotalKey, totalXp.value);
    await prefs.setInt(_kXpDailyKey, dailyXp.value);
    await prefs.setString(_kXpLastDateKey, _dateKey(accountingDate));
    await prefs.setInt(_kXpLevelKey, level.value);
  }

  Future<void> _resetDailyXpIfNeeded(
    DateTime now, {
    bool persistIfChanged = true,
  }) async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    final String today = _dateKey(now);
    final String? lastDate = prefs.getString(_kXpLastDateKey);
    if (lastDate == null) {
      if (persistIfChanged) {
        await prefs.setString(_kXpLastDateKey, today);
      }
      return;
    }
    if (lastDate == today) {
      return;
    }
    dailyXp.value = 0;
    if (persistIfChanged) {
      await _persistXpState(accountingDate: now);
    }
  }

  Future<void> _restoreMusicState() async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    musicAutoPlayEnabled.value = prefs.getBool(_kMusicAutoPlayEnabledKey) ?? true;
    isMusicPlaying.value = prefs.getBool(_kMusicIsPlayingKey) ?? true;
    currentTrackIndex.value = max(0, prefs.getInt(_kMusicTrackIndexKey) ?? 0);
    final double savedVolume = prefs.getDouble(_kMusicVolumeKey) ?? 1.0;
    musicVolume.value = savedVolume.clamp(0.0, 1.0);
  }

  Future<void> _persistMusicState() async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicAutoPlayEnabledKey, musicAutoPlayEnabled.value);
    await prefs.setBool(_kMusicIsPlayingKey, isMusicPlaying.value);
    await prefs.setInt(_kMusicTrackIndexKey, currentTrackIndex.value);
    await prefs.setDouble(_kMusicVolumeKey, musicVolume.value);
  }

  Future<bool> _playBgmForCurrentState() async {
    final bool started = await _audioService.playBgm(
      currentTrackIndex.value,
      volume: musicVolume.value,
    );
    if (!started) {
      debugPrint('[AppController] Audio playback degraded silently.');
    }
    return started;
  }

  Future<void> _restoreSupervisorState() async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    _activeSupervisorSessionId = prefs.getString(_kSupervisorSessionIdKey);
    final String? rawBackgroundAt = prefs.getString(_kSupervisorLastBackgroundAtKey);
    _lastBackgroundAt = rawBackgroundAt == null ? null : DateTime.tryParse(rawBackgroundAt)?.toLocal();
    _stage3mSent = prefs.getBool(_kSupervisorStage3mSentKey) ?? false;
    _stage6mSent = prefs.getBool(_kSupervisorStage6mSentKey) ?? false;
  }

  Future<void> _persistSupervisorState() async {
    final SharedPreferences prefs = _preferences ??= await SharedPreferences.getInstance();
    if (_activeSupervisorSessionId == null) {
      await prefs.remove(_kSupervisorSessionIdKey);
      await prefs.remove(_kSupervisorLastBackgroundAtKey);
      await prefs.setBool(_kSupervisorStage3mSentKey, false);
      await prefs.setBool(_kSupervisorStage6mSentKey, false);
      return;
    }

    await prefs.setString(_kSupervisorSessionIdKey, _activeSupervisorSessionId!);
    if (_lastBackgroundAt != null) {
      await prefs.setString(
        _kSupervisorLastBackgroundAtKey,
        _lastBackgroundAt!.toUtc().toIso8601String(),
      );
    }
    await prefs.setBool(_kSupervisorStage3mSentKey, _stage3mSent);
    await prefs.setBool(_kSupervisorStage6mSentKey, _stage6mSent);
  }

  Future<void> _cancelSupervisorSession({required bool clearState}) async {
    debugPrint(
      '[AppController] Cancel supervisor session: clearState=$clearState activeSession=$_activeSupervisorSessionId',
    );
    await _supervisorNotificationService.cancelSupervisorSession();
    if (!clearState) {
      return;
    }
    _activeSupervisorSessionId = null;
    _lastBackgroundAt = null;
    _stage3mSent = false;
    _stage6mSent = false;
    await _persistSupervisorState();
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

  int _sanitizeRemainingSeconds({
    required int seconds,
    required int phaseDurationSeconds,
    required int fallback,
  }) {
    if (!_isValidDuration(seconds)) {
      return fallback;
    }
    if (seconds > phaseDurationSeconds) {
      return phaseDurationSeconds;
    }
    return seconds;
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

  int _levelForXp(int xp) {
    int resolvedLevel = 1;
    for (int index = 0; index < _kLevelThresholds.length; index += 1) {
      if (xp >= _kLevelThresholds[index]) {
        resolvedLevel = index + 1;
      }
    }
    return resolvedLevel;
  }

  void dispose() {
    _stopTicker();
    unawaited(_audioService.stopBgm());
    unawaited(_cancelSupervisorSession(clearState: false));
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
    totalXp.dispose();
    dailyXp.dispose();
    level.dispose();
    justLeveledUp.dispose();
    isMusicPlaying.dispose();
    musicAutoPlayEnabled.dispose();
    currentTrackIndex.dispose();
    musicVolume.dispose();
  }
}
