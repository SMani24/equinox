import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/date_boundary.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/time_entry_repository.dart';
import '../../../data/repositories/timer_repository.dart';
import '../../settings/providers/settings_provider.dart';

export '../../../data/repositories/timer_repository.dart' show TimerState;

class IdleActivityNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final idlePreselectedActivityIdProvider =
    NotifierProvider<IdleActivityNotifier, String?>(IdleActivityNotifier.new);

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
    await timerRepo.updateDraft(
      preselectedActivityId: activityId,
      draftNote: note,
    );
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

// Today's Entries Provider
final todayEntriesStreamProvider = StreamProvider<List<TimeEntryWithActivity>>((ref) {
  final entryRepo = ref.watch(timeEntryRepositoryProvider);
  final settings = ref.watch(settingsProvider);
  final now = DateTime.now();
  final logicalToday = DateBoundary.getLogicalDate(
    now,
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

  const TodayScoreSummary({
    required this.grossProductiveScore,
    required this.grossRestCost,
    required this.netScore,
    required this.productiveSeconds,
    required this.restSeconds,
    required this.neutralSeconds,
    required this.targetGoal,
  });

  factory TodayScoreSummary.empty(double target) => TodayScoreSummary(
        grossProductiveScore: 0.0,
        grossRestCost: 0.0,
        netScore: 0.0,
        productiveSeconds: 0,
        restSeconds: 0,
        neutralSeconds: 0,
        targetGoal: target,
      );
}

final todayScoreSummaryProvider = Provider<TodayScoreSummary>((ref) {
  final entriesAsync = ref.watch(todayEntriesStreamProvider);
  final settings = ref.watch(settingsProvider);
  final entries = entriesAsync.value ?? [];

  if (entries.isEmpty) {
    return TodayScoreSummary.empty(settings.equilibriumTarget);
  }

  int prodSec = 0;
  int restSec = 0;
  int neutralSec = 0;
  final scores = <double>[];

  for (final item in entries) {
    final cat = item.activity.category;
    final dur = item.entry.durationSeconds;
    final score = item.entry.scoreSnapshot;

    scores.add(score);
    if (cat == 'productive') {
      prodSec += dur;
    } else if (cat == 'rest') {
      restSec += dur;
    } else {
      neutralSec += dur;
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
  );
});
