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
      final int xp = await controller.grantFocusXp(
        effectiveFocusSeconds: 25 * 60,
      );

      expect(xp, 250);
      expect(controller.totalXp.value, 250);
      expect(controller.dailyXp.value, 250);
      expect(controller.level.value, 2);
      expect(controller.justLeveledUp.value, isTrue);
    });

    test('grants zero xp for focus under 5 minutes', () async {
      final int xp = await controller.grantFocusXp(
        effectiveFocusSeconds: 4 * 60,
      );

      expect(xp, 0);
      expect(controller.totalXp.value, 0);
      expect(controller.dailyXp.value, 0);
      expect(controller.level.value, 1);
    });

    test('enforces daily cap of 2000 xp', () async {
      await controller.grantFocusXp(effectiveFocusSeconds: 150 * 60);
      final int xp = await controller.grantFocusXp(
        effectiveFocusSeconds: 150 * 60,
      );

      expect(xp, 500);
      expect(controller.dailyXp.value, 2000);
      expect(controller.totalXp.value, 2000);
    });

    test('resets daily bucket on day rollover', () async {
      await controller.grantFocusXp(effectiveFocusSeconds: 25 * 60);
      fakeNow = fakeNow.add(const Duration(days: 1));

      final int xp = await controller.grantFocusXp(
        effectiveFocusSeconds: 25 * 60,
      );

      expect(xp, 250);
      expect(controller.dailyXp.value, 250);
      expect(controller.totalXp.value, 500);
    });

    test(
      'uses strict level-only dialogue unlock and readable reason',
      () async {
        expect(controller.canUnlockDialogue(4), isFalse);
        expect(controller.dialogueLockReason(4), '达到 Lv.4 后解锁');

        await controller.grantFocusXp(effectiveFocusSeconds: 450 * 60);

        expect(controller.canUnlockDialogue(4), isTrue);
        expect(controller.dialogueLockReason(4), 'Lv.4 对话已解锁');
      },
    );

    test('unlocks dialogue segments progressively within same type', () async {
      const Set<String> level1ClickedOpeners = <String>{
        '诶？你问我以前是不是经常刷视频到凌晨？',
        '诶诶诶别戳脸啦！会、会变圆的！（小声）……再戳一下也不是不行。',
      };

      for (int i = 0; i < 10; i += 1) {
        await controller.triggerDialogue('clicked');
        expect(controller.isTalking, isTrue);
        expect(
          level1ClickedOpeners.contains(controller.currentDialogue),
          isTrue,
          reason:
              'Lv.1 时只能命中 clicked 的 Lv.1 对话段，实际: ${controller.currentDialogue}',
        );
        controller.skipDialogue();
      }

      await controller.grantFocusXp(effectiveFocusSeconds: 450 * 60);
      expect(controller.level.value, 4);

      const Set<String> level4ClickedOpeners = <String>{
        '我、我刚才是在冥想！对，冥想！',
        '如果现在能瞬移，你最想去哪里？我……想去便利店买柠檬茶。',
      };

      bool hitLevel4ClickedLine = false;
      bool hitLevel5ClickedLine = false;
      for (int i = 0; i < 60; i += 1) {
        await controller.triggerDialogue('clicked');
        if (level4ClickedOpeners.contains(controller.currentDialogue)) {
          hitLevel4ClickedLine = true;
        }
        if (controller.currentDialogue == '如果学习能像打游戏一样掉装备，我早就满级神装了吧') {
          hitLevel5ClickedLine = true;
        }
        controller.skipDialogue();
      }

      expect(hitLevel4ClickedLine, isTrue);
      expect(hitLevel5ClickedLine, isFalse);
    });

    test('interrupts lower-priority dialogue with P1 trigger', () async {
      await controller.triggerDialogue('clicked');
      expect(controller.currentDialogueType, 'clicked');

      await controller.triggerDialogue('completed');

      expect(controller.isTalking, isTrue);
      expect(controller.currentDialogueType, 'completed');
    });

    test('interrupts lower-priority dialogue with P2 trigger', () async {
      await controller.triggerDialogue('clicked');
      expect(controller.currentDialogueType, 'clicked');

      controller.startTimer();
      await controller.triggerDialogue('start_focus');

      expect(controller.isTalking, isTrue);
      expect(controller.currentDialogueType, 'start_focus');
    });

    test(
      'queues non-interrupting dialogue until current dialogue ends',
      () async {
        await controller.triggerDialogue('idle');
        expect(controller.currentDialogueType, 'idle');

        await controller.triggerDialogue('clicked');
        expect(controller.currentDialogueType, 'idle');

        controller.skipDialogue();
        await Future<void>.delayed(Duration.zero);

        expect(controller.isTalking, isTrue);
        expect(controller.currentDialogueType, 'clicked');
      },
    );
  });
}
