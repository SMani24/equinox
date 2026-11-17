import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/eq_card.dart';
import '../../../core/utils/score_calculator.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    try {
      final backupService = ref.read(backupServiceProvider);
      final jsonString = await backupService.exportToJsonString();

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${tempDir.path}/equinox_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            subject: 'Equinox Backup ($dateStr)',
            text: 'Equinox offline backup file',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final backupService = ref.read(backupServiceProvider);
      final csvString = await backupService.exportToCsvString();

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${tempDir.path}/equinox_entries_$dateStr.csv');
      await file.writeAsString(csvString);

      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'text/csv')],
            subject: 'Equinox CSV Export ($dateStr)',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final eq = context.eq;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) return;

      final path = files.single.path;
      if (path == null) return;
      final jsonContent = await File(path).readAsString();

      if (!context.mounted) return;

      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup File'),
          content: const Text(
            'Choose how to apply this backup:\n\n'
            '• Smart Merge: merges records by UUID without losing existing data.\n\n'
            '• Replace All: completely overwrites local data with the backup file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Smart Merge'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: eq.danger),
              onPressed: () => Navigator.of(ctx).pop('replace'),
              child: const Text('Replace All'),
            ),
          ],
        ),
      );

      if (mode == null || !context.mounted) return;

      final backupService = ref.read(backupServiceProvider);
      final summary = await backupService.importFromJsonString(
        jsonContent,
        smartMerge: mode == 'merge',
      );
      await ref.read(settingsProvider.notifier).reload();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported: +${summary.activitiesAdded} activities (${summary.activitiesUpdated} updated), +${summary.entriesAdded} sessions (${summary.entriesUpdated} updated)',
            ),
            backgroundColor: eq.gain,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _showTargetGoalDialog(
      BuildContext context, WidgetRef ref, double current) {
    final eq = context.eq;
    final controller = TextEditingController(text: current.toStringAsFixed(1));
    double selectedVal = current;
    final presets = [0.0, 1.0, 2.0, 3.0, 5.0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void saveTarget(double val) {
            setDialogState(() {
              selectedVal = val;
              controller.text = val.toStringAsFixed(1);
            });
            ref.read(settingsProvider.notifier).setEquilibriumTarget(val);
          }

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  ref.read(settingsProvider.notifier).setEquilibriumTarget(val);
                }
              }
            },
            child: AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Daily Target Goal')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: eq.gainSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Auto-saved',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: eq.gain,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0.0 means pure balance between work and rest. Positive values target a work surplus.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.sm,
                    children: presets.map((p) {
                      final isSelected = (selectedVal - p).abs() < 0.05;
                      final label =
                          p == 0.0 ? '0.0 (Balanced)' : '+${p.toStringAsFixed(1)}';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => saveTarget(p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Custom Target Net Points',
                      hintText: 'e.g. 0.0 or 2.0',
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text);
                      if (val != null) {
                        setDialogState(() => selectedVal = val);
                        ref
                            .read(settingsProvider.notifier)
                            .setEquilibriumTarget(val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    final val = double.tryParse(controller.text);
                    if (val != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setEquilibriumTarget(val);
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRestBudgetDialog(
      BuildContext context, WidgetRef ref, double? current) {
    final presets = [null, 2.0, 3.0, 4.0, 6.0];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Rest Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optional soft ceiling on daily rest points spent. Warnings only highlight days exceeding this budget.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: Space.md),
            ...presets.map((val) {
              final selected = (val == null && current == null) ||
                  (val != null &&
                      current != null &&
                      (val - current).abs() < 0.05);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(
                  val == null ? 'Off (no budget limit)' : 'Max -${val.toStringAsFixed(1)} pts/day',
                ),
                onTap: () {
                  ref.read(settingsProvider.notifier).setDailyRestBudget(val);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showRolloverHourDialog(BuildContext context, WidgetRef ref, int current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Day Rollover Hour'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose when your new logical day starts (ideal for night owls).',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: Space.md),
            RadioGroup<int>(
              groupValue: current,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).setRolloverHour(val);
                  Navigator.of(ctx).pop();
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [0, 2, 3, 4, 5, 6].map((hour) {
                  final label = hour == 0
                      ? 'Midnight (12:00 AM standard)'
                      : '$hour:00 AM';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    leading: Radio<int>(value: hour),
                    onTap: () {
                      ref.read(settingsProvider.notifier).setRolloverHour(hour);
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = context.eq;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.xxl,
        ),
        children: [
          _buildSectionHeader(context, 'Goals & day boundary'),
          EqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: _buildLeadingIcon(
                      Icons.track_changes_rounded, eq.accent),
                  title: const Text('Daily target goal',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Daily target net balance points',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _valuePill(
                    context,
                    ScoreCalculator.formatScore(settings.equilibriumTarget),
                  ),
                  onTap: () => _showTargetGoalDialog(
                    context,
                    ref,
                    settings.equilibriumTarget,
                  ),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading: _buildLeadingIcon(Icons.shield_moon_outlined, eq.spend),
                  title: const Text('Daily rest budget',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Optional cap on daily rest spend',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _valuePill(
                    context,
                    settings.dailyRestBudget == null
                        ? 'Off'
                        : '-${settings.dailyRestBudget!.toStringAsFixed(1)} pts',
                  ),
                  onTap: () => _showRestBudgetDialog(
                    context,
                    ref,
                    settings.dailyRestBudget,
                  ),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading: _buildLeadingIcon(Icons.nightlight_round, eq.accent),
                  title: const Text('Day rollover hour',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Hour when a new logical day begins',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: _valuePill(
                    context,
                    settings.rolloverHour == 0
                        ? '12:00 AM'
                        : '${settings.rolloverHour}:00 AM',
                  ),
                  onTap: () => _showRolloverHourDialog(
                    context,
                    ref,
                    settings.rolloverHour,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),

          _buildSectionHeader(context, 'Appearance'),
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: Space.sm),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (sel) {
                      if (sel.isNotEmpty) notifier.setThemeMode(sel.first);
                    },
                  ),
                ),
                const SizedBox(height: Space.lg),
                Text(
                  'Accent color',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.md,
                  children: AppAccentPreset.values.map((preset) {
                    final selected = settings.accentPreset == preset;
                    final color =
                        Theme.of(context).brightness == Brightness.dark
                            ? preset.darkAccent
                            : preset.lightAccent;
                    return GestureDetector(
                      onTap: () => notifier.setAccentPreset(preset),
                      child: Tooltip(
                        message: preset.label,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? eq.textPrimary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),

          _buildSectionHeader(context, 'Smart features (offline)'),
          EqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary:
                      _buildLeadingIcon(Icons.auto_awesome_rounded, eq.accent),
                  title: const Text('Smart suggestions',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Rank activities by time-of-day, sequence & duration',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: settings.smartSuggestionsEnabled,
                  onChanged: notifier.setSmartSuggestionsEnabled,
                ),
                const Divider(height: 1, indent: 64),
                SwitchListTile(
                  secondary: _buildLeadingIcon(Icons.space_bar_rounded, eq.gain),
                  title: const Text('Gaps & morning sleep catch-up',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Show untracked gaps ≥ ${settings.minGapMinutes}m & morning sleep prompt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: settings.gapRemindersEnabled,
                  onChanged: notifier.setGapRemindersEnabled,
                ),
                const Divider(height: 1, indent: 64),
                SwitchListTile(
                  secondary: _buildLeadingIcon(
                      Icons.notifications_active_outlined, eq.spend),
                  title: const Text('Forgotten timer check',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Warn if a running timer exceeds normal session length',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: settings.forgottenTimerAlertEnabled,
                  onChanged: notifier.setForgottenTimerAlertEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),

          _buildSectionHeader(context, 'Data backup & sync'),
          EqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading:
                      _buildLeadingIcon(Icons.file_download_outlined, eq.gain),
                  title: const Text('Export JSON backup',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Sync-ready backup file with UUIDs',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Icon(Icons.chevron_right, color: eq.textMuted),
                  onTap: () => _exportJson(context, ref),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading:
                      _buildLeadingIcon(Icons.file_upload_outlined, eq.accent),
                  title: const Text('Import JSON backup',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Smart UUID merge or full restore',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Icon(Icons.chevron_right, color: eq.textMuted),
                  onTap: () => _importJson(context, ref),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading:
                      _buildLeadingIcon(Icons.table_chart_outlined, eq.spend),
                  title: const Text('Export CSV spreadsheet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Session log for Excel / Sheets',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Icon(Icons.chevron_right, color: eq.textMuted),
                  onTap: () => _exportCsv(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),

          _buildSectionHeader(context, 'Privacy & about'),
          EqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: _buildLeadingIcon(Icons.shield_outlined, eq.gain),
                  title: const Text('100% Offline-First',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Zero internet permissions. All data, smart suggestions, and charts run locally on-device.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading:
                      _buildLeadingIcon(Icons.info_outline, eq.textSecondary),
                  title: const Text('Equinox',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Weighted Time Tracking & Equilibrium • v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valuePill(BuildContext context, String text) {
    final eq = context.eq;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: eq.surface2,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: eq.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final eq = context.eq;
    return Padding(
      padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: eq.textMuted,
            ),
      ),
    );
  }
}
