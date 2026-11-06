import 'package:drift/native.dart';
import 'package:equinox/core/services/backup_service.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BackupService backupService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupService Tests', () {
    test('JSON Export and Import (Smart Merge)', () async {
      // 1. Create initial test activity
      final initialAct = ActivitiesCompanion.insert(
        id: 'act-1',
        name: 'Initial Work',
        category: 'productive',
        coefficient: 1.0,
        colorHex: 0xFF10B981,
        iconCode: 1234,
        createdAt: 1000,
        updatedAt: 1000,
      );
      await db.into(db.activities).insert(initialAct);

      // Export JSON
      final jsonExport = await backupService.exportToJsonString();
      expect(jsonExport, contains('Initial Work'));

      // 2. Simulate incoming backup with updated version of act-1 and new act-2
      final incomingJson = '''
      {
        "version": 1,
        "appName": "Equinox",
        "exportedAt": 2000,
        "activities": [
          {
            "id": "act-1",
            "name": "Updated Work Name",
            "category": "productive",
            "coefficient": 1.5,
            "color_hex": 4279327105,
            "icon_code": 1234,
            "is_archived": false,
            "sort_order": 0,
            "created_at": 1000,
            "updated_at": 1500
          },
          {
            "id": "act-2",
            "name": "New Gaming",
            "category": "rest",
            "coefficient": -2.0,
            "color_hex": 4294200670,
            "icon_code": 5678,
            "is_archived": false,
            "sort_order": 1,
            "created_at": 1200,
            "updated_at": 1200
          }
        ],
        "time_entries": [],
        "settings": []
      }
      ''';

      final summary = await backupService.importFromJsonString(
        incomingJson,
        smartMerge: true,
      );

      expect(summary.activitiesAdded, 1);
      expect(summary.activitiesUpdated, 1);

      // Verify db state
      final updated = await (db.select(db.activities)..where((t) => t.id.equals('act-1'))).getSingle();
      expect(updated.name, 'Updated Work Name');
      expect(updated.coefficient, 1.5);

      final added = await (db.select(db.activities)..where((t) => t.id.equals('act-2'))).getSingle();
      expect(added.name, 'New Gaming');
    });

    test('CSV Export produces formatted rows', () async {
      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(
              id: 'act-test',
              name: 'Deep Coding',
              category: 'productive',
              coefficient: 1.5,
              colorHex: 0xFF10B981,
              iconCode: 1234,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );

      await db.into(db.timeEntries).insert(
            TimeEntriesCompanion.insert(
              id: 'entry-1',
              activityId: 'act-test',
              startTime: 1700000000000,
              endTime: 1700003600000,
              durationSeconds: 3600,
              coefficientSnapshot: 1.5,
              scoreSnapshot: 1.5,
              createdAt: 1700003600000,
              updatedAt: 1700003600000,
            ),
          );

      final csv = await backupService.exportToCsvString();
      expect(csv, contains('Deep Coding'));
      expect(csv, contains('productive'));
      expect(csv, contains('01:00:00'));
      expect(csv, contains('1.5'));
    });
  });
}
