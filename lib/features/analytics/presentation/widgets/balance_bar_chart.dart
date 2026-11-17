import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/eq_card.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/analytics_provider.dart';

/// Diverging work vs. rest chart (gain positive, rest negative) with an optional
/// goal reference line, 7-day rolling net callout, and tap-to-open Day Detail.
class BalanceBarChart extends StatelessWidget {
  final List<DaySummary> recentDays;
  final List<double> rollingNetSeries;
  final double targetGoal;
  final ValueChanged<DateTime>? onDayTapped;

  const BalanceBarChart({
    super.key,
    required this.recentDays,
    this.rollingNetSeries = const [],
    this.targetGoal = 0.0,
    this.onDayTapped,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    if (recentDays.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No balance history yet',
        body: 'Log sessions to compare daily gain vs. rest balance.',
      );
    }

    double maxPos = math.max(1.0, targetGoal.abs());
    double maxNeg = 1.0;
    for (final day in recentDays) {
      maxPos = math.max(maxPos, day.grossProductive);
      maxNeg = math.max(maxNeg, day.grossRest);
    }
    maxPos = (maxPos * 1.2).ceilToDouble();
    maxNeg = (maxNeg * 1.2).ceilToDouble();

    final barWidth = recentDays.length > 20 ? 6.0 : (recentDays.length > 10 ? 10.0 : 16.0);

    final barGroups = List.generate(recentDays.length, (i) {
      final d = recentDays[i];
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            fromY: -d.grossRest,
            toY: d.grossProductive,
            width: barWidth,
            borderRadius: BorderRadius.circular(4),
            rodStackItems: [
              if (d.grossProductive > 0)
                BarChartRodStackItem(0, d.grossProductive, eq.gain),
              if (d.grossRest > 0)
                BarChartRodStackItem(-d.grossRest, 0, eq.spend),
            ],
            color: Colors.transparent,
          ),
        ],
      );
    });

    final latestRollingNet =
        rollingNetSeries.isNotEmpty ? rollingNetSeries.last : 0.0;

    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work vs. Rest balance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rolling net avg: ${ScoreCalculator.formatScore(latestRollingNet)}/day · Tap a bar to inspect',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: eq.gain, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('Work', style: TextStyle(fontSize: 11, color: eq.textMuted)),
                  const SizedBox(width: 8),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: eq.spend, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('Rest', style: TextStyle(fontSize: 11, color: eq.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          SizedBox(
            height: 196,
            child: BarChart(
              duration: Motion.base,
              BarChartData(
                maxY: maxPos,
                minY: -maxNeg,
                barTouchData: BarTouchData(
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent &&
                        response != null &&
                        response.spot != null &&
                        onDayTapped != null) {
                      final idx = response.spot!.touchedBarGroupIndex;
                      if (idx >= 0 && idx < recentDays.length) {
                        onDayTapped!(recentDays[idx].date);
                      }
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => eq.surface3,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = recentDays[group.x];
                      final dateStr = DateFormat('MMM d').format(day.date);
                      return BarTooltipItem(
                        '$dateStr\nWork ${ScoreCalculator.formatScore(day.grossProductive, showUnit: false)} · Rest ${ScoreCalculator.formatScore(-day.grossRest, showUnit: false)}\nNet ${ScoreCalculator.formatScore(day.netScore)}',
                        TextStyle(
                          color: eq.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: eq.border,
                      strokeWidth: 1,
                    ),
                    if (targetGoal != 0.0)
                      HorizontalLine(
                        y: targetGoal,
                        color: eq.accent.withValues(alpha: 0.7),
                        strokeWidth: 1.2,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: eq.accent,
                          ),
                          labelResolver: (_) =>
                              'Goal ${ScoreCalculator.formatScore(targetGoal, showUnit: false)}',
                        ),
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, _) {
                        return Text(
                          val == 0 ? '0' : '${val.toInt()}',
                          style: TextStyle(
                            color: eq.textMuted,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= recentDays.length) {
                          return const SizedBox.shrink();
                        }
                        final step = recentDays.length > 16 ? 5 : (recentDays.length > 8 ? 2 : 1);
                        if (idx % step != 0 && idx != recentDays.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final date = recentDays[idx].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            recentDays.length <= 7
                                ? DateFormat('E').format(date)
                                : DateFormat('d').format(date),
                            style: TextStyle(
                              color: eq.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: eq.textMuted.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
