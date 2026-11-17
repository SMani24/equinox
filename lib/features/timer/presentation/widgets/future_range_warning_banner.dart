import 'package:flutter/material.dart';
import '../../../../core/theme/eq_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/time_range_resolver.dart';

/// Displays an amber warning banner when an entry's end time is in the future,
/// offering a one-tap action to shift the session back by one day when valid.
class FutureRangeWarningBanner extends StatelessWidget {
  final DateTime endDateTime;
  final TimeOfDay endTime;
  final VoidCallback? onShiftBackOneDay;

  const FutureRangeWarningBanner({
    super.key,
    required this.endDateTime,
    required this.endTime,
    this.onShiftBackOneDay,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!TimeRangeResolver.isInFuture(endDateTime, now)) {
      return const SizedBox.shrink();
    }

    final shiftedBackEnd = DateTime(
      endDateTime.year,
      endDateTime.month,
      endDateTime.day - 1,
      endDateTime.hour,
      endDateTime.minute,
      endDateTime.second,
    );
    final canShiftBack = !TimeRangeResolver.isInFuture(shiftedBackEnd, now);

    final eq = context.eq;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: eq.dangerSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: eq.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ends in the future (${DurationFormatter.formatDateLabel(endDateTime)}, ${endTime.format(context)})',
                style: TextStyle(
                  fontSize: 12,
                  color: eq.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (canShiftBack && onShiftBackOneDay != null)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: eq.danger,
                ),
                onPressed: onShiftBackOneDay,
                child: const Text(
                  'Shift -1d',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
