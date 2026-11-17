import 'package:flutter/material.dart';
import '../utils/duration_formatter.dart';

/// Displays formatted durations without unwanted mid-phrase wrapping
/// (e.g. preventing "1h\n46m").
class DurationText extends StatelessWidget {
  final int seconds;
  final bool decimalHours;
  final TextStyle? style;

  const DurationText(
    this.seconds, {
    super.key,
    this.decimalHours = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final text = decimalHours
        ? DurationFormatter.formatDecimalHours(seconds)
        : DurationFormatter.formatHumanReadable(seconds);
    return Text(
      text,
      softWrap: false,
      maxLines: 1,
      style: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
