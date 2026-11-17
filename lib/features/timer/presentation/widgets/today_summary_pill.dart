import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/timer_provider.dart';
import 'balance_ring.dart';

/// Compact, borderless header showing today's date, equilibrium gauge,
/// net score vs goal, and a minimal work/rest strip.
class TodaySummaryPill extends StatelessWidget {
  final TodayScoreSummary summary;
  final VoidCallback? onTap;

  const TodaySummaryPill({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final netScore = summary.netScore;
    final hasAny = (summary.productiveSeconds + summary.restSeconds + summary.neutralSeconds) > 0;
    final metGoal = netScore >= summary.targetGoal - 0.001;
    final overRestBudget = summary.dailyRestBudget != null &&
        summary.dailyRestBudget! > 0 &&
        summary.grossRestCost > summary.dailyRestBudget! + 0.01;

    final statusColor = !hasAny
        ? eq.textSecondary
        : (overRestBudget || !metGoal ? eq.danger : eq.gain);

    final workDur = DurationFormatter.formatDecimalHours(summary.productiveSeconds);
    final restDur = DurationFormatter.formatDecimalHours(summary.restSeconds);
    final workScore =
        ScoreCalculator.formatScore(summary.grossProductiveScore, showUnit: false);
    final restScore =
        ScoreCalculator.formatScore(-summary.grossRestCost, showUnit: false);

    final totalBalanceSec = summary.productiveSeconds + summary.restSeconds;
    final workRatio = totalBalanceSec > 0
        ? (summary.productiveSeconds / totalBalanceSec).clamp(0.0, 1.0)
        : 0.5;

    final todayLabel = DateFormat('EEE, MMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xs),
      child: Material(
        color: eq.surface1,
        borderRadius: BorderRadius.circular(Radii.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.md,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todayLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: eq.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            overRestBudget
                                ? 'Rest budget exceeded (-${summary.dailyRestBudget!.toStringAsFixed(1)} max)'
                                : (summary.targetGoal != 0.0
                                    ? 'Daily goal ${ScoreCalculator.formatScore(summary.targetGoal)}'
                                    : 'Work–rest balance'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: overRestBudget ? eq.danger : eq.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasAny
                            ? statusColor.withValues(alpha: 0.14)
                            : eq.surface2,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BalanceRing(
                            productiveScore: summary.grossProductiveScore,
                            restCost: summary.grossRestCost,
                            targetGoal: summary.targetGoal,
                            size: 20,
                            strokeWidth: 3,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ScoreCalculator.formatScore(netScore),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 4,
                    child: totalBalanceSec == 0
                        ? Container(color: eq.surface3)
                        : Row(
                            children: [
                              if (workRatio > 0)
                                Expanded(
                                  flex: (workRatio * 1000).round().clamp(1, 1000),
                                  child: Container(color: eq.gain),
                                ),
                              if (workRatio < 1)
                                Expanded(
                                  flex: ((1.0 - workRatio) * 1000)
                                      .round()
                                      .clamp(1, 1000),
                                  child: Container(color: eq.spend),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: Space.xs + 2),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    spacing: Space.md,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: eq.gain,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$workDur work · $workScore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: eq.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: eq.spend,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$restDur rest · $restScore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: eq.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
