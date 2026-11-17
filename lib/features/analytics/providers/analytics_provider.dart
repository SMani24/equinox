import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../settings/providers/settings_provider.dart';
import '../../smart/insights_engine.dart';
import '../../timer/providers/timer_provider.dart';
import '../domain/time_slicer.dart';

enum DateRangePreset { day, week, month, year }

class AnalyticsDateRange {
  final DateRangePreset preset;
  final int offset; // 0 = current window, -1 = previous window, etc.
  final DateTime start;
  final DateTime end;
  final DateTime prevStart;
  final DateTime prevEnd;
  final List<DateTime> logicalDays;

  const AnalyticsDateRange({
    required this.preset,
    this.offset = 0,
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
    required this.logicalDays,
  });

  String get formattedLabel {
    switch (preset) {
      case DateRangePreset.day:
        return DateFormat('EEE, MMM d, yyyy').format(logicalDays.first);
      case DateRangePreset.week:
      case DateRangePreset.month:
        final first = logicalDays.first;
        final last = logicalDays.last;
        if (first.month == last.month) {
          return '${DateFormat('MMM d').format(first)} – ${DateFormat('d, yyyy').format(last)}';
        }
        return '${DateFormat('MMM d').format(first)} – ${DateFormat('MMM d').format(last)}';
      case DateRangePreset.year:
        final first = logicalDays.first;
        final last = logicalDays.last;
        return '${DateFormat('MMM yyyy').format(first)} – ${DateFormat('MMM yyyy').format(last)}';
    }
  }

  factory AnalyticsDateRange.forPresetWithLogicalToday(
    DateRangePreset preset, {
    required DateTime logicalToday,
    int offset = 0,
    int rolloverHour = 0,
  }) {
    final safeOffset = offset > 0 ? 0 : offset;
    final int spanDays;
    switch (preset) {
      case DateRangePreset.day:
        spanDays = 1;
      case DateRangePreset.week:
        spanDays = 7;
      case DateRangePreset.month:
        spanDays = 30;
      case DateRangePreset.year:
        spanDays = 365;
    }

    final anchorEndDay = DateTime(
      logicalToday.year,
      logicalToday.month,
      logicalToday.day + safeOffset * spanDays,
    );
    final anchorStartDay = DateTime(
      anchorEndDay.year,
      anchorEndDay.month,
      anchorEndDay.day - (spanDays - 1),
    );
    final prevEndDay = DateTime(
      anchorStartDay.year,
      anchorStartDay.month,
      anchorStartDay.day - 1,
    );
    final prevStartDay = DateTime(
      prevEndDay.year,
      prevEndDay.month,
      prevEndDay.day - (spanDays - 1),
    );

    final logicalDays = List<DateTime>.generate(
      spanDays,
      (i) => DateTime(
        anchorStartDay.year,
        anchorStartDay.month,
        anchorStartDay.day + i,
      ),
    );

    return AnalyticsDateRange(
      preset: preset,
      offset: safeOffset,
      start: DateBoundary.getDayStart(anchorStartDay, rolloverHour: rolloverHour),
      end: DateBoundary.getDayEnd(anchorEndDay, rolloverHour: rolloverHour),
      prevStart:
          DateBoundary.getDayStart(prevStartDay, rolloverHour: rolloverHour),
      prevEnd: DateBoundary.getDayEnd(prevEndDay, rolloverHour: rolloverHour),
      logicalDays: logicalDays,
    );
  }
}

class AnalyticsDateRangeNotifier extends Notifier<AnalyticsDateRange> {
  DateRangePreset _currentPreset = DateRangePreset.week;
  int _offset = 0;

  @override
  AnalyticsDateRange build() {
    final settings = ref.watch(settingsProvider);
    final logicalDateAsync = ref.watch(currentLogicalDateProvider);
    final logicalToday = logicalDateAsync.value ??
        DateBoundary.getLogicalDate(
          DateTime.now(),
          rolloverHour: settings.rolloverHour,
        );

    return AnalyticsDateRange.forPresetWithLogicalToday(
      _currentPreset,
      logicalToday: logicalToday,
      offset: _offset,
      rolloverHour: settings.rolloverHour,
    );
  }

  void setPreset(DateRangePreset preset, {int rolloverHour = 0}) {
    _currentPreset = preset;
    _offset = 0;
    _recompute(rolloverHour: rolloverHour);
  }

  void stepPeriod(int delta, {int rolloverHour = 0}) {
    final nextOffset = _offset + delta;
    _offset = nextOffset > 0 ? 0 : nextOffset;
    _recompute(rolloverHour: rolloverHour);
  }

  void _recompute({int? rolloverHour}) {
    final settings = ref.read(settingsProvider);
    final effectiveRollover = rolloverHour ?? settings.rolloverHour;
    final logicalToday = ref.read(currentLogicalDateProvider).value ??
        DateBoundary.getLogicalDate(
          DateTime.now(),
          rolloverHour: effectiveRollover,
        );

    state = AnalyticsDateRange.forPresetWithLogicalToday(
      _currentPreset,
      logicalToday: logicalToday,
      offset: _offset,
      rolloverHour: effectiveRollover,
    );
  }
}

final analyticsDateRangeProvider =
    NotifierProvider<AnalyticsDateRangeNotifier, AnalyticsDateRange>(
  AnalyticsDateRangeNotifier.new,
);

/// Watches entries covering BOTH the selected range and its preceding comparison period.
final analyticsEntriesStreamProvider =
    StreamProvider<List<TimeEntryWithActivity>>((ref) {
  final entryRepo = ref.watch(timeEntryRepositoryProvider);
  final range = ref.watch(analyticsDateRangeProvider);
  return entryRepo.watchEntriesBetween(range.prevStart, range.end);
});

/// Watches all historical entries for streak & records calculation.
final allEntriesStreamProvider =
    StreamProvider<List<TimeEntryWithActivity>>((ref) {
  final entryRepo = ref.watch(timeEntryRepositoryProvider);
  return entryRepo.watchEntriesBetween(
    DateTime(2020, 1, 1),
    DateTime(2100, 1, 1),
  );
});

enum HeatmapMetric { netScore, productiveHours, restHours }

class HeatmapMetricNotifier extends Notifier<HeatmapMetric> {
  @override
  HeatmapMetric build() => HeatmapMetric.netScore;

  void setMetric(HeatmapMetric metric) => state = metric;
}

final heatmapMetricProvider =
    NotifierProvider<HeatmapMetricNotifier, HeatmapMetric>(
  HeatmapMetricNotifier.new,
);

class RhythmActivityFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActivityId(String? id) => state = id;
}

final rhythmActivityFilterProvider =
    NotifierProvider<RhythmActivityFilterNotifier, String?>(
  RhythmActivityFilterNotifier.new,
);

class SelectedHeatmapDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void toggleDate(DateTime date) {
    if (state != null &&
        state!.year == date.year &&
        state!.month == date.month &&
        state!.day == date.day) {
      state = null;
    } else {
      state = date;
    }
  }

  void clear() => state = null;
}

final selectedHeatmapDateProvider =
    NotifierProvider<SelectedHeatmapDateNotifier, DateTime?>(
  SelectedHeatmapDateNotifier.new,
);

class DaySummary {
  final DateTime date;
  final double netScore;
  final double grossProductive;
  final double grossRest;
  final int productiveSeconds;
  final int restSeconds;
  final int neutralSeconds;
  final List<TimeEntryWithActivity> entries;

  const DaySummary({
    required this.date,
    required this.netScore,
    required this.grossProductive,
    required this.grossRest,
    required this.productiveSeconds,
    required this.restSeconds,
    required this.neutralSeconds,
    required this.entries,
  });

  int get totalSeconds => productiveSeconds + restSeconds + neutralSeconds;
}

class HourlyRhythmSlot {
  final int dayOfWeek; // 1 = Mon, 7 = Sun
  final int hour; // 0..23
  int productiveSeconds = 0;
  int restSeconds = 0;
  int neutralSeconds = 0;
  int dayCount = 0;

  HourlyRhythmSlot({required this.dayOfWeek, required this.hour});

  int get totalSeconds => productiveSeconds + restSeconds + neutralSeconds;
}

class ActivityDonutItem {
  final Activity activity;
  final int durationSeconds;
  final double totalScore;
  final double durationPercentage;
  final List<int> recent14DaySeconds;

  const ActivityDonutItem({
    required this.activity,
    required this.durationSeconds,
    required this.totalScore,
    required this.durationPercentage,
    this.recent14DaySeconds = const [],
  });
}

class StreaksData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? bestDay;
  final double bestDayScore;
  final TimeEntryWithActivity? longestFocusSession;

  const StreaksData({
    required this.currentStreak,
    required this.longestStreak,
    this.bestDay,
    this.bestDayScore = 0.0,
    this.longestFocusSession,
  });
}

class AnalyticsSummaryData {
  final Map<DateTime, DaySummary> daySummaries;
  final List<DaySummary> recentDaysBarData;
  final List<double> rollingNetSeries;
  final List<HourlyRhythmSlot> hourlyRhythmGrid;
  final List<ActivityDonutItem> activityDonutItems;
  final int totalDurationSeconds;
  final int productiveSeconds;
  final int restSeconds;
  final int neutralSeconds;
  final double totalNetScore;
  final double previousNetScore;
  final int previousDurationSeconds;
  final int goalHitDays;
  final int activeDaysCount;
  final List<TimeSlice> currentSlices;
  final List<TimeSlice> previousSlices;

  const AnalyticsSummaryData({
    required this.daySummaries,
    required this.recentDaysBarData,
    this.rollingNetSeries = const [],
    required this.hourlyRhythmGrid,
    required this.activityDonutItems,
    required this.totalDurationSeconds,
    this.productiveSeconds = 0,
    this.restSeconds = 0,
    this.neutralSeconds = 0,
    required this.totalNetScore,
    this.previousNetScore = 0.0,
    this.previousDurationSeconds = 0,
    this.goalHitDays = 0,
    this.activeDaysCount = 0,
    this.currentSlices = const [],
    this.previousSlices = const [],
  });
}

final analyticsSummaryProvider = Provider<AnalyticsSummaryData>((ref) {
  final entriesAsync = ref.watch(analyticsEntriesStreamProvider);
  final settings = ref.watch(settingsProvider);
  final range = ref.watch(analyticsDateRangeProvider);
  final rhythmFilterActId = ref.watch(rhythmActivityFilterProvider);
  final entries = entriesAsync.value ?? [];

  // Accurate pro-rated slices strictly clipped to current range & prev range
  final currentSlices = TimeSlicer.sliceEntries(
    entries,
    rolloverHour: settings.rolloverHour,
    rangeStart: range.start,
    rangeEnd: range.end,
  );
  final previousSlices = TimeSlicer.sliceEntries(
    entries,
    rolloverHour: settings.rolloverHour,
    rangeStart: range.prevStart,
    rangeEnd: range.prevEnd,
  );

  // Group overlapping entries per logical day for drill-down list
  final Map<DateTime, Set<String>> seenEntryIdsPerDay = {};
  final Map<DateTime, List<TimeEntryWithActivity>> entriesByDay = {};
  final Map<DateTime, ({int pSec, int rSec, int nSec, double pScore, double rCost, double net})> dayAgg = {};
  final Map<String, int> durationByActivity = {};
  final Map<String, double> scoreByActivity = {};
  final Map<String, Activity> activityMap = {};

  final Map<String, HourlyRhythmSlot> rhythmMap = {};
  for (int d = 1; d <= 7; d++) {
    for (int h = 0; h < 24; h++) {
      rhythmMap['$d-$h'] = HourlyRhythmSlot(dayOfWeek: d, hour: h);
    }
  }

  int grandTotalSeconds = 0;
  int prodSecondsTotal = 0;
  int restSecondsTotal = 0;
  int neutralSecondsTotal = 0;
  double grandTotalScore = 0.0;

  for (final s in currentSlices) {
    grandTotalSeconds += s.seconds;
    grandTotalScore += s.score;

    final cat = s.activity.category;
    if (cat == 'productive') {
      prodSecondsTotal += s.seconds;
    } else if (cat == 'rest') {
      restSecondsTotal += s.seconds;
    } else {
      neutralSecondsTotal += s.seconds;
    }

    final prevD = dayAgg[s.logicalDay] ??
        (pSec: 0, rSec: 0, nSec: 0, pScore: 0.0, rCost: 0.0, net: 0.0);
    dayAgg[s.logicalDay] = (
      pSec: prevD.pSec + (cat == 'productive' ? s.seconds : 0),
      rSec: prevD.rSec + (cat == 'rest' ? s.seconds : 0),
      nSec: prevD.nSec + (cat != 'productive' && cat != 'rest' ? s.seconds : 0),
      pScore: prevD.pScore + (cat == 'productive' ? s.score : 0.0),
      rCost: prevD.rCost + (cat == 'rest' ? s.score.abs() : 0.0),
      net: prevD.net + s.score,
    );

    final seenSet = seenEntryIdsPerDay.putIfAbsent(s.logicalDay, () => {});
    if (seenSet.add(s.entry.id)) {
      entriesByDay.putIfAbsent(s.logicalDay, () => []).add(s.source);
    }

    activityMap[s.activity.id] = s.activity;
    durationByActivity[s.activity.id] =
        (durationByActivity[s.activity.id] ?? 0) + s.seconds;
    scoreByActivity[s.activity.id] =
        (scoreByActivity[s.activity.id] ?? 0.0) + s.score;

    // Accumulate 7x24 pro-rated grid (respecting optional activity filter)
    if (rhythmFilterActId == null || rhythmFilterActId == s.activity.id) {
      final slot = rhythmMap['${s.weekday}-${s.hour}'];
      if (slot != null) {
        if (cat == 'productive') {
          slot.productiveSeconds += s.seconds;
        } else if (cat == 'rest') {
          slot.restSeconds += s.seconds;
        } else {
          slot.neutralSeconds += s.seconds;
        }
      }
    }
  }

  final Map<DateTime, DaySummary> daySummaries = {};
  int goalHitDays = 0;
  for (final d in range.logicalDays) {
    final agg = dayAgg[d];
    if (agg != null) {
      if (agg.net >= settings.equilibriumTarget - 0.001) {
        goalHitDays++;
      }
      daySummaries[d] = DaySummary(
        date: d,
        netScore: agg.net,
        grossProductive: agg.pScore,
        grossRest: agg.rCost,
        productiveSeconds: agg.pSec,
        restSeconds: agg.rSec,
        neutralSeconds: agg.nSec,
        entries: entriesByDay[d] ?? const [],
      );
    }
  }

  // Bar series matching active preset:
  // - Day/Week/Month -> show range days (capped neatly or full 30 days)
  // - Year -> show last 30 days bar data for legibility (while calendar year grid shows all 365)
  final barDays = range.logicalDays.length > 31
      ? range.logicalDays.sublist(range.logicalDays.length - 30)
      : range.logicalDays;

  final recentDaysBarData = barDays.map((d) {
    return daySummaries[d] ??
        DaySummary(
          date: d,
          netScore: 0.0,
          grossProductive: 0.0,
          grossRest: 0.0,
          productiveSeconds: 0,
          restSeconds: 0,
          neutralSeconds: 0,
          entries: const [],
        );
  }).toList();

  // Rolling 7-day average net line aligned with barDays
  final List<double> rollingNet = [];
  for (int i = 0; i < recentDaysBarData.length; i++) {
    final windowStart = math.max(0, i - 6);
    double sum = 0.0;
    for (int j = windowStart; j <= i; j++) {
      sum += recentDaysBarData[j].netScore;
    }
    rollingNet.add(sum / (i - windowStart + 1));
  }

  // Build 14-day sparklines per activity relative to logicalToday
  final last14Days =
      DateBoundary.getLastNDays(14, rolloverHour: settings.rolloverHour);
  final sparkStart =
      DateBoundary.getDayStart(last14Days.first, rolloverHour: settings.rolloverHour);
  final sparkEnd =
      DateBoundary.getDayEnd(last14Days.last, rolloverHour: settings.rolloverHour);
  final sparkSlices = TimeSlicer.sliceEntries(
    entries,
    rolloverHour: settings.rolloverHour,
    rangeStart: sparkStart,
    rangeEnd: sparkEnd,
  );
  final Map<String, Map<DateTime, int>> sparkSecMap = {};
  for (final s in sparkSlices) {
    final actDays = sparkSecMap.putIfAbsent(s.activity.id, () => {});
    actDays[s.logicalDay] = (actDays[s.logicalDay] ?? 0) + s.seconds;
  }

  final List<ActivityDonutItem> donutItems = [];
  durationByActivity.forEach((actId, dur) {
    final act = activityMap[actId]!;
    final pct = grandTotalSeconds > 0 ? (dur / grandTotalSeconds) * 100 : 0.0;
    final actSpark = sparkSecMap[actId];
    final sparkSeries = last14Days.map((d) => actSpark?[d] ?? 0).toList();
    donutItems.add(
      ActivityDonutItem(
        activity: act,
        durationSeconds: dur,
        totalScore: scoreByActivity[actId] ?? 0.0,
        durationPercentage: pct,
        recent14DaySeconds: sparkSeries,
      ),
    );
  });
  donutItems.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));

  double prevNetScore = 0.0;
  int prevDurationSeconds = 0;
  for (final s in previousSlices) {
    prevNetScore += s.score;
    prevDurationSeconds += s.seconds;
  }

  return AnalyticsSummaryData(
    daySummaries: daySummaries,
    recentDaysBarData: recentDaysBarData,
    rollingNetSeries: rollingNet,
    hourlyRhythmGrid: rhythmMap.values.toList(),
    activityDonutItems: donutItems,
    totalDurationSeconds: grandTotalSeconds,
    productiveSeconds: prodSecondsTotal,
    restSeconds: restSecondsTotal,
    neutralSeconds: neutralSecondsTotal,
    totalNetScore: grandTotalScore,
    previousNetScore: prevNetScore,
    previousDurationSeconds: prevDurationSeconds,
    goalHitDays: goalHitDays,
    activeDaysCount: dayAgg.length,
    currentSlices: currentSlices,
    previousSlices: previousSlices,
  );
});

/// Global streaks & personal records computed from all history.
final streaksProvider = Provider<StreaksData>((ref) {
  final entries = ref.watch(allEntriesStreamProvider).value ?? [];
  final settings = ref.watch(settingsProvider);
  if (entries.isEmpty) {
    return const StreaksData(currentStreak: 0, longestStreak: 0);
  }

  final slices = TimeSlicer.sliceEntries(
    entries,
    rolloverHour: settings.rolloverHour,
  );

  final Map<DateTime, double> netByDay = {};
  for (final s in slices) {
    netByDay[s.logicalDay] = (netByDay[s.logicalDay] ?? 0.0) + s.score;
  }

  TimeEntryWithActivity? longestFocus;
  for (final e in entries) {
    if (e.activity.category == 'productive') {
      if (longestFocus == null ||
          e.entry.durationSeconds > longestFocus.entry.durationSeconds) {
        longestFocus = e;
      }
    }
  }

  DateTime? bestDay;
  double bestDayScore = double.negativeInfinity;
  netByDay.forEach((d, score) {
    if (score > bestDayScore) {
      bestDayScore = score;
      bestDay = d;
    }
  });

  final sortedDays = netByDay.keys.toList()..sort();
  final target = settings.equilibriumTarget;
  int longestStreak = 0;
  int running = 0;
  DateTime? prevDate;

  for (final day in sortedDays) {
    final hit = (netByDay[day] ?? 0.0) >= target - 0.001;
    final contiguous = prevDate != null &&
        DateTime.utc(day.year, day.month, day.day)
                .difference(DateTime.utc(prevDate.year, prevDate.month, prevDate.day))
                .inDays ==
            1;
    if (hit) {
      running = (prevDate == null || contiguous) ? running + 1 : 1;
      if (running > longestStreak) longestStreak = running;
    } else {
      running = 0;
    }
    prevDate = day;
  }

  // Current streak ending today (or yesterday if today hasn't ended/hit yet)
  final logicalToday = ref.watch(currentLogicalDateProvider).value ??
      DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );
  int currentStreak = 0;
  DateTime cursor = logicalToday;
  final todayHit = (netByDay[cursor] ?? double.negativeInfinity) >= target - 0.001;
  if (!todayHit) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  while (netByDay.containsKey(cursor) &&
      (netByDay[cursor] ?? double.negativeInfinity) >= target - 0.001) {
    currentStreak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }

  return StreaksData(
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    bestDay: bestDay,
    bestDayScore: bestDayScore == double.negativeInfinity ? 0.0 : bestDayScore,
    longestFocusSession: longestFocus,
  );
});

/// Calendar grid day-map over past 365 days (for the Year contribution grid).
final yearCalendarSummariesProvider = Provider<Map<DateTime, DaySummary>>((ref) {
  final entries = ref.watch(allEntriesStreamProvider).value ?? [];
  final settings = ref.watch(settingsProvider);
  final logicalToday = ref.watch(currentLogicalDateProvider).value ??
      DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );

  final startDay = DateTime(
    logicalToday.year,
    logicalToday.month,
    logicalToday.day - 364,
  );
  final rangeStart = DateBoundary.getDayStart(startDay, rolloverHour: settings.rolloverHour);
  final rangeEnd = DateBoundary.getDayEnd(logicalToday, rolloverHour: settings.rolloverHour);

  final slices = TimeSlicer.sliceEntries(
    entries,
    rolloverHour: settings.rolloverHour,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );

  final Map<DateTime, ({int pSec, int rSec, int nSec, double pScore, double rCost, double net})> agg = {};
  for (final s in slices) {
    final cat = s.activity.category;
    final prev = agg[s.logicalDay] ??
        (pSec: 0, rSec: 0, nSec: 0, pScore: 0.0, rCost: 0.0, net: 0.0);
    agg[s.logicalDay] = (
      pSec: prev.pSec + (cat == 'productive' ? s.seconds : 0),
      rSec: prev.rSec + (cat == 'rest' ? s.seconds : 0),
      nSec: prev.nSec + (cat != 'productive' && cat != 'rest' ? s.seconds : 0),
      pScore: prev.pScore + (cat == 'productive' ? s.score : 0.0),
      rCost: prev.rCost + (cat == 'rest' ? s.score.abs() : 0.0),
      net: prev.net + s.score,
    );
  }

  return agg.map((d, a) => MapEntry(
        d,
        DaySummary(
          date: d,
          netScore: a.net,
          grossProductive: a.pScore,
          grossRest: a.rCost,
          productiveSeconds: a.pSec,
          restSeconds: a.rSec,
          neutralSeconds: a.nSec,
          entries: const [],
        ),
      ));
});

/// Generated insights for the active Insights period.
final insightsProvider = Provider<List<InsightCardData>>((ref) {
  final summary = ref.watch(analyticsSummaryProvider);
  final settings = ref.watch(settingsProvider);
  final streaks = ref.watch(streaksProvider);

  return InsightsEngine.generate(
    currentSlices: summary.currentSlices,
    previousSlices: summary.previousSlices,
    dailyTargetGoal: settings.equilibriumTarget,
    currentGoalStreak: streaks.currentStreak,
    dailyRestBudget: settings.dailyRestBudget,
  );
});

/// Activity weekly hours & 14-day sparklines for the Activities list screen.
final activityWeeklyStatsProvider =
    Provider<Map<String, ({int weekSeconds, List<int> spark14Days})>>((ref) {
  final history = ref.watch(recentHistoryEntriesProvider).value ?? [];
  final settings = ref.watch(settingsProvider);
  final days14 = DateBoundary.getLastNDays(14, rolloverHour: settings.rolloverHour);
  final start = DateBoundary.getDayStart(days14.first, rolloverHour: settings.rolloverHour);
  final end = DateBoundary.getDayEnd(days14.last, rolloverHour: settings.rolloverHour);
  final weekCutoff = days14[7]; // last 7 days

  final slices = TimeSlicer.sliceEntries(
    history,
    rolloverHour: settings.rolloverHour,
    rangeStart: start,
    rangeEnd: end,
  );

  final Map<String, Map<DateTime, int>> byActDay = {};
  for (final s in slices) {
    final map = byActDay.putIfAbsent(s.activity.id, () => {});
    map[s.logicalDay] = (map[s.logicalDay] ?? 0) + s.seconds;
  }

  return byActDay.map((actId, dayMap) {
    int weekSec = 0;
    final spark = <int>[];
    for (final d in days14) {
      final sec = dayMap[d] ?? 0;
      spark.add(sec);
      if (!d.isBefore(weekCutoff)) {
        weekSec += sec;
      }
    }
    return MapEntry(actId, (weekSeconds: weekSec, spark14Days: spark));
  });
});
