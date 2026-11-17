import 'package:flutter/material.dart';
import '../theme/eq_colors.dart';
import '../theme/tokens.dart';
import '../utils/score_calculator.dart';

class ScorePill extends StatelessWidget {
  final double score;
  final bool compact;
  final bool showUnit;
  final bool isDangerOverride;

  const ScorePill({
    super.key,
    required this.score,
    this.compact = false,
    this.showUnit = true,
    this.isDangerOverride = false,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final color = isDangerOverride ? eq.danger : eq.forCoefficient(score);
    final soft = isDangerOverride ? eq.dangerSoft : eq.softForCoefficient(score);
    final text = ScoreCalculator.formatScore(score, showUnit: showUnit);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? Space.sm : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        softWrap: false,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 13,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
