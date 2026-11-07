import 'dart:async';
import 'dart:io';
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
        subText: activityName != null
            ? 'Equinox • $activityName'
            : 'Equinox Timer',
        actions: const [
          AndroidNotificationAction(
            'action_pause',
            'Pause',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'action_stop',
            'Stop & Log',
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
          ? 'Tracking: $activityName'
          : 'Timer Running';

      await _notificationsPlugin.show(
        id: timerNotificationId,
        title: title,
        body: 'Tap to view Equinox or control with buttons below',
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
      final androidDetails = AndroidNotificationDetails(
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
        subText: activityName != null
            ? 'Equinox (Paused) • $activityName'
            : 'Equinox Timer (Paused)',
        actions: const [
          AndroidNotificationAction(
            'action_resume',
            'Resume',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            'action_stop',
            'Stop & Log',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        linux: const LinuxNotificationDetails(),
      );

      final hours = elapsedSeconds ~/ 3600;
      final minutes = (elapsedSeconds % 3600) ~/ 60;
      final seconds = elapsedSeconds % 60;
      final timeStr =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      await _notificationsPlugin.show(
        id: timerNotificationId,
        title: 'Timer Paused ($timeStr)',
        body: activityName != null
            ? '$activityName • Tap Resume or Stop'
            : 'Tap Resume to continue tracking',
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
