import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../data/database/app_database.dart';

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

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isNextDay = false;
  String? _selectedActivityId;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    // Default 1 hour prior to now
    final startDt = now.subtract(const Duration(hours: 1));
    _startTime = TimeOfDay.fromDateTime(startDt);
    _endTime = TimeOfDay.fromDateTime(now);

    if (widget.activities.isNotEmpty) {
      _selectedActivityId = widget.activities.first.id;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(
        _date.year,
        _date.month,
        _date.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime {
    final baseDate = _isNextDay ? _date.add(const Duration(days: 1)) : _date;
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      _endTime.hour,
      _endTime.minute,
    );
  }

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
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
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
        // Auto-detect overnight crossing when end is before or equal to start
        final startMins = _startTime.hour * 60 + _startTime.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          _isNextDay = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationSec = _durationSeconds;
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

            // Date Selector
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              tileColor: AppColors.surfaceElevated,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: const Text('Date'),
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
                      _startTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                      _endTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
