import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../core/utils/time_range_resolver.dart';
import '../../../../data/database/app_database.dart';
import 'future_range_warning_banner.dart';
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

    if (pickedTime == null || !mounted) return;
    if (pickedTime == TimeOfDay.fromDateTime(initial)) return;

    final now = DateTime.now();
    if (isStart) {
      final resolvedStart = TimeRangeResolver.resolveClassifiedStartTime(
        currentEnd: _endTime,
        pickedStart: pickedTime,
      );
      setState(() {
        _startTime = resolvedStart;
      });
    } else {
      final resolvedEnd = TimeRangeResolver.resolveClassifiedEndTime(
        currentStart: _startTime,
        pickedEnd: pickedTime,
        now: now,
      );
      if (resolvedEnd == null) {
        final candidateOnStartDay =
            TimeRangeResolver.combineDateAndTime(_startTime, pickedTime);
        final candidateDayAfterStart = TimeRangeResolver.combineDateAndTime(
          _startTime,
          pickedTime,
          dayOffset: 1,
        );
        final isFutureRejection = candidateOnStartDay.isAfter(_startTime) ||
            (candidateDayAfterStart.isAfter(_startTime) &&
                TimeRangeResolver.dateOnly(candidateDayAfterStart) ==
                    TimeRangeResolver.dateOnly(now));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFutureRejection
                  ? 'End time cannot be in the future'
                  : 'End time must be after start time',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _endTime = resolvedEnd;
      });
    }
  }

  String _formatBoundaryTime(BuildContext context, DateTime dt, DateTime now) {
    final timeText = TimeOfDay.fromDateTime(dt).format(context);
    final diff = TimeRangeResolver.calendarDaysBetween(dt, now);
    if (diff == 0) return timeText;
    if (diff == 1) return 'Yesterday $timeText';
    if (diff == -1) return 'Tomorrow $timeText';
    final dateText = dt.year == now.year
        ? DateFormat('MMM d').format(dt)
        : DateFormat('MMM d, yyyy').format(dt);
    return '$dateText $timeText';
  }

  Widget _buildTimeChip({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: compact ? 10 : 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$label: $value',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBoundariesSection(BuildContext context, {bool compact = false}) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: compact ? 6 : 8,
          runSpacing: 6,
          children: [
            _buildTimeChip(
              label: 'Start',
              value: _formatBoundaryTime(context, _startTime, now),
              onTap: () => _pickTime(isStart: true),
              compact: compact,
            ),
            _buildTimeChip(
              label: 'End',
              value: _formatBoundaryTime(context, _endTime, now),
              onTap: () => _pickTime(isStart: false),
              compact: compact,
            ),
          ],
        ),
        FutureRangeWarningBanner(
          endDateTime: _endTime,
          endTime: TimeOfDay.fromDateTime(_endTime),
          onShiftBackOneDay: () {
            setState(() {
              _startTime = DateTime(
                _startTime.year,
                _startTime.month,
                _startTime.day - 1,
                _startTime.hour,
                _startTime.minute,
                _startTime.second,
              );
              _endTime = DateTime(
                _endTime.year,
                _endTime.month,
                _endTime.day - 1,
                _endTime.hour,
                _endTime.minute,
                _endTime.second,
              );
            });
          },
        ),
      ],
    );
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
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height || size.height < 520;

    final filteredActivities = widget.activities.where((a) {
      if (_selectedCategoryFilter == 'all') return true;
      return a.category == _selectedCategoryFilter;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? size.height * 0.96 : size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + (isLandscape ? 8 : 16),
      ),
      child: isLandscape
          ? _buildLandscapeLayout(context, durationSec, timeStr, filteredActivities)
          : _buildPortraitLayout(context, durationSec, timeStr, filteredActivities),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    int durationSec,
    String timeStr,
    List<Activity> filteredActivities,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'What did you just do?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _confirmDiscard,
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.rest),
                label: const Text(
                  'Discard',
                  style: TextStyle(color: AppColors.rest, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Side-by-side body
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Duration & Note
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Duration card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
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
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _buildTimeBoundariesSection(context, compact: true),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _handleSplit,
                                icon: const Icon(Icons.call_split, size: 14),
                                label: const Text('Split Session', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Note field
                      TextField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Session note or memo (optional)',
                          prefixIcon: Icon(Icons.edit_note, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const VerticalDivider(width: 1),

              // Right Pane: Filter chips & Activities list
              Expanded(
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredActivities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _buildActivityTile(filteredActivities[index], durationSec);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    int durationSec,
    String timeStr,
    List<Activity> filteredActivities,
  ) {
    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DURATION',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _handleSplit,
                      icon: const Icon(Icons.call_split, size: 16),
                      label: const Text('Split Session', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTimeBoundariesSection(context),
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
              return _buildActivityTile(filteredActivities[index], durationSec);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTile(Activity activity, int durationSec) {
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
              color: isSelected ? Color(activity.colorHex) : AppColors.border,
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
                      style: const TextStyle(
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
