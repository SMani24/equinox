import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

class ActivityAvatar extends StatelessWidget {
  final int iconCode;
  final int colorHex;
  final double size;
  final double iconSize;
  final double radius;

  const ActivityAvatar({
    super.key,
    required this.iconCode,
    required this.colorHex,
    this.size = 40,
    this.iconSize = 20,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        AppIcons.getIconData(iconCode),
        color: color,
        size: iconSize,
      ),
    );
  }
}
