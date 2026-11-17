import 'package:flutter/material.dart';
import '../../data/database/app_database.dart';
import '../theme/app_icons.dart';
import '../theme/eq_colors.dart';
import '../theme/tokens.dart';

class ActivityChip extends StatelessWidget {
  final Activity activity;
  final bool selected;
  final String? badgeText;
  final VoidCallback onTap;

  const ActivityChip({
    super.key,
    required this.activity,
    this.selected = false,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final color = Color(activity.colorHex);

    return Material(
      color: selected ? color.withValues(alpha: 0.16) : eq.surface1,
      borderRadius: BorderRadius.circular(Radii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.pill),
            border: selected
                ? Border.all(color: color.withValues(alpha: 0.7), width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.getIconData(activity.iconCode),
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  activity.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: eq.textPrimary,
                  ),
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Text(
                  badgeText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: eq.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
