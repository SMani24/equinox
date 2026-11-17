import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/activity_avatar.dart';
import '../../../../core/ui/duration_text.dart';
import '../../../../core/ui/score_pill.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../data/repositories/time_entry_repository.dart';

/// Vertical timeline row with a clean left time gutter, tonal surface,
/// non-wrapping duration, swipe-left delete (for instant undo), and swipe-right restart.
class TimelineEntryTile extends StatelessWidget {
  final TimeEntryWithActivity item;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onRestart;
  final bool isFirst;
  final bool isLast;

  const TimelineEntryTile({
    super.key,
    required this.item,
    required this.onDelete,
    this.onEdit,
    this.onRestart,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final entry = item.entry;
    final activity = item.activity;

    final now = DateTime.now();
    final startDt = DateTime.fromMillisecondsSinceEpoch(entry.startTime);
    final endDt = DateTime.fromMillisecondsSinceEpoch(entry.endTime);
    final timeRange =
        DurationFormatter.formatTimelineTimeRange(startDt, endDt, now);
    final isFuture = endDt.isAfter(now.add(const Duration(minutes: 1)));
    final gutterTime = DateFormat('h:mm a').format(startDt);

    return Dismissible(
      key: Key(entry.id),
      direction: onRestart != null
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 3),
        decoration: BoxDecoration(
          color: eq.accentSoft,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: eq.accent, size: 20),
            const SizedBox(width: 6),
            Text(
              'Start again',
              style: TextStyle(
                color: eq.accent,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 3),
        decoration: BoxDecoration(
          color: eq.dangerSoft,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Icon(Icons.delete_outline_rounded, color: eq.danger),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onRestart?.call();
          return false; // Keep entry in place; just trigger restart
        }
        return true; // Swipe left removes row immediately; parent shows Undo snackbar
      },
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 3),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left vertical time gutter & connector node
              SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(activity.colorHex),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            gutterTime,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: eq.textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Material(
                  color: eq.surface1,
                  borderRadius: BorderRadius.circular(Radii.md),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.md,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          ActivityAvatar(
                            iconCode: activity.iconCode,
                            colorHex: activity.colorHex,
                            size: 38,
                            iconSize: 18,
                            radius: 10,
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        activity.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      ScoreCalculator.formatCoefficient(
                                          entry.coefficientSnapshot),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: eq.forCoefficient(
                                            entry.coefficientSnapshot),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      timeRange,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: eq.textMuted,
                                      ),
                                    ),
                                    if (isFuture)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: eq.dangerSoft,
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          'Future',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: eq.danger,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (entry.note != null &&
                                    entry.note!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    entry.note!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      color: eq.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ScorePill(
                                score: entry.scoreSnapshot,
                                compact: true,
                                showUnit: false,
                              ),
                              const SizedBox(height: 3),
                              DurationText(
                                entry.durationSeconds,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: eq.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
