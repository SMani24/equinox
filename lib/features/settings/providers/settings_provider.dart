import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/database/app_database.dart';

class SettingsState {
  final double equilibriumTarget;
  final int rolloverHour;
  final ThemeMode themeMode;
  final AppAccentPreset accentPreset;
  final double? dailyRestBudget;
  final bool smartSuggestionsEnabled;
  final bool gapRemindersEnabled;
  final bool forgottenTimerAlertEnabled;
  final int minGapMinutes;
  final String? dismissedSleepCatchupDate;
  final bool isLoading;

  const SettingsState({
    required this.equilibriumTarget,
    required this.rolloverHour,
    this.themeMode = ThemeMode.dark,
    this.accentPreset = AppAccentPreset.indigo,
    this.dailyRestBudget,
    this.smartSuggestionsEnabled = true,
    this.gapRemindersEnabled = true,
    this.forgottenTimerAlertEnabled = true,
    this.minGapMinutes = 15,
    this.dismissedSleepCatchupDate,
    this.isLoading = false,
  });

  SettingsState copyWith({
    double? equilibriumTarget,
    int? rolloverHour,
    ThemeMode? themeMode,
    AppAccentPreset? accentPreset,
    double? dailyRestBudget,
    bool clearDailyRestBudget = false,
    bool? smartSuggestionsEnabled,
    bool? gapRemindersEnabled,
    bool? forgottenTimerAlertEnabled,
    int? minGapMinutes,
    String? dismissedSleepCatchupDate,
    bool? isLoading,
  }) {
    return SettingsState(
      equilibriumTarget: equilibriumTarget ?? this.equilibriumTarget,
      rolloverHour: rolloverHour ?? this.rolloverHour,
      themeMode: themeMode ?? this.themeMode,
      accentPreset: accentPreset ?? this.accentPreset,
      dailyRestBudget: clearDailyRestBudget
          ? null
          : (dailyRestBudget ?? this.dailyRestBudget),
      smartSuggestionsEnabled:
          smartSuggestionsEnabled ?? this.smartSuggestionsEnabled,
      gapRemindersEnabled: gapRemindersEnabled ?? this.gapRemindersEnabled,
      forgottenTimerAlertEnabled:
          forgottenTimerAlertEnabled ?? this.forgottenTimerAlertEnabled,
      minGapMinutes: minGapMinutes ?? this.minGapMinutes,
      dismissedSleepCatchupDate:
          dismissedSleepCatchupDate ?? this.dismissedSleepCatchupDate,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _kEquilibriumTarget = 'equilibrium_target';
  static const _kRolloverHour = 'rollover_hour';
  static const _kThemeMode = 'theme_mode';
  static const _kAccentPreset = 'accent_preset';
  static const _kDailyRestBudget = 'daily_rest_budget';
  static const _kSmartSuggestions = 'smart_suggestions';
  static const _kGapReminders = 'gap_reminders';
  static const _kForgottenTimerAlert = 'forgotten_timer_alert';
  static const _kMinGapMinutes = 'min_gap_minutes';
  static const _kDismissedSleepCatchup = 'dismissed_sleep_catchup_date';

  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState(
      equilibriumTarget: 0.0,
      rolloverHour: 0,
      isLoading: true,
    );
  }

  Future<void> reload() => _loadSettings();

  Future<void> _loadSettings() async {
    try {
      final db = ref.read(databaseProvider);
      final rows = await db.select(db.appSettings).get();
      double target = 0.0;
      int rollover = 0;
      ThemeMode themeMode = ThemeMode.dark;
      AppAccentPreset accentPreset = AppAccentPreset.indigo;
      double? restBudget;
      bool smartSuggestions = true;
      bool gapReminders = true;
      bool forgottenAlert = true;
      int minGapMinutes = 15;
      String? dismissedSleepDate;

      for (final row in rows) {
        switch (row.key) {
          case _kEquilibriumTarget:
            target = double.tryParse(row.value) ?? 0.0;
          case _kRolloverHour:
            rollover = int.tryParse(row.value) ?? 0;
          case _kThemeMode:
            themeMode = _parseThemeMode(row.value);
          case _kAccentPreset:
            accentPreset = AppAccentPreset.fromKey(row.value);
          case _kDailyRestBudget:
            final parsed = double.tryParse(row.value);
            restBudget = (parsed != null && parsed > 0) ? parsed : null;
          case _kSmartSuggestions:
            smartSuggestions = row.value != 'false';
          case _kGapReminders:
            gapReminders = row.value != 'false';
          case _kForgottenTimerAlert:
            forgottenAlert = row.value != 'false';
          case _kMinGapMinutes:
            minGapMinutes = (int.tryParse(row.value) ?? 15).clamp(5, 120);
          case _kDismissedSleepCatchup:
            dismissedSleepDate = row.value.isEmpty ? null : row.value;
        }
      }

      state = SettingsState(
        equilibriumTarget: target,
        rolloverHour: rollover,
        themeMode: themeMode,
        accentPreset: accentPreset,
        dailyRestBudget: restBudget,
        smartSuggestionsEnabled: smartSuggestions,
        gapRemindersEnabled: gapReminders,
        forgottenTimerAlertEnabled: forgottenAlert,
        minGapMinutes: minGapMinutes,
        dismissedSleepCatchupDate: dismissedSleepDate,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  ThemeMode _parseThemeMode(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final db = ref.read(databaseProvider);
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> setEquilibriumTarget(double target) async {
    state = state.copyWith(equilibriumTarget: target);
    await _saveSetting(_kEquilibriumTarget, target.toString());
  }

  Future<void> setRolloverHour(int hour) async {
    state = state.copyWith(rolloverHour: hour);
    await _saveSetting(_kRolloverHour, hour.toString());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveSetting(_kThemeMode, mode.name);
  }

  Future<void> setAccentPreset(AppAccentPreset preset) async {
    state = state.copyWith(accentPreset: preset);
    await _saveSetting(_kAccentPreset, preset.name);
  }

  Future<void> setDailyRestBudget(double? budget) async {
    if (budget == null || budget <= 0) {
      state = state.copyWith(clearDailyRestBudget: true);
      await _saveSetting(_kDailyRestBudget, '0');
    } else {
      state = state.copyWith(dailyRestBudget: budget);
      await _saveSetting(_kDailyRestBudget, budget.toStringAsFixed(1));
    }
  }

  Future<void> setSmartSuggestionsEnabled(bool enabled) async {
    state = state.copyWith(smartSuggestionsEnabled: enabled);
    await _saveSetting(_kSmartSuggestions, enabled.toString());
  }

  Future<void> setGapRemindersEnabled(bool enabled) async {
    state = state.copyWith(gapRemindersEnabled: enabled);
    await _saveSetting(_kGapReminders, enabled.toString());
  }

  Future<void> setForgottenTimerAlertEnabled(bool enabled) async {
    state = state.copyWith(forgottenTimerAlertEnabled: enabled);
    await _saveSetting(_kForgottenTimerAlert, enabled.toString());
  }

  Future<void> setMinGapMinutes(int minutes) async {
    final clamped = minutes.clamp(5, 120);
    state = state.copyWith(minGapMinutes: clamped);
    await _saveSetting(_kMinGapMinutes, clamped.toString());
  }

  Future<void> dismissSleepCatchupForDate(String isoDayKey) async {
    state = state.copyWith(dismissedSleepCatchupDate: isoDayKey);
    await _saveSetting(_kDismissedSleepCatchup, isoDayKey);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
