import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_app/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  group('background supervisor notifications', () {
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
      fakeNow = DateTime(2026, 3, 29, 10, 0, 0);
      controller = buildController();
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    test('requests notification permission on initialize', () {
      expect(notifications.permissionRequestCalls, 1);
    });

    test('schedules once when app backgrounds during studying + running', () async {
      controller.startTimer();

      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      await controller.handleLifecycleStateChanged(AppLifecycleState.hidden);

      expect(notifications.scheduleCalls, 1);
      expect(notifications.lastBackgroundedAt, fakeNow);
    });

    test('does not schedule outside active focus', () async {
      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);

      expect(notifications.scheduleCalls, 0);
    });

    test('cancels on resume and pause/reset invalidation', () async {
      controller.startTimer();
      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);

      await controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
      controller.startTimer();
      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      controller.pauseTimer();
      controller.startTimer();
      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      controller.resetTimer();

      expect(notifications.cancelCalls, greaterThanOrEqualTo(3));
    });

    test('gracefully skips when permission or scheduling is denied', () async {
      notifications.scheduleResult = false;
      controller.startTimer();

      await controller.handleLifecycleStateChanged(AppLifecycleState.paused);
      await controller.handleLifecycleStateChanged(AppLifecycleState.hidden);

      expect(notifications.scheduleCalls, 2);
    });
  });
}
