import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/timer_provider.dart';

class TodaySummaryPill extends StatelessWidget {
  final TodayScoreSummary summary;

  const TodaySummaryPill({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final netScore = summary.netScore;
    final isPositive = netScore >= 0;
    final scoreColor = isPositive ? AppColors.productive : AppColors.rest;
    final glowColor = isPositive ? AppColors.productiveGlow : AppColors.restGlow;

    final workDur = DurationFormatter.formatDecimalHours(summary.productiveSeconds);
    final restDur = DurationFormatter.formatDecimalHours(summary.restSeconds);
    final workScore = ScoreCalculator.formatScore(summary.grossProductiveScore, showUnit: false);
    final restScore = ScoreCalculator.formatScore(-summary.grossRestCost, showUnit: false);

    // Compute progress ratio for Work vs Rest balance
    final totalBalanceSec = summary.productiveSeconds + summary.restSeconds;
    final workRatio = totalBalanceSec > 0
        ? (summary.productiveSeconds / totalBalanceSec).clamp(0.0, 1.0)
        : 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "TODAY'S EQUILIBRIUM",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 10,
                          ),
                    ),
                  ),
                  if (summary.targetGoal != 0.0) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Goal: ${ScoreCalculator.formatScore(summary.targetGoal)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  ScoreCalculator.formatScore(netScore),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Equilibrium Ratio Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (workRatio * 1000).toInt(),
                    child: Container(color: AppColors.productive),
                  ),
                  Expanded(
                    flex: ((1.0 - workRatio) * 1000).toInt(),
                    child: Container(color: AppColors.rest),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
                  const SizedBox(width: 6),
                  Text(
                    '$workDur Work ($workScore)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.rest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$restDur Rest ($restScore)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
