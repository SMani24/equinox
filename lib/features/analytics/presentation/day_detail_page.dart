import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/eq_card.dart';
import '../../../core/ui/score_pill.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../activities/providers/activities_provider.dart';
import '../../analytics/domain/time_slicer.dart';
import '../../settings/providers/settings_provider.dart';
import '../../smart/gap_detector.dart';
import '../../timer/presentation/widgets/day_ribbon.dart';
import '../../timer/presentation/widgets/edit_entry_sheet.dart';
import '../../timer/presentation/widgets/manual_entry_sheet.dart';
import '../../timer/presentation/widgets/timeline_entry_tile.dart';
import '../../timer/providers/timer_provider.dart';

/// Full-day drill-down screen displaying ribbon, breakdown, gaps, and editable sessions.
class DayDetailPage extends ConsumerWidget {
  final DateTime logicalDate;

  const DayDetailPage({super.key, required this.logicalDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = context.eq;
    final settings = ref.watch(settingsProvider);
    final activities =
        ref.watch(allActivitiesStreamProvider).value?.where((a) => !a.isArchived).toList() ??
            [];
    final suggestions = ref.watch(activitySuggestionsProvider);
    final entryRepo = ref.watch(timeEntryRepositoryProvider);

    final dayStart = DateBoundary.getDayStart(
      logicalDate,
      rolloverHour: settings.rolloverHour,
    );
    final dayEnd = DateBoundary.getDayEnd(
      logicalDate,
      rolloverHour: settings.rolloverHour,
    );

    final dayStream = ref.watch(_dayEntriesStreamProvider(logicalDate));
    final entries = dayStream.value ?? const <TimeEntryWithActivity>[];

    final slices = TimeSlicer.sliceEntries(
      entries,
      rolloverHour: settings.rolloverHour,
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );

    int prodSec = 0;
    int restSec = 0;
    int neutralSec = 0;
    double prodPts = 0.0;
    double restPts = 0.0;
    double net = 0.0;

    for (final s in slices) {
      net += s.score;
      if (s.activity.category == 'productive') {
        prodSec += s.seconds;
        prodPts += s.score;
      } else if (s.activity.category == 'rest') {
        restSec += s.seconds;
        restPts += s.score.abs();
      } else {
        neutralSec += s.seconds;
      }
    }

    final gaps = GapDetector.findGaps(
      entries: entries,
      rangeStart: dayStart,
      rangeEnd: dayEnd,
      now: DateTime.now(),
      minGapMinutes: settings.minGapMinutes,
      includeLeadingBeforeFirstEntry: false,
      includeTrailingUpToNow: false,
    );

    void openManual({DateTime? start, DateTime? end, String? actId}) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ManualEntrySheet(
          activities: activities,
          suggestions: suggestions,
          initialStartTime: start ?? DateTime(logicalDate.year, logicalDate.month, logicalDate.day, 12, 0),
          initialEndTime: end ?? DateTime(logicalDate.year, logicalDate.month, logicalDate.day, 13, 0),
          initialActivityId: actId,
          onSave: ({
            required activityId,
            required startTime,
            required endTime,
            note,
          }) {
            entryRepo.createEntry(
              activityId: activityId,
              startTime: startTime,
              endTime: endTime,
              note: note,
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEE, MMM d, yyyy').format(logicalDate)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add session to day',
            onPressed: activities.isEmpty ? null : () => openManual(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: EqCard(
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
                            'Day equilibrium',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ScoreCalculator.formatScore(net),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: eq.forBalance(
                                    net,
                                    goal: settings.equilibriumTarget,
                                  ),
                                ),
                          ),
                        ],
                      ),
                      ScorePill(
                        score: net,
                        isDangerOverride: net < settings.equilibriumTarget - 0.001,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _MiniStat(
                        color: eq.gain,
                        label: 'Work',
                        detail:
                            '${DurationFormatter.formatHumanReadable(prodSec)} (${ScoreCalculator.formatScore(prodPts, showUnit: false)})',
                      ),
                      _MiniStat(
                        color: eq.spend,
                        label: 'Rest',
                        detail:
                            '${DurationFormatter.formatHumanReadable(restSec)} (${ScoreCalculator.formatScore(-restPts, showUnit: false)})',
                      ),
                      _MiniStat(
                        color: eq.neutral,
                        label: 'Neutral',
                        detail: DurationFormatter.formatHumanReadable(neutralSec),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  DayRibbon(
                    dayStart: dayStart,
                    dayEnd: dayEnd,
                    entries: entries,
                    gaps: gaps,
                    now: DateTime.now(),
                    onTapGap: (g) => openManual(start: g.start, end: g.end),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Text(
              'Sessions (${entries.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Space.sm),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.lg),
              child: EmptyState(
                icon: Icons.timelapse_outlined,
                title: 'No sessions logged',
                body: 'Tap + in the top right to log an entry for this date.',
              ),
            )
          else
            ...entries.map(
              (item) => TimelineEntryTile(
                item: item,
                onEdit: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EditEntrySheet(
                      item: item,
                      activities: activities,
                      suggestions: suggestions,
                      onSave: ({
                        required entryId,
                        required activityId,
                        required startTime,
                        required endTime,
                        note,
                      }) {
                        entryRepo.updateEntry(
                          id: entryId,
                          activityId: activityId,
                          startTime: startTime,
                          endTime: endTime,
                          note: note,
                        );
                      },
                      onDelete: () => entryRepo.deleteEntry(item.entry.id),
                    ),
                  );
                },
                onDelete: () async {
                  final deleted = item.entry;
                  await entryRepo.deleteEntry(deleted.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text('Removed ${item.activity.name}'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => entryRepo.restoreEntry(deleted),
                          ),
                        ),
                      );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

final _dayEntriesStreamProvider = StreamProvider.autoDispose
    .family<List<TimeEntryWithActivity>, DateTime>((ref, logicalDate) {
  final settings = ref.watch(settingsProvider);
  final repo = ref.watch(timeEntryRepositoryProvider);
  return repo.watchEntriesForDay(
    logicalDate,
    rolloverHour: settings.rolloverHour,
  );
});

class _MiniStat extends StatelessWidget {
  final Color color;
  final String label;
  final String detail;

  const _MiniStat({
    required this.color,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: eq.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: eq.textPrimary,
          ),
        ),
      ],
    );
  }
}
