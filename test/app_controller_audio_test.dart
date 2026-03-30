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
      expect(audio.playBgmCalls, greaterThanOrEqualTo(2));
    });

    test('triggers start sfx on first start', () {
      controller.startTimer();

      expect(audio.playStartSfxCalls, 1);
    });

    test('audio failure does not block timer transition methods', () async {
      audio.playBgmResult = false;
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
