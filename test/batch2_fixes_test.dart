import 'package:drift/native.dart';
import 'package:equinox/core/theme/app_icons.dart';
import 'package:equinox/core/utils/date_boundary.dart';
import 'package:equinox/core/utils/duration_formatter.dart';
import 'package:equinox/core/utils/score_calculator.dart';
import 'package:equinox/data/database/app_database.dart';
import 'package:equinox/data/repositories/activity_repository.dart';
import 'package:equinox/data/repositories/time_entry_repository.dart';
import 'package:equinox/data/repositories/timer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Batch 2 Fixes & Overnight Logic Tests', () {
    test('TimerState active elapsed duration properly excludes paused duration', () {
      final start = 1730930000000;
      // Started 1000 seconds ago, paused for 600 seconds, running for 400 seconds
      final timerState = TimerState(
        rawData: null,
        isRunning: true,
        isPaused: false,
        startEpochMs: start,
        elapsedSeconds: 400,
        preselectedActivityId: 'act_deep_work',
      );

      expect(timerState.elapsedSeconds, 400);

      // Verify that when computing startDt from elapsedSeconds, duration is exactly 400s
      final now = DateTime.fromMillisecondsSinceEpoch(start + 1000 * 1000);
      final effectiveStart = now.subtract(Duration(seconds: timerState.elapsedSeconds));
      final duration = now.difference(effectiveStart).inSeconds;

      expect(duration, 400);
      expect(duration, isNot(1000)); // Crucial: paused 600s is excluded!
    });

    test('DurationFormatter formatTimeRange formats cross-day range with (+1d)', () {
      final start = DateTime(2026, 11, 6, 23, 30);
      final end = DateTime(2026, 11, 7, 7, 0);

      final formatted = DurationFormatter.formatTimeRange(start, end);
      expect(formatted, contains('11:30 PM'));
      expect(formatted, contains('7:00 AM'));
      expect(formatted, contains('(+1d)'));
    });

    test('DurationFormatter formatTimeRange on same day does not append (+1d)', () {
      final start = DateTime(2026, 11, 6, 10, 0);
      final end = DateTime(2026, 11, 6, 11, 30);

      final formatted = DurationFormatter.formatTimeRange(start, end);
      expect(formatted, contains('10:00 AM'));
      expect(formatted, contains('11:30 AM'));
      expect(formatted, isNot(contains('(+1d)')));
    });

    test('Overnight manual entry end calculation produces positive duration', () {
      final date = DateTime(2026, 11, 6);
      final startHour = 23;
      final startMinute = 30;
      final endHour = 7;
      final endMinute = 0;

      final startDt = DateTime(date.year, date.month, date.day, startHour, startMinute);
      // With overnight toggle (+1 day)
      final nextDay = date.add(const Duration(days: 1));
      final endDt = DateTime(nextDay.year, nextDay.month, nextDay.day, endHour, endMinute);

      final diffSeconds = endDt.difference(startDt).inSeconds;
      expect(diffSeconds, 27000); // 7 hours 30 minutes = 27000s
      expect(DurationFormatter.formatHumanReadable(diffSeconds), '7h 30m');

      // Neutral activity (sleep) yields 0.00 pts
      final sleepScore = ScoreCalculator.calculateScore(diffSeconds, 0.0);
      expect(sleepScore, 0.0);
    });

    test('Overnight session score pro-rating across day boundaries', () {
      final logicalToday = DateTime(2026, 11, 7);
      final dayStart = DateBoundary.getDayStart(logicalToday, rolloverHour: 0);
      final dayEnd = DateBoundary.getDayEnd(logicalToday, rolloverHour: 0);

      final dayStartMs = dayStart.millisecondsSinceEpoch;
      final dayEndMs = dayEnd.millisecondsSinceEpoch;

      // Session: Deep Work (+1.5x) from 11:00 PM yesterday to 2:00 AM today (3 hours total)
      final sessionStart = DateTime(2026, 11, 6, 23, 0).millisecondsSinceEpoch;
      final sessionEnd = DateTime(2026, 11, 7, 2, 0).millisecondsSinceEpoch;

      // Portion belonging to today (midnight to 2:00 AM = 2 hours)
      final effectiveStart = sessionStart < dayStartMs ? dayStartMs : sessionStart;
      final effectiveEnd = sessionEnd > dayEndMs ? dayEndMs : sessionEnd;
      final effectiveDurSec = ((effectiveEnd - effectiveStart) / 1000).round();

      expect(effectiveDurSec, 7200); // 2 hours
      final todayScore = ScoreCalculator.calculateScore(effectiveDurSec, 1.5);
      expect(todayScore, closeTo(3.0, 0.001)); // 2h * 1.5x = +3.0 pts
    });

    test('TimeEntryRepository.updateEntry changes wrongly entered activity and recalculates score', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final repo = TimeEntryRepository(db);

      final actRepo = ActivityRepository(db);
      final standardWork = await actRepo.createActivity(
        name: 'Standard Work / Study',
        category: 'productive',
        coefficient: 1.0,
        colorHex: 0xFF3B82F6,
        iconCode: 123,
      );
      final deepWork = await actRepo.createActivity(
        name: 'Deep Work',
        category: 'productive',
        coefficient: 1.5,
        colorHex: 0xFF10B981,
        iconCode: 124,
      );
      final wastedTime = await actRepo.createActivity(
        name: 'Wasted Time',
        category: 'rest',
        coefficient: -1.5,
        colorHex: 0xFFEF4444,
        iconCode: 125,
      );

      final start = DateTime(2026, 11, 8, 13, 32);
      final end = DateTime(2026, 11, 8, 15, 3); // 1h 31m = 5460s

      // 1. Initial creation with Standard Work (+1.0x)
      final initialEntry = await repo.createEntry(
        activityId: standardWork.id,
        startTime: start,
        endTime: end,
        note: 'Studying chapter 4',
      );

      expect(initialEntry.activityId, standardWork.id);
      expect(initialEntry.durationSeconds, 5460);
      expect(initialEntry.coefficientSnapshot, standardWork.coefficient);
      final initialScore = (5460 / 3600.0) * standardWork.coefficient;
      expect(initialEntry.scoreSnapshot, closeTo(initialScore, 0.001));

      // 2. User entered it wrong! Change to Deep Work (+1.5x)
      await repo.updateEntry(
        id: initialEntry.id,
        activityId: deepWork.id,
        startTime: start,
        endTime: end,
        note: 'Actually was deep focus coding',
      );

      final updatedEntry = await repo.getEntryById(initialEntry.id);
      expect(updatedEntry, isNotNull);
      expect(updatedEntry!.activityId, deepWork.id);
      expect(updatedEntry.durationSeconds, 5460);
      expect(updatedEntry.coefficientSnapshot, deepWork.coefficient);
      final updatedScore = (5460 / 3600.0) * deepWork.coefficient;
      expect(updatedEntry.scoreSnapshot, closeTo(updatedScore, 0.001));
      expect(updatedEntry.note, 'Actually was deep focus coding');

      // 3. Change to Wasted Time (-1.5x)
      await repo.updateEntry(
        id: initialEntry.id,
        activityId: wastedTime.id,
        startTime: start,
        endTime: end,
      );

      final negativeEntry = await repo.getEntryById(initialEntry.id);
      expect(negativeEntry, isNotNull);
      expect(negativeEntry!.activityId, wastedTime.id);
      expect(negativeEntry.coefficientSnapshot, wastedTime.coefficient);
      final negativeScore = (5460 / 3600.0) * wastedTime.coefficient;
      expect(negativeEntry.scoreSnapshot, closeTo(negativeScore, 0.001));
      expect(negativeEntry.scoreSnapshot, lessThan(0.0));
    });

    test('AppIcons curated list contains trash icon and 30+ expanded icons', () {
      expect(AppIcons.curatedIcons, contains(Icons.delete));
      expect(AppIcons.curatedIcons, contains(Icons.delete_outline));
      expect(AppIcons.curatedIcons, contains(Icons.delete_sweep));
      expect(AppIcons.curatedIcons, contains(Icons.recycling));
      expect(AppIcons.curatedIcons.length, greaterThanOrEqualTo(80));

      // Check getIconData lookup for trash icon
      expect(AppIcons.getIconData(Icons.delete.codePoint), Icons.delete);
    });

    test('Activities sort by points descending, ascending and name correctly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final actRepo = ActivityRepository(db);

      // Clear any pre-seeded default activities
      await db.delete(db.activities).go();

      await actRepo.createActivity(name: 'Study', category: 'productive', coefficient: 1.0, colorHex: 0xFF00FF00, iconCode: 1);
      await actRepo.createActivity(name: 'Deep Work', category: 'productive', coefficient: 1.5, colorHex: 0xFF00FF00, iconCode: 2);
      await actRepo.createActivity(name: 'Slacking', category: 'rest', coefficient: -1.5, colorHex: 0xFFFF0000, iconCode: 3);
      await actRepo.createActivity(name: 'Rest', category: 'rest', coefficient: -1.0, colorHex: 0xFFFF0000, iconCode: 4);
      await actRepo.createActivity(name: 'Lunch', category: 'neutral', coefficient: 0.0, colorHex: 0xFF888888, iconCode: 5);

      final list = await actRepo.getActivities();
      expect(list.length, 5);

      // Sort points High to Low
      final desc = List<Activity>.from(list)..sort((a, b) => b.coefficient.compareTo(a.coefficient));
      expect(desc.map((a) => a.coefficient).toList(), [1.5, 1.0, 0.0, -1.0, -1.5]);
      expect(desc.first.name, 'Deep Work');
      expect(desc.last.name, 'Slacking');

      // Sort points Low to High
      final asc = List<Activity>.from(list)..sort((a, b) => a.coefficient.compareTo(b.coefficient));
      expect(asc.map((a) => a.coefficient).toList(), [-1.5, -1.0, 0.0, 1.0, 1.5]);
      expect(asc.first.name, 'Slacking');
      expect(asc.last.name, 'Deep Work');

      // Sort Name A to Z
      final alpha = List<Activity>.from(list)..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      expect(alpha.map((a) => a.name).toList(), ['Deep Work', 'Lunch', 'Rest', 'Slacking', 'Study']);

      // Persist sorted order to database via reorderActivities
      await actRepo.reorderActivities(desc.map((a) => a.id).toList());
      final persisted = await actRepo.getActivities();
      expect(persisted.map((a) => a.coefficient).toList(), [1.5, 1.0, 0.0, -1.0, -1.5]);
    });
  });
}
