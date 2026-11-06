import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/analytics_provider.dart';

class ActivityDonutChart extends StatefulWidget {
  final List<ActivityDonutItem> items;
  final int totalDurationSeconds;

  const ActivityDonutChart({
    super.key,
    required this.items,
    required this.totalDurationSeconds,
  });

  @override
  State<ActivityDonutChart> createState() => _ActivityDonutChartState();
}

class _ActivityDonutChartState extends State<ActivityDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty || widget.totalDurationSeconds == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No activity data logged in this range',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final sections = List.generate(widget.items.length, (i) {
      final item = widget.items[i];
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 34.0 : 28.0;

      return PieChartSectionData(
        value: item.durationSeconds.toDouble(),
        color: Color(item.activity.colorHex),
        radius: radius,
        showTitle: false,
      );
    });

    final totalHoursStr = DurationFormatter.formatDecimalHours(
      widget.totalDurationSeconds,
    );

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
          Text(
            'Activity Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        startDegreeOffset: -90,
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 42,
                        sections: sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalHoursStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Legend
              Expanded(
                child: Column(
                  children: widget.items.take(5).map((item) {
                    final act = item.activity;
                    final durStr = DurationFormatter.formatHumanReadable(item.durationSeconds);
                    final scoreStr = ScoreCalculator.formatScore(item.totalScore);
                    final scoreColor = AppColors.forCoefficient(item.totalScore);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.getIconData(act.iconCode),
                            color: Color(act.colorHex),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              act.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$durStr (${item.durationPercentage.toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            scoreStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
