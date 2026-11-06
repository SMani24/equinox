import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/analytics_provider.dart';

class HourlyRhythmHeatmap extends StatelessWidget {
  final List<HourlyRhythmSlot> slots;

  const HourlyRhythmHeatmap({super.key, required this.slots});

  Color _getColorForSlot(HourlyRhythmSlot? slot) {
    if (slot == null) return AppColors.surfaceElevated;
    final prod = slot.productiveSeconds;
    final rest = slot.restSeconds;

    if (prod == 0 && rest == 0) {
      if (slot.neutralSeconds > 0) {
        return AppColors.neutral.withValues(alpha: 0.3);
      }
      return AppColors.surfaceElevated;
    }

    if (prod >= rest) {
      final hours = prod / 3600.0;
      if (hours >= 3.0) return AppColors.productive;
      if (hours >= 1.5) return AppColors.productive.withValues(alpha: 0.7);
      return AppColors.productive.withValues(alpha: 0.4);
    } else {
      final hours = rest / 3600.0;
      if (hours >= 2.0) return AppColors.rest;
      if (hours >= 1.0) return AppColors.rest.withValues(alpha: 0.7);
      return AppColors.rest.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Map of '$dow-$hour' -> slot
    final Map<String, HourlyRhythmSlot> slotMap = {
      for (final s in slots) '${s.dayOfWeek}-${s.hour}': s,
    };

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '24-Hour Rhythm (Time of Day)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.productive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Work', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.rest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Rest', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hour markings (00..23)
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 6),
                  child: Row(
                    children: List.generate(24, (h) {
                      return SizedBox(
                        width: 14,
                        child: Text(
                          h % 4 == 0 ? '$h' : '',
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ),
                ),

                // 7 Rows (Mon..Sun)
                ...List.generate(7, (dowIndex) {
                  final dow = dowIndex + 1; // 1 = Mon
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            days[dowIndex],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        ...List.generate(24, (hour) {
                          final slot = slotMap['$dow-$hour'];
                          final color = _getColorForSlot(slot);

                          return Container(
                            width: 12,
                            height: 14,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
