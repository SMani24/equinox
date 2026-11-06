import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ActivityRepository(db);
});

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TimeEntryRepository(db);
});

final timerRepositoryProvider = Provider<TimerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TimerRepository(db);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupService(db);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
