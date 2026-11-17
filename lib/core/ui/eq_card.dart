import 'package:flutter/material.dart';
import '../theme/eq_colors.dart';
import '../theme/tokens.dart';

enum EqSurfaceTone { level1, level2, level3 }

/// Tonal surface container replacing bordered "card soup".
/// Uses background luminance steps instead of harsh 1px borders.
class EqCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final EqSurfaceTone tone;
  final double radius;
  final VoidCallback? onTap;
  final Color? accentTint;

  const EqCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.tone = EqSurfaceTone.level1,
    this.radius = Radii.lg,
    this.onTap,
    this.accentTint,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final Color baseColor = switch (tone) {
      EqSurfaceTone.level1 => eq.surface1,
      EqSurfaceTone.level2 => eq.surface2,
      EqSurfaceTone.level3 => eq.surface3,
    };

    final Color bgColor = accentTint != null
        ? Color.alphaBlend(accentTint!.withValues(alpha: 0.08), baseColor)
        : baseColor;

    final inner = Padding(
      padding: padding ?? const EdgeInsets.all(Space.lg),
      child: child,
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: inner,
              )
            : inner,
      ),
    );
  }
}
