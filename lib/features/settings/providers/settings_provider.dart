import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/database/app_database.dart';

class SettingsState {
  final double equilibriumTarget;
  final int rolloverHour;
  final bool isLoading;

  const SettingsState({
    required this.equilibriumTarget,
    required this.rolloverHour,
    this.isLoading = false,
  });

  SettingsState copyWith({
    double? equilibriumTarget,
    int? rolloverHour,
    bool? isLoading,
  }) {
    return SettingsState(
      equilibriumTarget: equilibriumTarget ?? this.equilibriumTarget,
      rolloverHour: rolloverHour ?? this.rolloverHour,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState(
      equilibriumTarget: 0.0,
      rolloverHour: 0,
      isLoading: true,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final db = ref.read(databaseProvider);
      final rows = await db.select(db.appSettings).get();
      double target = 0.0;
      int rollover = 0;

      for (final row in rows) {
        if (row.key == 'equilibrium_target') {
          target = double.tryParse(row.value) ?? 0.0;
        } else if (row.key == 'rollover_hour') {
          rollover = int.tryParse(row.value) ?? 0;
        }
      }

      state = SettingsState(
        equilibriumTarget: target,
        rolloverHour: rollover,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setEquilibriumTarget(double target) async {
    state = state.copyWith(equilibriumTarget: target);
    final db = ref.read(databaseProvider);
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'equilibrium_target',
            value: target.toString(),
          ),
        );
  }

  Future<void> setRolloverHour(int hour) async {
    state = state.copyWith(rolloverHour: hour);
    final db = ref.read(databaseProvider);
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: 'rollover_hour',
            value: hour.toString(),
          ),
        );
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
