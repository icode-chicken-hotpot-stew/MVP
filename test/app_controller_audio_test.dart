import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_app/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  group('audio integration', () {
    late FakeSupervisorNotificationService notifications;
    late FakeAudioService audio;
    late AppController controller;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      notifications = FakeSupervisorNotificationService();
      audio = FakeAudioService();
      controller = AppController(
        supervisorNotificationService: notifications,
        audioService: audio,
      );
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    test('autoplays bgm on initialization when enabled', () {
      expect(audio.initializeCalls, 1);
      expect(audio.playBgmCalls, 1);
      expect(controller.isMusicPlaying.value, isTrue);
    });

    test('persists manual pause/resume intent in controller state', () async {
      await controller.playOrPauseMusic();
      expect(controller.isMusicPlaying.value, isFalse);
      expect(controller.musicAutoPlayEnabled.value, isFalse);
      expect(audio.pauseBgmCalls, 1);

      await controller.playOrPauseMusic();
      expect(controller.isMusicPlaying.value, isTrue);
      expect(controller.musicAutoPlayEnabled.value, isTrue);
      expect(audio.resumeBgmCalls, 1);
      expect(audio.playBgmCalls, 1);
    });

    test('plays selected track when track changed while paused', () async {
      await controller.playOrPauseMusic();
      expect(controller.isMusicPlaying.value, isFalse);

      await controller.playNextTrack();
      final int selectedTrackIndex = controller.currentTrackIndex.value;
      final int playCallsBeforeResume = audio.playBgmCalls;

      await controller.playOrPauseMusic();

      expect(controller.isMusicPlaying.value, isTrue);
      expect(audio.resumeBgmCalls, 0);
      expect(audio.playBgmCalls, playCallsBeforeResume + 1);
      expect(audio.lastTrackIndex, selectedTrackIndex);
    });

    test('pauses on background and resumes on foreground', () async {
      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      expect(audio.pauseBgmCalls, 1);

      await controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
      expect(audio.resumeBgmCalls, 1);
      expect(controller.isMusicPlaying.value, isTrue);
    });

    test('does not resume if user already turned music off', () async {
      await controller.playOrPauseMusic();
      final int pauseCallsAfterManualOff = audio.pauseBgmCalls;

      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      await controller.handleLifecycleStateChanged(AppLifecycleState.resumed);

      expect(audio.pauseBgmCalls, pauseCallsAfterManualOff);
      expect(audio.resumeBgmCalls, 0);
      expect(controller.isMusicPlaying.value, isFalse);
    });

    test('marks music stopped when lifecycle resume fails', () async {
      audio.resumeBgmResult = false;

      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      await controller.handleLifecycleStateChanged(AppLifecycleState.resumed);

      expect(audio.resumeBgmCalls, 1);
      expect(controller.isMusicPlaying.value, isFalse);
    });

    test('changing music volume does not restart current track', () async {
      final int initialPlayCalls = audio.playBgmCalls;

      await controller.setMusicVolume(0.35);

      expect(controller.musicVolume.value, closeTo(0.35, 0.0001));
      expect(audio.setBgmVolumeCalls, 1);
      expect(audio.playBgmCalls, initialPlayCalls);
    });

    test('triggers start sfx on first start', () {
      controller.startTimer();

      expect(audio.playStartSfxCalls, 1);
    });

    test('routes semantic ui open/back events to button sfx', () async {
      await controller.triggerUiOpenSfx();
      await Future<void>.delayed(const Duration(milliseconds: 220));
      await controller.triggerUiBackSfx();

      expect(audio.playButtonOpenSfxCalls, 1);
      expect(audio.playButtonBackSfxCalls, 1);
    });

    test('deduplicates rapid repeated ui sfx of same type', () async {
      await controller.triggerUiOpenSfx();
      await controller.triggerUiOpenSfx();
      await Future<void>.delayed(const Duration(milliseconds: 220));
      await controller.triggerUiBackSfx();
      await controller.triggerUiBackSfx();

      expect(audio.playButtonOpenSfxCalls, 1);
      expect(audio.playButtonBackSfxCalls, 1);
    });

    test('deduplicates rapid repeated ui sfx across different types', () async {
      await controller.triggerUiOpenSfx();
      await controller.triggerUiBackSfx();

      expect(audio.playButtonOpenSfxCalls, 1);
      expect(audio.playButtonBackSfxCalls, 0);
    });

    test('ui button sfx failures are non-blocking', () async {
      audio.playButtonOpenSfxResult = false;
      audio.playButtonBackSfxResult = false;

      await controller.triggerUiOpenSfx();
      await controller.triggerUiBackSfx();

      controller.startTimer();
      controller.pauseTimer();
      expect(controller.phaseStatus.value, PomodoroPhaseStatus.paused);
    });

    test('audio failure does not block timer transition methods', () async {
      audio.resumeBgmResult = false;
      await controller.playOrPauseMusic();
      await controller.playOrPauseMusic();

      expect(controller.musicAutoPlayEnabled.value, isTrue);
      expect(controller.isMusicPlaying.value, isFalse);

      controller.startTimer();
      controller.pauseTimer();
      expect(controller.phaseStatus.value, PomodoroPhaseStatus.paused);
    });
  });
}
