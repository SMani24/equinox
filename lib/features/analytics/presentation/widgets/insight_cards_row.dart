import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/eq_card.dart';
import '../../../smart/insights_engine.dart';

class InsightCardsRow extends StatelessWidget {
  final List<InsightCardData> insights;

  const InsightCardsRow({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    final eq = context.eq;

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, index) {
          final item = insights[index];
          final Color toneColor = switch (item.tone) {
            InsightTone.gain => eq.gain,
            InsightTone.spend => eq.spend,
            InsightTone.warning => eq.danger,
            InsightTone.neutral => eq.accent,
          };

          return SizedBox(
            width: 270,
            child: EqCard(
              padding: const EdgeInsets.all(Space.md),
              accentTint: toneColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item.icon, size: 16, color: toneColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: eq.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: eq.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
