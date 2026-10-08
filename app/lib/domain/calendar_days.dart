DateTime startOfDay(DateTime day) => DateTime(day.year, day.month, day.day);

/// Calendar arithmetic keeps midnight boundaries correct across DST changes.
DateTime calendarDayOffset(DateTime day, int offset) =>
    DateTime(day.year, day.month, day.day + offset);

String calendarDateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
