import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) {
  if (details.actionId != null) {
    NotificationService.actionStream.add(details.actionId!);
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final StreamController<String> actionStream =
      StreamController<String>.broadcast();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const int timerNotificationId = 888;
  static const String channelId = 'equinox_timer_channel';
  static const String channelName = 'Equinox Active Timer';
  static const String channelDescription =
      'Shows active timer status in the notification shade';

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open Equinox',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.actionId != null) {
            actionStream.add(details.actionId!);
          } else {
            actionStream.add('open_app');
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Request notification permission on Android 13+
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization note: $e');
    }
  }

  Future<void> showRunningTimer({
    required int startEpochMs,
    String? activityName,
  }) async {
    if (!_initialized) await initialize();

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.stopwatch,
        ongoing: true,
        autoCancel: false,
        usesChronometer: true,
        when: startEpochMs,
        showWhen: true,
        color: const Color(0xFF6366F1),
        actions: const [
          AndroidNotificationAction(
            'action_pause',
            'Pause',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'action_stop',
            'Stop',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        linux: const LinuxNotificationDetails(),
      );

      final title = activityName != null && activityName.isNotEmpty
          ? activityName
          : 'Timer';

      await _notificationsPlugin.show(
        id: timerNotificationId,
        title: title,
        body: 'Running',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Could not show running timer notification: $e');
    }
  }

  Future<void> showPausedTimer({
    required int elapsedSeconds,
    String? activityName,
  }) async {
    if (!_initialized) await initialize();

    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.stopwatch,
        ongoing: true,
        autoCancel: false,
        usesChronometer: false,
        showWhen: false,
        color: Color(0xFF6366F1),
        actions: [
          AndroidNotificationAction(
            'action_resume',
            'Resume',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'action_stop',
            'Stop',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      final notificationDetails = const NotificationDetails(
        android: androidDetails,
        linux: LinuxNotificationDetails(),
      );

      final hours = elapsedSeconds ~/ 3600;
      final minutes = (elapsedSeconds % 3600) ~/ 60;
      final seconds = elapsedSeconds % 60;
      final timeStr = hours > 0
          ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
          : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      final title = activityName != null && activityName.isNotEmpty
          ? activityName
          : 'Timer';

      await _notificationsPlugin.show(
        id: timerNotificationId,
        title: title,
        body: 'Paused ($timeStr)',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Could not show paused timer notification: $e');
    }
  }

  Future<void> cancelTimerNotification() async {
    try {
      await _notificationsPlugin.cancel(id: timerNotificationId);
    } catch (e) {
      debugPrint('Could not cancel timer notification: $e');
    }
  }
}
