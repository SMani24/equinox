import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/time_entry_repository.dart';
import 'future_range_warning_banner.dart';

class EditEntrySheet extends StatefulWidget {
  final TimeEntryWithActivity item;
  final List<Activity> activities;
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
        final startMins = _startTime.hour * 60 + _startTime.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        _isNextDay = endMins <= startMins;
      });
    }
  }

  void _showActivityPickerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) {
        String filter = 'all';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final filtered = widget.activities.where((a) {
              if (filter == 'all') return true;
              return a.category == filter;
            }).toList();

            final pickerSize = MediaQuery.of(ctx).size;
            final isPickerLandscape = pickerSize.width > pickerSize.height || pickerSize.height < 520;

            return Container(
              constraints: BoxConstraints(
                maxHeight: isPickerLandscape ? pickerSize.height * 0.95 : pickerSize.height * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  const Text(
                    'Select Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the new activity to re-classify this session',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          selected: filter == 'all',
                          label: const Text('All Activities'),
                          onSelected: (_) => setDialogState(() => filter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: filter == 'productive',
                          label: const Text('Productive (+)'),
                          onSelected: (_) => setDialogState(() => filter = 'productive'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: filter == 'rest',
                          label: const Text('Rest & Leisure (-)'),
                          onSelected: (_) => setDialogState(() => filter = 'rest'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: filter == 'neutral',
                          label: const Text('Neutral (0)'),
                          onSelected: (_) => setDialogState(() => filter = 'neutral'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final act = filtered[idx];
                        final isSelected = act.id == _selectedActivityId;
                        final scorePreview = ScoreCalculator.calculateScore(
                          _durationSeconds,
                          act.coefficient,
                        );

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _selectedActivityId = act.id;
                              });
                              Navigator.of(dialogContext).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(act.colorHex).withValues(alpha: 0.15)
                                    : AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Color(act.colorHex)
                                      : AppColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(act.colorHex).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      AppIcons.getIconData(act.iconCode),
                                      color: Color(act.colorHex),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          act.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${ScoreCalculator.formatCoefficient(act.coefficient)} • ${act.category.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.forCoefficient(act.coefficient),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.forCoefficient(act.coefficient)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      ScoreCalculator.formatScore(scorePreview),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.forCoefficient(act.coefficient),
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
          },
        );
      },
    );
  }

  void _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
          'Remove this ${widget.item.activity.name} entry permanently?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rest),
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
    final durationSec = _durationSeconds;
    final startDt = _startDateTime;
    final endDt = _endDateTime;
    final act = _selectedActivity;
    final score = ScoreCalculator.calculateScore(durationSec, act.coefficient);
    final scoreColor = AppColors.forCoefficient(act.coefficient);

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

            // Sheet Title & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Time Entry',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.rest),
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
            const SizedBox(height: 16),

            // Highlighted Active Activity Card (Tap to change)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showActivityPickerDialog,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(act.colorHex).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(act.colorHex).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(act.colorHex).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          AppIcons.getIconData(act.iconCode),
                          color: Color(act.colorHex),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACTIVITY',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              act.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Weight: ${ScoreCalculator.formatCoefficient(act.coefficient)} • ${act.category.toUpperCase()}',
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
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.sync_alt_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

            // Time Range Selectors (Start & End)
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
                  _date = _date.subtract(const Duration(days: 1));
                });
              },
            ),
            const SizedBox(height: 12),

            // Live Duration & Recalculated Score preview banner
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
            const SizedBox(height: 16),

            // Session Note Field
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

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
