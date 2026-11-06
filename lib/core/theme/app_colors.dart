import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds & Surfaces (Deep Obsidian Aesthetic)
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF181B24);
  static const Color surfaceElevated = Color(0xFF222634);
  static const Color surfaceHighlight = Color(0xFF2C3244);
  static const Color border = Color(0xFF2D3345);
  static const Color borderSubtle = Color(0xFF1E2330);

  // Text Colors
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Category & Balance Accents
  static const Color productive = Color(0xFF10B981); // Emerald
  static const Color productiveGlow = Color(0x3310B981);
  static const Color rest = Color(0xFFF43F5E); // Rose / Coral
  static const Color restGlow = Color(0x33F43F5E);
  static const Color restWarning = Color(0xFFF97316); // Orange
  static const Color restMild = Color(0xFFF59E0B); // Amber
  static const Color neutral = Color(0xFF64748B); // Slate
  static const Color neutralGlow = Color(0x3364748B);

  // Primary Action Accent
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryGlow = Color(0x406366F1);

  // Curated Color Palette for Activities
  static const List<Color> activityPalette = [
    Color(0xFF10B981), // Emerald
    Color(0xFF059669), // Deep Emerald
    Color(0xFF14B8A6), // Teal
    Color(0xFF06B6D4), // Cyan
    Color(0xFF0284C7), // Sky Blue
    Color(0xFF3B82F6), // Blue
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF7C3AED), // Violet
    Color(0xFF8B5CF6), // Purple
    Color(0xFFA855F7), // Amethyst
    Color(0xFFD946EF), // Magenta
    Color(0xFFEC4899), // Pink
    Color(0xFFF43F5E), // Rose
    Color(0xFFE11D48), // Crimson
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFEA580C), // Deep Coral
    Color(0xFFF59E0B), // Amber
    Color(0xFFEAB308), // Yellow Gold
    Color(0xFF84CC16), // Lime
    Color(0xFF65A30D), // Olive
    Color(0xFF64748B), // Slate
    Color(0xFF78716C), // Warm Stone
  ];

  static Color forCoefficient(double coefficient) {
    if (coefficient > 0) return productive;
    if (coefficient < 0) return rest;
    return neutral;
  }
}
