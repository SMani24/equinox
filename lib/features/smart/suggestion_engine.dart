import 'dart:math' as math;
import '../../core/utils/duration_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/time_entry_repository.dart';

class ActivitySuggestion {
  final Activity activity;
  final double score;
  final String? reason;

  const ActivitySuggestion({
    required this.activity,
    required this.score,
    this.reason,
  });
}

/// On-device context-aware activity ranker using historical local sessions.
/// Pure Dart, deterministic, and offline.
class SuggestionEngine {
  static List<ActivitySuggestion> rankActivities({
    required List<Activity> activities,
    required List<TimeEntryWithActivity> historyEntries,
    required DateTime now,
    TimeEntryWithActivity? previousEntry,
    int? sessionDurationSeconds,
  }) {
    final active = activities.where((a) => !a.isArchived).toList();
    if (active.isEmpty) return const [];

    // Cold start fallback: use user's custom sortOrder with duration heuristics
    if (historyEntries.length < 10) {
      return _coldStartRank(
        active,
        sessionDurationSeconds: sessionDurationSeconds,
      );
    }

    final cutoffMs =
        now.subtract(const Duration(days: 60)).millisecondsSinceEpoch;
    final recentEntries = historyEntries
        .where((e) => e.entry.startTime >= cutoffMs)
        .toList()
      ..sort((a, b) => a.entry.startTime.compareTo(b.entry.startTime));

    if (recentEntries.length < 10) {
      return _coldStartRank(
        active,
        sessionDurationSeconds: sessionDurationSeconds,
      );
    }

    final nowMinOfDay = now.hour * 60 + now.minute;
    final isNowWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    // 1. P_hour (Gaussian around time-of-day weighted by minutes)
    final Map<String, double> hourMass = {for (final a in active) a.id: 0.0};
    // 2. P_weekday
    final Map<String, double> weekdayMass = {for (final a in active) a.id: 0.0};
    // 3. P_next (Markov transitions within 2 hours of previous end)
    final Map<String, int> transitionCounts = {for (final a in active) a.id: 0};
    int totalTransitions = 0;
    // 4. Recency & durations per activity
    final Map<String, int> lastEndMs = {};
    final Map<String, List<int>> durationsByActivity = {};

    for (int i = 0; i < recentEntries.length; i++) {
      final item = recentEntries[i];
      final id = item.activity.id;
      if (!hourMass.containsKey(id)) continue;

      final startDt =
          DateTime.fromMillisecondsSinceEpoch(item.entry.startTime);
      final durSec = math.max(60, item.entry.durationSeconds);
      final midDt = startDt.add(Duration(seconds: durSec ~/ 2));
      final midMinOfDay = midDt.hour * 60 + midDt.minute;

      // Circular distance in minutes (0..720)
      int delta = (midMinOfDay - nowMinOfDay).abs();
      if (delta > 720) delta = 1440 - delta;

      const sigma = 60.0;
      final kernel = math.exp(-(delta * delta) / (2 * sigma * sigma));
      final minsWeight = math.min(durSec / 60.0, 240.0);
      hourMass[id] = (hourMass[id] ?? 0.0) + kernel * minsWeight;

      final entryWeekend =
          startDt.weekday == DateTime.saturday ||
          startDt.weekday == DateTime.sunday;
      if (entryWeekend == isNowWeekend) {
        weekdayMass[id] = (weekdayMass[id] ?? 0.0) + minsWeight;
      }

      if ((lastEndMs[id] ?? 0) < item.entry.endTime) {
        lastEndMs[id] = item.entry.endTime;
      }
      durationsByActivity.putIfAbsent(id, () => []).add(item.entry.durationSeconds);

      if (previousEntry != null && i > 0) {
        final prev = recentEntries[i - 1];
        if (prev.activity.id == previousEntry.activity.id) {
          final gapMs = item.entry.startTime - prev.entry.endTime;
          if (gapMs >= -60000 && gapMs <= const Duration(hours: 2).inMilliseconds) {
            transitionCounts[id] = (transitionCounts[id] ?? 0) + 1;
            totalTransitions++;
          }
        }
      }
    }

    final totalHourMass = hourMass.values.fold(0.0, (a, b) => a + b);
    final totalWeekdayMass = weekdayMass.values.fold(0.0, (a, b) => a + b);

    final hasDuration =
        sessionDurationSeconds != null && sessionDurationSeconds > 0;
    const double w1 = 0.30; // Hour of day
    const double w2 = 0.10; // Weekday/weekend
    const double w3 = 0.25; // Sequence habit
    const double w4 = 0.15; // Recency
    final double w5 = hasDuration ? 0.20 : 0.0;
    final double wSum = w1 + w2 + w3 + w4 + w5;

    final nowMs = now.millisecondsSinceEpoch;
    final List<ActivitySuggestion> ranked = [];

    for (final act in active) {
      final id = act.id;

      final pHour =
          totalHourMass > 0 ? (hourMass[id] ?? 0.0) / totalHourMass : 0.0;
      final pWeekday =
          totalWeekdayMass > 0 ? (weekdayMass[id] ?? 0.0) / totalWeekdayMass : 0.0;
      final pNext = (previousEntry != null && totalTransitions > 0)
          ? ((transitionCounts[id] ?? 0) + 0.5) /
              (totalTransitions + 0.5 * active.length)
          : 0.0;

      final lastMs = lastEndMs[id];
      final daysSince = lastMs != null
          ? math.max(0.0, (nowMs - lastMs) / Duration.millisecondsPerDay)
          : 60.0;
      final recency = lastMs != null ? math.exp(-daysSince / 7.0) : 0.0;

      double durationFit = 0.0;
      if (hasDuration) {
        final durs = durationsByActivity[id];
        if (durs != null && durs.length >= 2) {
          final sortedLog = durs
              .map((d) => math.log(math.max(10, d).toDouble()))
              .toList()
            ..sort();
          final medianLog = sortedLog[sortedLog.length ~/ 2];
          final targetLog = math.log(math.max(10, sessionDurationSeconds).toDouble());
          final diffLog = (targetLog - medianLog).abs();
          // +/- ~1 log unit matches smoothly
          durationFit = math.exp(-(diffLog * diffLog) / (2 * 0.85 * 0.85));
        } else if (sessionDurationSeconds >= 4 * 3600 && act.category == 'neutral') {
          durationFit = 0.7;
        }
      }

      // Normalize components roughly to comparable [0..1] scale
      final hourContrib = w1 * math.min(1.0, pHour * active.length * 0.5);
      final weekContrib = w2 * math.min(1.0, pWeekday * active.length * 0.5);
      final nextContrib = w3 * math.min(1.0, pNext * active.length * 0.6);
      final recencyContrib = w4 * recency;
      final durContrib = w5 * durationFit;

      final totalScore =
          (hourContrib + weekContrib + nextContrib + recencyContrib + durContrib) /
              wSum;

      String? reason;
      final candidates = <({double val, String label})>[
        if (hourContrib > 0.08)
          (val: hourContrib, label: 'Usually at this time'),
        if (nextContrib > 0.08 && previousEntry != null)
          (val: nextContrib, label: 'Often after ${previousEntry.activity.name}'),
        if (durContrib > 0.08 && hasDuration)
          (
            val: durContrib,
            label:
                'Fits ${DurationFormatter.formatHumanReadable(sessionDurationSeconds)}'
          ),
        if (recencyContrib > 0.08) (val: recencyContrib, label: 'Recently used'),
      ];
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.val.compareTo(a.val));
        reason = candidates.first.label;
      }

      ranked.add(
        ActivitySuggestion(activity: act, score: totalScore, reason: reason),
      );
    }

    ranked.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.activity.sortOrder.compareTo(b.activity.sortOrder);
    });

    return ranked;
  }

  static List<ActivitySuggestion> _coldStartRank(
    List<Activity> active, {
    int? sessionDurationSeconds,
  }) {
    final list = List<Activity>.from(active);
    list.sort((a, b) {
      if (sessionDurationSeconds != null && sessionDurationSeconds >= 4 * 3600) {
        final aNeutral = a.category == 'neutral' ? 0 : 1;
        final bNeutral = b.category == 'neutral' ? 0 : 1;
        if (aNeutral != bNeutral) return aNeutral.compareTo(bNeutral);
      }
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return List.generate(list.length, (i) {
      return ActivitySuggestion(
        activity: list[i],
        score: 1.0 - (i / math.max(1, list.length)),
        reason: null,
      );
    });
  }
}
