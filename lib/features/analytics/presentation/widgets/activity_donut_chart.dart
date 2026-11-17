import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/ui/activity_avatar.dart';
import '../../../../core/ui/duration_text.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/eq_card.dart';
import '../../../../core/ui/score_pill.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../data/database/app_database.dart';
import '../../providers/analytics_provider.dart';

/// "Where time went": category 100% stacked bar + ranked activity list with
/// mini bars and sparklines + toggleable donut summary.
class ActivityDonutChart extends StatefulWidget {
  final List<ActivityDonutItem> items;
  final int totalDurationSeconds;
  final int productiveSeconds;
  final int restSeconds;
  final int neutralSeconds;
  final ValueChanged<Activity>? onTapActivity;

  const ActivityDonutChart({
    super.key,
    required this.items,
    required this.totalDurationSeconds,
    this.productiveSeconds = 0,
    this.restSeconds = 0,
    this.neutralSeconds = 0,
    this.onTapActivity,
  });

  @override
  State<ActivityDonutChart> createState() => _ActivityDonutChartState();
}

class _ActivityDonutChartState extends State<ActivityDonutChart> {
  bool _showDonut = false;
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final eq = context.eq;
    if (widget.items.isEmpty || widget.totalDurationSeconds == 0) {
      return const EmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No activity data in this range',
        body: 'Log sessions in this period to see where your hours went.',
      );
    }

    final total = widget.totalDurationSeconds;
    final pSec = widget.productiveSeconds;
    final rSec = widget.restSeconds;
    final nSec = math.max(0, total - pSec - rSec);

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
                      'Where time went',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${DurationFormatter.formatDecimalHours(total)} tracked · Tap an activity for details',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _showDonut ? 'Show ranked bars' : 'Show donut',
                icon: Icon(
                  _showDonut ? Icons.view_list_rounded : Icons.donut_large_rounded,
                  color: eq.accent,
                  size: 20,
                ),
                onPressed: () => setState(() => _showDonut = !_showDonut),
              ),
            ],
          ),
          const SizedBox(height: Space.md),

          // Category 100% stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (pSec > 0)
                    Expanded(flex: pSec, child: Container(color: eq.gain)),
                  if (nSec > 0)
                    Expanded(flex: nSec, child: Container(color: eq.neutral)),
                  if (rSec > 0)
                    Expanded(flex: rSec, child: Container(color: eq.spend)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CatLabel(color: eq.gain, label: 'Work ${_pct(pSec, total)}'),
              _CatLabel(color: eq.neutral, label: 'Neutral ${_pct(nSec, total)}'),
              _CatLabel(color: eq.spend, label: 'Rest ${_pct(rSec, total)}'),
            ],
          ),
          const SizedBox(height: Space.lg),

          if (_showDonut)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: SizedBox(
                  width: 156,
                  height: 156,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, res) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    res == null ||
                                    res.touchedSection == null) {
                                  _touchedIndex = -1;
                                } else {
                                  _touchedIndex =
                                      res.touchedSection!.touchedSectionIndex;
                                }
                              });
                            },
                          ),
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 46,
                          sections: List.generate(widget.items.length, (i) {
                            final item = widget.items[i];
                            final touched = i == _touchedIndex;
                            return PieChartSectionData(
                              value: item.durationSeconds.toDouble(),
                              color: Color(item.activity.colorHex),
                              radius: touched ? 32 : 26,
                              showTitle: false,
                            );
                          }),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DurationFormatter.formatDecimalHours(total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(fontSize: 11, color: eq.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Ranked activity rows
          ...widget.items.take(8).map((item) {
            final act = item.activity;
            final actColor = Color(act.colorHex);
            final maxDur = math.max(1, widget.items.first.durationSeconds);
            final barFrac = (item.durationSeconds / maxDur).clamp(0.04, 1.0);

            return InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: widget.onTapActivity != null
                  ? () => widget.onTapActivity!(act)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ActivityAvatar(
                          iconCode: act.iconCode,
                          colorHex: act.colorHex,
                          size: 32,
                          iconSize: 16,
                          radius: 9,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              Row(
                                children: [
                                  DurationText(
                                    item.durationSeconds,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: eq.textMuted,
                                    ),
                                  ),
                                  Text(
                                    ' · ${item.durationPercentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: eq.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (item.recent14DaySeconds.isNotEmpty) ...[
                          SizedBox(
                            width: 46,
                            height: 18,
                            child: CustomPaint(
                              painter: _MicroSparklinePainter(
                                values: item.recent14DaySeconds,
                                color: actColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                        ],
                        ScorePill(
                          score: item.totalScore,
                          compact: true,
                          showUnit: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: barFrac,
                        minHeight: 4,
                        backgroundColor: eq.surface2,
                        valueColor: AlwaysStoppedAnimation<Color>(actColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _pct(int part, int total) {
    if (total <= 0) return '0%';
    return '${((part / total) * 100).round()}%';
  }
}

class _CatLabel extends StatelessWidget {
  final Color color;
  final String label;

  const _CatLabel({required this.color, required this.label});

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
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: eq.textSecondary)),
      ],
    );
  }
}

class _MicroSparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _MicroSparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = math.max(1, values.fold(0, math.max));
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / maxVal) * (size.height - 4) + 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MicroSparklinePainter old) =>
      old.values != values || old.color != color;
}
