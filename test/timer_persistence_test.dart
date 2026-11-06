import 'package:drift/native.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:equinox/data/repositories/timer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TimerRepository timerRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    timerRepo = TimerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Timer Persistence & Crash-Proof Logic Tests', () {
    test('startTimer inserts active timer with start_time', () async {
      final startTime = 1000000;
      await timerRepo.startTimer(startTimeMs: startTime);

      final active = await timerRepo.getActiveTimer();
      expect(active, isNotNull);
      expect(active!.startTime, startTime);
      expect(active.pausedAt, isNull);
      expect(active.accumulatedPausedMs, 0);

      // Verify state calculation 10 seconds later
      final state = TimerState.fromDb(active, nowMs: startTime + 10000);
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.elapsedSeconds, 10);
    });

    test('pauseTimer freezes elapsed time and records paused_at', () async {
      final startTime = 1000000;
      await timerRepo.startTimer(startTimeMs: startTime);

      // Pause 20 seconds later
      final pauseTime = startTime + 20000;
      await timerRepo.pauseTimer(nowMs: pauseTime);

      final active = await timerRepo.getActiveTimer();
      expect(active, isNotNull);
      expect(active!.pausedAt, pauseTime);

      // Verify that even if nowMs is 50 seconds later, elapsed is still 20s
      final state = TimerState.fromDb(active, nowMs: startTime + 50000);
      expect(state.isRunning, isFalse);
      expect(state.isPaused, isTrue);
      expect(state.elapsedSeconds, 20);
    });

    test('resumeTimer accumulates paused duration and clears paused_at', () async {
      final startTime = 1000000;
      await timerRepo.startTimer(startTimeMs: startTime);

      // Ran for 30s
      final pauseTime = startTime + 30000;
      await timerRepo.pauseTimer(nowMs: pauseTime);

      // Paused for 10s then resumed
      final resumeTime = pauseTime + 10000;
      await timerRepo.resumeTimer(nowMs: resumeTime);

      final active = await timerRepo.getActiveTimer();
      expect(active, isNotNull);
      expect(active!.pausedAt, isNull);
      expect(active.accumulatedPausedMs, 10000);

      // Ran for another 15s after resume (total running time = 30s + 15s = 45s)
      final state = TimerState.fromDb(active, nowMs: resumeTime + 15000);
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.elapsedSeconds, 45);
    });

    test('clearTimer deletes active timer row', () async {
      await timerRepo.startTimer();
      expect(await timerRepo.getActiveTimer(), isNotNull);

      await timerRepo.clearTimer();
      expect(await timerRepo.getActiveTimer(), isNull);
    });
  });
}
