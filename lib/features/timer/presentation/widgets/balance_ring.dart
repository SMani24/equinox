import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';

/// Compact circular balance gauge comparing productive gain vs rest spend
/// with an indicator tick for target equilibrium.
class BalanceRing extends StatelessWidget {
  final double productiveScore;
  final double restCost;
  final double targetGoal;
  final double size;
  final double strokeWidth;

  const BalanceRing({
    super.key,
    required this.productiveScore,
    required this.restCost,
    this.targetGoal = 0.0,
    this.size = 28,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BalanceRingPainter(
          productiveScore: productiveScore,
          restCost: restCost,
          targetGoal: targetGoal,
          gainColor: eq.gain,
          spendColor: eq.spend,
          trackColor: eq.surface3,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _BalanceRingPainter extends CustomPainter {
  final double productiveScore;
  final double restCost;
  final double targetGoal;
  final Color gainColor;
  final Color spendColor;
  final Color trackColor;
  final double strokeWidth;

  _BalanceRingPainter({
    required this.productiveScore,
    required this.restCost,
    required this.targetGoal,
    required this.gainColor,
    required this.spendColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = productiveScore + restCost;
    if (total <= 0.001) return;

    final gainSweep = (productiveScore / total) * 2 * math.pi;
    final spendSweep = (restCost / total) * 2 * math.pi;

    const startAngle = -math.pi / 2;

    if (gainSweep > 0.01) {
      final gainPaint = Paint()
        ..color = gainColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, gainSweep, false, gainPaint);
    }

    if (spendSweep > 0.01) {
      final spendPaint = Paint()
        ..color = spendColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        startAngle + gainSweep,
        spendSweep,
        false,
        spendPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceRingPainter old) {
    return old.productiveScore != productiveScore ||
        old.restCost != restCost ||
        old.targetGoal != targetGoal ||
        old.gainColor != gainColor ||
        old.spendColor != spendColor;
  }
}
