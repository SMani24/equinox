import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../../data/repositories/timer_repository.dart';
import '../../activities/providers/activities_provider.dart';
import '../../analytics/domain/time_slicer.dart';
import '../../settings/providers/settings_provider.dart';
import '../../smart/gap_detector.dart';
import '../../smart/suggestion_engine.dart';

export '../../../data/repositories/timer_repository.dart' show TimerState;

class IdleActivityNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final idlePreselectedActivityIdProvider =
    NotifierProvider<IdleActivityNotifier, String?>(IdleActivityNotifier.new);

class StopAndLogNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state = state + 1;
}

final stopAndLogRequestedProvider =
    NotifierProvider<StopAndLogNotifier, int>(StopAndLogNotifier.new);

final activeTimerStreamProvider = StreamProvider<ActiveTimerData?>((ref) {
  final repo = ref.watch(timerRepositoryProvider);
  return repo.watchActiveTimer();
});

final timerStateProvider = StreamProvider<TimerState>((ref) {
  final timerRepo = ref.watch(timerRepositoryProvider);

  // Controller to combine periodic tick with DB watch
  late StreamController<TimerState> controller;
  Timer? periodicTimer;
  StreamSubscription? dbSub;

  controller = StreamController<TimerState>(
    onListen: () {
      dbSub = timerRepo.watchActiveTimer().listen((data) {
        controller.add(TimerState.fromDb(data));
      });

      periodicTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
        final current = await timerRepo.getActiveTimer();
        if (current != null && current.pausedAt == null) {
          controller.add(TimerState.fromDb(current));
        }
      });
    },
    onCancel: () {
      periodicTimer?.cancel();
      dbSub?.cancel();
    },
  );

  return controller.stream;
});

class TimerController {
  final Ref ref;

  TimerController(this.ref);

  Future<void> start({String? preselectedActivityId, String? draftNote}) async {
    final timerRepo = ref.read(timerRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    final actRepo = ref.read(activityRepositoryProvider);

    final resolvedActivityId =
        preselectedActivityId ?? ref.read(idlePreselectedActivityIdProvider);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await timerRepo.startTimer(
      preselectedActivityId: resolvedActivityId,
      draftNote: draftNote,
      startTimeMs: nowMs,
    );

    // Clear idle selection once started
    ref.read(idlePreselectedActivityIdProvider.notifier).select(null);

    String? activityName;
    if (resolvedActivityId != null) {
      final act = await actRepo.getActivityById(resolvedActivityId);
      activityName = act?.name;
    }

    await notifService.showRunningTimer(
      startEpochMs: nowMs,
      activityName: activityName,
    );
  }

  Future<void> pause() async {
    final timerRepo = ref.read(timerRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    final actRepo = ref.read(activityRepositoryProvider);

    final active = await timerRepo.getActiveTimer();
    if (active == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await timerRepo.pauseTimer(nowMs: now);

    final state = TimerState.fromDb(active, nowMs: now);
    String? actName;
    if (active.preselectedActivityId != null) {
      final act = await actRepo.getActivityById(active.preselectedActivityId!);
      actName = act?.name;
    }

    await notifService.showPausedTimer(
      elapsedSeconds: state.elapsedSeconds,
      activityName: actName,
    );
  }

  Future<void> resume() async {
    final timerRepo = ref.read(timerRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);
    final actRepo = ref.read(activityRepositoryProvider);

    final active = await timerRepo.getActiveTimer();
    if (active == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await timerRepo.resumeTimer(nowMs: now);

    String? actName;
    if (active.preselectedActivityId != null) {
      final act = await actRepo.getActivityById(active.preselectedActivityId!);
      actName = act?.name;
    }

    // New start time anchor for notification chronometer
    final effectiveStart = now - (active.accumulatedPausedMs + (active.pausedAt != null ? (now - active.pausedAt!) : 0));
    await notifService.showRunningTimer(
      startEpochMs: effectiveStart,
      activityName: actName,
    );
  }

  Future<void> updateDraft({String? activityId, String? note}) async {
    final timerRepo = ref.read(timerRepositoryProvider);
    final actRepo = ref.read(activityRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    await timerRepo.updateDraft(
      preselectedActivityId: activityId,
      draftNote: note,
    );

    final active = await timerRepo.getActiveTimer();
    if (active != null) {
      String? actName;
      if (activityId != null) {
        final act = await actRepo.getActivityById(activityId);
        actName = act?.name;
      }
      if (active.pausedAt == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final effectiveStart = now - active.accumulatedPausedMs;
        await notifService.showRunningTimer(
          startEpochMs: effectiveStart,
          activityName: actName,
        );
      } else {
        final state = TimerState.fromDb(active);
        await notifService.showPausedTimer(
          elapsedSeconds: state.elapsedSeconds,
          activityName: actName,
        );
      }
    }
  }

  Future<void> discard() async {
    final timerRepo = ref.read(timerRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    ref.read(idlePreselectedActivityIdProvider.notifier).select(null);
    await timerRepo.clearTimer();
    await notifService.cancelTimerNotification();
  }

  Future<void> commitSession({
    required String activityId,
    required DateTime startTime,
    required DateTime endTime,
    String? note,
  }) async {
    final entryRepo = ref.read(timeEntryRepositoryProvider);
    final timerRepo = ref.read(timerRepositoryProvider);
    final notifService = ref.read(notificationServiceProvider);

    ref.read(idlePreselectedActivityIdProvider.notifier).select(null);
    await entryRepo.createEntry(
      activityId: activityId,
      startTime: startTime,
      endTime: endTime,
      note: note,
    );

    await timerRepo.clearTimer();
    await notifService.cancelTimerNotification();
  }
}

final timerControllerProvider = Provider<TimerController>((ref) {
  return TimerController(ref);
});

/// Emits the current logical date, updating whenever midnight or the rollover hour passes.
final currentLogicalDateProvider = StreamProvider<DateTime>((ref) {
  final settings = ref.watch(settingsProvider);

  DateTime computeLogical() => DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );

  late StreamController<DateTime> controller;
  Timer? timer;

  controller = StreamController<DateTime>(
    onListen: () {
      controller.add(computeLogical());
      timer = Timer.periodic(const Duration(seconds: 15), (_) {
        controller.add(computeLogical());
      });
    },
    onCancel: () {
      timer?.cancel();
    },
  );

  return controller.stream.distinct();
});

// Today's Entries Provider
final todayEntriesStreamProvider =
    StreamProvider<List<TimeEntryWithActivity>>((ref) {
  final entryRepo = ref.watch(timeEntryRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  final logicalDateAsync = ref.watch(currentLogicalDateProvider);
  final logicalToday = logicalDateAsync.value ??
      DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );

  return entryRepo.watchEntriesForDay(
    logicalToday,
    rolloverHour: settings.rolloverHour,
  );
});

class TodayScoreSummary {
  final double grossProductiveScore;
  final double grossRestCost;
  final double netScore;
  final int productiveSeconds;
  final int restSeconds;
  final int neutralSeconds;
  final double targetGoal;
  final double? dailyRestBudget;

  const TodayScoreSummary({
    required this.grossProductiveScore,
    required this.grossRestCost,
    required this.netScore,
    required this.productiveSeconds,
    required this.restSeconds,
    required this.neutralSeconds,
    required this.targetGoal,
    this.dailyRestBudget,
  });

  factory TodayScoreSummary.empty(double target, {double? dailyRestBudget}) =>
      TodayScoreSummary(
        grossProductiveScore: 0.0,
        grossRestCost: 0.0,
        netScore: 0.0,
        productiveSeconds: 0,
        restSeconds: 0,
        neutralSeconds: 0,
        targetGoal: target,
        dailyRestBudget: dailyRestBudget,
      );
}

final todayScoreSummaryProvider = Provider<TodayScoreSummary>((ref) {
  final entriesAsync = ref.watch(todayEntriesStreamProvider);
  final settings = ref.watch(settingsProvider);
  final logicalDateAsync = ref.watch(currentLogicalDateProvider);
  final logicalToday = logicalDateAsync.value ??
      DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );
  final entries = entriesAsync.value ?? [];

  if (entries.isEmpty) {
    return TodayScoreSummary.empty(
      settings.equilibriumTarget,
      dailyRestBudget: settings.dailyRestBudget,
    );
  }

  final dayStart = DateBoundary.getDayStart(
    logicalToday,
    rolloverHour: settings.rolloverHour,
  );
  final dayEnd = DateBoundary.getDayEnd(
    logicalToday,
    rolloverHour: settings.rolloverHour,
  );

  final slices = TimeSlicer.sliceEntries(
    entries,
    rolloverHour: settings.rolloverHour,
    rangeStart: dayStart,
    rangeEnd: dayEnd,
  );

  int prodSec = 0;
  int restSec = 0;
  int neutralSec = 0;
  final scores = <double>[];

  for (final s in slices) {
    scores.add(s.score);
    final cat = s.activity.category;
    if (cat == 'productive') {
      prodSec += s.seconds;
    } else if (cat == 'rest') {
      restSec += s.seconds;
    } else {
      neutralSec += s.seconds;
    }
  }

  return TodayScoreSummary(
    grossProductiveScore: ScoreCalculator.calculateGrossProductive(scores),
    grossRestCost: ScoreCalculator.calculateGrossRestCost(scores),
    netScore: ScoreCalculator.calculateNetBalance(scores),
    productiveSeconds: prodSec,
    restSeconds: restSec,
    neutralSeconds: neutralSec,
    targetGoal: settings.equilibriumTarget,
    dailyRestBudget: settings.dailyRestBudget,
  );
});

/// 60-day history stream shared across suggestion ranking, gap recovery, and sparklines.
final recentHistoryEntriesProvider =
    StreamProvider<List<TimeEntryWithActivity>>((ref) {
  final entryRepo = ref.watch(timeEntryRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  final logicalDateAsync = ref.watch(currentLogicalDateProvider);
  final logicalToday = logicalDateAsync.value ??
      DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );
  final start = DateBoundary.getDayStart(
    DateTime(logicalToday.year, logicalToday.month, logicalToday.day - 60),
    rolloverHour: settings.rolloverHour,
  );
  final end = DateBoundary.getDayEnd(
    logicalToday,
    rolloverHour: settings.rolloverHour,
  );
  return entryRepo.watchEntriesBetween(start, end);
});

/// Ranked quick-start activity suggestions based on recent history & time context.
final activitySuggestionsProvider = Provider<List<ActivitySuggestion>>((ref) {
  final settings = ref.watch(settingsProvider);
  final activities = ref.watch(activitiesStreamProvider).value ?? [];
  final history = ref.watch(recentHistoryEntriesProvider).value ?? [];
  final todayEntries = ref.watch(todayEntriesStreamProvider).value ?? [];

  if (!settings.smartSuggestionsEnabled) {
    return activities
        .where((a) => !a.isArchived)
        .map((a) => ActivitySuggestion(activity: a, score: 0.0))
        .toList();
  }

  final now = DateTime.now();
  TimeEntryWithActivity? prev;
  for (final e in todayEntries) {
    if (e.entry.endTime <= now.millisecondsSinceEpoch) {
      if (prev == null || e.entry.endTime > prev.entry.endTime) {
        prev = e;
      }
    }
  }

  return SuggestionEngine.rankActivities(
    activities: activities,
    historyEntries: history,
    now: now,
    previousEntry: prev,
  );
});

/// Untracked gaps >= minGapMinutes detected in today's timeline.
final todayGapsProvider = Provider<List<TimeGap>>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.gapRemindersEnabled) return const [];

  final todayEntries = ref.watch(todayEntriesStreamProvider).value ?? [];
  final timerState = ref.watch(timerStateProvider).value ?? TimerState.idle();
  final logicalToday = ref.watch(currentLogicalDateProvider).value ??
      DateBoundary.getLogicalDate(
        DateTime.now(),
        rolloverHour: settings.rolloverHour,
      );

  final dayStart = DateBoundary.getDayStart(
    logicalToday,
    rolloverHour: settings.rolloverHour,
  );
  final dayEnd = DateBoundary.getDayEnd(
    logicalToday,
    rolloverHour: settings.rolloverHour,
  );

  return GapDetector.findGaps(
    entries: todayEntries,
    rangeStart: dayStart,
    rangeEnd: dayEnd,
    now: DateTime.now(),
    minGapMinutes: settings.minGapMinutes,
    includeLeadingBeforeFirstEntry: false,
    includeTrailingUpToNow: !timerState.isRunning && !timerState.isPaused,
  );
});

/// Proactive morning catch-up banner when last night's sleep wasn't logged yet.
final morningSleepCatchupProvider = Provider<SleepCatchupSuggestion?>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.gapRemindersEnabled) return null;

  final activities = ref.watch(activitiesStreamProvider).value ?? [];
  final history = ref.watch(recentHistoryEntriesProvider).value ?? [];

  return GapDetector.detectMorningSleepCatchup(
    activities: activities,
    recentEntries: history,
    now: DateTime.now(),
    rolloverHour: settings.rolloverHour,
    dismissedDateKey: settings.dismissedSleepCatchupDate,
  );
});

/// True if an active running timer likely was left on accidentally.
final forgottenTimerWarningProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  if (!settings.forgottenTimerAlertEnabled) return false;

  final timerState = ref.watch(timerStateProvider).value ?? TimerState.idle();
  if (!timerState.isRunning) return false;

  final history = ref.watch(recentHistoryEntriesProvider).value ?? [];
  return GapDetector.shouldWarnForgottenTimer(
    elapsedSeconds: timerState.elapsedSeconds,
    preselectedActivityId: timerState.preselectedActivityId,
    historyEntries: history,
  );
});
