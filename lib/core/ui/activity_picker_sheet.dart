import 'package:flutter/material.dart';
import '../../data/database/app_database.dart';
import '../../features/smart/suggestion_engine.dart';
import '../theme/eq_colors.dart';
import '../theme/tokens.dart';
import '../utils/score_calculator.dart';
import 'activity_avatar.dart';
import 'activity_chip.dart';
import 'score_pill.dart';

/// Unified searchable, category-filtered, suggestion-aware activity picker sheet.
class ActivityPickerSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Activity> activities;
  final List<ActivitySuggestion> suggestions;
  final String? selectedActivityId;
  final int? previewDurationSeconds;
  final bool allowClear;
  final ValueChanged<Activity?> onSelected;

  const ActivityPickerSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.activities,
    this.suggestions = const [],
    this.selectedActivityId,
    this.previewDurationSeconds,
    this.allowClear = false,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<Activity> activities,
    List<ActivitySuggestion> suggestions = const [],
    String? selectedActivityId,
    int? previewDurationSeconds,
    bool allowClear = false,
    required ValueChanged<Activity?> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ActivityPickerSheet(
        title: title,
        subtitle: subtitle,
        activities: activities,
        suggestions: suggestions,
        selectedActivityId: selectedActivityId,
        previewDurationSeconds: previewDurationSeconds,
        allowClear: allowClear,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<ActivityPickerSheet> createState() => _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends State<ActivityPickerSheet> {
  String _categoryFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height || size.height < 520;

    final query = _searchQuery.trim().toLowerCase();
    final filtered = widget.activities.where((a) {
      if (_categoryFilter != 'all' && a.category != _categoryFilter) return false;
      if (query.isNotEmpty && !a.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    final topSuggestions = widget.suggestions.take(4).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? size.height * 0.94 : size.height * 0.80,
      ),
      padding: EdgeInsets.only(
        left: Space.lg,
        right: Space.lg,
        top: Space.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: eq.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (widget.allowClear && widget.selectedActivityId != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSelected(null);
                  },
                  child: const Text('Clear'),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),

          // Search box
          TextField(
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: Space.md),

          // Suggested pills when no query filter is active
          if (topSuggestions.isNotEmpty && _searchQuery.isEmpty && _categoryFilter == 'all') ...[
            Text(
              'Suggested now',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: eq.textMuted,
                  ),
            ),
            const SizedBox(height: Space.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: topSuggestions.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: ActivityChip(
                      activity: s.activity,
                      selected: s.activity.id == widget.selectedActivityId,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelected(s.activity);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: Space.md),
          ],

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilter('all', 'All', eq.accent),
                const SizedBox(width: Space.sm),
                _buildFilter('productive', 'Productive', eq.gain),
                const SizedBox(width: Space.sm),
                _buildFilter('rest', 'Rest', eq.spend),
                const SizedBox(width: Space.sm),
                _buildFilter('neutral', 'Neutral', eq.neutral),
              ],
            ),
          ),
          const SizedBox(height: Space.md),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching activities',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (context, idx) {
                      final act = filtered[idx];
                      final isSelected = act.id == widget.selectedActivityId;
                      final catColor = eq.forCategory(act.category);

                      return Material(
                        color: isSelected
                            ? Color(act.colorHex).withValues(alpha: 0.14)
                            : eq.surface2,
                        borderRadius: BorderRadius.circular(Radii.md),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelected(act);
                          },
                          borderRadius: BorderRadius.circular(Radii.md),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.md,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: isSelected
                                  ? Border.all(
                                      color: Color(act.colorHex),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                ActivityAvatar(
                                  iconCode: act.iconCode,
                                  colorHex: act.colorHex,
                                  size: 38,
                                  iconSize: 18,
                                ),
                                const SizedBox(width: Space.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        act.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${ScoreCalculator.formatCoefficient(act.coefficient)} • ${act.category[0].toUpperCase()}${act.category.substring(1)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: catColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.previewDurationSeconds != null)
                                  ScorePill(
                                    score: ScoreCalculator.calculateScore(
                                      widget.previewDurationSeconds!,
                                      act.coefficient,
                                    ),
                                    compact: true,
                                  )
                                else if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(act.colorHex),
                                    size: 20,
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

  Widget _buildFilter(String key, String label, Color accent) {
    final eq = context.eq;
    final selected = _categoryFilter == key;
    return FilterChip(
      selected: selected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? accent : eq.textSecondary,
        ),
      ),
      backgroundColor: eq.surface2,
      selectedColor: accent.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? accent.withValues(alpha: 0.6) : Colors.transparent,
      ),
      onSelected: (_) => setState(() => _categoryFilter = key),
    );
  }
}
