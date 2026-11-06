import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../data/database/app_database.dart';
import 'split_session_dialog.dart';

class ClassifySessionSheet extends StatefulWidget {
  final DateTime initialStartTime;
  final DateTime initialEndTime;
  final List<Activity> activities;
  final String? initialActivityId;
  final String? initialNote;
  final void Function({
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) onSave;
  final void Function(SplitSessionResult result) onSplitSave;
  final VoidCallback onDiscard;

  const ClassifySessionSheet({
    super.key,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.activities,
    this.initialActivityId,
    this.initialNote,
    required this.onSave,
    required this.onSplitSave,
    required this.onDiscard,
  });

  @override
  State<ClassifySessionSheet> createState() => _ClassifySessionSheetState();
}

class _ClassifySessionSheetState extends State<ClassifySessionSheet> {
  late DateTime _startTime;
  late DateTime _endTime;
  late TextEditingController _noteController;
  String _selectedCategoryFilter = 'all'; // 'all', 'productive', 'rest', 'neutral'
  String? _selectedActivityId;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _selectedActivityId = widget.initialActivityId;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _durationSeconds {
    final diff = _endTime.difference(_startTime).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null) return;

    setState(() {
      final newDt = DateTime(
        initial.year,
        initial.month,
        initial.day,
        pickedTime.hour,
        pickedTime.minute,
        initial.second,
      );

      if (isStart) {
        if (newDt.isBefore(_endTime)) {
          _startTime = newDt;
        }
      } else {
        if (newDt.isAfter(_startTime)) {
          _endTime = newDt;
        }
      }
    });
  }

  Future<void> _handleSplit() async {
    if (_durationSeconds < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session is too short to split (minimum 2 seconds required).'),
        ),
      );
      return;
    }

    final result = await showDialog<SplitSessionResult>(
      context: context,
      builder: (ctx) => SplitSessionDialog(
        startTime: _startTime,
        endTime: _endTime,
        activities: widget.activities,
        initialActivityId: _selectedActivityId,
      ),
    );

    if (result != null) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSplitSave(result);
      }
    }
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Session?'),
        content: const Text(
          'This tracked timer session will be completely erased and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rest),
            onPressed: () {
              Navigator.of(ctx).pop(); // dismiss dialog
              Navigator.of(context).pop(); // dismiss sheet
              widget.onDiscard();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationSec = _durationSeconds;
    final timeStr = DurationFormatter.formatHms(durationSec);

    final filteredActivities = widget.activities.where((a) {
      if (_selectedCategoryFilter == 'all') return true;
      return a.category == _selectedCategoryFilter;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What did you just do?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Select an activity to log this session',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _confirmDiscard,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rest),
                  label: const Text(
                    'Discard',
                    style: TextStyle(color: AppColors.rest, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Duration & Start/End Time Adjusters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DURATION',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _pickTime(isStart: true),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    DurationFormatter.formatTimeRange(_startTime, _endTime),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _handleSplit,
                        icon: const Icon(Icons.call_split, size: 16),
                        label: const Text('Split Session', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Note Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Session note or memo (optional)',
                prefixIcon: Icon(Icons.edit_note, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('all', 'All Activities'),
                const SizedBox(width: 8),
                _buildFilterChip('productive', 'Productive (+)', AppColors.productive),
                const SizedBox(width: 8),
                _buildFilterChip('rest', 'Rest & Leisure (-)', AppColors.rest),
                const SizedBox(width: 8),
                _buildFilterChip('neutral', 'Neutral (0.0)', AppColors.neutral),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Activities Grid with Live Score Previews
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: filteredActivities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final activity = filteredActivities[index];
                final score = ScoreCalculator.calculateScore(
                  durationSec,
                  activity.coefficient,
                );
                final scoreFormatted = ScoreCalculator.formatScore(score);
                final isSelected = _selectedActivityId == activity.id;

                final scoreColor = AppColors.forCoefficient(activity.coefficient);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _selectedActivityId = activity.id;
                      });
                      // Auto-save on tap
                      Navigator.of(context).pop();
                      widget.onSave(
                        activityId: activity.id,
                        startTime: _startTime,
                        endTime: _endTime,
                        note: _noteController.text,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Color(activity.colorHex).withValues(alpha: 0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Color(activity.colorHex)
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(activity.colorHex).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              AppIcons.getIconData(activity.iconCode),
                              color: Color(activity.colorHex),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Weight: ${ScoreCalculator.formatCoefficient(activity.coefficient)} • ${activity.category.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Live Score Preview Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scoreColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              scoreFormatted,
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
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

  Widget _buildFilterChip(String key, String label, [Color? activeColor]) {
    final isSelected = _selectedCategoryFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? (activeColor ?? AppColors.primaryLight)
              : AppColors.textSecondary,
        ),
      ),
      backgroundColor: AppColors.surface,
      selectedColor: (activeColor ?? AppColors.primaryLight).withValues(alpha: 0.15),
      side: BorderSide(
        color: isSelected
            ? (activeColor ?? AppColors.primaryLight)
            : AppColors.border,
      ),
      onSelected: (_) {
        setState(() {
          _selectedCategoryFilter = key;
        });
      },
    );
  }
}
