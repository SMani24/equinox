import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../activities/providers/activities_provider.dart';
import '../providers/timer_provider.dart';
import 'widgets/classify_session_sheet.dart';
import 'widgets/edit_entry_sheet.dart';
import 'widgets/manual_entry_sheet.dart';
import 'widgets/split_session_dialog.dart';
import 'widgets/timeline_entry_tile.dart';
import 'widgets/timer_dial.dart';
import 'widgets/today_summary_pill.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  void _showPreselectActivityDialog(
    BuildContext context,
    WidgetRef ref,
    List<Activity> activities,
    String? currentActivityId, {
    required bool isIdle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final ctxSize = MediaQuery.of(ctx).size;
        final isCtxLandscape = ctxSize.width > ctxSize.height || ctxSize.height < 520;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: isCtxLandscape ? ctxSize.height * 0.92 : ctxSize.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pre-select Activity (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (currentActivityId != null)
                    TextButton(
                      onPressed: () {
                        if (isIdle) {
                          ref
                              .read(idlePreselectedActivityIdProvider.notifier)
                              .select(null);
                        } else {
                          ref
                              .read(timerControllerProvider)
                              .updateDraft(activityId: null);
                        }
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final act = activities[index];
                    final isSelected = act.id == currentActivityId;
                    return ListTile(
                      selected: isSelected,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        AppIcons.getIconData(act.iconCode),
                        color: Color(act.colorHex),
                      ),
                      title: Text(act.name),
                      trailing: Text(
                        act.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forCoefficient(act.coefficient),
                        ),
                      ),
                      onTap: () {
                        if (isIdle) {
                          ref
                              .read(idlePreselectedActivityIdProvider.notifier)
                              .select(act.id);
                        } else {
                          ref
                              .read(timerControllerProvider)
                              .updateDraft(activityId: act.id);
                        }
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClassifySheet(
    BuildContext context,
    WidgetRef ref,
    TimerState timerState,
    List<Activity> activities, {
    String? preselectedActivityId,
  }) {
    final now = DateTime.now();
    // Use active elapsed time (excluding paused duration) so paused intervals are never logged
    final effectiveDuration = timerState.elapsedSeconds > 0
        ? Duration(seconds: timerState.elapsedSeconds)
        : Duration.zero;
    final startDt = now.subtract(effectiveDuration);

    final activityIdToUse =
        preselectedActivityId ?? timerState.preselectedActivityId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => ClassifySessionSheet(
        initialStartTime: startDt,
        initialEndTime: now,
        activities: activities,
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

          // Save Part 1
          await entryRepo.createEntry(
            activityId: result.firstActivityId,
            startTime: result.startTime,
            endTime: result.splitTime,
            note: result.firstNote,
          );
          // Save Part 2
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
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => ManualEntrySheet(
        activities: activities,
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
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => EditEntrySheet(
        item: item,
        activities: activities,
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
                content: Text('Session updated successfully'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        onDelete: () async {
          await ref.read(timeEntryRepositoryProvider).deleteEntry(item.entry.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session deleted'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerStateAsync = ref.watch(timerStateProvider);
    final timerState = timerStateAsync.value ?? TimerState.idle();

    final todaySummary = ref.watch(todayScoreSummaryProvider);
    final todayEntriesAsync = ref.watch(todayEntriesStreamProvider);
    final todayEntries = todayEntriesAsync.value ?? [];

    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final activities = activitiesAsync.value ?? [];

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
              preselectedActivityId: effectiveActivityId,
            );
          }
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Summary Pill
            SliverToBoxAdapter(
              child: TodaySummaryPill(summary: todaySummary),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Hero Timer Ring Dial
            SliverToBoxAdapter(
              child: TimerDial(
                timerState: timerState,
                preselectedActivity: preselectedActivity,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Optional Pre-select Activity & Session Note chips
            SliverToBoxAdapter(
              child: Center(
                child: Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: Icon(
                        preselectedActivity != null
                            ? AppIcons.getIconData(preselectedActivity.iconCode)
                            : Icons.tag,
                        size: 16,
                        color: preselectedActivity != null
                            ? Color(preselectedActivity.colorHex)
                            : AppColors.textMuted,
                      ),
                      label: Text(
                        preselectedActivity != null
                            ? preselectedActivity.name
                            : 'Pre-select activity',
                        style: TextStyle(
                          fontSize: 12,
                          color: preselectedActivity != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                      onPressed: () => _showPreselectActivityDialog(
                        context,
                        ref,
                        activities,
                        effectiveActivityId,
                        isIdle: isIdle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Action Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: isIdle
                    ? SizedBox(
                        height: 58,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            ref.read(timerControllerProvider).start(
                                  preselectedActivityId: effectiveActivityId,
                                );
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: const Text(
                            'START TIMER',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          // Pause / Resume Secondary Button
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
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
                                  color: isRunning
                                      ? AppColors.restMild
                                      : AppColors.productive,
                                ),
                                label: Text(
                                  isRunning ? 'PAUSE' : 'RESUME',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isRunning
                                        ? AppColors.restMild
                                        : AppColors.productive,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stop & Log Primary Button
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 3,
                                ),
                                onPressed: () => _showClassifySheet(
                                  context,
                                  ref,
                                  timerState,
                                  activities,
                                  preselectedActivityId: effectiveActivityId,
                                ),
                                icon: const Icon(Icons.stop_rounded, size: 22),
                                label: const Text(
                                  'STOP & LOG',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Today's Timeline Header & Manual Entry Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TODAY'S TIMELINE",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textMuted,
                          ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showManualEntrySheet(
                        context,
                        ref,
                        activities,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Manual Entry',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Timeline Entries List
            if (todayEntries.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.timelapse_outlined,
                          size: 40,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No sessions logged yet today',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap Start Timer or log manually to build today’s balance',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = todayEntries[index];
                    return TimelineEntryTile(
                      item: item,
                      onEdit: () => _showEditEntrySheet(
                        context,
                        ref,
                        item,
                        activities,
                      ),
                      onDelete: () {
                        ref
                            .read(timeEntryRepositoryProvider)
                            .deleteEntry(item.entry.id);
                      },
                    );
                  },
                  childCount: todayEntries.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }
}
