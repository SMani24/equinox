import 'package:flutter/material.dart';

/// Shared helpers for resolving date boundaries and overnight spans across
/// timer classification, entry editing, and manual entry creation.
class TimeRangeResolver {
  static const Duration futureGraceWindow = Duration(minutes: 1);

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Exact calendar day difference (b - a) unaffected by DST transitions.
  static int calendarDaysBetween(DateTime a, DateTime b) {
    final utcA = DateTime.utc(a.year, a.month, a.day);
    final utcB = DateTime.utc(b.year, b.month, b.day);
    return utcB.difference(utcA).inDays;
  }

  static DateTime combineDateAndTime(
    DateTime date,
    TimeOfDay time, {
    int dayOffset = 0,
    int second = 0,
  }) {
    return DateTime(
      date.year,
      date.month,
      date.day + dayOffset,
      time.hour,
      time.minute,
      second,
    );
  }

  static bool isInFuture(DateTime dt, DateTime now) {
    return dt.isAfter(now.add(futureGraceWindow));
  }

  /// Resolves the start date and overnight flag when entering a manual session.
  /// When [userManuallyPickedDate] is false and an overnight span (`end <= start`)
  /// would extend into tomorrow while shifting back 1 day places its end on or
  /// before [now] (with grace window), anchors the session to yesterday -> today.
  static ({DateTime startDate, bool isNextDay}) resolveManualRange({
    required DateTime currentDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required bool currentIsNextDay,
    required bool userManuallyPickedDate,
    required bool userManuallyToggledNextDay,
    required DateTime now,
  }) {
    final startMins = startTime.hour * 60 + startTime.minute;
    final endMins = endTime.hour * 60 + endTime.minute;
    final spansMidnight = endMins <= startMins;

    final resolvedNextDay =
        userManuallyToggledNextDay ? currentIsNextDay : spansMidnight;
    DateTime resolvedDate = dateOnly(currentDate);

    if (!userManuallyPickedDate) {
      final today = dateOnly(now);
      if (spansMidnight && !userManuallyToggledNextDay) {
        final endOnTomorrow = combineDateAndTime(today, endTime, dayOffset: 1);
        final endOnToday = combineDateAndTime(today, endTime);
        if (isInFuture(endOnTomorrow, now) && !isInFuture(endOnToday, now)) {
          resolvedDate = DateTime(today.year, today.month, today.day - 1);
          return (startDate: resolvedDate, isNextDay: true);
        }
      }

      final startOnToday = combineDateAndTime(today, startTime);
      if (!spansMidnight && !isInFuture(startOnToday, now)) {
        resolvedDate = today;
      }
    }

    return (startDate: resolvedDate, isNextDay: resolvedNextDay);
  }

  /// Resolves start date and overnight flag when editing an existing entry's
  /// start or end time.
  ///
  /// When editing the start time (and the user has not manually pinned the start
  /// date or overnight toggle), preserves the entry's existing end calendar day
  /// so moving an early-morning entry's start backward past midnight (e.g. from
  /// 8:41 AM to 11:00 PM) anchors start to the previous night instead of pushing
  /// the end time forward into tomorrow.
  static ({DateTime startDate, bool isNextDay}) resolveEditedRange({
    required DateTime currentStartDate,
    required TimeOfDay currentStartTime,
    required TimeOfDay currentEndTime,
    required bool currentIsNextDay,
    required bool isEditingStart,
    required TimeOfDay pickedTime,
    required bool userManuallyPickedDate,
    required bool userManuallyToggledNextDay,
    required DateTime now,
  }) {
    final newStart = isEditingStart ? pickedTime : currentStartTime;
    final newEnd = isEditingStart ? currentEndTime : pickedTime;
    final startMins = newStart.hour * 60 + newStart.minute;
    final endMins = newEnd.hour * 60 + newEnd.minute;
    final spansMidnight = endMins <= startMins;

    if (userManuallyPickedDate || userManuallyToggledNextDay) {
      return (
        startDate: dateOnly(currentStartDate),
        isNextDay: userManuallyToggledNextDay ? currentIsNextDay : spansMidnight,
      );
    }

    final normalizedStartDate = dateOnly(currentStartDate);
    final anchoredEndDay = DateTime(
      normalizedStartDate.year,
      normalizedStartDate.month,
      normalizedStartDate.day + (currentIsNextDay ? 1 : 0),
    );
    final resolvedNextDay = spansMidnight;
    DateTime resolvedDate;

    if (isEditingStart) {
      resolvedDate = spansMidnight
          ? DateTime(
              anchoredEndDay.year,
              anchoredEndDay.month,
              anchoredEndDay.day - 1,
            )
          : anchoredEndDay;

      final resolvedEnd = combineDateAndTime(
        resolvedDate,
        newEnd,
        dayOffset: resolvedNextDay ? 1 : 0,
      );
      final prevDayEnd = combineDateAndTime(
        resolvedDate,
        newEnd,
        dayOffset: resolvedNextDay ? 0 : -1,
      );
      if (isInFuture(resolvedEnd, now) && !isInFuture(prevDayEnd, now)) {
        resolvedDate = DateTime(
          resolvedDate.year,
          resolvedDate.month,
          resolvedDate.day - 1,
        );
      }
    } else {
      resolvedDate = normalizedStartDate;
      final resolvedStart = combineDateAndTime(resolvedDate, newStart);
      final resolvedEnd = combineDateAndTime(
        resolvedDate,
        newEnd,
        dayOffset: resolvedNextDay ? 1 : 0,
      );
      final prevDayEnd = combineDateAndTime(
        resolvedDate,
        newEnd,
        dayOffset: resolvedNextDay ? 0 : -1,
      );
      if (isInFuture(resolvedEnd, now) &&
          (spansMidnight || isInFuture(resolvedStart, now)) &&
          !isInFuture(prevDayEnd, now)) {
        resolvedDate = DateTime(
          resolvedDate.year,
          resolvedDate.month,
          resolvedDate.day - 1,
        );
      }
    }

    return (startDate: resolvedDate, isNextDay: resolvedNextDay);
  }

  /// Resolves a newly picked start time when classifying a finished timer.
  /// Keeps [currentEnd] anchored and places [pickedStart] on the same calendar
  /// day if earlier than [currentEnd], or the previous calendar day otherwise.
  static DateTime resolveClassifiedStartTime({
    required DateTime currentEnd,
    required TimeOfDay pickedStart,
  }) {
    final onEndDay = combineDateAndTime(currentEnd, pickedStart);
    if (onEndDay.isBefore(currentEnd)) {
      return onEndDay;
    }
    return combineDateAndTime(currentEnd, pickedStart, dayOffset: -1);
  }

  /// Resolves a newly picked end time when classifying a finished timer.
  /// Returns null if the resulting end time cannot be placed strictly after
  /// [currentStart] without entering the future relative to [now].
  static DateTime? resolveClassifiedEndTime({
    required DateTime currentStart,
    required TimeOfDay pickedEnd,
    required DateTime now,
  }) {
    final onStartDay = combineDateAndTime(currentStart, pickedEnd);
    if (onStartDay.isAfter(currentStart)) {
      return isInFuture(onStartDay, now) ? null : onStartDay;
    }
    final dayAfterStart = combineDateAndTime(
      currentStart,
      pickedEnd,
      dayOffset: 1,
    );
    if (dayAfterStart.isAfter(currentStart) && !isInFuture(dayAfterStart, now)) {
      return dayAfterStart;
    }
    return null;
  }
}
