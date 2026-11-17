import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../data/repositories/time_entry_repository.dart';
import '../../../smart/gap_detector.dart';

/// Interactive 24-hour horizontal strip showing activity-colored intervals,
/// hatched untracked gaps, and a "now" marker.
class DayRibbon extends StatelessWidget {
  final DateTime dayStart;
  final DateTime dayEnd;
  final List<TimeEntryWithActivity> entries;
  final List<TimeGap> gaps;
  final DateTime? now;
  final ValueChanged<TimeEntryWithActivity>? onTapEntry;
  final ValueChanged<TimeGap>? onTapGap;

  const DayRibbon({
    super.key,
    required this.dayStart,
    required this.dayEnd,
    required this.entries,
    required this.gaps,
    this.now,
    this.onTapEntry,
    this.onTapGap,
  });

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    final startMs = dayStart.millisecondsSinceEpoch;
    final endMs = dayEnd.millisecond == 999
        ? dayEnd.millisecondsSinceEpoch + 1
        : dayEnd.millisecondsSinceEpoch;
    final totalMs = math.max(1, endMs - startMs);

    final startHour = dayStart.hour;
    final hourLabels = List<int>.generate(5, (i) => (startHour + i * 6) % 24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (width <= 0) return;
                final frac = (details.localPosition.dx / width).clamp(0.0, 1.0);
                final tapMs = startMs + (frac * totalMs).round();

                for (final item in entries) {
                  if (tapMs >= item.entry.startTime && tapMs <= item.entry.endTime) {
                    onTapEntry?.call(item);
                    return;
                  }
                }
                for (final gap in gaps) {
                  if (tapMs >= gap.start.millisecondsSinceEpoch &&
                      tapMs <= gap.end.millisecondsSinceEpoch) {
                    onTapGap?.call(gap);
                    return;
                  }
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _DayRibbonPainter(
                      startMs: startMs,
                      endMs: endMs,
                      entries: entries,
                      gaps: gaps,
                      nowMs: now?.millisecondsSinceEpoch,
                      trackColor: eq.surface2,
                      hatchColor: eq.textMuted.withValues(alpha: 0.22),
                      nowColor: eq.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: hourLabels.asMap().entries.map((e) {
            final label = e.key == 4 ? 'End' : _formatTickHour(e.value);
            return Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: eq.textMuted,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatTickHour(int h) {
    if (h == 0) return '12a';
    if (h < 12) return '${h}a';
    if (h == 12) return '12p';
    return '${h - 12}p';
  }
}

class _DayRibbonPainter extends CustomPainter {
  final int startMs;
  final int endMs;
  final List<TimeEntryWithActivity> entries;
  final List<TimeGap> gaps;
  final int? nowMs;
  final Color trackColor;
  final Color hatchColor;
  final Color nowColor;

  _DayRibbonPainter({
    required this.startMs,
    required this.endMs,
    required this.entries,
    required this.gaps,
    required this.nowMs,
    required this.trackColor,
    required this.hatchColor,
    required this.nowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = trackColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final spanMs = math.max(1, endMs - startMs);

    // Draw hatched gaps first
    final hatchPaint = Paint()
      ..color = hatchColor
      ..strokeWidth = 1.2;
    for (final gap in gaps) {
      final s = math.max(startMs, gap.start.millisecondsSinceEpoch);
      final e = math.min(endMs, gap.end.millisecondsSinceEpoch);
      if (e <= s) continue;
      final left = ((s - startMs) / spanMs) * size.width;
      final right = ((e - startMs) / spanMs) * size.width;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(left, 0, right, size.height));
      for (double x = left - size.height; x < right + size.height; x += 6) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          hatchPaint,
        );
      }
      canvas.restore();
    }

    // Draw logged segments
    for (final item in entries) {
      final s = math.max(startMs, item.entry.startTime);
      final e = math.min(endMs, item.entry.endTime);
      if (e <= s) continue;
      final left = ((s - startMs) / spanMs) * size.width;
      final width = math.max(2.0, ((e - s) / spanMs) * size.width);
      final rect = Rect.fromLTWH(left, 2, width, size.height - 4);
      final paint = Paint()..color = Color(item.activity.colorHex);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
    }

    // Draw "now" needle
    if (nowMs != null && nowMs! >= startMs && nowMs! <= endMs) {
      final x = ((nowMs! - startMs) / spanMs) * size.width;
      final linePaint = Paint()
        ..color = nowColor
        ..strokeWidth = 1.8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DayRibbonPainter old) {
    return old.entries != entries ||
        old.gaps != gaps ||
        old.nowMs != nowMs ||
        old.startMs != startMs ||
        old.endMs != endMs ||
        old.trackColor != trackColor;
  }
}
