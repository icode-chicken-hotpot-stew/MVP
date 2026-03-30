import 'package:mvp_app/services/audio_service.dart';
import 'package:mvp_app/services/supervisor_notification_service.dart';

class FakeSupervisorNotificationService
    implements SupervisorNotificationService {
  int initializeCalls = 0;
  int permissionRequestCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  bool permissionGranted = true;
  bool scheduleResult = true;
  DateTime? lastBackgroundedAt;
  String? lastSessionId;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<bool> requestPermissionIfNeeded() async {
    permissionRequestCalls += 1;
    return permissionGranted;
  }

  @override
  Future<bool> scheduleSupervisorSession({
    required DateTime backgroundedAt,
    required String sessionId,
  }) async {
    scheduleCalls += 1;
    lastBackgroundedAt = backgroundedAt;
    lastSessionId = sessionId;
    return scheduleResult;
  }

  @override
  Future<void> cancelSupervisorSession() async {
    cancelCalls += 1;
  }
}

class FakeAudioService implements AudioService {
  @override
  int get trackCount => 2;

  int initializeCalls = 0;
  int playBgmCalls = 0;
  int pauseBgmCalls = 0;
  int stopBgmCalls = 0;
  int playStartSfxCalls = 0;
  int playEncouragementSfxCalls = 0;
  bool playBgmResult = true;
  bool playStartSfxResult = true;
  bool playEncouragementSfxResult = true;
  int? lastTrackIndex;
  double? lastVolume;

  @override
  Future<void> initialize({
    required int trackIndex,
    required double volume,
  }) async {
    initializeCalls += 1;
    lastTrackIndex = trackIndex;
    lastVolume = volume;
  }

  @override
  Future<bool> playBgm(int trackIndex, {required double volume}) async {
    playBgmCalls += 1;
    lastTrackIndex = trackIndex;
    lastVolume = volume;
    return playBgmResult;
  }

  @override
  Future<void> pauseBgm() async {
    pauseBgmCalls += 1;
  }

  @override
  Future<bool> resumeBgm({required double volume}) async {
    lastVolume = volume;
    return playBgmResult;
  }

  @override
  Future<void> stopBgm() async {
    stopBgmCalls += 1;
  }

  @override
  Future<bool> playStartSfx() async {
    playStartSfxCalls += 1;
    return playStartSfxResult;
  }

  @override
  Future<bool> playEncouragementSfx() async {
    playEncouragementSfxCalls += 1;
    return playEncouragementSfxResult;
  }
}
