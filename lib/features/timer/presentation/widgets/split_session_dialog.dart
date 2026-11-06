import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../data/database/app_database.dart';

class SplitSessionResult {
  final DateTime splitTime;
  final String firstActivityId;
  final String secondActivityId;
  final String? firstNote;
  final String? secondNote;

  const SplitSessionResult({
    required this.splitTime,
    required this.firstActivityId,
    required this.secondActivityId,
    this.firstNote,
    this.secondNote,
  });
}

class SplitSessionDialog extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;
  final List<Activity> activities;
  final String? initialActivityId;

  const SplitSessionDialog({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.activities,
    this.initialActivityId,
  });

  @override
  State<SplitSessionDialog> createState() => _SplitSessionDialogState();
}

class _SplitSessionDialogState extends State<SplitSessionDialog> {
  late int _totalSeconds;
  late double _firstSegmentSeconds;
  late String _firstActivityId;
  late String _secondActivityId;
  final TextEditingController _firstNoteController = TextEditingController();
  final TextEditingController _secondNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.endTime.difference(widget.startTime).inSeconds;
    if (_totalSeconds < 2) _totalSeconds = 2;

    final double minSplit = _totalSeconds <= 10
        ? 1.0
        : (_totalSeconds <= 60 ? 5.0 : 15.0);
    final double maxSplit = (_totalSeconds - minSplit).toDouble();
    final double effectiveMin = minSplit < maxSplit ? minSplit : 1.0;
    final double effectiveMax = maxSplit > effectiveMin
        ? maxSplit
        : math.max(1.0, (_totalSeconds - 1.0).toDouble());

    _firstSegmentSeconds = (_totalSeconds / 2).clamp(effectiveMin, effectiveMax);

    _firstActivityId = widget.initialActivityId ??
        (widget.activities.isNotEmpty ? widget.activities.first.id : '');
    final other = widget.activities.firstWhere(
      (a) => a.id != _firstActivityId,
      orElse: () => widget.activities.first,
    );
    _secondActivityId = other.id;
  }

  @override
  void dispose() {
    _firstNoteController.dispose();
    _secondNoteController.dispose();
    super.dispose();
  }

  Activity? _getActivity(String id) {
    for (final a in widget.activities) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final firstSec = _firstSegmentSeconds.toInt();
    final secondSec = _totalSeconds - firstSec;

    final firstAct = _getActivity(_firstActivityId);
    final secondAct = _getActivity(_secondActivityId);

    final firstScore = ScoreCalculator.calculateScore(
      firstSec,
      firstAct?.coefficient ?? 0.0,
    );
    final secondScore = ScoreCalculator.calculateScore(
      secondSec,
      secondAct?.coefficient ?? 0.0,
    );

    final splitDt = widget.startTime.add(Duration(seconds: firstSec));

    final double minSplit = _totalSeconds <= 10
        ? 1.0
        : (_totalSeconds <= 60 ? 5.0 : 15.0);
    final double maxSplit = (_totalSeconds - minSplit).toDouble();
    final double minBound = minSplit < maxSplit ? minSplit : 1.0;
    final double maxBound = maxSplit > minBound
        ? maxSplit
        : math.max(minBound + 1.0, (_totalSeconds - 1.0).toDouble());
    final double clampedVal = _firstSegmentSeconds.clamp(minBound, maxBound);
    final int divisions = math.max(1, (maxBound - minBound).round());

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split Session',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total duration: ${DurationFormatter.formatHms(_totalSeconds)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Split ratio slider
              Text(
                'Split Point: ${DurationFormatter.formatHumanReadable(firstSec)} / ${DurationFormatter.formatHumanReadable(secondSec)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: clampedVal,
                min: minBound,
                max: maxBound,
                divisions: divisions,
                label: DurationFormatter.formatHumanReadable(firstSec),
                onChanged: (val) {
                  setState(() {
                    _firstSegmentSeconds = val;
                  });
                },
              ),
              const Divider(height: 24),

              // Segment 1 Section
              _buildSegmentSection(
                title: 'Part 1: Start → Split',
                durationSec: firstSec,
                score: firstScore,
                selectedActivityId: _firstActivityId,
                onActivityChanged: (id) => setState(() => _firstActivityId = id!),
                noteController: _firstNoteController,
              ),
              const SizedBox(height: 16),

              // Segment 2 Section
              _buildSegmentSection(
                title: 'Part 2: Split → End',
                durationSec: secondSec,
                score: secondScore,
                selectedActivityId: _secondActivityId,
                onActivityChanged: (id) => setState(() => _secondActivityId = id!),
                noteController: _secondNoteController,
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        SplitSessionResult(
                          splitTime: splitDt,
                          firstActivityId: _firstActivityId,
                          secondActivityId: _secondActivityId,
                          firstNote: _firstNoteController.text,
                          secondNote: _secondNoteController.text,
                        ),
                      );
                    },
                    child: const Text('Confirm & Save Split'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int mathMax(int a, int b) => a > b ? a : b;

  Widget _buildSegmentSection({
    required String title,
    required int durationSec,
    required double score,
    required String selectedActivityId,
    required ValueChanged<String?> onActivityChanged,
    required TextEditingController noteController,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.forCoefficient(score).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${DurationFormatter.formatHumanReadable(durationSec)} (${ScoreCalculator.formatScore(score)})',
                  style: TextStyle(
                    color: AppColors.forCoefficient(score),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedActivityId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Activity',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: widget.activities.map((act) {
              return DropdownMenuItem<String>(
                value: act.id,
                child: Row(
                  children: [
                    Icon(
                      AppIcons.getIconData(act.iconCode),
                      color: Color(act.colorHex),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        act.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            onChanged: onActivityChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
