/// Optional platform services must never prevent access to local health logs.
Future<List<String>> runStartupTasks(
  Map<String, Future<void> Function()> tasks, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final failures = <String>[];
  for (final task in tasks.entries) {
    try {
      await task.value().timeout(timeout);
    } catch (_) {
      failures.add(task.key);
    }
  }
  return failures;
}
