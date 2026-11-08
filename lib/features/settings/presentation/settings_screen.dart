import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
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

      // Ask user whether to Replace All or Smart Merge
      final mode = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Backup File'),
          content: const Text(
            'Choose how to apply this backup:\n\n'
            '• Smart Merge: merges records by UUID without losing existing data (recommended for multi-device sync).\n\n'
            '• Replace All: completely overwrites local data with the backup file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Smart Merge'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rest),
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported: +${summary.activitiesAdded} activities (${summary.activitiesUpdated} updated), +${summary.entriesAdded} sessions (${summary.entriesUpdated} updated)',
            ),
            backgroundColor: AppColors.productive,
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

  void _showTargetGoalDialog(BuildContext context, WidgetRef ref, double current) {
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
                  const Text('Daily Equilibrium Target'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.productive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: AppColors.productive),
                        SizedBox(width: 4),
                        Text(
                          'Auto-saved',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.productive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set your ideal daily net balance score. 0.0 means pure balance between work and rest. Positive values target a work surplus.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: presets.map((p) {
                      final isSelected = (selectedVal - p).abs() < 0.05;
                      final label = p == 0.0 ? '0.0 (Balanced)' : '+${p.toStringAsFixed(1)}';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) => saveTarget(p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
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
                        setDialogState(() {
                          selectedVal = val;
                        });
                        ref.read(settingsProvider.notifier).setEquilibriumTarget(val);
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
                      ref.read(settingsProvider.notifier).setEquilibriumTarget(val);
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

  void _showRolloverHourDialog(BuildContext context, WidgetRef ref, int current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Day Rollover Hour'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose when your "new day" starts. Ideal for night owls so late-night sessions (e.g. at 2 AM) count toward the current logical day.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Backup'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1: Equilibrium & Daily Goals
          _buildSectionHeader('EQUILIBRIUM & GOALS'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildLeadingIcon(
                      Icons.track_changes_rounded, AppColors.primaryLight),
                  title: const Text(
                    'Daily Target Goal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Daily target net balance points',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      ScoreCalculator.formatScore(settings.equilibriumTarget),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  onTap: () => _showTargetGoalDialog(
                    context,
                    ref,
                    settings.equilibriumTarget,
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildLeadingIcon(
                      Icons.nightlight_round, AppColors.primaryLight),
                  title: const Text(
                    'Day Rollover Hour',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Hour when a new logical day starts',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      settings.rolloverHour == 0
                          ? '12:00 AM'
                          : '${settings.rolloverHour}:00 AM',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
          const SizedBox(height: 24),

          // Section 2: Data Management (100% Offline & Sync-Ready)
          _buildSectionHeader('DATA BACKUP & MULTI-DEVICE SYNC'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildLeadingIcon(
                      Icons.file_download_outlined, AppColors.productive),
                  title: const Text(
                    'Export JSON Backup',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Sync-ready backup file with unique UUIDs',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onTap: () => _exportJson(context, ref),
                ),
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildLeadingIcon(
                      Icons.file_upload_outlined, AppColors.primaryLight),
                  title: const Text(
                    'Import JSON Backup',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Smart UUID merge or complete restore',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onTap: () => _importJson(context, ref),
                ),
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildLeadingIcon(
                      Icons.table_chart_outlined, AppColors.restWarning),
                  title: const Text(
                    'Export CSV Spreadsheet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Full session history for Excel / Google Sheets',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onTap: () => _exportCsv(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Privacy & About
          _buildSectionHeader('PRIVACY & ABOUT'),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: _buildLeadingIcon(
                      Icons.shield_outlined, AppColors.productive),
                  title: const Text(
                    '100% Offline-First',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'Zero internet permissions. All data, calculations, and heatmaps stay strictly on your local device.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 16,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _buildLeadingIcon(
                      Icons.info_outline, AppColors.textSecondary),
                  title: const Text(
                    'Equinox',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Weighted Time Tracking & Balance Engine • v1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
