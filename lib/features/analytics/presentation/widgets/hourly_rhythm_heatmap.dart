import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/eq_card.dart';
import '../../../../data/database/app_database.dart';
import '../../providers/analytics_provider.dart';

/// Pro-rated 7x24 circadian heatmap showing when focus vs. rest actually happens,
/// with optional per-activity filter and an auto-computed peak window takeaway.
class HourlyRhythmHeatmap extends StatelessWidget {
  final List<HourlyRhythmSlot> slots;
  final List<Activity> activities;
  final String? selectedActivityId;
  final ValueChanged<String?>? onActivityFilterChanged;

  const HourlyRhythmHeatmap({
    super.key,
    required this.slots,
    this.activities = const [],
    this.selectedActivityId,
    this.onActivityFilterChanged,
  });

  Color _getColorForSlot(BuildContext context, HourlyRhythmSlot? slot) {
    final eq = context.eq;
    if (slot == null) return eq.surface2;
    final prod = slot.productiveSeconds;
    final rest = slot.restSeconds;

    if (prod == 0 && rest == 0) {
      if (slot.neutralSeconds > 0) {
        return eq.neutral.withValues(alpha: 0.35);
      }
      return eq.surface2;
    }

    if (prod >= rest) {
      final mins = prod / 60.0;
      if (mins >= 180) return eq.gain;
      if (mins >= 90) return eq.gain.withValues(alpha: 0.72);
      return eq.gain.withValues(alpha: 0.40);
    } else {
      final mins = rest / 60.0;
      if (mins >= 120) return eq.spend;
      if (mins >= 60) return eq.spend.withValues(alpha: 0.72);
      return eq.spend.withValues(alpha: 0.40);
    }
  }

  String _computePeakCaption() {
    final Map<int, int> workByHour = {};
    int totalWork = 0;
    for (final s in slots) {
      if (s.productiveSeconds > 0) {
        workByHour[s.hour] = (workByHour[s.hour] ?? 0) + s.productiveSeconds;
        totalWork += s.productiveSeconds;
      }
    }
    if (totalWork < 600) {
      return 'Hourly concentration across weekdays and weekends';
    }
    int bestH = 9;
    int bestPair = -1;
    for (int h = 0; h < 23; h++) {
      final pair = (workByHour[h] ?? 0) + (workByHour[h + 1] ?? 0);
      if (pair > bestPair) {
        bestPair = pair;
        bestH = h;
      }
    }
    String fmt(int hr) {
      final n = hr % 24;
      if (n == 0) return '12 AM';
      if (n < 12) return '$n AM';
      if (n == 12) return '12 PM';
      return '${n - 12} PM';
    }

    return 'Peak focus window: ${fmt(bestH)} – ${fmt(bestH + 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final Map<String, HourlyRhythmSlot> slotMap = {
      for (final s in slots) '${s.dayOfWeek}-${s.hour}': s,
    };

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24-Hour Rhythm',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _computePeakCaption(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onActivityFilterChanged != null && activities.isNotEmpty)
                DropdownButton<String?>(
                  value: selectedActivityId,
                  dropdownColor: eq.surface2,
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: eq.accent,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All activities'),
                    ),
                    ...activities.where((a) => !a.isArchived).map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(a.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                  ],
                  onChanged: onActivityFilterChanged,
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 36, bottom: 6),
                  child: Row(
                    children: List.generate(24, (h) {
                      return SizedBox(
                        width: 14,
                        child: Text(
                          h % 4 == 0 ? '$h' : '',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: eq.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ),
                ),
                ...List.generate(7, (dowIndex) {
                  final dow = dowIndex + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            days[dowIndex],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: eq.textSecondary,
                            ),
                          ),
                        ),
                        ...List.generate(24, (hour) {
                          final slot = slotMap['$dow-$hour'];
                          final color = _getColorForSlot(context, slot);
                          return Container(
                            width: 12,
                            height: 14,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2.5),
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
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _LegendDot(color: eq.gain, label: 'Work'),
              const SizedBox(width: 10),
              _LegendDot(color: eq.spend, label: 'Rest'),
              const SizedBox(width: 10),
              _LegendDot(color: eq.neutral.withValues(alpha: 0.45), label: 'Neutral'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: eq.textMuted)),
      ],
    );
  }
}
