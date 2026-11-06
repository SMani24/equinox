import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service for crash-proof active timer notifications
  await NotificationService().initialize();

  runApp(
    const ProviderScope(
      child: EquinoxApp(),
    ),
  );
}
