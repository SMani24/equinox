import 'dart:math' as math;
import '../../core/utils/date_boundary.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/time_entry_repository.dart';

class TimeGap {
  final DateTime start;
  final DateTime end;

  const TimeGap({required this.start, required this.end});

  int get durationSeconds => math.max(0, end.difference(start).inSeconds);
}

class SleepCatchupSuggestion {
  final DateTime start;
  final DateTime end;
  final Activity sleepActivity;

  const SleepCatchupSuggestion({
    required this.start,
    required this.end,
    required this.sleepActivity,
  });

  int get durationSeconds => math.max(0, end.difference(start).inSeconds);
}

/// Detects untracked intervals on a day's timeline, forgotten running timers,
/// missed overnight sleep catch-ups, and smart manual-entry prefill bounds.
class GapDetector {
  /// Returns merged busy intervals and untracked gaps >= [minGapMinutes]
  /// within `[rangeStart, min(rangeEnd, now)]`.
  /// When [betweenEntriesOnly] is true, returns only gaps strictly between logged
  /// sessions (plus optionally trailing gap after the last session up to [now]).
  static List<TimeGap> findGaps({
    required List<TimeEntryWithActivity> entries,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime now,
    int minGapMinutes = 15,
    bool includeLeadingBeforeFirstEntry = false,
    bool includeTrailingUpToNow = true,
  }) {
    final effectiveEndMs =
        math.min(rangeEnd.millisecondsSinceEpoch + 1, now.millisecondsSinceEpoch);
    final rangeStartMs = rangeStart.millisecondsSinceEpoch;
    if (effectiveEndMs <= rangeStartMs) return const [];

    // Clip and merge intervals within [rangeStartMs, effectiveEndMs]
    final intervals = <({int start, int end})>[];
    for (final item in entries) {
      final s = math.max(item.entry.startTime, rangeStartMs);
      final e = math.min(item.entry.endTime, effectiveEndMs);
      if (e > s) intervals.add((start: s, end: e));
    }
    if (intervals.isEmpty) {
      if (!includeLeadingBeforeFirstEntry) return const [];
      final mins = (effectiveEndMs - rangeStartMs) ~/ 60000;
      if (mins < minGapMinutes) return const [];
      return [
        TimeGap(
          start: DateTime.fromMillisecondsSinceEpoch(rangeStartMs),
          end: DateTime.fromMillisecondsSinceEpoch(effectiveEndMs),
        ),
      ];
    }

    intervals.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[intervals.first];
    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];
      final last = merged.last;
      if (next.start <= last.end) {
        merged[merged.length - 1] =
            (start: last.start, end: math.max(last.end, next.end));
      } else {
        merged.add(next);
      }
    }

    final minGapMs = minGapMinutes * 60 * 1000;
    final gaps = <TimeGap>[];

    if (includeLeadingBeforeFirstEntry &&
        merged.first.start - rangeStartMs >= minGapMs) {
      gaps.add(
        TimeGap(
          start: DateTime.fromMillisecondsSinceEpoch(rangeStartMs),
          end: DateTime.fromMillisecondsSinceEpoch(merged.first.start),
        ),
      );
    }

    for (int i = 0; i < merged.length - 1; i++) {
      final gapStart = merged[i].end;
      final gapEnd = merged[i + 1].start;
      if (gapEnd - gapStart >= minGapMs) {
        gaps.add(
          TimeGap(
            start: DateTime.fromMillisecondsSinceEpoch(gapStart),
            end: DateTime.fromMillisecondsSinceEpoch(gapEnd),
          ),
        );
      }
    }

    if (includeTrailingUpToNow &&
        effectiveEndMs - merged.last.end >= minGapMs) {
      gaps.add(
        TimeGap(
          start: DateTime.fromMillisecondsSinceEpoch(merged.last.end),
          end: DateTime.fromMillisecondsSinceEpoch(effectiveEndMs),
        ),
      );
    }

    return gaps;
  }

  /// Detects if a running timer likely was forgotten (elapsed > max(4h, p95)).
  static bool shouldWarnForgottenTimer({
    required int elapsedSeconds,
    String? preselectedActivityId,
    required List<TimeEntryWithActivity> historyEntries,
  }) {
    const minThresholdSeconds = 4 * 3600;
    if (elapsedSeconds < minThresholdSeconds) return false;

    if (preselectedActivityId == null) {
      return elapsedSeconds >= 6 * 3600;
    }

    final matching = historyEntries
        .where((e) => e.activity.id == preselectedActivityId)
        .map((e) => e.entry.durationSeconds)
        .toList()
      ..sort();

    if (matching.length < 3) {
      return elapsedSeconds >= minThresholdSeconds;
    }

    final p95Idx = ((matching.length - 1) * 0.95).ceil();
    final p95 = matching[p95Idx];
    final threshold = math.max(minThresholdSeconds, p95);
    return elapsedSeconds > threshold;
  }

  /// Checks whether today is missing an overnight sleep log and returns a suggested
  /// window based on the user's recent neutral/sleep history (or 11:30 PM -> ~now).
  static SleepCatchupSuggestion? detectMorningSleepCatchup({
    required List<Activity> activities,
    required List<TimeEntryWithActivity> recentEntries,
    required DateTime now,
    required int rolloverHour,
    String? dismissedDateKey,
  }) {
    final todayLogical =
        DateBoundary.getLogicalDate(now, rolloverHour: rolloverHour);
    final todayKey = _dateKey(todayLogical);
    if (dismissedDateKey == todayKey) return null;

    // Show catch-up prompt in morning / early afternoon hours
    if (now.hour < 5 || now.hour >= 14) return null;

    // Locate likely sleep activity
    Activity? sleepAct;
    for (final act in activities.where((a) => !a.isArchived)) {
      final lower = act.name.toLowerCase();
      if (lower.contains('sleep') ||
          lower.contains('nap') ||
          lower.contains('خواب')) {
        sleepAct = act;
        break;
      }
    }
    sleepAct ??= activities.where((a) => !a.isArchived && a.category == 'neutral').firstOrNull;
    if (sleepAct == null) return null;

    final yesterdayMidnight = DateTime(now.year, now.month, now.day - 1, 21, 0);
    final nowMs = now.millisecondsSinceEpoch;
    final windowStartMs = yesterdayMidnight.millisecondsSinceEpoch;

    // Check if any entry >= 3 hours already covers part of last night
    for (final item in recentEntries) {
      final overlapsNight =
          item.entry.endTime >= windowStartMs && item.entry.startTime <= nowMs;
      if (overlapsNight && item.entry.durationSeconds >= 3 * 3600) {
        return null;
      }
      if (overlapsNight && item.activity.id == sleepAct.id && item.entry.durationSeconds >= 3600) {
        return null;
      }
    }

    // Estimate typical bedtime hour & minute from sleepAct history >= 3h
    int bedtimeMinutes = 23 * 60 + 30; // Default 11:30 PM
    final sleepSamples = recentEntries
        .where((e) => e.activity.id == sleepAct!.id && e.entry.durationSeconds >= 3 * 3600)
        .take(14)
        .toList();

    if (sleepSamples.isNotEmpty) {
      final normalizedMins = <int>[];
      for (final s in sleepSamples) {
        final st = DateTime.fromMillisecondsSinceEpoch(s.entry.startTime);
        int mins = st.hour * 60 + st.minute;
        if (mins < 12 * 60) mins += 24 * 60; // Map 1 AM to 25:00 for averaging
        normalizedMins.add(mins);
      }
      normalizedMins.sort();
      bedtimeMinutes = normalizedMins[normalizedMins.length ~/ 2];
    }

    DateTime suggestedStart;
    if (bedtimeMinutes >= 24 * 60) {
      final minsAfterMidnight = bedtimeMinutes - 24 * 60;
      suggestedStart = DateTime(
        now.year,
        now.month,
        now.day,
        minsAfterMidnight ~/ 60,
        minsAfterMidnight % 60,
      );
    } else {
      suggestedStart = DateTime(
        now.year,
        now.month,
        now.day - 1,
        bedtimeMinutes ~/ 60,
        bedtimeMinutes % 60,
      );
    }

    // Also clamp suggestedStart after last evening session if one ended later
    for (final item in recentEntries) {
      if (item.entry.endTime > suggestedStart.millisecondsSinceEpoch &&
          item.entry.endTime < nowMs - 2 * 3600 * 1000) {
        suggestedStart = DateTime.fromMillisecondsSinceEpoch(item.entry.endTime);
      }
    }

    final suggestedEnd = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (suggestedEnd.difference(suggestedStart).inHours < 3) return null;

    return SleepCatchupSuggestion(
      start: suggestedStart,
      end: suggestedEnd,
      sleepActivity: sleepAct,
    );
  }

  /// Smart defaults for Manual Entry when opened directly (not from a specific gap):
  /// starts where the last today entry ended (if recent today), otherwise 1h before [now].
  static ({DateTime start, DateTime end}) suggestManualPrefill({
    required List<TimeEntryWithActivity> todayEntries,
    required DateTime now,
  }) {
    final end = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    if (todayEntries.isNotEmpty) {
      DateTime? latestEnd;
      for (final e in todayEntries) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.entry.endTime);
        if (!dt.isAfter(now)) {
          if (latestEnd == null || dt.isAfter(latestEnd)) {
            latestEnd = dt;
          }
        }
      }
      if (latestEnd != null) {
        final diff = end.difference(latestEnd);
        if (diff.inMinutes >= 2 && diff.inHours <= 10) {
          return (
            start: DateTime(
              latestEnd.year,
              latestEnd.month,
              latestEnd.day,
              latestEnd.hour,
              latestEnd.minute,
            ),
            end: end,
          );
        }
      }
    }
    return (start: end.subtract(const Duration(hours: 1)), end: end);
  }

  static String dateKeyFor(DateTime logicalDate) => _dateKey(logicalDate);

  static String _dateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
