import 'package:drift/drift.dart';
import '../database/app_database.dart';

class TimerState {
  final ActiveTimerData? rawData;
  final bool isRunning;
  final bool isPaused;
  final int elapsedSeconds;
  final int startEpochMs;
  final String? preselectedActivityId;
  final String? draftNote;

  const TimerState({
    required this.rawData,
    required this.isRunning,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.startEpochMs,
    this.preselectedActivityId,
    this.draftNote,
  });

  factory TimerState.idle() => const TimerState(
        rawData: null,
        isRunning: false,
        isPaused: false,
        elapsedSeconds: 0,
        startEpochMs: 0,
      );

  factory TimerState.fromDb(ActiveTimerData? data, {int? nowMs}) {
    if (data == null) return TimerState.idle();

    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final isPaused = data.pausedAt != null;

    int totalPausedMs = data.accumulatedPausedMs;
    if (isPaused && data.pausedAt != null) {
      // If currently paused, elapsed paused time is fixed at pausedAt
      final runningMs = (data.pausedAt! - data.startTime) - totalPausedMs;
      final elapsed = (runningMs / 1000).floor();
      return TimerState(
        rawData: data,
        isRunning: false,
        isPaused: true,
        elapsedSeconds: elapsed < 0 ? 0 : elapsed,
        startEpochMs: data.startTime,
        preselectedActivityId: data.preselectedActivityId,
        draftNote: data.draftNote,
      );
    } else {
      final runningMs = (now - data.startTime) - totalPausedMs;
      final elapsed = (runningMs / 1000).floor();
      return TimerState(
        rawData: data,
        isRunning: true,
        isPaused: false,
        elapsedSeconds: elapsed < 0 ? 0 : elapsed,
        startEpochMs: data.startTime,
        preselectedActivityId: data.preselectedActivityId,
        draftNote: data.draftNote,
      );
    }
  }
}

class TimerRepository {
  final AppDatabase db;

  TimerRepository(this.db);

  Stream<ActiveTimerData?> watchActiveTimer() {
    return (db.select(db.activeTimers)..where((t) => t.id.equals(1)))
        .watchSingleOrNull();
  }

  Future<ActiveTimerData?> getActiveTimer() {
    return (db.select(db.activeTimers)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
  }

  Future<void> startTimer({
    String? preselectedActivityId,
    String? draftNote,
    int? startTimeMs,
  }) async {
    final now = startTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.into(db.activeTimers).insertOnConflictUpdate(
          ActiveTimersCompanion.insert(
            id: const Value(1),
            startTime: now,
            accumulatedPausedMs: const Value(0),
            pausedAt: const Value(null),
            preselectedActivityId: Value(preselectedActivityId),
            draftNote: Value(draftNote),
          ),
        );
  }

  Future<void> pauseTimer({int? nowMs}) async {
    final current = await getActiveTimer();
    if (current == null || current.pausedAt != null) return;

    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await (db.update(db.activeTimers)..where((t) => t.id.equals(1))).write(
      ActiveTimersCompanion(
        pausedAt: Value(now),
      ),
    );
  }

  Future<void> resumeTimer({int? nowMs}) async {
    final current = await getActiveTimer();
    if (current == null || current.pausedAt == null) return;

    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final pauseDuration = now - current.pausedAt!;
    final newAccumulated = current.accumulatedPausedMs + pauseDuration;

    await (db.update(db.activeTimers)..where((t) => t.id.equals(1))).write(
      ActiveTimersCompanion(
        accumulatedPausedMs: Value(newAccumulated),
        pausedAt: const Value(null),
      ),
    );
  }

  Future<void> updateDraft({
    String? preselectedActivityId,
    String? draftNote,
  }) async {
    await (db.update(db.activeTimers)..where((t) => t.id.equals(1))).write(
      ActiveTimersCompanion(
        preselectedActivityId: Value(preselectedActivityId),
        draftNote: Value(draftNote),
      ),
    );
  }

  Future<void> clearTimer() async {
    await (db.delete(db.activeTimers)..where((t) => t.id.equals(1))).go();
  }
}
