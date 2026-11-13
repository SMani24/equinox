import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../core/utils/time_range_resolver.dart';
import '../../../../data/database/app_database.dart';
import 'future_range_warning_banner.dart';

class ManualEntrySheet extends StatefulWidget {
  final List<Activity> activities;
  final void Function({
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) onSave;

  const ManualEntrySheet({
    super.key,
    required this.activities,
    required this.onSave,
  });

  /// Resolves the start date and overnight flag when start/end times change.
  /// When [userManuallyPickedDate] is false and an overnight span (`end <= start`)
  /// would extend into tomorrow (future) while shifting back 1 day places its
  /// end on or before [now], anchors the session to yesterday -> today instead.
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
    // Default 1 hour prior to now
    final startDt = now.subtract(const Duration(hours: 1));
    _date = DateTime(startDt.year, startDt.month, startDt.day);
    _startTime = TimeOfDay.fromDateTime(startDt);
    _endTime = TimeOfDay.fromDateTime(now);
    _isNextDay = startDt.day != now.day ||
        startDt.month != now.month ||
        startDt.year != now.year;

    if (widget.activities.isNotEmpty) {
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
    if (_selectedActivityId == null) return null;
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

  @override
  Widget build(BuildContext context) {
    final durationSec = _durationSeconds;
    final startDt = _startDateTime;
    final endDt = _endDateTime;
    final act = _selectedActivity;
    final score = act != null
        ? ScoreCalculator.calculateScore(durationSec, act.coefficient)
        : 0.0;
    final scoreColor = act != null
        ? AppColors.forCoefficient(act.coefficient)
        : AppColors.neutral;
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manual Time Entry',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Start Date Selector
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: AppColors.surfaceElevated,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: const Text('Start Date'),
              trailing: Text(
                DurationFormatter.formatDateLabel(_date),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),

            // Time range selector
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    tileColor: AppColors.surfaceElevated,
                    leading: const Icon(Icons.schedule, size: 20),
                    title: const Text('Start', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      '${_startTime.format(context)}\n${DurationFormatter.formatDateLabel(startDt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    isThreeLine: true,
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _isNextDay ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    tileColor: AppColors.surfaceElevated,
                    leading: const Icon(Icons.schedule, size: 20),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('End', style: TextStyle(fontSize: 12)),
                        if (_isNextDay)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '+1 Day',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${_endTime.format(context)}\n${DurationFormatter.formatDateLabel(endDt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    isThreeLine: true,
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Overnight toggle switch
            InkWell(
              borderRadius: BorderRadius.circular(8),
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
                      color: _isNextDay ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Spans into next day (+1 Day overnight)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isNextDay ? FontWeight.w700 : FontWeight.w500,
                        color: _isNextDay ? AppColors.primary : AppColors.textMuted,
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
            const SizedBox(height: 12),

            // Duration & Score preview banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.timelapse,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Duration: ${DurationFormatter.formatHumanReadable(durationSec)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ScoreCalculator.formatScore(score),
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Activity Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedActivityId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Activity',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: widget.activities.map((act) {
                return DropdownMenuItem<String>(
                  value: act.id,
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.getIconData(act.iconCode),
                        color: Color(act.colorHex),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(act.name)),
                      Text(
                        ScoreCalculator.formatCoefficient(act.coefficient),
                        style: TextStyle(
                          color: AppColors.forCoefficient(act.coefficient),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedActivityId = val;
                });
              },
            ),
            const SizedBox(height: 12),

            // Note Field
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Session note (optional)',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
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
