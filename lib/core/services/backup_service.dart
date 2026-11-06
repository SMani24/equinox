import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../utils/duration_formatter.dart';

class ImportSummary {
  final int activitiesAdded;
  final int activitiesUpdated;
  final int entriesAdded;
  final int entriesUpdated;

  const ImportSummary({
    required this.activitiesAdded,
    required this.activitiesUpdated,
    required this.entriesAdded,
    required this.entriesUpdated,
  });
}

class BackupService {
  final AppDatabase db;

  BackupService(this.db);

  Future<String> exportToJsonString() async {
    final activitiesList = await db.select(db.activities).get();
    final timeEntriesList = await db.select(db.timeEntries).get();
    final settingsList = await db.select(db.appSettings).get();

    final exportMap = {
      'version': 1,
      'appName': 'Equinox',
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'activities': activitiesList.map((a) => {
            'id': a.id,
            'name': a.name,
            'category': a.category,
            'coefficient': a.coefficient,
            'color_hex': a.colorHex,
            'icon_code': a.iconCode,
            'is_archived': a.isArchived,
            'sort_order': a.sortOrder,
            'created_at': a.createdAt,
            'updated_at': a.updatedAt,
          }).toList(),
      'time_entries': timeEntriesList.map((e) => {
            'id': e.id,
            'activity_id': e.activityId,
            'start_time': e.startTime,
            'end_time': e.endTime,
            'duration_seconds': e.durationSeconds,
            'coefficient_snapshot': e.coefficientSnapshot,
            'score_snapshot': e.scoreSnapshot,
            'note': e.note,
            'created_at': e.createdAt,
            'updated_at': e.updatedAt,
          }).toList(),
      'settings': settingsList.map((s) => {
            'key': s.key,
            'value': s.value,
          }).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  Future<ImportSummary> importFromJsonString(
    String jsonString, {
    bool smartMerge = true,
  }) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final rawActivities = (data['activities'] as List? ?? []).cast<Map<String, dynamic>>();
    final rawEntries = (data['time_entries'] as List? ?? []).cast<Map<String, dynamic>>();
    final rawSettings = (data['settings'] as List? ?? []).cast<Map<String, dynamic>>();

    int activitiesAdded = 0;
    int activitiesUpdated = 0;
    int entriesAdded = 0;
    int entriesUpdated = 0;

    await db.transaction(() async {
      if (!smartMerge) {
        // Replace all
        await db.delete(db.timeEntries).go();
        await db.delete(db.activities).go();
        await db.delete(db.appSettings).go();
      }

      // Import Activities
      for (final a in rawActivities) {
        final id = a['id'] as String;
        final name = a['name'] as String;
        final category = a['category'] as String;
        final coefficient = (a['coefficient'] as num).toDouble();
        final colorHex = (a['color_hex'] as num).toInt();
        final iconCode = (a['icon_code'] as num).toInt();
        final isArchived = (a['is_archived'] as bool?) ?? false;
        final sortOrder = (a['sort_order'] as num?)?.toInt() ?? 0;
        final createdAt = (a['created_at'] as num).toInt();
        final updatedAt = (a['updated_at'] as num).toInt();

        final existing = await (db.select(db.activities)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null) {
          await db.into(db.activities).insert(
                ActivitiesCompanion.insert(
                  id: id,
                  name: name,
                  category: category,
                  coefficient: coefficient,
                  colorHex: colorHex,
                  iconCode: iconCode,
                  isArchived: Value(isArchived),
                  sortOrder: Value(sortOrder),
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
              );
          activitiesAdded++;
        } else if (smartMerge && updatedAt > existing.updatedAt) {
          await (db.update(db.activities)..where((t) => t.id.equals(id))).write(
            ActivitiesCompanion(
              name: Value(name),
              category: Value(category),
              coefficient: Value(coefficient),
              colorHex: Value(colorHex),
              iconCode: Value(iconCode),
              isArchived: Value(isArchived),
              sortOrder: Value(sortOrder),
              updatedAt: Value(updatedAt),
            ),
          );
          activitiesUpdated++;
        }
      }

      // Import Time Entries
      for (final e in rawEntries) {
        final id = e['id'] as String;
        final activityId = e['activity_id'] as String;
        final startTime = (e['start_time'] as num).toInt();
        final endTime = (e['end_time'] as num).toInt();
        final durationSeconds = (e['duration_seconds'] as num).toInt();
        final coeffSnapshot = (e['coefficient_snapshot'] as num).toDouble();
        final scoreSnapshot = (e['score_snapshot'] as num).toDouble();
        final note = e['note'] as String?;
        final createdAt = (e['created_at'] as num).toInt();
        final updatedAt = (e['updated_at'] as num).toInt();

        final existing = await (db.select(db.timeEntries)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();

        if (existing == null) {
          await db.into(db.timeEntries).insert(
                TimeEntriesCompanion.insert(
                  id: id,
                  activityId: activityId,
                  startTime: startTime,
                  endTime: endTime,
                  durationSeconds: durationSeconds,
                  coefficientSnapshot: coeffSnapshot,
                  scoreSnapshot: scoreSnapshot,
                  note: Value(note),
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
              );
          entriesAdded++;
        } else if (smartMerge && updatedAt > existing.updatedAt) {
          await (db.update(db.timeEntries)..where((t) => t.id.equals(id))).write(
            TimeEntriesCompanion(
              activityId: Value(activityId),
              startTime: Value(startTime),
              endTime: Value(endTime),
              durationSeconds: Value(durationSeconds),
              coefficientSnapshot: Value(coeffSnapshot),
              scoreSnapshot: Value(scoreSnapshot),
              note: Value(note),
              updatedAt: Value(updatedAt),
            ),
          );
          entriesUpdated++;
        }
      }

      // Import Settings
      for (final s in rawSettings) {
        final key = s['key'] as String;
        final value = s['value'] as String;
        await db.into(db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                key: key,
                value: value,
              ),
            );
      }
    });

    return ImportSummary(
      activitiesAdded: activitiesAdded,
      activitiesUpdated: activitiesUpdated,
      entriesAdded: entriesAdded,
      entriesUpdated: entriesUpdated,
    );
  }

  Future<String> exportToCsvString() async {
    final query = db.select(db.timeEntries).join([
      innerJoin(
        db.activities,
        db.activities.id.equalsExp(db.timeEntries.activityId),
      ),
    ])..orderBy([
        OrderingTerm(
          expression: db.timeEntries.startTime,
          mode: OrderingMode.asc,
        ),
      ]);

    final rows = await query.get();

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    final List<List<dynamic>> csvData = [
      [
        'Entry ID',
        'Date',
        'Start Time',
        'End Time',
        'Duration (Seconds)',
        'Duration (Formatted)',
        'Activity Name',
        'Category',
        'Coefficient',
        'Score (Points)',
        'Note',
      ]
    ];

    for (final row in rows) {
      final entry = row.readTable(db.timeEntries);
      final activity = row.readTable(db.activities);

      final startDate = DateTime.fromMillisecondsSinceEpoch(entry.startTime);
      final endDate = DateTime.fromMillisecondsSinceEpoch(entry.endTime);

      csvData.add([
        entry.id,
        dateFormat.format(startDate),
        timeFormat.format(startDate),
        timeFormat.format(endDate),
        entry.durationSeconds,
        DurationFormatter.formatHms(entry.durationSeconds),
        activity.name,
        activity.category,
        entry.coefficientSnapshot,
        entry.scoreSnapshot.toStringAsFixed(2),
        entry.note ?? '',
      ]);
    }

    return Csv().encode(csvData);
  }
}
