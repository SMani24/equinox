import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/analytics_provider.dart';

class MonthlyHeatmapCard extends StatelessWidget {
  final Map<DateTime, DaySummary> daySummaries;
  final HeatmapMetric metric;
  final DateTime? selectedDate;
  final ValueChanged<HeatmapMetric> onMetricChanged;
  final ValueChanged<DateTime> onDateSelected;

  const MonthlyHeatmapCard({
    super.key,
    required this.daySummaries,
    required this.metric,
    required this.selectedDate,
    required this.onMetricChanged,
    required this.onDateSelected,
  });

  Color _getColorForDay(DaySummary? summary) {
    if (summary == null) return AppColors.surfaceElevated;

    switch (metric) {
      case HeatmapMetric.netScore:
        final score = summary.netScore;
        if (score > 3.0) return AppColors.productive;
        if (score >= 1.5) return AppColors.productive.withValues(alpha: 0.7);
        if (score > 0.1) return AppColors.productive.withValues(alpha: 0.4);
        if (score.abs() <= 0.1) {
          return summary.entries.isNotEmpty
              ? AppColors.neutral.withValues(alpha: 0.5)
              : AppColors.surfaceElevated;
        }
        if (score <= -3.0) return AppColors.rest;
        if (score <= -1.5) return AppColors.rest.withValues(alpha: 0.7);
        return AppColors.rest.withValues(alpha: 0.4);

      case HeatmapMetric.productiveHours:
        final hours = summary.productiveSeconds / 3600.0;
        if (hours >= 6.0) return AppColors.productive;
        if (hours >= 4.0) return AppColors.productive.withValues(alpha: 0.75);
        if (hours >= 2.0) return AppColors.productive.withValues(alpha: 0.5);
        if (hours > 0.0) return AppColors.productive.withValues(alpha: 0.25);
        return AppColors.surfaceElevated;

      case HeatmapMetric.restHours:
        final hours = summary.restSeconds / 3600.0;
        if (hours >= 4.0) return AppColors.rest;
        if (hours >= 2.5) return AppColors.rest.withValues(alpha: 0.75);
        if (hours >= 1.0) return AppColors.rest.withValues(alpha: 0.5);
        if (hours > 0.0) return AppColors.rest.withValues(alpha: 0.25);
        return AppColors.surfaceElevated;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Show past 60 days
    final days = List.generate(60, (i) {
      return today.subtract(Duration(days: 59 - i));
    });

    final selectedSummary =
        selectedDate != null ? daySummaries[selectedDate!] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Heatmap',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              DropdownButton<HeatmapMetric>(
                value: metric,
                dropdownColor: AppColors.surfaceElevated,
                underline: const SizedBox(),
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
                items: const [
                  DropdownMenuItem(
                    value: HeatmapMetric.netScore,
                    child: Text('Net Score'),
                  ),
                  DropdownMenuItem(
                    value: HeatmapMetric.productiveHours,
                    child: Text('Productive Hours'),
                  ),
                  DropdownMenuItem(
                    value: HeatmapMetric.restHours,
                    child: Text('Rest Hours'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) onMetricChanged(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // GitHub-style Grid (7 rows for days of week, columns for weeks)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day of week labels
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                    return Container(
                      height: 18,
                      width: 16,
                      margin: const EdgeInsets.only(bottom: 4, right: 6),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Heatmap squares grouped into weekly columns
                _buildGridColumns(days),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                metric == HeatmapMetric.netScore ? 'Deficit' : 'Less',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              const SizedBox(width: 6),
              if (metric == HeatmapMetric.netScore) ...[
                _buildLegendSquare(AppColors.rest),
                _buildLegendSquare(AppColors.rest.withValues(alpha: 0.5)),
                _buildLegendSquare(AppColors.surfaceElevated),
                _buildLegendSquare(AppColors.productive.withValues(alpha: 0.5)),
                _buildLegendSquare(AppColors.productive),
              ] else ...[
                _buildLegendSquare(AppColors.surfaceElevated),
                _buildLegendSquare(AppColors.primary.withValues(alpha: 0.25)),
                _buildLegendSquare(AppColors.primary.withValues(alpha: 0.5)),
                _buildLegendSquare(AppColors.primary.withValues(alpha: 0.75)),
                _buildLegendSquare(AppColors.primary),
              ],
              const SizedBox(width: 6),
              Text(
                metric == HeatmapMetric.netScore ? 'Surplus' : 'More',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),

          // Selected Day Drill-down Inspector
          if (selectedDate != null) ...[
            const Divider(height: 24),
            _buildDayDetailCard(context, selectedDate!, selectedSummary),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildGridColumns(List<DateTime> days) {
    // Group days by week columns
    final List<List<DateTime>> columns = [];
    List<DateTime> currentColumn = [];

    // Pad first column so weekday 1 (Mon) is at top (offset 0)
    final firstDay = days.first;
    final firstWeekday = firstDay.weekday; // 1 = Mon, 7 = Sun
    for (int i = 1; i < firstWeekday; i++) {
      // placeholder for empty cells prior to start
    }

    for (final day in days) {
      currentColumn.add(day);
      if (day.weekday == 7) {
        columns.add(currentColumn);
        currentColumn = [];
      }
    }
    if (currentColumn.isNotEmpty) {
      columns.add(currentColumn);
    }

    return Row(
      children: columns.map((col) {
        return Column(
          children: List.generate(7, (rowIndex) {
            final dayOfWeek = rowIndex + 1; // 1 = Mon .. 7 = Sun
            final match = col.where((d) => d.weekday == dayOfWeek);
            if (match.isEmpty) {
              return Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 4, bottom: 4),
              );
            }
            final date = match.first;
            final normDate = DateTime(date.year, date.month, date.day);
            final summary = daySummaries[normDate];
            final color = _getColorForDay(summary);
            final isSelected = selectedDate != null &&
                selectedDate!.year == normDate.year &&
                selectedDate!.month == normDate.month &&
                selectedDate!.day == normDate.day;

            return GestureDetector(
              onTap: () => onDateSelected(normDate),
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
              ),
            );
          }),
        );
      }).toList(),
    );
  }

  Widget _buildDayDetailCard(
    BuildContext context,
    DateTime date,
    DaySummary? summary,
  ) {
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(date);
    final netScore = summary?.netScore ?? 0.0;
    final prodDur = DurationFormatter.formatDecimalHours(
      summary?.productiveSeconds ?? 0,
    );
    final restDur = DurationFormatter.formatDecimalHours(
      summary?.restSeconds ?? 0,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                ScoreCalculator.formatScore(netScore),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.forCoefficient(netScore),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$prodDur Productive',
                style: const TextStyle(fontSize: 12, color: AppColors.productive),
              ),
              const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
              Text(
                '$restDur Rest',
                style: const TextStyle(fontSize: 12, color: AppColors.rest),
              ),
              const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
              Text(
                '${summary?.entries.length ?? 0} sessions',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (summary != null && summary.entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...summary.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.getIconData(e.activity.iconCode),
                      color: Color(e.activity.colorHex),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        e.activity.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${DurationFormatter.formatHumanReadable(e.entry.durationSeconds)} (${ScoreCalculator.formatScore(e.entry.scoreSnapshot)})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forCoefficient(e.entry.scoreSnapshot),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
