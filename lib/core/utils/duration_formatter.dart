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

  /// Returns time range e.g. "09:30 AM – 10:45 AM" or "11:30 PM – 7:00 AM (+1d)"
  static String formatTimeRange(DateTime start, DateTime end) {
    final format = DateFormat('h:mm a');
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final daysDiff = endDate.difference(startDate).inDays;
    final daySuffix = daysDiff > 0 ? ' (+$daysDiff${daysDiff == 1 ? 'd' : 'd'})' : '';
    return '${format.format(start)} – ${format.format(end)}$daySuffix';
  }

  /// Returns date label e.g. "Today", "Yesterday", "Nov 6"
  static String formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }
}
