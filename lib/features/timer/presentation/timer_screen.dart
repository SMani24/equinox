import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/eq_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/activity_chip.dart';
import '../../../core/ui/activity_picker_sheet.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/eq_card.dart';
import '../../../core/ui/eq_section_header.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../activities/providers/activities_provider.dart';
import '../../analytics/presentation/day_detail_page.dart';
import '../../settings/providers/settings_provider.dart';
import '../../smart/gap_detector.dart';
import '../../smart/suggestion_engine.dart';
import '../providers/timer_provider.dart';
import 'widgets/classify_session_sheet.dart';
import 'widgets/day_ribbon.dart';
import 'widgets/edit_entry_sheet.dart';
import 'widgets/manual_entry_sheet.dart';
import 'widgets/split_session_dialog.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/timer_dial.dart';
import 'widgets/today_summary_pill.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  Map<String, List<String>> _buildRecentNotesMap(
    List<TimeEntryWithActivity> history,
  ) {
    final Map<String, List<String>> notesByAct = {};
    final sorted = List<TimeEntryWithActivity>.from(history)
      ..sort((a, b) => b.entry.endTime.compareTo(a.entry.endTime));
    for (final item in sorted) {
      final note = item.entry.note?.trim();
      if (note == null || note.isEmpty) continue;
      final list = notesByAct.putIfAbsent(item.activity.id, () => []);
      if (!list.contains(note) && list.length < 6) {
        list.add(note);
      }
    }
    return notesByAct;
  }

  void _showUnifiedPreselectPicker(
    BuildContext context,
    WidgetRef ref,
    List<Activity> activities,
    List<ActivitySuggestion> suggestions,
    String? currentActivityId, {
    required bool isIdle,
  }) {
    ActivityPickerSheet.show(
      context: context,
      title: 'Pre-select Activity',
      subtitle: 'Optional — choose what you are starting now',
      activities: activities,
      suggestions: suggestions,
      selectedActivityId: currentActivityId,
      allowClear: true,
      onSelected: (act) {
        if (isIdle) {
          ref.read(idlePreselectedActivityIdProvider.notifier).select(act?.id);
        } else {
          ref.read(timerControllerProvider).updateDraft(activityId: act?.id);
        }
      },
    );
  }

  void _showClassifySheet(
    BuildContext context,
    WidgetRef ref,
    TimerState timerState,
    List<Activity> activities,
    List<TimeEntryWithActivity> history,
    List<TimeEntryWithActivity> todayEntries, {
    String? preselectedActivityId,
  }) {
    final now = DateTime.now();
    final effectiveDuration = timerState.elapsedSeconds > 0
        ? Duration(seconds: timerState.elapsedSeconds)
        : Duration.zero;
    final startDt = now.subtract(effectiveDuration);
    final activityIdToUse =
        preselectedActivityId ?? timerState.preselectedActivityId;

    final settings = ref.read(settingsProvider);
    TimeEntryWithActivity? prevEntry;
    for (final e in todayEntries) {
      if (e.entry.endTime <= startDt.millisecondsSinceEpoch) {
        if (prevEntry == null || e.entry.endTime > prevEntry.entry.endTime) {
          prevEntry = e;
        }
      }
    }

    final classifySuggestions = settings.smartSuggestionsEnabled
        ? SuggestionEngine.rankActivities(
            activities: activities,
            historyEntries: history,
            now: startDt,
            previousEntry: prevEntry,
            sessionDurationSeconds: timerState.elapsedSeconds,
          )
        : const <ActivitySuggestion>[];

    final recentNotes = _buildRecentNotesMap(history);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ClassifySessionSheet(
        initialStartTime: startDt,
        initialEndTime: now,
        activities: activities,
        suggestions: classifySuggestions,
        recentNotesByActivity: recentNotes,
        initialActivityId: activityIdToUse,
        initialNote: timerState.draftNote,
        onSave: ({
          required String activityId,
          required DateTime startTime,
          required DateTime endTime,
          String? note,
        }) {
          ref.read(timerControllerProvider).commitSession(
                activityId: activityId,
                startTime: startTime,
                endTime: endTime,
                note: note,
              );
        },
        onSplitSave: (SplitSessionResult result) async {
          final entryRepo = ref.read(timeEntryRepositoryProvider);
          final controller = ref.read(timerControllerProvider);
          await entryRepo.createEntry(
            activityId: result.firstActivityId,
            startTime: result.startTime,
            endTime: result.splitTime,
            note: result.firstNote,
          );
          await entryRepo.createEntry(
            activityId: result.secondActivityId,
            startTime: result.splitTime,
            endTime: result.endTime,
            note: result.secondNote,
          );
          await controller.discard();
        },
        onDiscard: () {
          ref.read(timerControllerProvider).discard();
        },
      ),
    );
  }

  void _showManualEntrySheet(
    BuildContext context,
    WidgetRef ref,
    List<Activity> activities,
    List<TimeEntryWithActivity> todayEntries,
    List<TimeEntryWithActivity> history, {
    DateTime? initialStartTime,
    DateTime? initialEndTime,
    String? initialActivityId,
  }) {
    final now = DateTime.now();
    final smartRange = initialStartTime != null && initialEndTime != null
        ? (start: initialStartTime, end: initialEndTime)
        : GapDetector.suggestManualPrefill(
            todayEntries: todayEntries,
            now: now,
          );

    final settings = ref.read(settingsProvider);
    final gapDuration = smartRange.end.difference(smartRange.start).inSeconds;
    final suggestions = settings.smartSuggestionsEnabled
        ? SuggestionEngine.rankActivities(
            activities: activities,
            historyEntries: history,
            now: smartRange.start,
            sessionDurationSeconds: gapDuration > 0 ? gapDuration : null,
          )
        : const <ActivitySuggestion>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ManualEntrySheet(
        activities: activities,
        suggestions: suggestions,
        recentNotesByActivity: _buildRecentNotesMap(history),
        initialStartTime: smartRange.start,
        initialEndTime: smartRange.end,
        initialActivityId: initialActivityId ??
            (suggestions.isNotEmpty ? suggestions.first.activity.id : null),
        onSave: ({
          required String activityId,
          required DateTime startTime,
          required DateTime endTime,
          String? note,
        }) {
          ref.read(timeEntryRepositoryProvider).createEntry(
                activityId: activityId,
                startTime: startTime,
                endTime: endTime,
                note: note,
              );
        },
      ),
    );
  }

  void _showEditEntrySheet(
    BuildContext context,
    WidgetRef ref,
    TimeEntryWithActivity item,
    List<Activity> activities,
    List<ActivitySuggestion> suggestions,
    List<TimeEntryWithActivity> history,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => EditEntrySheet(
        item: item,
        activities: activities,
        suggestions: suggestions,
        recentNotesByActivity: _buildRecentNotesMap(history),
        onSave: ({
          required String entryId,
          required String activityId,
          required DateTime startTime,
          required DateTime endTime,
          String? note,
        }) async {
          await ref.read(timeEntryRepositoryProvider).updateEntry(
                id: entryId,
                activityId: activityId,
                startTime: startTime,
                endTime: endTime,
                note: note,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session updated'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        onDelete: () async {
          await ref.read(timeEntryRepositoryProvider).deleteEntry(item.entry.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Removed ${item.activity.name}'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    ref.read(timeEntryRepositoryProvider).restoreEntry(item.entry);
                  },
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = context.eq;
    final timerState =
        ref.watch(timerStateProvider).value ?? TimerState.idle();
    final todaySummary = ref.watch(todayScoreSummaryProvider);
    final todayEntries = ref.watch(todayEntriesStreamProvider).value ?? [];
    final activities = ref.watch(activitiesStreamProvider).value ?? [];
    final history = ref.watch(recentHistoryEntriesProvider).value ?? [];
    final suggestions = ref.watch(activitySuggestionsProvider);
    final todayGaps = ref.watch(todayGapsProvider);
    final sleepCatchup = ref.watch(morningSleepCatchupProvider);
    final forgottenWarning = ref.watch(forgottenTimerWarningProvider);
    final settings = ref.watch(settingsProvider);
    final logicalToday = ref.watch(currentLogicalDateProvider).value ??
        DateBoundary.getLogicalDate(
          DateTime.now(),
          rolloverHour: settings.rolloverHour,
        );

    final isIdle = !timerState.isRunning && !timerState.isPaused;
    final isRunning = timerState.isRunning;
    final idlePreselectedId = ref.watch(idlePreselectedActivityIdProvider);
    final effectiveActivityId =
        isIdle ? idlePreselectedId : timerState.preselectedActivityId;

    Activity? preselectedActivity;
    if (effectiveActivityId != null) {
      for (final a in activities) {
        if (a.id == effectiveActivityId) {
          preselectedActivity = a;
          break;
        }
      }
    }

    ref.listen(stopAndLogRequestedProvider, (prev, next) {
      if (next > 0 && !isIdle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _showClassifySheet(
              context,
              ref,
              timerState,
              activities,
              history,
              todayEntries,
              preselectedActivityId: effectiveActivityId,
            );
          }
        });
      }
    });

    final dayStart = DateBoundary.getDayStart(
      logicalToday,
      rolloverHour: settings.rolloverHour,
    );
    final dayEnd = DateBoundary.getDayEnd(
      logicalToday,
      rolloverHour: settings.rolloverHour,
    );

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height && size.width >= 600;

    void handleDialTap() {
      final controller = ref.read(timerControllerProvider);
      if (isIdle) {
        controller.start(preselectedActivityId: effectiveActivityId);
      } else if (isRunning) {
        controller.pause();
      } else {
        controller.resume();
      }
    }

    void handleStopAndLog() {
      _showClassifySheet(
        context,
        ref,
        timerState,
        activities,
        history,
        todayEntries,
        preselectedActivityId: effectiveActivityId,
      );
    }

    final quickChips = (suggestions.isNotEmpty
            ? suggestions.map((s) => s.activity)
            : activities)
        .take(4)
        .toList();

    Widget buildControls() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: isIdle
            ? SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: eq.accent,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0B0D12)
                            : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(timerControllerProvider)
                        .start(preselectedActivityId: effectiveActivityId);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: const Text(
                    'Start Timer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              isRunning ? eq.spendSoft : eq.gainSoft,
                          foregroundColor: isRunning ? eq.spend : eq.gain,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (isRunning) {
                            ref.read(timerControllerProvider).pause();
                          } else {
                            ref.read(timerControllerProvider).resume();
                          }
                        },
                        icon: Icon(
                          isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isRunning ? 'Pause' : 'Resume',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: eq.accent,
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF0B0D12)
                                  : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          handleStopAndLog();
                        },
                        icon: const Icon(Icons.stop_rounded, size: 22),
                        label: const Text(
                          'Stop & Log',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      );
    }

    Widget buildQuickChipsRow() {
      return SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          children: [
            ...quickChips.map((act) {
              final selected = act.id == effectiveActivityId;
              return Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: ActivityChip(
                  activity: act,
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isIdle) {
                      if (selected) {
                        ref
                            .read(idlePreselectedActivityIdProvider.notifier)
                            .select(null);
                      } else {
                        ref
                            .read(timerControllerProvider)
                            .start(preselectedActivityId: act.id);
                      }
                    } else {
                      ref
                          .read(timerControllerProvider)
                          .updateDraft(activityId: selected ? null : act.id);
                    }
                  },
                ),
              );
            }),
            ActionChip(
              avatar: Icon(Icons.tune_rounded, size: 15, color: eq.accent),
              label: const Text('Pick'),
              backgroundColor: eq.surface1,
              side: BorderSide.none,
              onPressed: () => _showUnifiedPreselectPicker(
                context,
                ref,
                activities,
                suggestions,
                effectiveActivityId,
                isIdle: isIdle,
              ),
            ),
          ],
        ),
      );
    }

    List<Widget> buildSmartBanners() {
      final banners = <Widget>[];
      if (forgottenWarning) {
        banners.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: EqCard(
              accentTint: eq.spend,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 18, color: eq.spend),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      preselectedActivity != null
                          ? 'Still doing ${preselectedActivity.name}? (${DurationFormatter.formatHumanReadable(timerState.elapsedSeconds)})'
                          : 'Timer running for ${DurationFormatter.formatHumanReadable(timerState.elapsedSeconds)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: handleStopAndLog,
                    child: const Text('Stop & Log'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (sleepCatchup != null) {
        final rangeText = DurationFormatter.formatTimelineTimeRange(
          sleepCatchup.start,
          sleepCatchup.end,
          DateTime.now(),
        );
        banners.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: EqCard(
              accentTint: eq.accent,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.getIconData(sleepCatchup.sleepActivity.iconCode),
                    size: 18,
                    color: Color(sleepCatchup.sleepActivity.colorHex),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Log last night's sleep?",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          rangeText,
                          style: TextStyle(fontSize: 11.5, color: eq.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .dismissSleepCatchupForDate(
                            GapDetector.dateKeyFor(logicalToday),
                          );
                      _showManualEntrySheet(
                        context,
                        ref,
                        activities,
                        todayEntries,
                        history,
                        initialStartTime: sleepCatchup.start,
                        initialEndTime: sleepCatchup.end,
                        initialActivityId: sleepCatchup.sleepActivity.id,
                      );
                    },
                    child: const Text('Log'),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    color: eq.textMuted,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .dismissSleepCatchupForDate(
                            GapDetector.dateKeyFor(logicalToday),
                          );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return banners;
    }

    // Build chronological timeline rows with between-session gap chips
    List<Widget> buildTimelineRows() {
      if (todayEntries.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
            child: EmptyState(
              icon: Icons.timelapse_outlined,
              title: 'No sessions logged yet today',
              body: 'Tap the ring or a quick-start chip above, or add an entry manually.',
              action: TextButton.icon(
                onPressed: () => _showManualEntrySheet(
                  context,
                  ref,
                  activities,
                  todayEntries,
                  history,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Manual entry'),
              ),
            ),
          ),
        ];
      }

      final widgets = <Widget>[];
      // todayEntries are ordered newest -> oldest (startTime desc).
      for (int i = 0; i < todayEntries.length; i++) {
        final item = todayEntries[i];
        widgets.add(
          TimelineEntryTile(
            item: item,
            isFirst: i == 0,
            isLast: i == todayEntries.length - 1,
            onEdit: () => _showEditEntrySheet(
              context,
              ref,
              item,
              activities,
              suggestions,
              history,
            ),
            onRestart: () {
              HapticFeedback.mediumImpact();
              ref
                  .read(timerControllerProvider)
                  .start(preselectedActivityId: item.activity.id);
            },
            onDelete: () async {
              final deleted = item.entry;
              await ref.read(timeEntryRepositoryProvider).deleteEntry(deleted.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Removed ${item.activity.name}'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          ref
                              .read(timeEntryRepositoryProvider)
                              .restoreEntry(deleted);
                        },
                      ),
                    ),
                  );
              }
            },
          ),
        );

        // Check gap strictly between this entry and older next entry in descending list
        if (i < todayEntries.length - 1 && settings.gapRemindersEnabled) {
          final older = todayEntries[i + 1];
          final gapMs = item.entry.startTime - older.entry.endTime;
          if (gapMs >= settings.minGapMinutes * 60 * 1000) {
            final gapStart = DateTime.fromMillisecondsSinceEpoch(older.entry.endTime);
            final gapEnd = DateTime.fromMillisecondsSinceEpoch(item.entry.startTime);
            final gapDurStr =
                DurationFormatter.formatHumanReadable((gapMs / 1000).round());
            widgets.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(86, 2, Space.lg, 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  onTap: () => _showManualEntrySheet(
                    context,
                    ref,
                    activities,
                    todayEntries,
                    history,
                    initialStartTime: gapStart,
                    initialEndTime: gapEnd,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: eq.surface1,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(
                        color: eq.borderSubtle,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 14, color: eq.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Untracked · $gapDurStr',
                            style: TextStyle(fontSize: 11.5, color: eq.textMuted),
                          ),
                        ),
                        Text(
                          'Fill',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: eq.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }
      return widgets;
    }

    Widget buildDayRibbonBlock() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: DayRibbon(
          dayStart: dayStart,
          dayEnd: dayEnd,
          entries: todayEntries,
          gaps: todayGaps,
          now: DateTime.now(),
          onTapEntry: (item) => _showEditEntrySheet(
            context,
            ref,
            item,
            activities,
            suggestions,
            history,
          ),
          onTapGap: (gap) => _showManualEntrySheet(
            context,
            ref,
            activities,
            todayEntries,
            history,
            initialStartTime: gap.start,
            initialEndTime: gap.end,
          ),
        ),
      );
    }

    final summaryPill = TodaySummaryPill(
      summary: todaySummary,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DayDetailPage(logicalDate: logicalToday),
          ),
        );
      },
    );

    final timelineHeader = EqSectionHeader(
      title: 'Timeline',
      trailing: TextButton.icon(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: () => _showManualEntrySheet(
          context,
          ref,
          activities,
          todayEntries,
          history,
        ),
        icon: const Icon(Icons.add_rounded, size: 17),
        label: const Text('Manual'),
      ),
    );

    if (isLandscape) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              // Left column: Summary + Ring + Chips + Controls
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(
                    children: [
                      summaryPill,
                      const SizedBox(height: Space.sm),
                      TimerDial(
                        timerState: timerState,
                        preselectedActivity: preselectedActivity,
                        onTap: handleDialTap,
                        onLongPress: isIdle ? null : handleStopAndLog,
                      ),
                      const SizedBox(height: Space.md),
                      buildQuickChipsRow(),
                      const SizedBox(height: Space.md),
                      buildControls(),
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: eq.borderSubtle),
              // Right column: Smart banners + Ribbon + Timeline
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  children: [
                    ...buildSmartBanners(),
                    buildDayRibbonBlock(),
                    const SizedBox(height: Space.md),
                    timelineHeader,
                    const SizedBox(height: Space.xs),
                    ...buildTimelineRows(),
                    const SizedBox(height: Space.xl),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: summaryPill),
            const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
            SliverToBoxAdapter(
              child: TimerDial(
                timerState: timerState,
                preselectedActivity: preselectedActivity,
                onTap: handleDialTap,
                onLongPress: isIdle ? null : handleStopAndLog,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
            SliverToBoxAdapter(child: buildQuickChipsRow()),
            const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
            SliverToBoxAdapter(child: buildControls()),
            const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
            ...buildSmartBanners()
                .map((b) => SliverToBoxAdapter(child: b)),
            SliverToBoxAdapter(child: buildDayRibbonBlock()),
            const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
            SliverToBoxAdapter(child: timelineHeader),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xs)),
            SliverList(
              delegate: SliverChildListDelegate(buildTimelineRows()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
          ],
        ),
      ),
    );
  }
}
