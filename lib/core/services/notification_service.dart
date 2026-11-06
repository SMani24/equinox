import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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
          // Can be used to bring app to foreground
        },
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
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        usesChronometer: true,
        when: startEpochMs,
        showWhen: true,
        subText: 'Equinox Timer',
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
        body: 'Tap to view Equinox and balance score',
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
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        usesChronometer: false,
        showWhen: false,
        subText: 'Equinox Timer (Paused)',
      );

      final notificationDetails = const NotificationDetails(
        android: androidDetails,
        linux: LinuxNotificationDetails(),
      );

      final hours = elapsedSeconds ~/ 3600;
      final minutes = (elapsedSeconds % 3600) ~/ 60;
      final seconds = elapsedSeconds % 60;
      final timeStr =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      await _notificationsPlugin.show(
        id: timerNotificationId,
        title: 'Timer Paused ($timeStr)',
        body: activityName ?? 'Tap to resume',
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
