import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Activities, TimeEntries, ActiveTimers, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedInitialData();
        },
      );

  Future<void> _seedInitialData() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const uuid = Uuid();

    final defaultActivities = [
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Deep Work',
        category: 'productive',
        coefficient: 1.5,
        colorHex: 0xFF10B981, // Emerald
        iconCode: Icons.psychology.codePoint,
        sortOrder: const Value(0),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Standard Work / Study',
        category: 'productive',
        coefficient: 1.0,
        colorHex: 0xFF3B82F6, // Blue
        iconCode: Icons.menu_book.codePoint,
        sortOrder: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Exercise / Workout',
        category: 'productive',
        coefficient: 1.2,
        colorHex: 0xFF06B6D4, // Cyan
        iconCode: Icons.fitness_center.codePoint,
        sortOrder: const Value(2),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Chores / Errands',
        category: 'productive',
        coefficient: 0.5,
        colorHex: 0xFF14B8A6, // Teal
        iconCode: Icons.cleaning_services.codePoint,
        sortOrder: const Value(3),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Mindful Rest / Walk',
        category: 'rest',
        coefficient: -1.0,
        colorHex: 0xFFF59E0B, // Amber
        iconCode: Icons.self_improvement.codePoint,
        sortOrder: const Value(4),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'TV / YouTube',
        category: 'rest',
        coefficient: -2.0,
        colorHex: 0xFFF97316, // Orange
        iconCode: Icons.tv.codePoint,
        sortOrder: const Value(5),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Video Games / Doomscrolling',
        category: 'rest',
        coefficient: -3.0,
        colorHex: 0xFFF43F5E, // Rose
        iconCode: Icons.sports_esports.codePoint,
        sortOrder: const Value(6),
        createdAt: now,
        updatedAt: now,
      ),
      ActivitiesCompanion.insert(
        id: uuid.v4(),
        name: 'Sleep / Meals',
        category: 'neutral',
        coefficient: 0.0,
        colorHex: 0xFF64748B, // Slate
        iconCode: Icons.bedtime.codePoint,
        sortOrder: const Value(7),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final act in defaultActivities) {
      await into(activities).insert(act);
    }

    // Default settings
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'equilibrium_target',
        value: '0.0',
      ),
    );
    await into(appSettings).insert(
      AppSettingsCompanion.insert(
        key: 'rollover_hour',
        value: '0',
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'equinox.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
