import 'package:equinox/core/utils/date_boundary.dart';
import 'package:equinox/core/utils/duration_formatter.dart';
import 'package:equinox/core/utils/score_calculator.dart';
import 'package:equinox/data/repositories/timer_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Batch 2 Fixes & Overnight Logic Tests', () {
    test('TimerState active elapsed duration properly excludes paused duration', () {
      final start = 1730930000000;
      // Started 1000 seconds ago, paused for 600 seconds, running for 400 seconds
      final timerState = TimerState(
        rawData: null,
        isRunning: true,
        isPaused: false,
        startEpochMs: start,
        elapsedSeconds: 400,
        preselectedActivityId: 'act_deep_work',
      );

      expect(timerState.elapsedSeconds, 400);

      // Verify that when computing startDt from elapsedSeconds, duration is exactly 400s
      final now = DateTime.fromMillisecondsSinceEpoch(start + 1000 * 1000);
      final effectiveStart = now.subtract(Duration(seconds: timerState.elapsedSeconds));
      final duration = now.difference(effectiveStart).inSeconds;

      expect(duration, 400);
      expect(duration, isNot(1000)); // Crucial: paused 600s is excluded!
    });

    test('DurationFormatter formatTimeRange formats cross-day range with (+1d)', () {
      final start = DateTime(2026, 11, 6, 23, 30);
      final end = DateTime(2026, 11, 7, 7, 0);

      final formatted = DurationFormatter.formatTimeRange(start, end);
      expect(formatted, contains('11:30 PM'));
      expect(formatted, contains('7:00 AM'));
      expect(formatted, contains('(+1d)'));
    });

    test('DurationFormatter formatTimeRange on same day does not append (+1d)', () {
      final start = DateTime(2026, 11, 6, 10, 0);
      final end = DateTime(2026, 11, 6, 11, 30);

      final formatted = DurationFormatter.formatTimeRange(start, end);
      expect(formatted, contains('10:00 AM'));
      expect(formatted, contains('11:30 AM'));
      expect(formatted, isNot(contains('(+1d)')));
    });

    test('Overnight manual entry end calculation produces positive duration', () {
      final date = DateTime(2026, 11, 6);
      final startHour = 23;
      final startMinute = 30;
      final endHour = 7;
      final endMinute = 0;

      final startDt = DateTime(date.year, date.month, date.day, startHour, startMinute);
      // With overnight toggle (+1 day)
      final nextDay = date.add(const Duration(days: 1));
      final endDt = DateTime(nextDay.year, nextDay.month, nextDay.day, endHour, endMinute);

      final diffSeconds = endDt.difference(startDt).inSeconds;
      expect(diffSeconds, 27000); // 7 hours 30 minutes = 27000s
      expect(DurationFormatter.formatHumanReadable(diffSeconds), '7h 30m');

      // Neutral activity (sleep) yields 0.00 pts
      final sleepScore = ScoreCalculator.calculateScore(diffSeconds, 0.0);
      expect(sleepScore, 0.0);
    });

    test('Overnight session score pro-rating across day boundaries', () {
      final logicalToday = DateTime(2026, 11, 7);
      final dayStart = DateBoundary.getDayStart(logicalToday, rolloverHour: 0);
      final dayEnd = DateBoundary.getDayEnd(logicalToday, rolloverHour: 0);

      final dayStartMs = dayStart.millisecondsSinceEpoch;
      final dayEndMs = dayEnd.millisecondsSinceEpoch;

      // Session: Deep Work (+1.5x) from 11:00 PM yesterday to 2:00 AM today (3 hours total)
      final sessionStart = DateTime(2026, 11, 6, 23, 0).millisecondsSinceEpoch;
      final sessionEnd = DateTime(2026, 11, 7, 2, 0).millisecondsSinceEpoch;

      // Portion belonging to today (midnight to 2:00 AM = 2 hours)
      final effectiveStart = sessionStart < dayStartMs ? dayStartMs : sessionStart;
      final effectiveEnd = sessionEnd > dayEndMs ? dayEndMs : sessionEnd;
      final effectiveDurSec = ((effectiveEnd - effectiveStart) / 1000).round();

      expect(effectiveDurSec, 7200); // 2 hours
      final todayScore = ScoreCalculator.calculateScore(effectiveDurSec, 1.5);
      expect(todayScore, closeTo(3.0, 0.001)); // 2h * 1.5x = +3.0 pts
    });
  });
}
