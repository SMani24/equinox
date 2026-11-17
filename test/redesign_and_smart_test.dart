import 'package:drift/native.dart';
import 'package:equinox/app.dart';
import 'package:equinox/core/providers/core_providers.dart';
import 'package:equinox/core/theme/app_theme.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:equinox/data/repositories/time_entry_repository.dart';
import 'package:equinox/features/analytics/domain/time_slicer.dart';
import 'package:equinox/features/smart/activity_autofill.dart';
import 'package:equinox/features/smart/gap_detector.dart';
import 'package:equinox/features/smart/insights_engine.dart';
import 'package:equinox/features/smart/suggestion_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _makeAct(
  String id,
  String name,
  String category,
  double coeff, {
  int color = 0xFF10B981,
  int sort = 0,
}) {
  return Activity(
    id: id,
    name: name,
    category: category,
    coefficient: coeff,
    colorHex: color,
    iconCode: Icons.star.codePoint,
    isArchived: false,
    sortOrder: sort,
    createdAt: 0,
    updatedAt: 0,
  );
}

TimeEntryWithActivity _makeEntry(
  String id,
  Activity act,
  DateTime start,
  DateTime end,
) {
  final durSec = end.difference(start).inSeconds;
  return TimeEntryWithActivity(
    entry: TimeEntry(
      id: id,
      activityId: act.id,
      startTime: start.millisecondsSinceEpoch,
      endTime: end.millisecondsSinceEpoch,
      durationSeconds: durSec,
      coefficientSnapshot: act.coefficient,
      scoreSnapshot: (durSec / 3600.0) * act.coefficient,
      note: null,
      createdAt: start.millisecondsSinceEpoch,
      updatedAt: end.millisecondsSinceEpoch,
    ),
    activity: act,
  );
}

void main() {
  group('TimeSlicer Analytics Correctness', () {
    test('pro-rates overnight sleep across days and hours', () {
      final sleep = _makeAct('sleep', 'Sleep', 'neutral', 0.0);
      final entry = _makeEntry(
        'e1',
        sleep,
        DateTime(2026, 11, 12, 23, 0),
        DateTime(2026, 11, 13, 8, 42),
      );

      final allSlices = TimeSlicer.sliceEntry(entry).toList();
      final nov12Sec = allSlices
          .where((s) => s.logicalDay == DateTime(2026, 11, 12))
          .fold(0, (a, b) => a + b.seconds);
      final nov13Sec = allSlices
          .where((s) => s.logicalDay == DateTime(2026, 11, 13))
          .fold(0, (a, b) => a + b.seconds);

      expect(nov12Sec, 3600); // 1h on Nov 12
      expect(nov13Sec, 8 * 3600 + 42 * 60); // 8h 42m on Nov 13
      expect(nov12Sec + nov13Sec, entry.entry.durationSeconds);
    });

    test('splits a multi-hour work session accurately across hourly buckets (<= 3600s each)', () {
      final work = _makeAct('work', 'Deep Work', 'productive', 1.5);
      final entry = _makeEntry(
        'e2',
        work,
        DateTime(2026, 11, 15, 9, 10),
        DateTime(2026, 11, 15, 12, 10),
      );

      final slices = TimeSlicer.sliceEntry(entry).toList();
      final byHour = {for (final s in slices) s.hour: s.seconds};

      expect(byHour[9], 50 * 60);
      expect(byHour[10], 60 * 60);
      expect(byHour[11], 60 * 60);
      expect(byHour[12], 10 * 60);
      for (final sec in byHour.values) {
        expect(sec, lessThanOrEqualTo(3600));
      }
    });

    test('respects rolloverHour when slicing cross-midnight entries', () {
      final work = _makeAct('work', 'Study', 'productive', 1.0);
      final entry = _makeEntry(
        'e3',
        work,
        DateTime(2026, 11, 16, 2, 0),
        DateTime(2026, 11, 16, 5, 0),
      );

      final slices = TimeSlicer.sliceEntry(entry, rolloverHour: 4).toList();
      final nov15Sec = slices
          .where((s) => s.logicalDay == DateTime(2026, 11, 15))
          .fold(0, (a, b) => a + b.seconds);
      final nov16Sec = slices
          .where((s) => s.logicalDay == DateTime(2026, 11, 16))
          .fold(0, (a, b) => a + b.seconds);

      expect(nov15Sec, 7200); // 2 AM -> 4 AM counts toward Nov 15
      expect(nov16Sec, 3600); // 4 AM -> 5 AM counts toward Nov 16
    });

    test('clips range totals cleanly without leaking out-of-range duration', () {
      final work = _makeAct('work', 'Study', 'productive', 1.0);
      final entry = _makeEntry(
        'e4',
        work,
        DateTime(2026, 11, 15, 22, 0),
        DateTime(2026, 11, 16, 2, 0),
      );

      final slices = TimeSlicer.sliceEntry(
        entry,
        rangeStart: DateTime(2026, 11, 16, 0, 0),
        rangeEnd: DateTime(2026, 11, 16, 23, 59, 59, 999),
      ).toList();

      final totalSec = slices.fold(0, (a, b) => a + b.seconds);
      final totalScore = slices.fold(0.0, (a, b) => a + b.score);
      expect(totalSec, 7200); // Only 2h on Nov 16
      expect(totalScore, closeTo(2.0, 0.001));
    });
  });

  group('Smart Engine Tests', () {
    test('SuggestionEngine ranks context-appropriate activity highest', () {
      final study = _makeAct('study', 'Study', 'productive', 1.0, sort: 0);
      final tv = _makeAct('tv', 'YouTube', 'rest', -2.0, sort: 1);
      final sleep = _makeAct('sleep', 'Sleep', 'neutral', 0.0, sort: 2);
      final acts = [study, tv, sleep];

      final history = <TimeEntryWithActivity>[];
      for (int d = 1; d <= 12; d++) {
        history.add(_makeEntry(
          's$d',
          study,
          DateTime(2026, 11, d, 8, 30),
          DateTime(2026, 11, d, 10, 30),
        ));
        history.add(_makeEntry(
          't$d',
          tv,
          DateTime(2026, 11, d, 20, 30),
          DateTime(2026, 11, d, 21, 30),
        ));
        history.add(_makeEntry(
          'sl$d',
          sleep,
          DateTime(2026, 11, d, 23, 0),
          DateTime(2026, 11, d + 1, 7, 30),
        ));
      }

      // Morning at 9:00 AM -> Study is top pick
      final morningRank = SuggestionEngine.rankActivities(
        activities: acts,
        historyEntries: history,
        now: DateTime(2026, 11, 14, 9, 0),
      );
      expect(morningRank.first.activity.id, 'study');
      expect(morningRank.first.reason, isNotNull);

      // Evening at 9:00 PM -> TV is top pick
      final eveningRank = SuggestionEngine.rankActivities(
        activities: acts,
        historyEntries: history,
        now: DateTime(2026, 11, 14, 21, 0),
      );
      expect(eveningRank.first.activity.id, 'tv');
    });

    test('ActivityAutofill matches English & Persian keywords, duplicate names, and distinct colors', () {
      final study = ActivityAutofill.suggestForName('Deep Coding');
      expect(study, isNotNull);
      expect(study!.category, 'productive');
      expect(study.primaryIcon, Icons.code);

      // Persian/Farsi keywords
      final persianStudy = ActivityAutofill.suggestForName('مطالعه درس ریاضی');
      expect(persianStudy, isNotNull);
      expect(persianStudy!.category, 'productive');
      expect(persianStudy.primaryIcon, Icons.menu_book);

      final persianSleep = ActivityAutofill.suggestForName('خواب شب');
      expect(persianSleep, isNotNull);
      expect(persianSleep!.category, 'neutral');
      expect(persianSleep.primaryIcon, Icons.bedtime);

      // Icon search in Persian + English
      expect(ActivityAutofill.searchIcons('زباله'), contains(Icons.delete));

      // Duplicate typo detection
      final existing = [
        _makeAct('1', 'Deep Work', 'productive', 1.5, color: 0xFF10B981),
        _makeAct('2', 'Gaming', 'rest', -2.0, color: 0xFFF43F5E),
      ];
      final dup = ActivityAutofill.suggestForName(
        'Deep Wrok',
        existingActivities: existing,
      );
      expect(dup?.duplicateMatch?.id, '1');

      // Auto color maximizes hue separation
      final pickedColor = Color(
        ActivityAutofill.pickDistinctColor(
          category: 'productive',
          existingActivities: existing,
        ),
      );
      final pickedHue = HSLColor.fromColor(pickedColor).hue;
      for (final act in existing) {
        final existingHue = HSLColor.fromColor(Color(act.colorHex)).hue;
        var diff = (pickedHue - existingHue).abs();
        if (diff > 180) diff = 360 - diff;
        expect(diff, greaterThanOrEqualTo(25.0));
      }
    });

    test('GapDetector detects between-session gaps, sleep catch-up, and forgotten timers', () {
      final work = _makeAct('work', 'Study', 'productive', 1.0);
      final sleep = _makeAct('sleep', 'Sleep / Meals', 'neutral', 0.0);

      final e1 = _makeEntry(
        '1',
        work,
        DateTime(2026, 11, 17, 9, 0),
        DateTime(2026, 11, 17, 10, 0),
      );
      final e2 = _makeEntry(
        '2',
        work,
        DateTime(2026, 11, 17, 10, 45),
        DateTime(2026, 11, 17, 12, 0),
      );

      final gaps = GapDetector.findGaps(
        entries: [e1, e2],
        rangeStart: DateTime(2026, 11, 17, 0, 0),
        rangeEnd: DateTime(2026, 11, 17, 23, 59, 59, 999),
        now: DateTime(2026, 11, 17, 12, 5),
        minGapMinutes: 15,
      );
      expect(gaps.length, 1);
      expect(gaps.first.durationSeconds, 45 * 60);

      // Morning sleep catch-up
      final catchup = GapDetector.detectMorningSleepCatchup(
        activities: [work, sleep],
        recentEntries: [e1],
        now: DateTime(2026, 11, 17, 9, 15),
        rolloverHour: 0,
      );
      expect(catchup, isNotNull);
      expect(catchup!.sleepActivity.id, 'sleep');

      // Forgotten timer
      expect(
        GapDetector.shouldWarnForgottenTimer(
          elapsedSeconds: 5 * 3600,
          preselectedActivityId: 'work',
          historyEntries: [e1, e2],
        ),
        isTrue,
      );
    });

    test('InsightsEngine generates focus delta, peak window, and streak cards', () {
      final work = _makeAct('work', 'Deep Work', 'productive', 1.5);
      final prev = TimeSlicer.sliceEntries([
        _makeEntry('p1', work, DateTime(2026, 11, 8, 9, 0), DateTime(2026, 11, 8, 11, 0)),
      ]);
      final cur = TimeSlicer.sliceEntries([
        _makeEntry('c1', work, DateTime(2026, 11, 15, 9, 0), DateTime(2026, 11, 15, 13, 0)),
      ]);

      final cards = InsightsEngine.generate(
        currentSlices: cur,
        previousSlices: prev,
        dailyTargetGoal: 1.0,
        currentGoalStreak: 4,
      );
      expect(cards.any((c) => c.id == 'streak'), isTrue);
      expect(cards.any((c) => c.id == 'focus_delta'), isTrue);
      expect(cards.any((c) => c.id == 'peak_window'), isTrue);
    });
  });

  group('Responsive Layout & Theme Tests', () {
    testWidgets('EquinoxApp renders in Dark & Light themes cleanly at 360x640 and 800x360',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1. Portrait 360x640 with 1.3x text scale (Light Theme)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
              theme: AppTheme.buildLightTheme(),
              home: const MainNavigationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Landscape 800x360 (Dark Theme) across tabs
      tester.view.physicalSize = const Size(800, 360);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const EquinoxApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await db.close();
    });
  });
}
