import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/activity_avatar.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../timer/providers/timer_provider.dart';
import '../providers/activities_provider.dart';
import 'activity_detail_page.dart';
import 'activity_form_sheet.dart';

enum ActivitySortOption {
  custom,
  mostUsed,
  recentlyUsed,
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
  String _activeTab = 'all';
  ActivitySortOption _sortOption = ActivitySortOption.custom;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFormSheet({
    Activity? activityToEdit,
    required List<Activity> allActivities,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ActivityFormSheet(
        activityToEdit: activityToEdit,
        existingActivities: allActivities,
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
                ref
                    .read(activityRepositoryProvider)
                    .deleteActivity(activityToEdit.id);
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
    setState(() => _sortOption = ActivitySortOption.custom);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity order saved as default'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final showArchived = _activeTab == 'archived';
    final activitiesAsync = showArchived
        ? ref.watch(allActivitiesStreamProvider)
        : ref.watch(activitiesStreamProvider);
    final allIncludingArchived =
        ref.watch(allActivitiesStreamProvider).value ?? [];
    final weeklyStats = ref.watch(activityWeeklyStatsProvider);
    final history = ref.watch(recentHistoryEntriesProvider).value ?? [];

    final Map<String, int> lastUsedByAct = {};
    for (final h in history) {
      final cur = lastUsedByAct[h.activity.id] ?? 0;
      if (h.entry.endTime > cur) lastUsedByAct[h.activity.id] = h.entry.endTime;
    }

    final allList = activitiesAsync.value ?? [];
    final q = _searchQuery.trim().toLowerCase();
    final activities = allList.where((a) {
      if (_activeTab == 'archived') {
        if (!a.isArchived) return false;
      } else if (_activeTab != 'all' && a.category != _activeTab) {
        return false;
      } else if (a.isArchived) {
        return false;
      }
      if (q.isNotEmpty && !a.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();

    switch (_sortOption) {
      case ActivitySortOption.mostUsed:
        activities.sort((a, b) {
          final sa = weeklyStats[a.id]?.weekSeconds ?? 0;
          final sb = weeklyStats[b.id]?.weekSeconds ?? 0;
          return sb.compareTo(sa);
        });
      case ActivitySortOption.recentlyUsed:
        activities.sort((a, b) {
          final la = lastUsedByAct[a.id] ?? 0;
          final lb = lastUsedByAct[b.id] ?? 0;
          return lb.compareTo(la);
        });
      case ActivitySortOption.pointsDesc:
        activities.sort((a, b) => b.coefficient.compareTo(a.coefficient));
      case ActivitySortOption.pointsAsc:
        activities.sort((a, b) => a.coefficient.compareTo(b.coefficient));
      case ActivitySortOption.nameAsc:
        activities.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case ActivitySortOption.custom:
        break;
    }

    final isCustomOrder =
        _sortOption == ActivitySortOption.custom && _searchQuery.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        actions: [
          PopupMenuButton<ActivitySortOption>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort activities',
            initialValue: _sortOption,
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (context) => [
              _sortMenuItem(
                ActivitySortOption.custom,
                Icons.reorder_rounded,
                'Custom Order',
                eq.accent,
              ),
              _sortMenuItem(
                ActivitySortOption.mostUsed,
                Icons.local_fire_department_rounded,
                'Most used (7d)',
                eq.gain,
              ),
              _sortMenuItem(
                ActivitySortOption.recentlyUsed,
                Icons.history_rounded,
                'Recently used',
                eq.accent,
              ),
              _sortMenuItem(
                ActivitySortOption.pointsDesc,
                Icons.arrow_downward_rounded,
                'Points: High to Low',
                eq.gain,
              ),
              _sortMenuItem(
                ActivitySortOption.pointsAsc,
                Icons.arrow_upward_rounded,
                'Points: Low to High',
                eq.spend,
              ),
              _sortMenuItem(
                ActivitySortOption.nameAsc,
                Icons.sort_by_alpha_rounded,
                'Name: A to Z',
                eq.accent,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: eq.accent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0B0D12)
            : Colors.white,
        onPressed: () =>
            _showFormSheet(allActivities: allIncludingArchived),
        icon: const Icon(Icons.add),
        label: const Text('New Activity',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.xs,
              Space.lg,
              Space.sm,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search activities…',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.xs,
            ),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Active', eq.accent),
                const SizedBox(width: Space.sm),
                _buildFilterChip('productive', 'Productive', eq.gain),
                const SizedBox(width: Space.sm),
                _buildFilterChip('rest', 'Rest', eq.spend),
                const SizedBox(width: Space.sm),
                _buildFilterChip('neutral', 'Neutral', eq.neutral),
                const SizedBox(width: Space.sm),
                _buildFilterChip('archived', 'Archived', eq.textMuted),
              ],
            ),
          ),

          if (_sortOption != ActivitySortOption.custom)
            Container(
              margin: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.xs,
                Space.lg,
                Space.sm,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: eq.accentSoft,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.sort_rounded, size: 16, color: eq.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sorted by ${_sortOption.name}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: eq.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () =>
                        _saveCurrentOrderAsDefault(activities, allList),
                    child: const Text('Save Order'),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _sortOption = ActivitySortOption.custom),
                  ),
                ],
              ),
            ),

          Expanded(
            child: activities.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: EmptyState(
                      icon: Icons.category_outlined,
                      title: showArchived
                          ? 'No archived activities'
                          : 'No matching activities',
                      body: 'Tap New Activity below to create one.',
                    ),
                  )
                : isCustomOrder
                    ? ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(
                          Space.lg,
                          Space.sm,
                          Space.lg,
                          92,
                        ),
                        itemCount: activities.length,
                        proxyDecorator:
                            (Widget child, int index, Animation<double> anim) {
                          return AnimatedBuilder(
                            animation: anim,
                            builder: (ctx, c) {
                              final t = Curves.easeInOutCubic.transform(anim.value);
                              final scale = lerpDouble(1.0, 1.03, t)!;
                              return Transform.scale(
                                scale: scale,
                                child: Material(
                                  color: Colors.transparent,
                                  elevation: lerpDouble(0, 12, t)!,
                                  borderRadius: BorderRadius.circular(Radii.md),
                                  child: child,
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
                            await ref
                                .read(activityRepositoryProvider)
                                .reorderActivities(
                                  updatedFull.map((a) => a.id).toList(),
                                );
                          }
                        },
                        itemBuilder: (context, index) => _buildActivityTile(
                          act: activities[index],
                          index: index,
                          isDraggable: true,
                          allIncludingArchived: allIncludingArchived,
                          stat: weeklyStats[activities[index].id],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          Space.lg,
                          Space.sm,
                          Space.lg,
                          92,
                        ),
                        itemCount: activities.length,
                        itemBuilder: (context, index) => _buildActivityTile(
                          act: activities[index],
                          index: index,
                          isDraggable: false,
                          allIncludingArchived: allIncludingArchived,
                          stat: weeklyStats[activities[index].id],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ActivitySortOption> _sortMenuItem(
    ActivitySortOption opt,
    IconData icon,
    String label,
    Color activeColor,
  ) {
    final eq = context.eq;
    final selected = _sortOption == opt;
    return PopupMenuItem(
      value: opt,
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? activeColor : eq.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : eq.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (selected) Icon(Icons.check, size: 16, color: activeColor),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required Activity act,
    required int index,
    required bool isDraggable,
    required List<Activity> allIncludingArchived,
    required ({int weekSeconds, List<int> spark14Days})? stat,
  }) {
    final eq = context.eq;
    final coeffFormatted = ScoreCalculator.formatCoefficient(act.coefficient);
    final catColor = eq.forCategory(act.category);
    final weekSec = stat?.weekSeconds ?? 0;

    final content = Container(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: Material(
        color: eq.surface1,
        borderRadius: BorderRadius.circular(Radii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityDetailPage(activity: act),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                ActivityAvatar(
                  iconCode: act.iconCode,
                  colorHex: act.colorHex,
                  size: 40,
                  iconSize: 20,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        act.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            coeffFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: catColor,
                            ),
                          ),
                          if (weekSec > 0) ...[
                            Text(
                              ' · ${DurationFormatter.formatHumanReadable(weekSec)} this wk',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: eq.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (stat != null && weekSec > 0) ...[
                  SizedBox(
                    width: 38,
                    height: 16,
                    child: CustomPaint(
                      painter: _TinyBarSparkPainter(
                        values: stat.spark14Days,
                        color: Color(act.colorHex),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                if (isDraggable)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: eq.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: eq.textMuted, size: 19),
                  onSelected: (val) async {
                    final repo = ref.read(activityRepositoryProvider);
                    if (val == 'edit') {
                      _showFormSheet(
                        activityToEdit: act,
                        allActivities: allIncludingArchived,
                      );
                    } else if (val == 'archive') {
                      await repo.setArchived(act.id, !act.isArchived);
                    } else if (val == 'delete') {
                      await repo.deleteActivity(act.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(act.isArchived ? 'Unarchive' : 'Archive'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Delete', style: TextStyle(color: eq.danger)),
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
    }
    return KeyedSubtree(key: ValueKey(act.id), child: content);
  }

  Widget _buildFilterChip(String key, String label, Color color) {
    final eq = context.eq;
    final isSelected = _activeTab == key;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? color : eq.textSecondary,
        ),
      ),
      backgroundColor: eq.surface1,
      selectedColor: color.withValues(alpha: 0.14),
      side: BorderSide(
        color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
      ),
      onSelected: (_) => setState(() => _activeTab = key),
    );
  }
}

class _TinyBarSparkPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _TinyBarSparkPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = math.max(1, values.fold(0, math.max));
    final w = size.width / values.length;
    final paint = Paint()..color = color.withValues(alpha: 0.8);
    for (int i = 0; i < values.length; i++) {
      final h = math.max(1.5, (values[i] / maxVal) * size.height);
      canvas.drawRect(
        Rect.fromLTWH(i * w + 0.3, size.height - h, math.max(1.0, w - 0.6), h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TinyBarSparkPainter old) =>
      old.values != values || old.color != color;
}
