import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../settings/providers/settings_provider.dart';

enum DateRangePreset { week, month, year, custom }

class AnalyticsDateRange {
  final DateRangePreset preset;
  final DateTime start;
  final DateTime end;

  const AnalyticsDateRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  factory AnalyticsDateRange.forPreset(DateRangePreset preset, {int rolloverHour = 0}) {
    final now = DateTime.now();
    final today = DateBoundary.getLogicalDate(now, rolloverHour: rolloverHour);
    final end = DateBoundary.getDayEnd(today, rolloverHour: rolloverHour);

    switch (preset) {
      case DateRangePreset.week:
        final startDay = today.subtract(const Duration(days: 6));
        final start = DateBoundary.getDayStart(startDay, rolloverHour: rolloverHour);
        return AnalyticsDateRange(preset: preset, start: start, end: end);
      case DateRangePreset.month:
        final startDay = today.subtract(const Duration(days: 29));
        final start = DateBoundary.getDayStart(startDay, rolloverHour: rolloverHour);
        return AnalyticsDateRange(preset: preset, start: start, end: end);
      case DateRangePreset.year:
        final startDay = today.subtract(const Duration(days: 364));
        final start = DateBoundary.getDayStart(startDay, rolloverHour: rolloverHour);
        return AnalyticsDateRange(preset: preset, start: start, end: end);
      case DateRangePreset.custom:
        final startDay = today.subtract(const Duration(days: 14));
        final start = DateBoundary.getDayStart(startDay, rolloverHour: rolloverHour);
        return AnalyticsDateRange(preset: preset, start: start, end: end);
    }
  }
}

class AnalyticsDateRangeNotifier extends Notifier<AnalyticsDateRange> {
  @override
  AnalyticsDateRange build() {
    final settings = ref.watch(settingsProvider);
    return AnalyticsDateRange.forPreset(
      DateRangePreset.month,
      rolloverHour: settings.rolloverHour,
    );
  }

  void setPreset(DateRangePreset preset, {int rolloverHour = 0}) {
    state = AnalyticsDateRange.forPreset(preset, rolloverHour: rolloverHour);
  }
}

final analyticsDateRangeProvider =
    NotifierProvider<AnalyticsDateRangeNotifier, AnalyticsDateRange>(
  AnalyticsDateRangeNotifier.new,
);

final analyticsEntriesStreamProvider =
    StreamProvider<List<TimeEntryWithActivity>>((ref) {
  final entryRepo = ref.watch(timeEntryRepositoryProvider);
  final range = ref.watch(analyticsDateRangeProvider);
  return entryRepo.watchEntriesBetween(range.start, range.end);
});

// Heatmap filter mode (Net Score, Productive Hours, Rest Hours)
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

// Selected day in heatmap for drill-down inspection
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
}

final selectedHeatmapDateProvider =
    NotifierProvider<SelectedHeatmapDateNotifier, DateTime?>(
  SelectedHeatmapDateNotifier.new,
);

// Data structure for a day's aggregate
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
}

// 7x24 Rhythm slot (Day of Week 0..6: Mon..Sun, Hour 0..23)
class HourlyRhythmSlot {
  final int dayOfWeek; // 1 = Mon, 7 = Sun
  final int hour; // 0..23
  int productiveSeconds = 0;
  int restSeconds = 0;
  int neutralSeconds = 0;

  HourlyRhythmSlot({required this.dayOfWeek, required this.hour});
}

// Activity distribution item
class ActivityDonutItem {
  final Activity activity;
  final int durationSeconds;
  final double totalScore;
  final double durationPercentage;

  const ActivityDonutItem({
    required this.activity,
    required this.durationSeconds,
    required this.totalScore,
    required this.durationPercentage,
  });
}

// Analytics Aggregate State
class AnalyticsSummaryData {
  final Map<DateTime, DaySummary> daySummaries;
  final List<DaySummary> recentDaysBarData;
  final List<HourlyRhythmSlot> hourlyRhythmGrid;
  final List<ActivityDonutItem> activityDonutItems;
  final int totalDurationSeconds;
  final double totalNetScore;

  const AnalyticsSummaryData({
    required this.daySummaries,
    required this.recentDaysBarData,
    required this.hourlyRhythmGrid,
    required this.activityDonutItems,
    required this.totalDurationSeconds,
    required this.totalNetScore,
  });
}

final analyticsSummaryProvider = Provider<AnalyticsSummaryData>((ref) {
  final entriesAsync = ref.watch(analyticsEntriesStreamProvider);
  final settings = ref.watch(settingsProvider);
  final entries = entriesAsync.value ?? [];

  final Map<DateTime, List<TimeEntryWithActivity>> groupedByDay = {};
  final Map<String, int> durationByActivity = {};
  final Map<String, double> scoreByActivity = {};
  final Map<String, Activity> activityMap = {};

  // Initialize 7x24 grid (Mon..Sun = 1..7, Hour 0..23)
  final Map<String, HourlyRhythmSlot> rhythmMap = {};
  for (int d = 1; d <= 7; d++) {
    for (int h = 0; h < 24; h++) {
      rhythmMap['$d-$h'] = HourlyRhythmSlot(dayOfWeek: d, hour: h);
    }
  }

  int grandTotalSeconds = 0;
  double grandTotalScore = 0.0;

  for (final item in entries) {
    final entry = item.entry;
    final act = item.activity;
    final startDt = DateTime.fromMillisecondsSinceEpoch(entry.startTime);
    final logical = DateBoundary.getLogicalDate(startDt, rolloverHour: settings.rolloverHour);

    groupedByDay.putIfAbsent(logical, () => []).add(item);

    grandTotalSeconds += entry.durationSeconds;
    grandTotalScore += entry.scoreSnapshot;

    activityMap[act.id] = act;
    durationByActivity[act.id] = (durationByActivity[act.id] ?? 0) + entry.durationSeconds;
    scoreByActivity[act.id] = (scoreByActivity[act.id] ?? 0.0) + entry.scoreSnapshot;

    // Distribute into 7x24 rhythm grid
    final dow = startDt.weekday;
    final hour = startDt.hour;
    final slot = rhythmMap['$dow-$hour'];
    if (slot != null) {
      if (act.category == 'productive') {
        slot.productiveSeconds += entry.durationSeconds;
      } else if (act.category == 'rest') {
        slot.restSeconds += entry.durationSeconds;
      } else {
        slot.neutralSeconds += entry.durationSeconds;
      }
    }
  }

  // Build DaySummary map
  final Map<DateTime, DaySummary> daySummaries = {};
  groupedByDay.forEach((day, dayEntries) {
    int prodSec = 0;
    int restSec = 0;
    int neutralSec = 0;
    double prodScore = 0.0;
    double restCost = 0.0;
    double net = 0.0;

    for (final e in dayEntries) {
      final s = e.entry.scoreSnapshot;
      final d = e.entry.durationSeconds;
      net += s;
      if (e.activity.category == 'productive') {
        prodSec += d;
        prodScore += s;
      } else if (e.activity.category == 'rest') {
        restSec += d;
        restCost += s.abs();
      } else {
        neutralSec += d;
      }
    }

    daySummaries[day] = DaySummary(
      date: day,
      netScore: net,
      grossProductive: prodScore,
      grossRest: restCost,
      productiveSeconds: prodSec,
      restSeconds: restSec,
      neutralSeconds: neutralSec,
      entries: dayEntries,
    );
  });

  // Recent 14 days for Bar Chart
  final last14Days = DateBoundary.getLastNDays(14, rolloverHour: settings.rolloverHour);
  final recentDaysBarData = last14Days.map((d) {
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

  // Donut chart items
  final List<ActivityDonutItem> donutItems = [];
  durationByActivity.forEach((actId, dur) {
    final act = activityMap[actId]!;
    final pct = grandTotalSeconds > 0 ? (dur / grandTotalSeconds) * 100 : 0.0;
    donutItems.add(
      ActivityDonutItem(
        activity: act,
        durationSeconds: dur,
        totalScore: scoreByActivity[actId] ?? 0.0,
        durationPercentage: pct,
      ),
    );
  });
  donutItems.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));

  return AnalyticsSummaryData(
    daySummaries: daySummaries,
    recentDaysBarData: recentDaysBarData,
    hourlyRhythmGrid: rhythmMap.values.toList(),
    activityDonutItems: donutItems,
    totalDurationSeconds: grandTotalSeconds,
    totalNetScore: grandTotalScore,
  );
});
