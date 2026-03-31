import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_app/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  group('xp and level system', () {
    late FakeSupervisorNotificationService notifications;
    late FakeAudioService audio;
    late DateTime fakeNow;
    late AppController controller;

    AppController buildController() {
      return AppController(
        supervisorNotificationService: notifications,
        audioService: audio,
        now: () => fakeNow,
      );
    }

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      notifications = FakeSupervisorNotificationService();
      audio = FakeAudioService();
      fakeNow = DateTime(2026, 3, 29, 9, 0, 0);
      controller = buildController();
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    test('grants 250 xp for a 25-minute focus completion', () async {
      final int xp = await controller.grantFocusXp(effectiveFocusSeconds: 25 * 60);

      expect(xp, 250);
      expect(controller.totalXp.value, 250);
      expect(controller.dailyXp.value, 250);
      expect(controller.level.value, 2);
      expect(controller.justLeveledUp.value, isTrue);
    });

    test('grants zero xp for focus under 5 minutes', () async {
      final int xp = await controller.grantFocusXp(effectiveFocusSeconds: 4 * 60);

      expect(xp, 0);
      expect(controller.totalXp.value, 0);
      expect(controller.dailyXp.value, 0);
      expect(controller.level.value, 1);
    });

    test('enforces daily cap of 2000 xp', () async {
      await controller.grantFocusXp(effectiveFocusSeconds: 150 * 60);
      final int xp = await controller.grantFocusXp(effectiveFocusSeconds: 150 * 60);

      expect(xp, 500);
      expect(controller.dailyXp.value, 2000);
      expect(controller.totalXp.value, 2000);
    });

    test('resets daily bucket on day rollover', () async {
      await controller.grantFocusXp(effectiveFocusSeconds: 25 * 60);
      fakeNow = fakeNow.add(const Duration(days: 1));

      final int xp = await controller.grantFocusXp(effectiveFocusSeconds: 25 * 60);

      expect(xp, 250);
      expect(controller.dailyXp.value, 250);
      expect(controller.totalXp.value, 500);
    });

    test('uses strict level-only dialogue unlock and readable reason', () async {
      expect(controller.canUnlockDialogue(4), isFalse);
      expect(controller.dialogueLockReason(4), '达到 Lv.4 后解锁');

      await controller.grantFocusXp(effectiveFocusSeconds: 450 * 60);

      expect(controller.canUnlockDialogue(4), isTrue);
      expect(controller.dialogueLockReason(4), 'Lv.4 对话已解锁');
    });
  });
}
