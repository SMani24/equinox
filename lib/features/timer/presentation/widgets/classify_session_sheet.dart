import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/activity_avatar.dart';
import '../../../../core/ui/score_pill.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../core/utils/time_range_resolver.dart';
import '../../../../data/database/app_database.dart';
import '../../../smart/suggestion_engine.dart';
import 'future_range_warning_banner.dart';
import 'split_session_dialog.dart';

class ClassifySessionSheet extends StatefulWidget {
  final DateTime initialStartTime;
  final DateTime initialEndTime;
  final List<Activity> activities;
  final List<ActivitySuggestion> suggestions;
  final Map<String, List<String>> recentNotesByActivity;
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
    this.suggestions = const [],
    this.recentNotesByActivity = const {},
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
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategoryFilter = 'all';
  String _searchQuery = '';
  String? _selectedActivityId;
  bool _showNoteInput = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _selectedActivityId = widget.initialActivityId;
    _showNoteInput = (widget.initialNote?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
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
    final eq = context.eq;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: eq.surface1,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_rounded, size: compact ? 11 : 12, color: eq.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$label: $value',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: eq.textSecondary,
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
          content:
              Text('Session is too short to split (minimum 2 seconds required).'),
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

    if (result != null && mounted) {
      Navigator.of(context).pop();
      widget.onSplitSave(result);
    }
  }

  void _confirmDiscard() {
    final eq = context.eq;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard session?'),
        content: const Text(
          'This tracked timer session will be erased and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: eq.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              widget.onDiscard();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _commitActivity(Activity activity) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedActivityId = activity.id);
    Navigator.of(context).pop();
    widget.onSave(
      activityId: activity.id,
      startTime: _startTime,
      endTime: _endTime,
      note: _noteController.text,
    );
  }

  List<Activity> _filteredActivities() {
    final q = _searchQuery.trim().toLowerCase();
    return widget.activities.where((a) {
      if (_selectedCategoryFilter != 'all' &&
          a.category != _selectedCategoryFilter) {
        return false;
      }
      if (q.isNotEmpty && !a.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  List<ActivitySuggestion> _topSuggestions() {
    if (widget.suggestions.isNotEmpty) {
      return widget.suggestions.take(4).toList();
    }
    return widget.activities
        .take(4)
        .map((a) => ActivitySuggestion(activity: a, score: 1.0))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final durationSec = _durationSeconds;
    final timeStr = DurationFormatter.formatHms(durationSec);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height || size.height < 520;
    final filtered = _filteredActivities();
    final suggestions = _topSuggestions();

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? size.height * 0.96 : size.height * 0.92,
      ),
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.of(context).viewInsets.bottom + (isLandscape ? 8 : 16),
      ),
      child: isLandscape
          ? _buildLandscapeLayout(context, durationSec, timeStr, filtered, suggestions)
          : _buildPortraitLayout(context, durationSec, timeStr, filtered, suggestions),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    int durationSec,
    String timeStr,
    List<Activity> filteredActivities,
    List<ActivitySuggestion> suggestions,
  ) {
    final eq = context.eq;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'What did you just do?',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _confirmDiscard,
                icon: Icon(Icons.delete_outline, size: 16, color: eq.danger),
                label: Text(
                  'Discard',
                  style: TextStyle(
                    color: eq.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.md, Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Space.md),
                        decoration: BoxDecoration(
                          color: eq.surface2,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeStr,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: Space.sm),
                            _buildTimeBoundariesSection(context, compact: true),
                            const SizedBox(height: Space.sm),
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
                      const SizedBox(height: Space.sm),
                      _buildNoteComposer(context, compact: true),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'All'),
                            const SizedBox(width: Space.sm),
                            _buildFilterChip('productive', 'Productive (+)', eq.gain),
                            const SizedBox(width: Space.sm),
                            _buildFilterChip('rest', 'Rest (-)', eq.spend),
                            const SizedBox(width: Space.sm),
                            _buildFilterChip('neutral', 'Neutral', eq.neutral),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
                          vertical: Space.sm,
                        ),
                        itemCount: filteredActivities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                        itemBuilder: (context, index) => _buildActivityTile(
                          filteredActivities[index],
                          durationSec,
                        ),
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
    List<ActivitySuggestion> suggestions,
  ) {
    final eq = context.eq;
    Activity? preselected;
    if (_selectedActivityId != null) {
      for (final a in widget.activities) {
        if (a.id == _selectedActivityId) {
          preselected = a;
          break;
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(top: Space.md, bottom: Space.xs),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: eq.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What did you just do?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Tap an activity to log this session',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _confirmDiscard,
                icon: Icon(Icons.delete_outline, size: 18, color: eq.danger),
                label: Text(
                  'Discard',
                  style: TextStyle(color: eq.danger, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
            children: [
              // Duration & adjusted start/end card
              Container(
                padding: const EdgeInsets.all(Space.lg),
                decoration: BoxDecoration(
                  color: eq.surface2,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              timeStr,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _handleSplit,
                          icon: const Icon(Icons.call_split, size: 16),
                          label: const Text('Split Session'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    _buildTimeBoundariesSection(context),
                  ],
                ),
              ),

              if (preselected != null) ...[
                const SizedBox(height: Space.md),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(preselected.colorHex),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    onPressed: () => _commitActivity(preselected!),
                    icon: Icon(AppIcons.getIconData(preselected.iconCode), size: 18),
                    label: Text(
                      'Log as ${preselected.name} (${ScoreCalculator.formatScore(ScoreCalculator.calculateScore(durationSec, preselected.coefficient), showUnit: false)})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: Space.sm),
              _buildNoteComposer(context),

              if (suggestions.isNotEmpty && _searchQuery.isEmpty && _selectedCategoryFilter == 'all') ...[
                const SizedBox(height: Space.md),
                Text(
                  'Suggested',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: eq.textMuted,
                      ),
                ),
                const SizedBox(height: Space.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: Space.sm,
                    mainAxisSpacing: Space.sm,
                    childAspectRatio: 2.3,
                  ),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) =>
                      _buildSuggestedGridTile(suggestions[index], durationSec),
                ),
              ],

              const SizedBox(height: Space.md),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Search all activities…',
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                ),
              ),
              const SizedBox(height: Space.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Activities'),
                    const SizedBox(width: Space.sm),
                    _buildFilterChip('productive', 'Productive (+)', eq.gain),
                    const SizedBox(width: Space.sm),
                    _buildFilterChip('rest', 'Rest & Leisure (-)', eq.spend),
                    const SizedBox(width: Space.sm),
                    _buildFilterChip('neutral', 'Neutral (0.0)', eq.neutral),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              ...filteredActivities.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: _buildActivityTile(a, durationSec),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteComposer(BuildContext context, {bool compact = false}) {
    final eq = context.eq;
    final notes = _selectedActivityId != null
        ? (widget.recentNotesByActivity[_selectedActivityId] ?? const [])
        : const <String>[];

    if (!_showNoteInput && !compact) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => setState(() => _showNoteInput = true),
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('Add session note'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _noteController,
          maxLines: compact ? 2 : 1,
          decoration: const InputDecoration(
            hintText: 'Session note or memo (optional)',
            isDense: true,
            prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
          ),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: notes.take(4).map((n) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      n,
                      style: TextStyle(fontSize: 11, color: eq.textSecondary),
                    ),
                    onPressed: () => setState(() => _noteController.text = n),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestedGridTile(ActivitySuggestion sug, int durationSec) {
    final eq = context.eq;
    final act = sug.activity;
    final score = ScoreCalculator.calculateScore(durationSec, act.coefficient);
    final isSelected = _selectedActivityId == act.id;
    final color = Color(act.colorHex);

    return Material(
      color: isSelected ? color.withValues(alpha: 0.16) : eq.surface2,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _commitActivity(act),
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            children: [
              ActivityAvatar(
                iconCode: act.iconCode,
                colorHex: act.colorHex,
                size: 32,
                iconSize: 16,
                radius: 9,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      act.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      sug.reason ??
                          ScoreCalculator.formatScore(score),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: eq.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTile(Activity activity, int durationSec) {
    final eq = context.eq;
    final score =
        ScoreCalculator.calculateScore(durationSec, activity.coefficient);
    final isSelected = _selectedActivityId == activity.id;
    final color = Color(activity.colorHex);

    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : eq.surface2,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _commitActivity(activity),
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            children: [
              ActivityAvatar(
                iconCode: activity.iconCode,
                colorHex: activity.colorHex,
                size: 38,
                iconSize: 18,
                radius: 10,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${ScoreCalculator.formatCoefficient(activity.coefficient)} • ${activity.category[0].toUpperCase()}${activity.category.substring(1)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: eq.forCategory(activity.category),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ScorePill(score: score, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, [Color? activeColor]) {
    final eq = context.eq;
    final isSelected = _selectedCategoryFilter == key;
    final chipColor = activeColor ?? eq.accent;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? chipColor : eq.textSecondary,
        ),
      ),
      backgroundColor: eq.surface2,
      selectedColor: chipColor.withValues(alpha: 0.14),
      side: BorderSide(
        color: isSelected ? chipColor.withValues(alpha: 0.5) : Colors.transparent,
      ),
      onSelected: (_) {
        setState(() {
          _selectedCategoryFilter = key;
        });
      },
    );
  }
}
