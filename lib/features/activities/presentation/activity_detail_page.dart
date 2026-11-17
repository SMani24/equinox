import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/activity_avatar.dart';
import '../../../core/ui/duration_text.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/eq_card.dart';
import '../../../core/ui/score_pill.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../../analytics/domain/time_slicer.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../timer/presentation/widgets/edit_entry_sheet.dart';
import '../providers/activities_provider.dart';
import 'activity_form_sheet.dart';

/// Deep-dive statistics and session history page for a single activity.
class ActivityDetailPage extends ConsumerWidget {
  final Activity activity;

  const ActivityDetailPage({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = context.eq;
    final allActivities = ref.watch(allActivitiesStreamProvider).value ?? [];
    final liveActivity = allActivities.firstWhere(
      (a) => a.id == activity.id,
      orElse: () => activity,
    );
    final activeActivities = allActivities.where((a) => !a.isArchived).toList();
    final allEntries = ref.watch(allEntriesStreamProvider).value ?? [];
    final settings = ref.watch(settingsProvider);

    final matchingEntries = allEntries
        .where((e) => e.activity.id == liveActivity.id)
        .toList()
      ..sort((a, b) => b.entry.startTime.compareTo(a.entry.startTime));

    final int totalSeconds =
        matchingEntries.fold(0, (s, e) => s + e.entry.durationSeconds);
    final double totalScore =
        matchingEntries.fold(0.0, (s, e) => s + e.entry.scoreSnapshot);
    final int avgSeconds =
        matchingEntries.isNotEmpty ? totalSeconds ~/ matchingEntries.length : 0;
    final int longestSeconds = matchingEntries.fold(
      0,
      (m, e) => math.max(m, e.entry.durationSeconds),
    );

    final slices = TimeSlicer.sliceEntries(
      matchingEntries,
      rolloverHour: settings.rolloverHour,
    );

    // 14-day series
    final last14 = DateBoundary.getLastNDays(14, rolloverHour: settings.rolloverHour);
    final Map<DateTime, int> secByDay = {};
    final List<int> hourHist = List<int>.filled(24, 0);
    final List<int> dowHist = List<int>.filled(7, 0);

    for (final s in slices) {
      secByDay[s.logicalDay] = (secByDay[s.logicalDay] ?? 0) + s.seconds;
      hourHist[s.hour] += s.seconds;
      dowHist[s.weekday - 1] += s.seconds;
    }

    final actColor = Color(liveActivity.colorHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(liveActivity.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit activity',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ActivityFormSheet(
                  activityToEdit: liveActivity,
                  existingActivities: allActivities,
                  onSave: ({
                    required name,
                    required category,
                    required coefficient,
                    required colorHex,
                    required iconCode,
                    bool recalculatePast = false,
                  }) async {
                    await ref.read(activityRepositoryProvider).updateActivity(
                          id: liveActivity.id,
                          name: name,
                          category: category,
                          coefficient: coefficient,
                          colorHex: colorHex,
                          iconCode: iconCode,
                          recalculatePastEntries: recalculatePast,
                        );
                  },
                  onDelete: () {
                    ref
                        .read(activityRepositoryProvider)
                        .deleteActivity(liveActivity.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          // Header Card
          EqCard(
            accentTint: actColor,
            child: Row(
              children: [
                ActivityAvatar(
                  iconCode: liveActivity.iconCode,
                  colorHex: liveActivity.colorHex,
                  size: 52,
                  iconSize: 26,
                  radius: 16,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveActivity.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ScoreCalculator.formatCoefficient(liveActivity.coefficient)} • ${liveActivity.category[0].toUpperCase()}${liveActivity.category.substring(1)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: eq.forCategory(liveActivity.category),
                        ),
                      ),
                    ],
                  ),
                ),
                ScorePill(score: totalScore),
              ],
            ),
          ),
          const SizedBox(height: Space.md),

          // 4 KPI Grid
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Total logged',
                  value: DurationFormatter.formatHumanReadable(totalSeconds),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _KpiCard(
                  label: 'Sessions',
                  value: '${matchingEntries.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Avg session',
                  value: DurationFormatter.formatHumanReadable(avgSeconds),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _KpiCard(
                  label: 'Longest',
                  value: DurationFormatter.formatHumanReadable(longestSeconds),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),

          // 14-day Trend Bar Chart
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last 14 days',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Space.md),
                SizedBox(
                  height: 130,
                  child: _build14DayChart(context, last14, secByDay, actColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          // Time-of-Day Histogram
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Typical time of day',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Space.md),
                _buildHourHistogram(context, hourHist, actColor),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          // Weekday Breakdown
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day of week',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Space.md),
                _buildWeekdayBars(context, dowHist, actColor),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          Text(
            'Recent sessions (${matchingEntries.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Space.sm),

          if (matchingEntries.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              title: 'No sessions yet',
              body: 'Start a timer with this activity to build insights here.',
            )
          else
            ...matchingEntries.take(25).map((item) {
              final startDt =
                  DateTime.fromMillisecondsSinceEpoch(item.entry.startTime);
              final endDt =
                  DateTime.fromMillisecondsSinceEpoch(item.entry.endTime);
              return EqCard(
                margin: const EdgeInsets.only(bottom: Space.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.md,
                  vertical: 10,
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditEntrySheet(
                      item: item,
                      activities: activeActivities,
                      onSave: ({
                        required entryId,
                        required activityId,
                        required startTime,
                        required endTime,
                        note,
                      }) {
                        ref.read(timeEntryRepositoryProvider).updateEntry(
                              id: entryId,
                              activityId: activityId,
                              startTime: startTime,
                              endTime: endTime,
                              note: note,
                            );
                      },
                      onDelete: () {
                        ref
                            .read(timeEntryRepositoryProvider)
                            .deleteEntry(item.entry.id);
                      },
                    ),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEE, MMM d').format(startDt),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            DurationFormatter.formatTimeRange(startDt, endDt),
                            style: TextStyle(fontSize: 12, color: eq.textMuted),
                          ),
                          if (item.entry.note != null &&
                              item.entry.note!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                item.entry.note!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: eq.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ScorePill(
                          score: item.entry.scoreSnapshot,
                          compact: true,
                        ),
                        const SizedBox(height: 3),
                        DurationText(
                          item.entry.durationSeconds,
                          style: TextStyle(fontSize: 11, color: eq.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _build14DayChart(
    BuildContext context,
    List<DateTime> days,
    Map<DateTime, int> secByDay,
    Color color,
  ) {
    final eq = context.eq;
    double maxHours = 1.0;
    for (final d in days) {
      final h = (secByDay[d] ?? 0) / 3600.0;
      if (h > maxHours) maxHours = h;
    }
    maxHours = (maxHours * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: maxHours,
        minY: 0,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: eq.textMuted.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => v == 0
                  ? const SizedBox.shrink()
                  : Text(
                      '${v.toStringAsFixed(0)}h',
                      style: TextStyle(fontSize: 10, color: eq.textMuted),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= days.length || idx % 3 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d').format(days[idx]),
                    style: TextStyle(fontSize: 10, color: eq.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(days.length, (i) {
          final h = (secByDay[days[i]] ?? 0) / 3600.0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: h,
                color: color,
                width: 9,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHourHistogram(
    BuildContext context,
    List<int> hourHist,
    Color color,
  ) {
    final eq = context.eq;
    final maxSec = math.max(1, hourHist.fold(0, math.max));

    return Column(
      children: [
        SizedBox(
          height: 76,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (h) {
              final frac = hourHist[h] / maxSec;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: math.max(0.06, frac),
                      child: Container(
                        decoration: BoxDecoration(
                          color: hourHist[h] > 0
                              ? color.withValues(alpha: 0.3 + 0.7 * frac)
                              : eq.surface2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['12a', '6a', '12p', '6p', '11p']
              .map((l) => Text(l, style: TextStyle(fontSize: 10, color: eq.textMuted)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildWeekdayBars(
    BuildContext context,
    List<int> dowHist,
    Color color,
  ) {
    final eq = context.eq;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxSec = math.max(1, dowHist.fold(0, math.max));

    return Column(
      children: List.generate(7, (i) {
        final sec = dowHist[i];
        final frac = sec / maxSec;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  labels[i],
                  style: TextStyle(fontSize: 12, color: eq.textSecondary),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: eq.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              SizedBox(
                width: 48,
                child: Text(
                  DurationFormatter.formatHumanReadable(sec),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: eq.textMuted),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;

  const _KpiCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    return EqCard(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: eq.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
