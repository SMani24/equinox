import 'dart:math' as math;
import '../../../core/utils/date_boundary.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';

/// Represents a slice of a [TimeEntryWithActivity] clipped to a single
/// `(logicalDay, weekday, hour)` bucket.
class TimeSlice {
  final TimeEntryWithActivity source;
  final DateTime logicalDay;
  final int hour; // 0..23 local wall-clock hour
  final int weekday; // 1 (Mon)..7 (Sun)
  final int seconds;
  final double score;

  const TimeSlice({
    required this.source,
    required this.logicalDay,
    required this.hour,
    required this.weekday,
    required this.seconds,
    required this.score,
  });

  Activity get activity => source.activity;
  TimeEntry get entry => source.entry;
}

/// Pure-Dart utility that slices entries accurately across calendar hours and
/// logical day rollover boundaries, preventing overnight sessions or long blocks
/// from being dumped into a single hour or start day.
class TimeSlicer {
  static Iterable<TimeSlice> sliceEntry(
    TimeEntryWithActivity item, {
    int rolloverHour = 0,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) sync* {
    final entry = item.entry;
    final entryStartMs = entry.startTime;
    final entryEndMs = entry.endTime;
    final totalEntryMs = entryEndMs - entryStartMs;
    if (totalEntryMs <= 0) return;

    final minMs = rangeStart?.millisecondsSinceEpoch ?? entryStartMs;
    final maxMs = rangeEnd == null
        ? entryEndMs
        : (rangeEnd.millisecond == 999
            ? rangeEnd.millisecondsSinceEpoch + 1
            : rangeEnd.millisecondsSinceEpoch);

    final clampedStartMs = math.max(entryStartMs, minMs);
    final clampedEndMs = math.min(entryEndMs, maxMs);
    if (clampedEndMs <= clampedStartMs) return;

    final int effectiveTotalSeconds = entry.durationSeconds > 0
        ? entry.durationSeconds
        : (totalEntryMs / 1000.0).round();

    int cursorMs = clampedStartMs;
    double cumulativeExactSeconds = 0.0;
    int cumulativeEmittedSeconds = 0;

    while (cursorMs < clampedEndMs) {
      final cursor = DateTime.fromMillisecondsSinceEpoch(cursorMs);
      var nextHourBoundary = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        cursor.hour + 1,
      );
      if (nextHourBoundary.millisecondsSinceEpoch <= cursorMs) {
        nextHourBoundary = DateTime.fromMillisecondsSinceEpoch(
          cursorMs + const Duration(hours: 1).inMilliseconds,
        );
      }

      final segmentEndMs =
          math.min(clampedEndMs, nextHourBoundary.millisecondsSinceEpoch);
      final segmentMs = segmentEndMs - cursorMs;

      cumulativeExactSeconds += segmentMs / 1000.0;
      final targetTotalSeconds = cumulativeExactSeconds.round();
      final sliceSeconds = targetTotalSeconds - cumulativeEmittedSeconds;
      cumulativeEmittedSeconds = targetTotalSeconds;

      if (sliceSeconds > 0) {
        final logicalDay = DateBoundary.getLogicalDate(
          cursor,
          rolloverHour: rolloverHour,
        );
        final double sliceScore;
        if (effectiveTotalSeconds > 0) {
          sliceScore = entry.scoreSnapshot * (sliceSeconds / effectiveTotalSeconds);
        } else {
          sliceScore = ScoreCalculator.calculateScore(
            sliceSeconds,
            entry.coefficientSnapshot,
          );
        }

        yield TimeSlice(
          source: item,
          logicalDay: logicalDay,
          hour: cursor.hour,
          weekday: cursor.weekday,
          seconds: sliceSeconds,
          score: sliceScore,
        );
      }

      cursorMs = segmentEndMs;
    }
  }

  static List<TimeSlice> sliceEntries(
    Iterable<TimeEntryWithActivity> entries, {
    int rolloverHour = 0,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) {
    final result = <TimeSlice>[];
    for (final item in entries) {
      result.addAll(
        sliceEntry(
          item,
          rolloverHour: rolloverHour,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      );
    }
    return result;
  }
}
