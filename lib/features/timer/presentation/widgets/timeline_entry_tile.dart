import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/score_calculator.dart';
import '../../../../data/repositories/time_entry_repository.dart';

class TimelineEntryTile extends StatelessWidget {
  final TimeEntryWithActivity item;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const TimelineEntryTile({
    super.key,
    required this.item,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final activity = item.activity;

    final now = DateTime.now();
    final startDt = DateTime.fromMillisecondsSinceEpoch(entry.startTime);
    final endDt = DateTime.fromMillisecondsSinceEpoch(entry.endTime);
    final timeRange = DurationFormatter.formatTimelineTimeRange(startDt, endDt, now);
    final isFuture = endDt.isAfter(now.add(const Duration(minutes: 1)));
    final durStr = DurationFormatter.formatHumanReadable(entry.durationSeconds);
    final scoreStr = ScoreCalculator.formatScore(entry.scoreSnapshot);
    final scoreColor = AppColors.forCoefficient(entry.coefficientSnapshot);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.rest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppColors.rest),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Entry?'),
                content: Text(
                  'Remove this ${activity.name} session ($durStr)?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.rest),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Colored activity icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(activity.colorHex).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      AppIcons.getIconData(activity.iconCode),
                      color: Color(activity.colorHex),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                activity.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ScoreCalculator.formatCoefficient(entry.coefficientSnapshot),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.forCoefficient(entry.coefficientSnapshot),
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
                              '$timeRange • $durStr',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (isFuture)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Text(
                                  'Future',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (entry.note != null && entry.note!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Score pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      scoreStr,
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
