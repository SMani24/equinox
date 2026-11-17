import 'package:flutter/material.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/activity_picker_sheet.dart';
import '../../../../core/ui/score_pill.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../core/utils/time_range_resolver.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/time_entry_repository.dart';
import '../../../smart/suggestion_engine.dart';
import 'future_range_warning_banner.dart';

class EditEntrySheet extends StatefulWidget {
  final TimeEntryWithActivity item;
  final List<Activity> activities;
  final List<ActivitySuggestion> suggestions;
  final Map<String, List<String>> recentNotesByActivity;
  final void Function({
    required String entryId,
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) onSave;
  final VoidCallback onDelete;

  const EditEntrySheet({
    super.key,
    required this.item,
    required this.activities,
    this.suggestions = const [],
    this.recentNotesByActivity = const {},
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isNextDay;
  bool _userManuallyPickedDate = false;
  bool _userManuallyToggledNextDay = false;
  late String _selectedActivityId;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final startDt = DateTime.fromMillisecondsSinceEpoch(widget.item.entry.startTime);
    final endDt = DateTime.fromMillisecondsSinceEpoch(widget.item.entry.endTime);

    _date = DateTime(startDt.year, startDt.month, startDt.day);
    _startTime = TimeOfDay.fromDateTime(startDt);
    _endTime = TimeOfDay.fromDateTime(endDt);
    _isNextDay = endDt.day != startDt.day ||
        endDt.month != startDt.month ||
        endDt.year != startDt.year;
    _selectedActivityId = widget.item.activity.id;
    _noteController = TextEditingController(text: widget.item.entry.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => TimeRangeResolver.combineDateAndTime(
        _date,
        _startTime,
      );

  DateTime get _endDateTime => TimeRangeResolver.combineDateAndTime(
        _date,
        _endTime,
        dayOffset: _isNextDay ? 1 : 0,
      );

  int get _durationSeconds {
    final diff = _endDateTime.difference(_startDateTime).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Activity get _selectedActivity {
    return widget.activities.firstWhere(
      (a) => a.id == _selectedActivityId,
      orElse: () => widget.item.activity,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _userManuallyPickedDate = true;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        final resolved = TimeRangeResolver.resolveEditedRange(
          currentStartDate: _date,
          currentStartTime: _startTime,
          currentEndTime: _endTime,
          currentIsNextDay: _isNextDay,
          isEditingStart: isStart,
          pickedTime: picked,
          userManuallyPickedDate: _userManuallyPickedDate,
          userManuallyToggledNextDay: _userManuallyToggledNextDay,
          now: DateTime.now(),
        );
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _date = resolved.startDate;
        _isNextDay = resolved.isNextDay;
      });
    }
  }

  void _showActivityPickerDialog() {
    ActivityPickerSheet.show(
      context: context,
      title: 'Select Activity',
      subtitle: 'Choose the activity for this session',
      activities: widget.activities,
      suggestions: widget.suggestions,
      selectedActivityId: _selectedActivityId,
      previewDurationSeconds: _durationSeconds,
      onSelected: (act) {
        if (act != null) {
          setState(() => _selectedActivityId = act.id);
        }
      },
    );
  }

  void _confirmDelete() async {
    final eq = context.eq;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          'Remove this ${widget.item.activity.name} entry permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: eq.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final durationSec = _durationSeconds;
    final startDt = _startDateTime;
    final endDt = _endDateTime;
    final act = _selectedActivity;
    final score = ScoreCalculator.calculateScore(durationSec, act.coefficient);
    final scoreColor = eq.forCoefficient(act.coefficient);
    final recentNotes = widget.recentNotesByActivity[_selectedActivityId] ?? const <String>[];

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height || size.height < 520;

    return Container(
      constraints: BoxConstraints(
        maxHeight: isLandscape ? size.height * 0.96 : size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 24,
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

            // Sheet Title & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Time Entry',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: eq.danger),
                      tooltip: 'Delete session',
                      onPressed: _confirmDelete,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Space.md),

            // Highlighted Active Activity Card (Tap to change)
            Material(
              color: Color(act.colorHex).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.lg),
                onTap: _showActivityPickerDialog,
                child: Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(
                      color: Color(act.colorHex).withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(act.colorHex).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Icon(
                          AppIcons.getIconData(act.iconCode),
                          color: Color(act.colorHex),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ScoreCalculator.formatCoefficient(act.coefficient)} • ${act.category[0].toUpperCase()}${act.category.substring(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scoreColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: eq.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: eq.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.sync_alt_rounded,
                              size: 14,
                              color: eq.accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.md),

            // Start Date Selector
            Material(
              color: eq.surface2,
              borderRadius: BorderRadius.circular(Radii.md),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.calendar_today, size: 18),
                title: const Text('Start Date'),
                trailing: Text(
                  DurationFormatter.formatDateLabel(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: Space.md),

            // Time Range Selectors (Start & End)
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: eq.surface2,
                    borderRadius: BorderRadius.circular(Radii.md),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _pickTime(isStart: true),
                      child: Padding(
                        padding: const EdgeInsets.all(Space.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start', style: TextStyle(fontSize: 12, color: eq.textMuted)),
                            const SizedBox(height: 4),
                            Text(
                              _startTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              DurationFormatter.formatDateLabel(startDt),
                              style: TextStyle(fontSize: 12, color: eq.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Material(
                    color: eq.surface2,
                    borderRadius: BorderRadius.circular(Radii.md),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _pickTime(isStart: false),
                      child: Container(
                        padding: const EdgeInsets.all(Space.md),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: _isNextDay
                              ? Border.all(color: eq.accent.withValues(alpha: 0.6))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('End', style: TextStyle(fontSize: 12, color: eq.textMuted)),
                                if (_isNextDay)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: eq.accentSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+1 Day',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: eq.accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _endTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              DurationFormatter.formatDateLabel(endDt),
                              style: TextStyle(fontSize: 12, color: eq.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),

            // Overnight toggle switch
            InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () {
                setState(() {
                  _userManuallyToggledNextDay = true;
                  _isNextDay = !_isNextDay;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isNextDay
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: _isNextDay ? eq.accent : eq.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Spans into next day (+1 Day overnight)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isNextDay ? FontWeight.w600 : FontWeight.w500,
                        color: _isNextDay ? eq.accent : eq.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            FutureRangeWarningBanner(
              endDateTime: endDt,
              endTime: _endTime,
              onShiftBackOneDay: () {
                setState(() {
                  _date = DateTime(_date.year, _date.month, _date.day - 1);
                  _userManuallyPickedDate = true;
                });
              },
            ),
            const SizedBox(height: Space.md),

            // Live Duration & Recalculated Score preview banner
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.md,
              ),
              decoration: BoxDecoration(
                color: eq.surface2,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timelapse, size: 18, color: eq.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Duration: ${DurationFormatter.formatHumanReadable(durationSec)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  ScorePill(score: score, compact: true),
                ],
              ),
            ),
            const SizedBox(height: Space.md),

            // Session Note Field
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Session note (optional)',
              ),
            ),
            if (recentNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: recentNotes.take(4).map((n) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(n, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _noteController.text = n),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: Space.lg),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                onPressed: durationSec <= 0
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onSave(
                          entryId: widget.item.entry.id,
                          activityId: _selectedActivityId,
                          startTime: _startDateTime,
                          endTime: _endDateTime,
                          note: _noteController.text,
                        );
                      },
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
