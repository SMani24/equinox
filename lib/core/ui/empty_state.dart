import 'package:flutter/material.dart';
import '../theme/eq_colors.dart';
import '../theme/tokens.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.lg),
      decoration: BoxDecoration(
        color: eq.surface1,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: eq.surface2,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: eq.textMuted),
          ),
          const SizedBox(height: Space.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: eq.textPrimary,
                ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: eq.textMuted,
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: Space.md),
            action!,
          ],
        ],
      ),
    );
  }
}
