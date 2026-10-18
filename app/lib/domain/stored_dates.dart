import 'calendar_days.dart';

/// Historical days retain the local calendar/time captured when recorded.
String localTimestamp(DateTime instant) => instant.toLocal().toIso8601String();

bool isStoredDateColumn(String name) =>
    name.endsWith('_at') ||
    name == 'date' ||
    name == 'log_date' ||
    name == 'scheduled_for' ||
    name == 'snoozed_until' ||
    name == 'bed_time' ||
    name == 'wake_time';

String normalizeStoredDate(String table, String column, String text) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|([+-])(\d{2}):(\d{2}))?)?$',
  ).firstMatch(text);
  final parsed = DateTime.tryParse(text);
  if (match == null || parsed == null) throw const FormatException('Invalid timestamp.');
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year ||
      date.month != month ||
      date.day != day ||
      int.parse(match[4] ?? '0') > 23 ||
      int.parse(match[5] ?? '0') > 59 ||
      int.parse(match[6] ?? '0') > 59 ||
      int.parse(match[8] ?? '0') > 23 ||
      int.parse(match[9] ?? '0') > 59) {
    throw const FormatException('Invalid timestamp.');
  }
  if (column == 'log_date' || (table == 'sleep_entry' && column == 'date')) {
    return calendarDateKey(date);
  }
  return localTimestamp(parsed);
}
