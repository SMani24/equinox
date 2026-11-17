import 'package:flutter/material.dart';

/// Semantic theme extension implementing the "Calm Instrument" surface ladder
/// and meaning-driven color tokens for both dark and light modes.
@immutable
class EquinoxColors extends ThemeExtension<EquinoxColors> {
  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color gain;
  final Color gainSoft;
  final Color spend;
  final Color spendSoft;
  final Color danger;
  final Color dangerSoft;
  final Color neutral;
  final Color neutralSoft;
  final Color accent;
  final Color accentSoft;

  const EquinoxColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.gain,
    required this.gainSoft,
    required this.spend,
    required this.spendSoft,
    required this.danger,
    required this.dangerSoft,
    required this.neutral,
    required this.neutralSoft,
    required this.accent,
    required this.accentSoft,
  });

  static EquinoxColors dark({Color accent = const Color(0xFF818CF8)}) {
    const gainColor = Color(0xFF34D399);
    const spendColor = Color(0xFFFBBF24); // Warm Amber (rest is healthy)
    const dangerColor = Color(0xFFFB7185); // Coral (over budget / deficit)
    const neutralColor = Color(0xFF94A3B8);

    return EquinoxColors(
      bg: const Color(0xFF0B0D12),
      surface1: const Color(0xFF12151C),
      surface2: const Color(0xFF191D26),
      surface3: const Color(0xFF222734),
      border: const Color(0xFF272D3B),
      borderSubtle: const Color(0xFF1B1F29),
      textPrimary: const Color(0xFFF1F5F9),
      textSecondary: const Color(0xFF9CA3AF),
      textMuted: const Color(0xFF6B7280),
      gain: gainColor,
      gainSoft: gainColor.withValues(alpha: 0.14),
      spend: spendColor,
      spendSoft: spendColor.withValues(alpha: 0.14),
      danger: dangerColor,
      dangerSoft: dangerColor.withValues(alpha: 0.14),
      neutral: neutralColor,
      neutralSoft: neutralColor.withValues(alpha: 0.14),
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.16),
    );
  }

  static EquinoxColors light({Color accent = const Color(0xFF4F46E5)}) {
    const gainColor = Color(0xFF059669);
    const spendColor = Color(0xFFD97706); // Warm Amber
    const dangerColor = Color(0xFFE11D48); // Crimson/Rose for deficit/delete
    const neutralColor = Color(0xFF64748B);

    return EquinoxColors(
      bg: const Color(0xFFF6F7FA),
      surface1: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFEEF1F6),
      surface3: const Color(0xFFE2E7F0),
      border: const Color(0xFFD9DFE9),
      borderSubtle: const Color(0xFFE9EDF4),
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF475569),
      textMuted: const Color(0xFF64748B),
      gain: gainColor,
      gainSoft: gainColor.withValues(alpha: 0.12),
      spend: spendColor,
      spendSoft: spendColor.withValues(alpha: 0.12),
      danger: dangerColor,
      dangerSoft: dangerColor.withValues(alpha: 0.12),
      neutral: neutralColor,
      neutralSoft: neutralColor.withValues(alpha: 0.12),
      accent: accent,
      accentSoft: accent.withValues(alpha: 0.13),
    );
  }

  /// Semantic color for an activity coefficient or signed delta:
  /// productive -> [gain], rest -> [spend] (warm amber), neutral -> [neutral].
  Color forCoefficient(double coefficient) {
    if (coefficient > 0) return gain;
    if (coefficient < 0) return spend;
    return neutral;
  }

  Color softForCoefficient(double coefficient) {
    if (coefficient > 0) return gainSoft;
    if (coefficient < 0) return spendSoft;
    return neutralSoft;
  }

  Color forCategory(String category) {
    switch (category) {
      case 'productive':
        return gain;
      case 'rest':
        return spend;
      default:
        return neutral;
    }
  }

  Color softForCategory(String category) {
    switch (category) {
      case 'productive':
        return gainSoft;
      case 'rest':
        return spendSoft;
      default:
        return neutralSoft;
    }
  }

  /// Balance status color relative to [goal]: on/above goal is [gain], below goal is [danger].
  Color forBalance(double balance, {double goal = 0.0}) {
    if (balance >= goal - 0.001) return gain;
    return danger;
  }

  Color softForBalance(double balance, {double goal = 0.0}) {
    if (balance >= goal - 0.001) return gainSoft;
    return dangerSoft;
  }

  @override
  EquinoxColors copyWith({
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? gain,
    Color? gainSoft,
    Color? spend,
    Color? spendSoft,
    Color? danger,
    Color? dangerSoft,
    Color? neutral,
    Color? neutralSoft,
    Color? accent,
    Color? accentSoft,
  }) {
    return EquinoxColors(
      bg: bg ?? this.bg,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      gain: gain ?? this.gain,
      gainSoft: gainSoft ?? this.gainSoft,
      spend: spend ?? this.spend,
      spendSoft: spendSoft ?? this.spendSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      neutral: neutral ?? this.neutral,
      neutralSoft: neutralSoft ?? this.neutralSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  EquinoxColors lerp(covariant EquinoxColors? other, double t) {
    if (other is! EquinoxColors) return this;
    return EquinoxColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      gain: Color.lerp(gain, other.gain, t)!,
      gainSoft: Color.lerp(gainSoft, other.gainSoft, t)!,
      spend: Color.lerp(spend, other.spend, t)!,
      spendSoft: Color.lerp(spendSoft, other.spendSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      neutralSoft: Color.lerp(neutralSoft, other.neutralSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

extension EquinoxThemeContext on BuildContext {
  EquinoxColors get eq =>
      Theme.of(this).extension<EquinoxColors>() ?? EquinoxColors.dark();
}
