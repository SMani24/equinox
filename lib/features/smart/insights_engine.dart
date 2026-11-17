import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/utils/duration_formatter.dart';
import '../../core/utils/score_calculator.dart';
import '../../data/database/app_database.dart';
import '../analytics/domain/time_slicer.dart';

enum InsightTone { gain, spend, warning, neutral }

class InsightCardData {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final InsightTone tone;
  final int priority;

  const InsightCardData({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.tone,
    required this.priority,
  });
}

/// Generates prioritized plain-English insights from sliced analytics data.
class InsightsEngine {
  static List<InsightCardData> generate({
    required List<TimeSlice> currentSlices,
    required List<TimeSlice> previousSlices,
    required double dailyTargetGoal,
    required int currentGoalStreak,
    double? dailyRestBudget,
  }) {
    if (currentSlices.isEmpty) return const [];

    final List<InsightCardData> cards = [];

    // Aggregate current period
    int curWorkSec = 0;
    int curRestSec = 0;
    double curNet = 0.0;
    final Map<int, int> workSecByHour = {};
    final Map<String, ({Activity act, int sec, double score})> byActivity = {};
    final Map<DateTime, double> restCostByDay = {};

    for (final s in currentSlices) {
      curNet += s.score;
      if (s.activity.category == 'productive') {
        curWorkSec += s.seconds;
        workSecByHour[s.hour] = (workSecByHour[s.hour] ?? 0) + s.seconds;
      } else if (s.activity.category == 'rest') {
        curRestSec += s.seconds;
        restCostByDay[s.logicalDay] =
            (restCostByDay[s.logicalDay] ?? 0.0) + s.score.abs();
      }
      final prev = byActivity[s.activity.id];
      byActivity[s.activity.id] = (
        act: s.activity,
        sec: (prev?.sec ?? 0) + s.seconds,
        score: (prev?.score ?? 0.0) + s.score,
      );
    }

    // Aggregate previous period
    int prevWorkSec = 0;
    double prevNet = 0.0;
    for (final s in previousSlices) {
      prevNet += s.score;
      if (s.activity.category == 'productive') {
        prevWorkSec += s.seconds;
      }
    }

    // 1. Streak insight
    if (currentGoalStreak >= 2) {
      cards.add(
        InsightCardData(
          id: 'streak',
          title: '$currentGoalStreak-day goal streak',
          body:
              'You hit your ${ScoreCalculator.formatScore(dailyTargetGoal, showUnit: false)} daily equilibrium goal $currentGoalStreak days in a row.',
          icon: Icons.local_fire_department_rounded,
          tone: InsightTone.gain,
          priority: 95,
        ),
      );
    }

    // 2. Period-over-period focus shift
    if (previousSlices.isNotEmpty && prevWorkSec >= 1800) {
      final deltaWork = curWorkSec - prevWorkSec;
      final pct = ((deltaWork / prevWorkSec) * 100).round();
      if (pct.abs() >= 8) {
        final ahead = deltaWork > 0;
        final deltaStr = DurationFormatter.formatHumanReadable(deltaWork.abs());
        cards.add(
          InsightCardData(
            id: 'focus_delta',
            title: ahead ? 'Focus is up $pct%' : 'Focus dipped ${pct.abs()}%',
            body: ahead
                ? 'You logged $deltaStr more productive time than in the previous period (Net ${ScoreCalculator.formatScore(curNet)} vs ${ScoreCalculator.formatScore(prevNet)}).'
                : 'You logged $deltaStr less productive time than in the previous period.',
            icon: ahead ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            tone: ahead ? InsightTone.gain : InsightTone.warning,
            priority: 90,
          ),
        );
      }
    }

    // 3. Peak 2-hour focus window
    if (workSecByHour.isNotEmpty && curWorkSec >= 3600) {
      int bestStartHour = 9;
      int bestTwoHourSec = -1;
      for (int h = 0; h < 23; h++) {
        final pair = (workSecByHour[h] ?? 0) + (workSecByHour[h + 1] ?? 0);
        if (pair > bestTwoHourSec) {
          bestTwoHourSec = pair;
          bestStartHour = h;
        }
      }
      if (bestTwoHourSec > 0) {
        final sharePct = ((bestTwoHourSec / curWorkSec) * 100).round();
        cards.add(
          InsightCardData(
            id: 'peak_window',
            title:
                'Peak window: ${_formatHour(bestStartHour)} – ${_formatHour(bestStartHour + 2)}',
            body:
                '$sharePct% of your productive focus falls in this two-hour stretch.',
            icon: Icons.bolt_rounded,
            tone: InsightTone.gain,
            priority: 82,
          ),
        );
      }
    }

    // 4. Biggest rest drain vs budget or equivalent 1x work
    final restItems = byActivity.values
        .where((v) => v.act.category == 'rest' && v.score < -0.1)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    if (restItems.isNotEmpty) {
      final topDrain = restItems.first;
      final equivSec = (topDrain.score.abs() * 3600).round();
      cards.add(
        InsightCardData(
          id: 'top_rest',
          title:
              '${topDrain.act.name}: ${ScoreCalculator.formatScore(topDrain.score)}',
          body:
              '${DurationFormatter.formatHumanReadable(topDrain.sec)} logged — offsets ${DurationFormatter.formatHumanReadable(equivSec)} of 1.0x work.',
          icon: Icons.balance_rounded,
          tone: InsightTone.spend,
          priority: 75,
        ),
      );
    }

    // 5. Rest budget compliance (if configured)
    if (dailyRestBudget != null && dailyRestBudget > 0 && restCostByDay.isNotEmpty) {
      final overDays =
          restCostByDay.values.where((c) => c > dailyRestBudget + 0.01).length;
      cards.add(
        InsightCardData(
          id: 'rest_budget',
          title: overDays == 0
              ? 'Within daily rest budget'
              : 'Over rest budget on $overDays day${overDays == 1 ? '' : 's'}',
          body: overDays == 0
              ? 'Every day stayed within your -${dailyRestBudget.toStringAsFixed(1)} pts rest allowance.'
              : 'Rest cost exceeded your -${dailyRestBudget.toStringAsFixed(1)} pts daily limit.',
          icon: overDays == 0 ? Icons.verified_rounded : Icons.warning_amber_rounded,
          tone: overDays == 0 ? InsightTone.gain : InsightTone.warning,
          priority: overDays > 0 ? 88 : 68,
        ),
      );
    }

    // 6. Top productive driver
    final prodItems = byActivity.values
        .where((v) => v.act.category == 'productive' && v.score > 0.1)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (prodItems.isNotEmpty) {
      final topGain = prodItems.first;
      cards.add(
        InsightCardData(
          id: 'top_gain',
          title:
              'Top driver: ${topGain.act.name}',
          body:
              '${DurationFormatter.formatHumanReadable(topGain.sec)} contributed ${ScoreCalculator.formatScore(topGain.score)} (${curRestSec > 0 ? 'balancing ${DurationFormatter.formatHumanReadable(curRestSec)} rest' : 'pure gain'}).',
          icon: Icons.star_rounded,
          tone: InsightTone.gain,
          priority: 70,
        ),
      );
    }

    cards.sort((a, b) => b.priority.compareTo(a.priority));
    return cards.take(math.min(4, cards.length)).toList();
  }

  static String _formatHour(int h) {
    final normalized = h % 24;
    if (normalized == 0) return '12 AM';
    if (normalized < 12) return '$normalized AM';
    if (normalized == 12) return '12 PM';
    return '${normalized - 12} PM';
  }
}
