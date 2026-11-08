import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../providers/activities_provider.dart';
import 'activity_form_sheet.dart';

enum ActivitySortOption {
  custom,
  pointsDesc,
  pointsAsc,
  nameAsc,
}

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  String _activeTab = 'all'; // 'all', 'productive', 'rest', 'neutral', 'archived'
  ActivitySortOption _sortOption = ActivitySortOption.custom;

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

  Future<void> _saveCurrentOrderAsDefault(
      List<Activity> sortedActivities, List<Activity> allList) async {
    final currentFilteredIds = sortedActivities.map((a) => a.id).toSet();
    final List<Activity> newFullList = [];
    int sortedIdx = 0;
    for (final item in allList) {
      if (currentFilteredIds.contains(item.id)) {
        newFullList.add(sortedActivities[sortedIdx]);
        sortedIdx++;
      } else {
        newFullList.add(item);
      }
    }
    final ids = newFullList.map((a) => a.id).toList();
    await ref.read(activityRepositoryProvider).reorderActivities(ids);
    if (!mounted) return;
    setState(() {
      _sortOption = ActivitySortOption.custom;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity order saved as default!'),
        duration: Duration(seconds: 2),
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

    // Apply sorting
    switch (_sortOption) {
      case ActivitySortOption.pointsDesc:
        activities.sort((a, b) => b.coefficient.compareTo(a.coefficient));
        break;
      case ActivitySortOption.pointsAsc:
        activities.sort((a, b) => a.coefficient.compareTo(b.coefficient));
        break;
      case ActivitySortOption.nameAsc:
        activities.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ActivitySortOption.custom:
        // Default DB sort order (preserved as is)
        break;
    }

    final isCustomOrder = _sortOption == ActivitySortOption.custom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities & Coefficients'),
        actions: [
          PopupMenuButton<ActivitySortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort activities',
            initialValue: _sortOption,
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ActivitySortOption.custom,
                child: Row(
                  children: [
                    Icon(
                      Icons.reorder_rounded,
                      size: 20,
                      color: _sortOption == ActivitySortOption.custom
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Custom Order',
                        style: TextStyle(
                          color: _sortOption == ActivitySortOption.custom
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: _sortOption == ActivitySortOption.custom
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_sortOption == ActivitySortOption.custom)
                      const Icon(Icons.check, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ActivitySortOption.pointsDesc,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 20,
                      color: _sortOption == ActivitySortOption.pointsDesc
                          ? AppColors.productive
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Points: High to Low',
                        style: TextStyle(
                          color: _sortOption == ActivitySortOption.pointsDesc
                              ? AppColors.productive
                              : AppColors.textPrimary,
                          fontWeight: _sortOption == ActivitySortOption.pointsDesc
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_sortOption == ActivitySortOption.pointsDesc)
                      const Icon(Icons.check, size: 18, color: AppColors.productive),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ActivitySortOption.pointsAsc,
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: _sortOption == ActivitySortOption.pointsAsc
                          ? AppColors.rest
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Points: Low to High',
                        style: TextStyle(
                          color: _sortOption == ActivitySortOption.pointsAsc
                              ? AppColors.rest
                              : AppColors.textPrimary,
                          fontWeight: _sortOption == ActivitySortOption.pointsAsc
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_sortOption == ActivitySortOption.pointsAsc)
                      const Icon(Icons.check, size: 18, color: AppColors.rest),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ActivitySortOption.nameAsc,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha_rounded,
                      size: 20,
                      color: _sortOption == ActivitySortOption.nameAsc
                          ? AppColors.primaryLight
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Name: A to Z',
                        style: TextStyle(
                          color: _sortOption == ActivitySortOption.nameAsc
                              ? AppColors.primaryLight
                              : AppColors.textPrimary,
                          fontWeight: _sortOption == ActivitySortOption.nameAsc
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (_sortOption == ActivitySortOption.nameAsc)
                      const Icon(Icons.check, size: 18, color: AppColors.primaryLight),
                  ],
                ),
              ),
            ],
          ),
        ],
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

          // Active Sort Banner
          if (!isCustomOrder)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _sortOption == ActivitySortOption.pointsDesc
                        ? Icons.arrow_downward_rounded
                        : _sortOption == ActivitySortOption.pointsAsc
                            ? Icons.arrow_upward_rounded
                            : Icons.sort_by_alpha_rounded,
                    size: 16,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sortOption == ActivitySortOption.pointsDesc
                          ? 'Sorted: Points (High → Low)'
                          : _sortOption == ActivitySortOption.pointsAsc
                              ? 'Sorted: Points (Low → High)'
                              : 'Sorted: Name (A → Z)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _saveCurrentOrderAsDefault(activities, allList),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Save Order',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _sortOption = ActivitySortOption.custom;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
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
                : isCustomOrder
                    ? ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: activities.length,
                        proxyDecorator: (Widget child, int index, Animation<double> animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (BuildContext context, Widget? child) {
                              final double animValue =
                                  Curves.easeInOutCubic.transform(animation.value);
                              final double elevation = lerpDouble(0, 16, animValue)!;
                              final double scale = lerpDouble(1.0, 1.035, animValue)!;
                              return Transform.scale(
                                scale: scale,
                                child: Material(
                                  color: Colors.transparent,
                                  elevation: elevation,
                                  shadowColor: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primaryLight.withValues(alpha: 0.9),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35 * animValue),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: child,
                          );
                        },
                        onReorderItem: (int oldIndex, int newIndex) async {
                          if (oldIndex == newIndex) return;

                          final item = activities[oldIndex];
                          final targetItem = activities[newIndex];

                          final updatedFull = List<Activity>.from(allList);
                          final fullOldIndex = updatedFull.indexOf(item);
                          final fullTargetIndex = updatedFull.indexOf(targetItem);

                          if (fullOldIndex != -1 && fullTargetIndex != -1) {
                            updatedFull.removeAt(fullOldIndex);
                            updatedFull.insert(fullTargetIndex, item);
                            final ids = updatedFull.map((a) => a.id).toList();
                            await ref.read(activityRepositoryProvider).reorderActivities(ids);
                          }
                        },
                        itemBuilder: (context, index) {
                          final act = activities[index];
                          return _buildActivityTile(
                            act: act,
                            index: index,
                            isDraggable: true,
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final act = activities[index];
                          return _buildActivityTile(
                            act: act,
                            index: index,
                            isDraggable: false,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required Activity act,
    required int index,
    required bool isDraggable,
  }) {
    final coeffFormatted = ScoreCalculator.formatCoefficient(act.coefficient);
    final coeffColor = AppColors.forCoefficient(act.coefficient);

    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
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
                if (isDraggable) ...[
                  const SizedBox(width: 4),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
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
      ),
    );

    if (isDraggable) {
      return ReorderableDelayedDragStartListener(
        key: ValueKey(act.id),
        index: index,
        child: content,
      );
    } else {
      return KeyedSubtree(
        key: ValueKey(act.id),
        child: content,
      );
    }
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
