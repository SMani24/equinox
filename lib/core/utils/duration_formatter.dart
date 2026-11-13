import 'package:intl/intl.dart';

class DurationFormatter {
  /// Returns HH:MM:SS format (e.g., 01:23:45 or 00:04:12)
  static String formatHms(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    return '$hStr:$mStr:$sStr';
  }

  /// Returns human readable duration like "1h 14m" or "45m" or "30s"
  static String formatHumanReadable(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      if (minutes == 0) return '${hours}h';
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Returns decimal hours e.g. "3.5h"
  static String formatDecimalHours(int totalSeconds) {
    final hours = totalSeconds / 3600.0;
    return '${hours.toStringAsFixed(1)}h';
  }

  static int _calendarDaysDiff(DateTime from, DateTime to) {
    final utcFrom = DateTime.utc(from.year, from.month, from.day);
    final utcTo = DateTime.utc(to.year, to.month, to.day);
    return utcTo.difference(utcFrom).inDays;
  }

  /// Returns time range e.g. "09:30 AM – 10:45 AM" or "11:30 PM – 7:00 AM (+1d)"
  static String formatTimeRange(DateTime start, DateTime end) {
    final format = DateFormat('h:mm a');
    final daysDiff = _calendarDaysDiff(start, end);
    final daySuffix = daysDiff > 0 ? ' (+${daysDiff}d)' : '';
    return '${format.format(start)} – ${format.format(end)}$daySuffix';
  }

  /// Returns a timeline-aware time range string relative to [referenceDate] (e.g., today).
  /// Clarifies when an overnight session started on a previous day (e.g. "Yesterday 11:00 PM – 8:42 AM")
  /// or ends on a subsequent day ("11:00 PM – 8:42 AM (+1d)").
  static String formatTimelineTimeRange(
    DateTime start,
    DateTime end,
    DateTime referenceDate,
  ) {
    final format = DateFormat('h:mm a');
    final startDiff = _calendarDaysDiff(referenceDate, start);
    String startPrefix = '';
    if (startDiff == -1) {
      startPrefix = 'Yesterday ';
    } else if (startDiff < -1) {
      startPrefix = '${DateFormat('MMM d').format(start)} ';
    } else if (startDiff == 1) {
      startPrefix = 'Tomorrow ';
    } else if (startDiff > 1) {
      startPrefix = '${DateFormat('MMM d').format(start)} ';
    }

    final endDiffFromRef = _calendarDaysDiff(referenceDate, end);
    String endSuffix = '';
    if (endDiffFromRef > 0) {
      endSuffix = ' (+${endDiffFromRef}d)';
    }

    return '$startPrefix${format.format(start)} – ${format.format(end)}$endSuffix';
  }

  /// Returns date label e.g. "Today", "Yesterday", "Tomorrow", "Nov 6, 2026"
  static String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final diff = _calendarDaysDiff(date, now);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
