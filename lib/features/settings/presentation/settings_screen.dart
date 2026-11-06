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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Equilibrium Target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your ideal daily net balance score. 0.0 means pure balance between work and rest. Positive values target a work surplus.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Target Net Points',
                hintText: 'e.g. 0.0 or 2.0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              ref.read(settingsProvider.notifier).setEquilibriumTarget(val);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Target'),
          ),
        ],
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
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.track_changes, color: AppColors.primaryLight),
                  title: const Text('Daily Target Goal'),
                  subtitle: const Text('Target net balance score for each day'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      ScoreCalculator.formatScore(settings.equilibriumTarget),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  onTap: () => _showTargetGoalDialog(
                    context,
                    ref,
                    settings.equilibriumTarget,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.nightlight_round, color: AppColors.primaryLight),
                  title: const Text('Day Rollover Hour'),
                  subtitle: const Text('Hour when previous day transitions to new day'),
                  trailing: Text(
                    settings.rolloverHour == 0
                        ? '12:00 AM'
                        : '${settings.rolloverHour}:00 AM',
                    style: const TextStyle(fontWeight: FontWeight.w700),
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
          const SizedBox(height: 20),

          // Section 2: Data Management (100% Offline & Sync-Ready)
          _buildSectionHeader('DATA BACKUP & MULTI-DEVICE SYNC'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: AppColors.productive),
                  title: const Text('Export JSON Backup'),
                  subtitle: const Text('Sync-ready schema with UUIDs (for Syncthing / desktop transfer)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportJson(context, ref),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined, color: AppColors.primaryLight),
                  title: const Text('Import / Merge Backup (JSON)'),
                  subtitle: const Text('Smart UUID merge or replace all local records'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importJson(context, ref),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined, color: AppColors.restWarning),
                  title: const Text('Export CSV Spreadsheet'),
                  subtitle: const Text('Export all historical entries for Excel / Google Sheets'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportCsv(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Privacy & About
          _buildSectionHeader('PRIVACY & ABOUT'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppColors.productive),
                  title: const Text('100% Offline-First'),
                  subtitle: const Text(
                    'Zero internet permissions. All data, calculations, and heatmaps stay strictly on your local device.',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
                  title: const Text('Equinox'),
                  subtitle: const Text('Weighted Time Tracking & Work-Rest Equilibrium • v1.0.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
