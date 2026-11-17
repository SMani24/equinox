import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/activity_avatar.dart';
import '../../../../core/ui/activity_chip.dart';
import '../../../../core/ui/activity_picker_sheet.dart';
import '../../../../core/ui/score_pill.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../core/utils/time_range_resolver.dart';
import '../../../../data/database/app_database.dart';
import '../../../smart/suggestion_engine.dart';
import 'future_range_warning_banner.dart';

class ManualEntrySheet extends StatefulWidget {
  final List<Activity> activities;
  final List<ActivitySuggestion> suggestions;
  final Map<String, List<String>> recentNotesByActivity;
  final DateTime? initialStartTime;
  final DateTime? initialEndTime;
  final String? initialActivityId;
  final void Function({
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) onSave;

  const ManualEntrySheet({
    super.key,
    required this.activities,
    this.suggestions = const [],
    this.recentNotesByActivity = const {},
    this.initialStartTime,
    this.initialEndTime,
    this.initialActivityId,
    required this.onSave,
  });

  static ({DateTime startDate, bool isNextDay}) resolveDateAndOvernight({
    required DateTime currentDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required bool currentIsNextDay,
    required bool userManuallyPickedDate,
    required bool userManuallyToggledNextDay,
    required DateTime now,
  }) =>
      TimeRangeResolver.resolveManualRange(
        currentDate: currentDate,
        startTime: startTime,
        endTime: endTime,
        currentIsNextDay: currentIsNextDay,
        userManuallyPickedDate: userManuallyPickedDate,
        userManuallyToggledNextDay: userManuallyToggledNextDay,
        now: now,
      );

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isNextDay = false;
  bool _userManuallyPickedDate = false;
  bool _userManuallyToggledNextDay = false;
  String? _selectedActivityId;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final endDt = widget.initialEndTime ?? now;
    final startDt =
        widget.initialStartTime ?? endDt.subtract(const Duration(hours: 1));
    _date = DateTime(startDt.year, startDt.month, startDt.day);
    _startTime = TimeOfDay.fromDateTime(startDt);
    _endTime = TimeOfDay.fromDateTime(endDt);
    _isNextDay = startDt.day != endDt.day ||
        startDt.month != endDt.month ||
        startDt.year != endDt.year;

    // If explicitly prefilled on a past range (e.g. from Day Ribbon or Detail), preserve date
    if (widget.initialStartTime != null) {
      _userManuallyPickedDate = true;
    }

    if (widget.initialActivityId != null) {
      _selectedActivityId = widget.initialActivityId;
    } else if (widget.suggestions.isNotEmpty) {
      _selectedActivityId = widget.suggestions.first.activity.id;
    } else if (widget.activities.isNotEmpty) {
      _selectedActivityId = widget.activities.first.id;
    }
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

  Activity? get _selectedActivity {
    if (_selectedActivityId == null || widget.activities.isEmpty) return null;
    return widget.activities.firstWhere(
      (a) => a.id == _selectedActivityId,
      orElse: () => widget.activities.first,
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
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        final resolved = ManualEntrySheet.resolveDateAndOvernight(
          currentDate: _date,
          startTime: _startTime,
          endTime: _endTime,
          currentIsNextDay: _isNextDay,
          userManuallyPickedDate: _userManuallyPickedDate,
          userManuallyToggledNextDay: _userManuallyToggledNextDay,
          now: DateTime.now(),
        );
        _date = resolved.startDate;
        _isNextDay = resolved.isNextDay;
      });
    }
  }

  void _openActivityPicker() {
    ActivityPickerSheet.show(
      context: context,
      title: 'Select Activity',
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

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final durationSec = _durationSeconds;
    final startDt = _startDateTime;
    final endDt = _endDateTime;
    final act = _selectedActivity;
    final score = act != null
        ? ScoreCalculator.calculateScore(durationSec, act.coefficient)
        : 0.0;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height || size.height < 520;
    final quickChips = (widget.suggestions.isNotEmpty
            ? widget.suggestions.map((s) => s.activity)
            : widget.activities)
        .take(4)
        .toList();
    final recentNotes = _selectedActivityId != null
        ? (widget.recentNotesByActivity[_selectedActivityId] ?? const <String>[])
        : const <String>[];

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manual Time Entry',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: Space.md),

            // Start Date Selector
            Material(
              color: eq.surface2,
              borderRadius: BorderRadius.circular(Radii.md),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.calendar_today_rounded, size: 18),
                title: const Text('Start Date'),
                trailing: Text(
                  DurationFormatter.formatDateLabel(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: Space.md),

            // Time range selector
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
                            Text(
                              'Start',
                              style: TextStyle(fontSize: 12, color: eq.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startTime.format(context),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
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
                                Text(
                                  'End',
                                  style: TextStyle(fontSize: 12, color: eq.textMuted),
                                ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
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

            // Overnight toggle
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

            // Duration & Score preview banner
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
                      Icon(Icons.timelapse_rounded, size: 18, color: eq.textMuted),
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

            // Selected Activity card (opens unified picker)
            if (act != null)
              Material(
                color: Color(act.colorHex).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _openActivityPicker,
                  child: Container(
                    padding: const EdgeInsets.all(Space.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        color: Color(act.colorHex).withValues(alpha: 0.45),
                      ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                ScoreCalculator.formatCoefficient(act.coefficient),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: eq.forCategory(act.category),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Change',
                          style: TextStyle(
                            color: eq.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: eq.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            if (quickChips.length > 1) ...[
              const SizedBox(height: Space.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickChips.map((q) {
                    return Padding(
                      padding: const EdgeInsets.only(right: Space.sm),
                      child: ActivityChip(
                        activity: q,
                        selected: q.id == _selectedActivityId,
                        onTap: () => setState(() => _selectedActivityId = q.id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: Space.md),

            // Note Field + Recent Note Suggestions
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

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: durationSec <= 0 || _selectedActivityId == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onSave(
                          activityId: _selectedActivityId!,
                          startTime: _startDateTime,
                          endTime: _endDateTime,
                          note: _noteController.text,
                        );
                      },
                child: const Text(
                  'Save Manual Entry',
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
