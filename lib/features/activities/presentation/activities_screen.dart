import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../providers/activities_provider.dart';
import 'activity_form_sheet.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  String _activeTab = 'all'; // 'all', 'productive', 'rest', 'neutral', 'archived'

  void _showFormSheet({Activity? activityToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => ActivityFormSheet(
        activityToEdit: activityToEdit,
        onSave: ({
          required String name,
          required String category,
          required double coefficient,
          required int colorHex,
          required int iconCode,
          bool recalculatePast = false,
        }) async {
          final repo = ref.read(activityRepositoryProvider);
          if (activityToEdit != null) {
            await repo.updateActivity(
              id: activityToEdit.id,
              name: name,
              category: category,
              coefficient: coefficient,
              colorHex: colorHex,
              iconCode: iconCode,
              recalculatePastEntries: recalculatePast,
            );
          } else {
            await repo.createActivity(
              name: name,
              category: category,
              coefficient: coefficient,
              colorHex: colorHex,
              iconCode: iconCode,
            );
          }
        },
        onDelete: activityToEdit != null
            ? () {
                ref.read(activityRepositoryProvider).deleteActivity(activityToEdit.id);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showArchived = _activeTab == 'archived';
    final activitiesAsync = showArchived
        ? ref.watch(allActivitiesStreamProvider)
        : ref.watch(activitiesStreamProvider);

    final allList = activitiesAsync.value ?? [];
    final activities = allList.where((a) {
      if (_activeTab == 'archived') return a.isArchived;
      if (_activeTab == 'productive') return a.category == 'productive';
      if (_activeTab == 'rest') return a.category == 'rest';
      if (_activeTab == 'neutral') return a.category == 'neutral';
      return !a.isArchived;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities & Coefficients'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showFormSheet(),
        icon: const Icon(Icons.add),
        label: const Text('New Activity', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Active'),
                const SizedBox(width: 8),
                _buildFilterChip('productive', 'Productive (+)', AppColors.productive),
                const SizedBox(width: 8),
                _buildFilterChip('rest', 'Rest (-)', AppColors.rest),
                const SizedBox(width: 8),
                _buildFilterChip('neutral', 'Neutral (0.0)', AppColors.neutral),
                const SizedBox(width: 8),
                _buildFilterChip('archived', 'Archived', AppColors.textMuted),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: activities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 48,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          showArchived ? 'No archived activities' : 'No activities in this category',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final act = activities[index];
                      final coeffFormatted =
                          ScoreCalculator.formatCoefficient(act.coefficient);
                      final coeffColor =
                          AppColors.forCoefficient(act.coefficient);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showFormSheet(activityToEdit: act),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(act.colorHex).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    AppIcons.getIconData(act.iconCode),
                                    color: Color(act.colorHex),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        act.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        act.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: coeffColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: coeffColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: coeffColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    coeffFormatted,
                                    style: TextStyle(
                                      color: coeffColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                  onSelected: (val) async {
                                    final repo = ref.read(activityRepositoryProvider);
                                    if (val == 'edit') {
                                      _showFormSheet(activityToEdit: act);
                                    } else if (val == 'archive') {
                                      await repo.setArchived(act.id, !act.isArchived);
                                    } else if (val == 'delete') {
                                      await repo.deleteActivity(act.id);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(act.isArchived ? 'Unarchive' : 'Archive'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete', style: TextStyle(color: AppColors.rest)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, [Color? color]) {
    final isSelected = _activeTab == key;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? (color ?? AppColors.primaryLight) : AppColors.textSecondary,
        ),
      ),
      backgroundColor: AppColors.surface,
      selectedColor: (color ?? AppColors.primaryLight).withValues(alpha: 0.15),
      side: BorderSide(
        color: isSelected ? (color ?? AppColors.primaryLight) : AppColors.border,
      ),
      onSelected: (_) {
        setState(() {
          _activeTab = key;
        });
      },
    );
  }
}
