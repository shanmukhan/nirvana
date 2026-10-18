import 'desk_break_type.dart';

/// Accept only known categories and real clock times from external payloads.
(DeskBreakType, int, int)? parseDeskBreakSlot(
  String? typeName,
  String? hourText,
  String? minuteText,
) {
  final hour = int.tryParse(hourText ?? '');
  final minute = int.tryParse(minuteText ?? '');
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  for (final type in DeskBreakType.values) {
    if (type.name == typeName) return (type, hour, minute);
  }
  return null;
}

DateTime? parseActivityDate(String? text) {
  if (text == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return null;
  }
  final date = DateTime.tryParse(text);
  if (date == null || date.toIso8601String().substring(0, 10) != text) {
    return null;
  }
  return date;
}

String? notificationRoute(String? payload) {
  switch (payload) {
    case 'water':
      return '/water-log';
    case 'dhyana':
      return '/dhyana';
    case 'knee':
      return '/knee';
    case 'weight':
      return '/weight';
  }
  final parts = payload?.split(':');
  if (parts == null || (parts.length != 4 && parts.length != 5) || parts.first != 'deskbreak') {
    return null;
  }
  final slot = parseDeskBreakSlot(parts[1], parts[2], parts[3]);
  if (slot == null) return null;
  final (type, hour, minute) = slot;
  final date = parts.length == 5 ? parseActivityDate(parts[4]) : null;
  if (parts.length == 5 && date == null) return null;
  return '/desk-break-log/${type.name}/$hour/$minute'
      '${date == null ? '' : '?date=${parts[4]}'}';
}
