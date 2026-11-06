import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../data/database/app_database.dart';
import '../../activities/providers/activities_provider.dart';
import '../providers/timer_provider.dart';
import 'widgets/classify_session_sheet.dart';
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
    String? currentActivityId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6,
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
                        ref.read(timerControllerProvider).updateDraft(activityId: null);
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
                        ref.read(timerControllerProvider).updateDraft(activityId: act.id);
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
    List<Activity> activities,
  ) {
    final now = DateTime.now();
    final startDt = timerState.startEpochMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(timerState.startEpochMs)
        : now.subtract(Duration(seconds: timerState.elapsedSeconds));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => ClassifySessionSheet(
        initialStartTime: startDt,
        initialEndTime: now,
        activities: activities,
        initialActivityId: timerState.preselectedActivityId,
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
            startTime: startDt,
            endTime: result.splitTime,
            note: result.firstNote,
          );
          // Save Part 2
          await entryRepo.createEntry(
            activityId: result.secondActivityId,
            startTime: result.splitTime,
            endTime: now,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerStateAsync = ref.watch(timerStateProvider);
    final timerState = timerStateAsync.value ?? TimerState.idle();

    final todaySummary = ref.watch(todayScoreSummaryProvider);
    final todayEntriesAsync = ref.watch(todayEntriesStreamProvider);
    final todayEntries = todayEntriesAsync.value ?? [];

    final activitiesAsync = ref.watch(activitiesStreamProvider);
    final activities = activitiesAsync.value ?? [];

    Activity? preselectedActivity;
    if (timerState.preselectedActivityId != null) {
      for (final a in activities) {
        if (a.id == timerState.preselectedActivityId) {
          preselectedActivity = a;
          break;
        }
      }
    }

    final isIdle = !timerState.isRunning && !timerState.isPaused;
    final isRunning = timerState.isRunning;

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
                        timerState.preselectedActivityId,
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
                                  preselectedActivityId:
                                      timerState.preselectedActivityId,
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
                            flex: 1,
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
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
                                  color: isRunning
                                      ? AppColors.restMild
                                      : AppColors.productive,
                                ),
                                label: Text(
                                  isRunning ? 'PAUSE' : 'RESUME',
                                  style: TextStyle(
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
                            flex: 2,
                            child: SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () {
                                  _showClassifySheet(
                                    context,
                                    ref,
                                    timerState,
                                    activities,
                                  );
                                },
                                icon: const Icon(Icons.stop_rounded, size: 24),
                                label: const Text(
                                  'STOP & LOG',
                                  style: TextStyle(
                                    fontSize: 15,
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
