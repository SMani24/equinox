import 'package:flutter/material.dart';
import 'eq_colors.dart';
import 'tokens.dart';

class AppTheme {
  static ThemeData get darkTheme => buildDarkTheme();

  static ThemeData get lightTheme => buildLightTheme();

  static ThemeData buildDarkTheme({
    AppAccentPreset accentPreset = AppAccentPreset.indigo,
  }) {
    final eq = EquinoxColors.dark(accent: accentPreset.darkAccent);
    return _buildTheme(brightness: Brightness.dark, eq: eq);
  }

  static ThemeData buildLightTheme({
    AppAccentPreset accentPreset = AppAccentPreset.indigo,
  }) {
    final eq = EquinoxColors.light(accent: accentPreset.lightAccent);
    return _buildTheme(brightness: Brightness.light, eq: eq);
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required EquinoxColors eq,
  }) {
    final isDark = brightness == Brightness.dark;
    final baseTextTheme =
        (isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
    final tabularFeature = [const FontFeature.tabularFigures()];

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.0,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFeatures: tabularFeature,
        fontSize: 15,
        color: eq.textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFeatures: tabularFeature,
        fontSize: 14,
        color: eq.textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontFeatures: tabularFeature,
        fontSize: 12,
        color: eq.textMuted,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFeatures: tabularFeature,
        color: eq.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: eq.accent,
            onPrimary: const Color(0xFF0B0D12),
            secondary: eq.gain,
            onSecondary: const Color(0xFF0B0D12),
            surface: eq.surface1,
            onSurface: eq.textPrimary,
            error: eq.danger,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: eq.accent,
            onPrimary: Colors.white,
            secondary: eq.gain,
            onSecondary: Colors.white,
            surface: eq.surface1,
            onSurface: eq.textPrimary,
            error: eq.danger,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: eq.bg,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [eq],
      cardTheme: CardThemeData(
        color: eq.surface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: eq.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: eq.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: eq.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: eq.surface1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: eq.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: eq.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: eq.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: eq.accent);
          }
          return IconThemeData(color: eq.textMuted);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: eq.surface1,
        indicatorColor: eq.accentSoft,
        selectedIconTheme: IconThemeData(color: eq.accent),
        unselectedIconTheme: IconThemeData(color: eq.textMuted),
        selectedLabelTextStyle: TextStyle(
          color: eq.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: eq.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: eq.surface1,
          selectedBackgroundColor: eq.accentSoft,
          selectedForegroundColor: eq.accent,
          foregroundColor: eq.textSecondary,
          side: BorderSide(color: eq.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: eq.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: eq.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: eq.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: eq.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: eq.accent, width: 1.5),
        ),
        labelStyle: TextStyle(color: eq.textSecondary),
        hintStyle: TextStyle(color: eq.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: eq.surface3,
        contentTextStyle: TextStyle(color: eq.textPrimary),
        actionTextColor: eq.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: eq.surface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: eq.surface1,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
    );
  }
}
