import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/score_calculator.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/analytics_provider.dart';
import 'widgets/activity_donut_chart.dart';
import 'widgets/balance_bar_chart.dart';
import 'widgets/hourly_rhythm_heatmap.dart';
import 'widgets/monthly_heatmap_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analyticsDateRangeProvider);
    final metric = ref.watch(heatmapMetricProvider);
    final selectedDate = ref.watch(selectedHeatmapDateProvider);
    final summaryData = ref.watch(analyticsSummaryProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Heatmaps'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Preset Filter
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildPresetTab(
                    ref,
                    label: '7 Days',
                    preset: DateRangePreset.week,
                    current: range.preset,
                    rolloverHour: settings.rolloverHour,
                  ),
                  _buildPresetTab(
                    ref,
                    label: '30 Days',
                    preset: DateRangePreset.month,
                    current: range.preset,
                    rolloverHour: settings.rolloverHour,
                  ),
                  _buildPresetTab(
                    ref,
                    label: '1 Year',
                    preset: DateRangePreset.year,
                    current: range.preset,
                    rolloverHour: settings.rolloverHour,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Quick Stat Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NET BALANCE SCORE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ScoreCalculator.formatScore(summaryData.totalNetScore),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forCoefficient(summaryData.totalNetScore),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TRACKED DURATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(summaryData.totalDurationSeconds / 3600.0).toStringAsFixed(1)} hrs',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chart 1: Monthly Calendar Heatmap
            MonthlyHeatmapCard(
              daySummaries: summaryData.daySummaries,
              metric: metric,
              selectedDate: selectedDate,
              onMetricChanged: (newMetric) {
                ref.read(heatmapMetricProvider.notifier).setMetric(newMetric);
              },
              onDateSelected: (date) {
                ref.read(selectedHeatmapDateProvider.notifier).toggleDate(date);
              },
            ),
            const SizedBox(height: 16),

            // Chart 2: 24-Hour Rhythm Heatmap
            HourlyRhythmHeatmap(slots: summaryData.hourlyRhythmGrid),
            const SizedBox(height: 16),

            // Chart 3: Work vs Rest Balance Bar Chart
            BalanceBarChart(recentDays: summaryData.recentDaysBarData),
            const SizedBox(height: 16),

            // Chart 4: Activity Distribution Donut Chart
            ActivityDonutChart(
              items: summaryData.activityDonutItems,
              totalDurationSeconds: summaryData.totalDurationSeconds,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetTab(
    WidgetRef ref, {
    required String label,
    required DateRangePreset preset,
    required DateRangePreset current,
    required int rolloverHour,
  }) {
    final isSelected = preset == current;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref
              .read(analyticsDateRangeProvider.notifier)
              .setPreset(preset, rolloverHour: rolloverHour);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
