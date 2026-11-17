import 'package:flutter/material.dart';

/// Standardized spacing tokens across Equinox.
abstract final class Space {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Standardized corner radii tokens.
abstract final class Radii {
  static const double sm = 8.0;
  static const double md = 14.0;
  static const double lg = 20.0;
  static const double xl = 28.0;
  static const double pill = 999.0;
}

/// Standardized motion durations and curves.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;
}

/// Curated accent theme choices for user customization.
enum AppAccentPreset {
  indigo('Indigo', Color(0xFF818CF8), Color(0xFF4F46E5)),
  emerald('Emerald', Color(0xFF34D399), Color(0xFF059669)),
  cyan('Cyan', Color(0xFF22D3EE), Color(0xFF0891B2)),
  amber('Amber', Color(0xFFFBBF24), Color(0xFFD97706)),
  rose('Rose', Color(0xFFFB7185), Color(0xFFE11D48));

  final String label;
  final Color darkAccent;
  final Color lightAccent;

  const AppAccentPreset(this.label, this.darkAccent, this.lightAccent);

  static AppAccentPreset fromKey(String? key) {
    for (final p in values) {
      if (p.name == key) return p;
    }
    return AppAccentPreset.indigo;
  }
}
