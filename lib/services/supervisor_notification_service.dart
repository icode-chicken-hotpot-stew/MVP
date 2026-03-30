import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract class SupervisorNotificationService {
  Future<void> initialize();

  Future<bool> scheduleSupervisorSession({
    required DateTime backgroundedAt,
    required String sessionId,
  });

  Future<void> cancelSupervisorSession();
}

class LocalSupervisorNotificationService
    implements SupervisorNotificationService {
  LocalSupervisorNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _stage3mNotificationId = 3101;
  static const int _stage6mNotificationId = 3102;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tzdata.initializeTimeZones();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(settings);

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'pomodoro_supervisor',
        'Pomodoro Supervisor',
        description: 'Background study supervision reminders.',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  @override
  Future<bool> scheduleSupervisorSession({
    required DateTime backgroundedAt,
    required String sessionId,
  }) async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? granted = await androidPlugin?.requestNotificationsPermission();
    if (granted == false) {
      debugPrint(
        '[SupervisorNotificationService] Notification permission denied.',
      );
      return false;
    }

    try {
      await cancelSupervisorSession();

      await _plugin.zonedSchedule(
        _stage3mNotificationId,
        '专注监管提醒',
        '你已经离开专注界面 3 分钟了，记得回来继续学习。',
        tz.TZDateTime.from(
          backgroundedAt.add(const Duration(minutes: 3)).toUtc(),
          tz.UTC,
        ),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'pomodoro_supervisor',
            'Pomodoro Supervisor',
            channelDescription: 'Background study supervision reminders.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'sessionId': sessionId, 'stage': '3m'}),
      );

      await _plugin.zonedSchedule(
        _stage6mNotificationId,
        '专注监管提醒',
        '你已经离开专注界面 6 分钟了，监督员在等你回到学习状态。',
        tz.TZDateTime.from(
          backgroundedAt.add(const Duration(minutes: 6)).toUtc(),
          tz.UTC,
        ),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'pomodoro_supervisor',
            'Pomodoro Supervisor',
            channelDescription: 'Background study supervision reminders.',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'sessionId': sessionId, 'stage': '6m'}),
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[SupervisorNotificationService] Failed to schedule reminders: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  @override
  Future<void> cancelSupervisorSession() async {
    try {
      await _plugin.cancel(_stage3mNotificationId);
      await _plugin.cancel(_stage6mNotificationId);
    } catch (error, stackTrace) {
      debugPrint(
        '[SupervisorNotificationService] Failed to cancel reminders: '
        '$error\n$stackTrace',
      );
    }
  }
}
