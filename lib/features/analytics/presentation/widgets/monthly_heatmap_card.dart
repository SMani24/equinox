import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/eq_card.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/analytics_provider.dart';

/// Calendar consistency heatmap: renders 60 days normally or full 52-week
/// year grid when [isYearMode] is true, with day drill-down inspection.
class MonthlyHeatmapCard extends StatelessWidget {
  final Map<DateTime, DaySummary> daySummaries;
  final HeatmapMetric metric;
  final DateTime? selectedDate;
  final bool isYearMode;
  final ValueChanged<HeatmapMetric> onMetricChanged;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onOpenDayDetail;

  const MonthlyHeatmapCard({
    super.key,
    required this.daySummaries,
    required this.metric,
    required this.selectedDate,
    this.isYearMode = false,
    required this.onMetricChanged,
    required this.onDateSelected,
    this.onOpenDayDetail,
  });

  Color _getColorForDay(BuildContext context, DaySummary? summary) {
    final eq = context.eq;
    if (summary == null) return eq.surface2;

    switch (metric) {
      case HeatmapMetric.netScore:
        final score = summary.netScore;
        if (score > 3.0) return eq.gain;
        if (score >= 1.5) return eq.gain.withValues(alpha: 0.72);
        if (score > 0.1) return eq.gain.withValues(alpha: 0.40);
        if (score.abs() <= 0.1) {
          return summary.totalSeconds > 0
              ? eq.neutral.withValues(alpha: 0.45)
              : eq.surface2;
        }
        if (score <= -3.0) return eq.danger;
        if (score <= -1.5) return eq.spend.withValues(alpha: 0.80);
        return eq.spend.withValues(alpha: 0.45);

      case HeatmapMetric.productiveHours:
        final hours = summary.productiveSeconds / 3600.0;
        if (hours >= 6.0) return eq.gain;
        if (hours >= 4.0) return eq.gain.withValues(alpha: 0.75);
        if (hours >= 2.0) return eq.gain.withValues(alpha: 0.50);
        if (hours > 0.0) return eq.gain.withValues(alpha: 0.25);
        return eq.surface2;

      case HeatmapMetric.restHours:
        final hours = summary.restSeconds / 3600.0;
        if (hours >= 4.0) return eq.spend;
        if (hours >= 2.5) return eq.spend.withValues(alpha: 0.75);
        if (hours >= 1.0) return eq.spend.withValues(alpha: 0.50);
        if (hours > 0.0) return eq.spend.withValues(alpha: 0.25);
        return eq.surface2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayCount = isYearMode ? 365 : 60;
    final days = List.generate(
      dayCount,
      (i) => DateTime(today.year, today.month, today.day - (dayCount - 1 - i)),
    );

    final selectedSummary =
        selectedDate != null ? daySummaries[selectedDate!] : null;

    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isYearMode ? 'Year at a glance' : 'Consistency calendar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      isYearMode ? 'Past 52 weeks · Tap any cell' : 'Past 60 days · Tap a day to inspect',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              DropdownButton<HeatmapMetric>(
                value: metric,
                dropdownColor: eq.surface2,
                underline: const SizedBox(),
                isDense: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: eq.accent,
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
          const SizedBox(height: Space.md),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: isYearMode, // Anchor year grid on most recent week at right
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                    final cellSize = isYearMode ? 11.0 : 18.0;
                    return Container(
                      height: cellSize,
                      width: 14,
                      margin: EdgeInsets.only(
                        bottom: isYearMode ? 3 : 4,
                        right: 6,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: isYearMode ? 8 : 9,
                          color: eq.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                _buildGridColumns(context, days, cellSize: isYearMode ? 11.0 : 18.0, gap: isYearMode ? 3.0 : 4.0),
              ],
            ),
          ),
          const SizedBox(height: Space.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                metric == HeatmapMetric.netScore ? 'Deficit' : 'Less',
                style: TextStyle(fontSize: 10, color: eq.textMuted),
              ),
              const SizedBox(width: 6),
              if (metric == HeatmapMetric.netScore) ...[
                _buildLegendSquare(eq.danger),
                _buildLegendSquare(eq.spend.withValues(alpha: 0.65)),
                _buildLegendSquare(eq.surface2),
                _buildLegendSquare(eq.gain.withValues(alpha: 0.5)),
                _buildLegendSquare(eq.gain),
              ] else ...[
                _buildLegendSquare(eq.surface2),
                _buildLegendSquare(eq.accent.withValues(alpha: 0.25)),
                _buildLegendSquare(eq.accent.withValues(alpha: 0.5)),
                _buildLegendSquare(eq.accent.withValues(alpha: 0.75)),
                _buildLegendSquare(eq.accent),
              ],
              const SizedBox(width: 6),
              Text(
                metric == HeatmapMetric.netScore ? 'Surplus' : 'More',
                style: TextStyle(fontSize: 10, color: eq.textMuted),
              ),
            ],
          ),

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
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildGridColumns(
    BuildContext context,
    List<DateTime> days, {
    required double cellSize,
    required double gap,
  }) {
    final eq = context.eq;
    final List<List<DateTime>> columns = [];
    List<DateTime> currentColumn = [];

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
            final dayOfWeek = rowIndex + 1;
            final match = col.where((d) => d.weekday == dayOfWeek);
            if (match.isEmpty) {
              return Container(
                width: cellSize,
                height: cellSize,
                margin: EdgeInsets.only(right: gap, bottom: gap),
              );
            }
            final date = match.first;
            final normDate = DateTime(date.year, date.month, date.day);
            final summary = daySummaries[normDate];
            final color = _getColorForDay(context, summary);
            final isSelected = selectedDate != null &&
                selectedDate!.year == normDate.year &&
                selectedDate!.month == normDate.month &&
                selectedDate!.day == normDate.day;

            return GestureDetector(
              onTap: () => onDateSelected(normDate),
              child: Container(
                width: cellSize,
                height: cellSize,
                margin: EdgeInsets.only(right: gap, bottom: gap),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(isYearMode ? 2.5 : 4),
                  border: isSelected
                      ? Border.all(color: eq.textPrimary, width: 1.5)
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
    final eq = context.eq;
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(date);
    final netScore = summary?.netScore ?? 0.0;
    final prodDur = DurationFormatter.formatDecimalHours(
      summary?.productiveSeconds ?? 0,
    );
    final restDur = DurationFormatter.formatDecimalHours(
      summary?.restSeconds ?? 0,
    );

    return EqCard(
      tone: EqSurfaceTone.level2,
      radius: Radii.md,
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              Text(
                ScoreCalculator.formatScore(netScore),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: eq.forCoefficient(netScore),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('$prodDur work', style: TextStyle(fontSize: 12, color: eq.gain)),
              Text('·', style: TextStyle(color: eq.textMuted)),
              Text('$restDur rest', style: TextStyle(fontSize: 12, color: eq.spend)),
              if (onOpenDayDetail != null)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => onOpenDayDetail!(date),
                  child: const Text('Open day →'),
                ),
            ],
          ),
          if (summary != null && summary.entries.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...summary.entries.take(6).map((e) {
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
                        style: const TextStyle(fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DurationFormatter.formatHumanReadable(e.entry.durationSeconds),
                      style: TextStyle(fontSize: 11, color: eq.textMuted),
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
