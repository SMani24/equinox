import 'package:drift/drift.dart';

@DataClassName('Activity')
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()(); // 'productive', 'rest', 'neutral'
  RealColumn get coefficient => real()();
  IntColumn get colorHex => integer()();
  IntColumn get iconCode => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TimeEntry')
class TimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get activityId => text().references(Activities, #id)();
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer()();
  IntColumn get durationSeconds => integer()();
  RealColumn get coefficientSnapshot => real()();
  RealColumn get scoreSnapshot => real()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ActiveTimerData')
class ActiveTimers extends Table {
  IntColumn get id => integer()(); // Primary key constrained to 1
  IntColumn get startTime => integer()();
  IntColumn get accumulatedPausedMs =>
      integer().withDefault(const Constant(0))();
  IntColumn get pausedAt => integer().nullable()();
  TextColumn get preselectedActivityId => text().nullable()();
  TextColumn get draftNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
