class DateBoundary {
  /// Returns the normalized logical date for a given timestamp, considering the day rollover hour.
  /// For instance, if rolloverHour is 4 (4 AM), a session at 2:30 AM on Nov 7 belongs to Nov 6.
  static DateTime getLogicalDate(DateTime dt, {int rolloverHour = 0}) {
    if (rolloverHour > 0 && dt.hour < rolloverHour) {
      final shifted = dt.subtract(const Duration(days: 1));
      return DateTime(shifted.year, shifted.month, shifted.day);
    }
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Returns the start boundary (inclusive) of a logical date.
  static DateTime getDayStart(DateTime logicalDate, {int rolloverHour = 0}) {
    return DateTime(
      logicalDate.year,
      logicalDate.month,
      logicalDate.day,
      rolloverHour,
      0,
      0,
      0,
    );
  }

  /// Returns the end boundary (inclusive) of a logical date.
  static DateTime getDayEnd(DateTime logicalDate, {int rolloverHour = 0}) {
    final nextDay = getDayStart(logicalDate, rolloverHour: rolloverHour).add(
      const Duration(days: 1),
    );
    return nextDay.subtract(const Duration(milliseconds: 1));
  }

  /// Returns the start and end epoch milliseconds for today's logical boundary.
  static ({int startMs, int endMs}) getTodayEpochRange({int rolloverHour = 0}) {
    final now = DateTime.now();
    final logical = getLogicalDate(now, rolloverHour: rolloverHour);
    final start = getDayStart(logical, rolloverHour: rolloverHour);
    final end = getDayEnd(logical, rolloverHour: rolloverHour);
    return (
      startMs: start.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
    );
  }

  /// Returns the last N days as a list of logical DateTimes (sorted oldest to newest).
  static List<DateTime> getLastNDays(int n, {int rolloverHour = 0}) {
    final now = DateTime.now();
    final today = getLogicalDate(now, rolloverHour: rolloverHour);
    return List.generate(n, (i) {
      return today.subtract(Duration(days: n - 1 - i));
    });
  }
}
