import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/analytics_provider.dart';

class BalanceBarChart extends StatelessWidget {
  final List<DaySummary> recentDays;

  const BalanceBarChart({super.key, required this.recentDays});

  @override
  Widget build(BuildContext context) {
    if (recentDays.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine max Y for scaling
    double maxY = 1.0;
    for (final day in recentDays) {
      maxY = math.max(maxY, day.grossProductive);
      maxY = math.max(maxY, day.grossRest);
    }
    maxY = (maxY * 1.25).ceilToDouble();

    final barGroups = List.generate(recentDays.length, (i) {
      final d = recentDays[i];
      return BarChartGroupData(
        x: i,
        barRods: [
          // Productive Rod (Green)
          BarChartRodData(
            toY: d.grossProductive,
            color: AppColors.productive,
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          // Rest Cost Rod (Coral)
          BarChartRodData(
            toY: d.grossRest,
            color: AppColors.rest,
            width: 7,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

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
                'Work vs. Rest (Past 14 Days)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.productive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Work (+)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(width: 10),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.rest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Rest (-)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceElevated,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = recentDays[group.x];
                      final dateStr = DateFormat('MMM d').format(day.date);
                      final isWork = rodIndex == 0;
                      final type = isWork ? 'Work' : 'Rest';
                      final val = isWork ? day.grossProductive : day.grossRest;
                      final pts = ScoreCalculator.formatScore(isWork ? val : -val);

                      return BarTooltipItem(
                        '$dateStr\n$type: $pts\nNet: ${ScoreCalculator.formatScore(day.netScore)}',
                        TextStyle(
                          color: isWork ? AppColors.productive : AppColors.rest,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const SizedBox();
                        return Text(
                          '${val.toInt()}p',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < recentDays.length) {
                          // Only show every other day for spacing
                          if (idx % 2 == 0) {
                            final date = recentDays[idx].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('d').format(date),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) {
                    return FlLine(
                      color: AppColors.border.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    );
                  },
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
