import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const MethodChannel _kSupervisorDebugChannel = MethodChannel(
  'mvp_app/supervisor_debug',
);

abstract class SupervisorNotificationService {
  Future<void> initialize();

  Future<bool> requestPermissionIfNeeded();

  Future<bool> scheduleSupervisorSession({
    required DateTime backgroundedAt,
    required String sessionId,
  });

  Future<void> cancelSupervisorSession();
}

void _debugSupervisorNotificationTap(NotificationResponse response) {
  debugPrint(
    '[SupervisorNotificationService] Notification tapped: '
    'id=${response.id} actionId=${response.actionId} payload=${response.payload}',
  );
}

@pragma('vm:entry-point')
void supervisorNotificationBackgroundTap(NotificationResponse response) {
  debugPrint(
    '[SupervisorNotificationService] Background notification response: '
    'id=${response.id} actionId=${response.actionId} payload=${response.payload}',
  );
}

class LocalSupervisorNotificationService
    implements SupervisorNotificationService {
  LocalSupervisorNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? debugChannel,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _debugChannel = debugChannel ?? _kSupervisorDebugChannel;

  static const int _stage3mNotificationId = 3101;
  static const int _stage6mNotificationId = 3102;

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _debugChannel;
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

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _debugSupervisorNotificationTap,
      onDidReceiveBackgroundNotificationResponse:
          supervisorNotificationBackgroundTap,
    );

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

    final bool? enabled = await androidPlugin?.areNotificationsEnabled();
    debugPrint(
      '[SupervisorNotificationService] Initialized. notificationsEnabled=$enabled',
    );

    _initialized = true;
  }

  @override
  Future<bool> requestPermissionIfNeeded() async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      debugPrint(
        '[SupervisorNotificationService] Android plugin unavailable; assuming enabled.',
      );
      return true;
    }

    final bool? enabledBeforeRequest = await androidPlugin
        .areNotificationsEnabled();
    debugPrint(
      '[SupervisorNotificationService] Permission before request: '
      'enabled=$enabledBeforeRequest',
    );
    if (enabledBeforeRequest == true) {
      return true;
    }

    final bool? granted = await androidPlugin.requestNotificationsPermission();
    final bool? enabledAfterRequest = await androidPlugin
        .areNotificationsEnabled();
    debugPrint(
      '[SupervisorNotificationService] Permission request result: '
      'granted=$granted enabledAfterRequest=$enabledAfterRequest',
    );
    return granted ?? enabledAfterRequest ?? false;
  }

  @override
  Future<bool> scheduleSupervisorSession({
    required DateTime backgroundedAt,
    required String sessionId,
  }) async {
    await initialize();

    final bool permissionReady = await requestPermissionIfNeeded();
    if (!permissionReady) {
      debugPrint(
        '[SupervisorNotificationService] Skip scheduling because permission is not ready.',
      );
      return false;
    }

    try {
      final DateTime stage3At = backgroundedAt.add(const Duration(minutes: 3));
      final DateTime stage6At = backgroundedAt.add(const Duration(minutes: 6));

      debugPrint(
        '[SupervisorNotificationService] Scheduling session=$sessionId '
        'backgroundedAt=${backgroundedAt.toIso8601String()} '
        'stage3=${stage3At.toIso8601String()} '
        'stage6=${stage6At.toIso8601String()}',
      );

      await cancelSupervisorSession();

      await _plugin.zonedSchedule(
        _stage3mNotificationId,
        '专注监管提醒',
        '你已经离开专注界面 3 分钟了，记得回来继续学习。',
        tz.TZDateTime.from(stage3At.toUtc(), tz.UTC),
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
        tz.TZDateTime.from(stage6At.toUtc(), tz.UTC),
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

      await _scheduleDebugAlarms(
        sessionId: sessionId,
        stage3At: stage3At,
        stage6At: stage6At,
      );

      final List<PendingNotificationRequest> pending =
          await _plugin.pendingNotificationRequests();
      debugPrint(
        '[SupervisorNotificationService] Pending notifications after schedule: '
        '${pending.map((PendingNotificationRequest request) => '{id=${request.id}, payload=${request.payload}}').join(', ')}',
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
      debugPrint('[SupervisorNotificationService] Cancelling pending reminders.');
      await _plugin.cancel(_stage3mNotificationId);
      await _plugin.cancel(_stage6mNotificationId);
      await _cancelDebugAlarms();
      final List<PendingNotificationRequest> pending =
          await _plugin.pendingNotificationRequests();
      debugPrint(
        '[SupervisorNotificationService] Pending notifications after cancel: '
        '${pending.map((PendingNotificationRequest request) => request.id).join(', ')}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SupervisorNotificationService] Failed to cancel reminders: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _scheduleDebugAlarms({
    required String sessionId,
    required DateTime stage3At,
    required DateTime stage6At,
  }) async {
    try {
      await _debugChannel.invokeMethod<void>('scheduleDebugAlarms', {
        'sessionId': sessionId,
        'stage3AtMillis': stage3At.millisecondsSinceEpoch,
        'stage6AtMillis': stage6At.millisecondsSinceEpoch,
      });
      debugPrint(
        '[SupervisorNotificationService] Scheduled native debug alarms for '
        'session=$sessionId',
      );
    } on MissingPluginException {
      debugPrint(
        '[SupervisorNotificationService] Native debug alarm channel unavailable.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '[SupervisorNotificationService] Failed to schedule native debug alarms: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _cancelDebugAlarms() async {
    try {
      await _debugChannel.invokeMethod<void>('cancelDebugAlarms');
    } on MissingPluginException {
      debugPrint(
        '[SupervisorNotificationService] Native debug alarm channel unavailable for cancel.',
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        '[SupervisorNotificationService] Failed to cancel native debug alarms: '
        '$error\n$stackTrace',
      );
    }
  }
}
