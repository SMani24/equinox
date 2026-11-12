import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/date_boundary.dart';
import '../../core/utils/score_calculator.dart';
import '../database/app_database.dart';

class TimeEntryWithActivity {
  final TimeEntry entry;
  final Activity activity;

  const TimeEntryWithActivity({
    required this.entry,
    required this.activity,
  });

  double get score => entry.scoreSnapshot;
  int get durationSeconds => entry.durationSeconds;
}

class TimeEntryRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  TimeEntryRepository(this.db);

  Stream<List<TimeEntryWithActivity>> watchEntriesForDay(
    DateTime logicalDate, {
    int rolloverHour = 0,
  }) {
    final start = DateBoundary.getDayStart(logicalDate, rolloverHour: rolloverHour);
    final end = DateBoundary.getDayEnd(logicalDate, rolloverHour: rolloverHour);
    return watchEntriesBetween(start, end);
  }

  Stream<List<TimeEntryWithActivity>> watchEntriesBetween(
    DateTime start,
    DateTime end,
  ) {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final query = db.select(db.timeEntries).join([
      innerJoin(
        db.activities,
        db.activities.id.equalsExp(db.timeEntries.activityId),
      ),
    ])
      ..where(
        db.timeEntries.startTime.isSmallerOrEqualValue(endMs) &
            db.timeEntries.endTime.isBiggerOrEqualValue(startMs),
      )
      ..orderBy([
        OrderingTerm(
          expression: db.timeEntries.startTime,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(
          expression: db.timeEntries.endTime,
          mode: OrderingMode.desc,
        ),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TimeEntryWithActivity(
          entry: row.readTable(db.timeEntries),
          activity: row.readTable(db.activities),
        );
      }).toList();
    });
  }

  Future<List<TimeEntryWithActivity>> getEntriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final query = db.select(db.timeEntries).join([
      innerJoin(
        db.activities,
        db.activities.id.equalsExp(db.timeEntries.activityId),
      ),
    ])
      ..where(
        db.timeEntries.startTime.isSmallerOrEqualValue(endMs) &
            db.timeEntries.endTime.isBiggerOrEqualValue(startMs),
      )
      ..orderBy([
        OrderingTerm(
          expression: db.timeEntries.startTime,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(
          expression: db.timeEntries.endTime,
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();
    return rows.map((row) {
      return TimeEntryWithActivity(
        entry: row.readTable(db.timeEntries),
        activity: row.readTable(db.activities),
      );
    }).toList();
  }

  Future<List<TimeEntryWithActivity>> getAllEntries() async {
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
    return rows.map((row) {
      return TimeEntryWithActivity(
        entry: row.readTable(db.timeEntries),
        activity: row.readTable(db.activities),
      );
    }).toList();
  }

  Future<TimeEntry> createEntry({
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
    double? overrideCoefficient,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = endTime.millisecondsSinceEpoch;
    final durationSeconds = ((endMs - startMs) / 1000).round();

    // Look up activity for snapshot coefficient if not overridden
    double coeff = overrideCoefficient ?? 0.0;
    if (overrideCoefficient == null) {
      final act = await (db.select(db.activities)
            ..where((t) => t.id.equals(activityId)))
          .getSingleOrNull();
      if (act != null) {
        coeff = act.coefficient;
      }
    }

    final score = ScoreCalculator.calculateScore(durationSeconds, coeff);

    final entry = TimeEntriesCompanion.insert(
      id: _uuid.v4(),
      activityId: activityId,
      startTime: startMs,
      endTime: endMs,
      durationSeconds: durationSeconds,
      coefficientSnapshot: coeff,
      scoreSnapshot: score,
      note: Value(note?.trim()),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.timeEntries).insert(entry);
    return (await (db.select(db.timeEntries)..where((t) => t.id.equals(entry.id.value)))
        .getSingle());
  }

  Future<TimeEntry?> getEntryById(String id) async {
    return (db.select(db.timeEntries)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateEntry({
    required String id,
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final startMs = startTime.millisecondsSinceEpoch;
    final endMs = endTime.millisecondsSinceEpoch;
    final durationSeconds = ((endMs - startMs) / 1000).round();

    final act = await (db.select(db.activities)
          ..where((t) => t.id.equals(activityId)))
        .getSingleOrNull();
    final coeff = act?.coefficient ?? 0.0;
    final score = ScoreCalculator.calculateScore(durationSeconds, coeff);

    await (db.update(db.timeEntries)..where((t) => t.id.equals(id))).write(
      TimeEntriesCompanion(
        activityId: Value(activityId),
        startTime: Value(startMs),
        endTime: Value(endMs),
        durationSeconds: Value(durationSeconds),
        coefficientSnapshot: Value(coeff),
        scoreSnapshot: Value(score),
        note: Value(note?.trim()),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteEntry(String id) async {
    await (db.delete(db.timeEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> splitEntry({
    required String originalEntryId,
    required DateTime splitTime,
    required String secondActivityId,
    String? firstNote,
    String? secondNote,
  }) async {
    final original = await (db.select(db.timeEntries)
          ..where((t) => t.id.equals(originalEntryId)))
        .getSingleOrNull();
    if (original == null) return;

    final origStart = DateTime.fromMillisecondsSinceEpoch(original.startTime);
    final origEnd = DateTime.fromMillisecondsSinceEpoch(original.endTime);

    if (splitTime.isBefore(origStart) || splitTime.isAfter(origEnd)) {
      throw ArgumentError('Split time must be between entry start and end time');
    }

    await db.transaction(() async {
      // 1. Update original entry to end at splitTime
      await updateEntry(
        id: original.id,
        activityId: original.activityId,
        startTime: origStart,
        endTime: splitTime,
        note: firstNote ?? original.note,
      );

      // 2. Create second entry from splitTime to origEnd
      await createEntry(
        activityId: secondActivityId,
        startTime: splitTime,
        endTime: origEnd,
        note: secondNote,
      );
    });
  }
}
