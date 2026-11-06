import 'package:equinox/core/utils/date_boundary.dart';
import 'package:equinox/core/utils/duration_formatter.dart';
import 'package:equinox/core/utils/score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoreCalculator Tests', () {
    test('1 hour of Deep Work (+1.5) produces +1.5 points', () {
      final score = ScoreCalculator.calculateScore(3600, 1.5);
      expect(score, closeTo(1.5, 0.0001));
      expect(ScoreCalculator.formatScore(score), '+1.50 pts');
    });

    test('30 minutes of Gaming (-2.0) produces -1.0 points', () {
      final score = ScoreCalculator.calculateScore(1800, -2.0);
      expect(score, closeTo(-1.0, 0.0001));
      expect(ScoreCalculator.formatScore(score), '-1.00 pts');
    });

    test('1h Deep Work (+1.0) and 30m Gaming (-2.0) yields 0.0 net balance', () {
      final workScore = ScoreCalculator.calculateScore(3600, 1.0); // +1.0
      final gameScore = ScoreCalculator.calculateScore(1800, -2.0); // -1.0
      final scores = [workScore, gameScore];

      expect(ScoreCalculator.calculateGrossProductive(scores), closeTo(1.0, 0.0001));
      expect(ScoreCalculator.calculateGrossRestCost(scores), closeTo(1.0, 0.0001));
      expect(ScoreCalculator.calculateNetBalance(scores), closeTo(0.0, 0.0001));
    });

    test('Neutral activity (0.0) yields 0.0 score', () {
      final score = ScoreCalculator.calculateScore(28800, 0.0); // 8 hours of sleep
      expect(score, 0.0);
      expect(ScoreCalculator.formatScore(score), '0.00 pts');
    });
  });

  group('DurationFormatter Tests', () {
    test('formatHms formats accurately', () {
      expect(DurationFormatter.formatHms(0), '00:00:00');
      expect(DurationFormatter.formatHms(45), '00:00:45');
      expect(DurationFormatter.formatHms(125), '00:02:05');
      expect(DurationFormatter.formatHms(3665), '01:01:05');
    });

    test('formatHumanReadable formats accurately', () {
      expect(DurationFormatter.formatHumanReadable(45), '45s');
      expect(DurationFormatter.formatHumanReadable(1800), '30m');
      expect(DurationFormatter.formatHumanReadable(3600), '1h');
      expect(DurationFormatter.formatHumanReadable(4500), '1h 15m');
    });
  });

  group('DateBoundary Tests', () {
    test('Logical date without rollover', () {
      final dt = DateTime(2026, 11, 6, 2, 30);
      final logical = DateBoundary.getLogicalDate(dt, rolloverHour: 0);
      expect(logical, DateTime(2026, 11, 6));
    });

    test('Logical date with 4 AM rollover before 4 AM shifts to previous day', () {
      final dt = DateTime(2026, 11, 7, 2, 30);
      final logical = DateBoundary.getLogicalDate(dt, rolloverHour: 4);
      expect(logical, DateTime(2026, 11, 6));
    });

    test('Logical date with 4 AM rollover after 4 AM stays on current day', () {
      final dt = DateTime(2026, 11, 7, 4, 30);
      final logical = DateBoundary.getLogicalDate(dt, rolloverHour: 4);
      expect(logical, DateTime(2026, 11, 7));
    });

    test('Day start and end boundary covers 24 hours', () {
      final logical = DateTime(2026, 11, 6);
      final start = DateBoundary.getDayStart(logical, rolloverHour: 4);
      final end = DateBoundary.getDayEnd(logical, rolloverHour: 4);

      expect(start, DateTime(2026, 11, 6, 4, 0, 0, 0));
      expect(end.difference(start).inSeconds, 86399);
    });
  });
}
