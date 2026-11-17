import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/eq_card.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/utils/score_calculator.dart';
import '../../activities/presentation/activity_detail_page.dart';
import '../../activities/providers/activities_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/analytics_provider.dart';
import 'day_detail_page.dart';
import 'widgets/activity_donut_chart.dart';
import 'widgets/balance_bar_chart.dart';
import 'widgets/hourly_rhythm_heatmap.dart';
import 'widgets/insight_cards_row.dart';
import 'widgets/monthly_heatmap_card.dart';
import 'widgets/streaks_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = context.eq;
    final range = ref.watch(analyticsDateRangeProvider);
    final metric = ref.watch(heatmapMetricProvider);
    final selectedDate = ref.watch(selectedHeatmapDateProvider);
    final summaryData = ref.watch(analyticsSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final streaks = ref.watch(streaksProvider);
    final insights = ref.watch(insightsProvider);
    final yearSummaries = ref.watch(yearCalendarSummariesProvider);
    final activities = ref.watch(activitiesStreamProvider).value ?? [];
    final rhythmFilterId = ref.watch(rhythmActivityFilterProvider);

    final netDelta = summaryData.totalNetScore - summaryData.previousNetScore;
    final hasPrevComparison = summaryData.previousDurationSeconds > 0;
    final totalPeriodDays = range.logicalDays.length;

    void openDay(DateTime day) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayDetailPage(logicalDate: day)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.xxl,
        ),
        children: [
          // Segmented Range Preset (Day · Week · Month · Year)
          SegmentedButton<DateRangePreset>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: DateRangePreset.day, label: Text('Day')),
              ButtonSegment(value: DateRangePreset.week, label: Text('Week')),
              ButtonSegment(value: DateRangePreset.month, label: Text('Month')),
              ButtonSegment(value: DateRangePreset.year, label: Text('Year')),
            ],
            selected: {range.preset},
            onSelectionChanged: (sel) {
              if (sel.isNotEmpty) {
                ref.read(analyticsDateRangeProvider.notifier).setPreset(
                      sel.first,
                      rolloverHour: settings.rolloverHour,
                    );
              }
            },
          ),
          const SizedBox(height: Space.sm),

          // Period Pager (< Nov 10 - Nov 16 >)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  ref.read(analyticsDateRangeProvider.notifier).stepPeriod(
                        -1,
                        rolloverHour: settings.rolloverHour,
                      );
                },
              ),
              Text(
                range.formattedLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: eq.textPrimary,
                    ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: range.offset >= 0
                    ? null
                    : () {
                        ref.read(analyticsDateRangeProvider.notifier).stepPeriod(
                              1,
                              rolloverHour: settings.rolloverHour,
                            );
                      },
              ),
            ],
          ),
          const SizedBox(height: Space.sm),

          // Hero Summary Card
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net equilibrium',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ScoreCalculator.formatScore(summaryData.totalNetScore),
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: eq.forCoefficient(summaryData.totalNetScore),
                                ),
                          ),
                          if (hasPrevComparison) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${netDelta >= 0 ? '▲' : '▼'} ${ScoreCalculator.formatScore(netDelta)} vs previous period',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: netDelta >= 0 ? eq.gain : eq.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DurationFormatter.formatHumanReadable(
                            summaryData.totalDurationSeconds,
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Goal hit ${summaryData.goalHitDays}/$totalPeriodDays days',
                          style: TextStyle(
                            fontSize: 12,
                            color: eq.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Auto-generated Insight Cards
          if (insights.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            InsightCardsRow(insights: insights),
          ],

          const SizedBox(height: Space.lg),

          // Diverging Balance Bar Chart (tap bar -> Day Detail)
          BalanceBarChart(
            recentDays: summaryData.recentDaysBarData,
            rollingNetSeries: summaryData.rollingNetSeries,
            targetGoal: settings.equilibriumTarget,
            onDayTapped: openDay,
          ),
          const SizedBox(height: Space.lg),

          // Where time went (Category stacked bar + Ranked list + Donut toggle)
          ActivityDonutChart(
            items: summaryData.activityDonutItems,
            totalDurationSeconds: summaryData.totalDurationSeconds,
            productiveSeconds: summaryData.productiveSeconds,
            restSeconds: summaryData.restSeconds,
            neutralSeconds: summaryData.neutralSeconds,
            onTapActivity: (act) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActivityDetailPage(activity: act),
                ),
              );
            },
          ),
          const SizedBox(height: Space.lg),

          // Pro-rated 7x24 Circadian Rhythm Heatmap
          HourlyRhythmHeatmap(
            slots: summaryData.hourlyRhythmGrid,
            activities: activities,
            selectedActivityId: rhythmFilterId,
            onActivityFilterChanged: (id) {
              ref.read(rhythmActivityFilterProvider.notifier).setActivityId(id);
            },
          ),
          const SizedBox(height: Space.lg),

          // Consistency Calendar / Full-Year Grid
          MonthlyHeatmapCard(
            daySummaries: range.preset == DateRangePreset.year
                ? yearSummaries
                : summaryData.daySummaries,
            metric: metric,
            selectedDate: selectedDate,
            isYearMode: range.preset == DateRangePreset.year,
            onMetricChanged: (m) {
              ref.read(heatmapMetricProvider.notifier).setMetric(m);
            },
            onDateSelected: (d) {
              ref.read(selectedHeatmapDateProvider.notifier).toggleDate(d);
            },
            onOpenDayDetail: openDay,
          ),
          const SizedBox(height: Space.lg),

          // Streaks & Records
          StreaksCard(
            streaks: streaks,
            onTapDay: openDay,
          ),
        ],
      ),
    );
  }
}
