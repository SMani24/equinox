import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ActivityRepository {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  ActivityRepository(this.db);

  Stream<List<Activity>> watchActivities({bool includeArchived = false}) {
    final query = db.select(db.activities);
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
    ]);
    return query.watch();
  }

  Future<List<Activity>> getActivities({bool includeArchived = false}) {
    final query = db.select(db.activities);
    if (!includeArchived) {
      query.where((tbl) => tbl.isArchived.equals(false));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc),
    ]);
    return query.get();
  }

  Future<Activity?> getActivityById(String id) {
    return (db.select(db.activities)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Activity> createActivity({
    required String name,
    required String category,
    required double coefficient,
    required int colorHex,
    required int iconCode,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxOrderResult = await (db.selectOnly(db.activities)
          ..addColumns([db.activities.sortOrder.max()]))
        .getSingle();
    final maxOrder = maxOrderResult.read(db.activities.sortOrder.max()) ?? 0;

    final entry = ActivitiesCompanion.insert(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      coefficient: coefficient,
      colorHex: colorHex,
      iconCode: iconCode,
      sortOrder: Value(maxOrder + 1),
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.activities).insert(entry);
    return (await getActivityById(entry.id.value))!;
  }

  Future<void> updateActivity({
    required String id,
    required String name,
    required String category,
    required double coefficient,
    required int colorHex,
    required int iconCode,
    bool recalculatePastEntries = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(
        name: Value(name.trim()),
        category: Value(category),
        coefficient: Value(coefficient),
        colorHex: Value(colorHex),
        iconCode: Value(iconCode),
        updatedAt: Value(now),
      ),
    );

    if (recalculatePastEntries) {
      final entries = await (db.select(db.timeEntries)
            ..where((t) => t.activityId.equals(id)))
          .get();

      for (final entry in entries) {
        final newScore = (entry.durationSeconds / 3600.0) * coefficient;
        await (db.update(db.timeEntries)..where((t) => t.id.equals(entry.id)))
            .write(
          TimeEntriesCompanion(
            coefficientSnapshot: Value(coefficient),
            scoreSnapshot: Value(newScore),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  Future<void> setArchived(String id, bool isArchived) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (db.update(db.activities)..where((t) => t.id.equals(id))).write(
      ActivitiesCompanion(
        isArchived: Value(isArchived),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> reorderActivities(List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (db.update(db.activities)..where((t) => t.id.equals(orderedIds[i])))
            .write(
          ActivitiesCompanion(
            sortOrder: Value(i),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  Future<void> deleteActivity(String id) async {
    // Check if there are time entries referencing this activity
    final countExpr = db.timeEntries.id.count();
    final result = await (db.selectOnly(db.timeEntries)
          ..addColumns([countExpr])
          ..where(db.timeEntries.activityId.equals(id)))
        .getSingle();
    final count = result.read(countExpr) ?? 0;

    if (count > 0) {
      // Soft-delete (archive) if referenced
      await setArchived(id, true);
    } else {
      await (db.delete(db.activities)..where((t) => t.id.equals(id))).go();
    }
  }
}
