class ReminderSlotPlan {
  final List<(int hour, int minute)> slots;
  final int eligibleCount;
  final String? issue;

  const ReminderSlotPlan._(this.slots, this.eligibleCount, this.issue);
  bool get truncated => eligibleCount > slots.length;
}

/// One shared plan for scheduled notifications, adherence, and UI coverage.
ReminderSlotPlan planReminderSlots({
  required int fromMinutes,
  required int toMinutes,
  required int intervalMinutes,
  int maxSlots = 16,
  bool Function(int)? isQuiet,
}) {
  if (fromMinutes < 0 ||
      fromMinutes > 1439 ||
      toMinutes < 0 ||
      toMinutes > 1439 ||
      intervalMinutes <= 0 ||
      intervalMinutes > 1440 ||
      maxSlots < 1 ||
      maxSlots > 64) {
    return const ReminderSlotPlan._([], 0, 'Choose valid reminder times and interval.');
  }
  if (toMinutes <= fromMinutes) {
    return const ReminderSlotPlan._([], 0, 'Active end must be later than the start.');
  }
  final slots = <(int, int)>[];
  var eligible = 0;
  for (var minute = fromMinutes; minute <= toMinutes; minute += intervalMinutes) {
    if (isQuiet?.call(minute) ?? false) continue;
    eligible++;
    if (slots.length < maxSlots) slots.add((minute ~/ 60, minute % 60));
  }
  return ReminderSlotPlan._(List.unmodifiable(slots), eligible, null);
}
