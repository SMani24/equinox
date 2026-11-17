import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/eq_card.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../providers/analytics_provider.dart';

class StreaksCard extends StatelessWidget {
  final StreaksData streaks;
  final ValueChanged<DateTime>? onTapDay;

  const StreaksCard({
    super.key,
    required this.streaks,
    this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final bestDayText = streaks.bestDay != null
        ? '${ScoreCalculator.formatScore(streaks.bestDayScore, showUnit: false)} (${DateFormat('MMM d').format(streaks.bestDay!)})'
        : '—';
    final longestFocus = streaks.longestFocusSession;
    final longestText = longestFocus != null
        ? '${DurationFormatter.formatHumanReadable(longestFocus.entry.durationSeconds)} · ${longestFocus.activity.name}'
        : '—';

    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Streaks & records',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: _RecordTile(
                  icon: Icons.local_fire_department_rounded,
                  color: streaks.currentStreak > 0 ? eq.gain : eq.textMuted,
                  label: 'Current streak',
                  value: '${streaks.currentStreak}d',
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _RecordTile(
                  icon: Icons.emoji_events_rounded,
                  color: eq.spend,
                  label: 'Best streak',
                  value: '${streaks.longestStreak}d',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: _RecordTile(
                  icon: Icons.star_rounded,
                  color: eq.accent,
                  label: 'Best day',
                  value: bestDayText,
                  onTap: streaks.bestDay != null && onTapDay != null
                      ? () => onTapDay!(streaks.bestDay!)
                      : null,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _RecordTile(
                  icon: Icons.timer_rounded,
                  color: eq.gain,
                  label: 'Longest focus',
                  value: longestText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _RecordTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    return Material(
      color: eq.surface2,
      borderRadius: BorderRadius.circular(Radii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: eq.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: eq.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
