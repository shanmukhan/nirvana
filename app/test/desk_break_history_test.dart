import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/desk_break_log_repository.dart';
import 'package:nirvana/services/desk_break_schedule_history.dart';
import 'package:nirvana/services/reminder_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('history excludes preactivation and disabled slots and includes unattended days', () async {
    final db = await openTestDatabase();
    final repo = DeskBreakLogRepository(db);
    final history = [
      DeskBreakScheduleRevision(DeskBreakType.eye, DateTime(2026, 10, 10, 10), [(9, 0), (11, 0)]),
      DeskBreakScheduleRevision(DeskBreakType.eye, DateTime(2026, 10, 12, 10), []),
    ];
    await repo.sweepScheduledOccurrences(history, now: DateTime(2026, 10, 12, 12));
    expect(await repo.forDay(DateTime(2026, 10, 9)), isEmpty);
    expect((await repo.forDay(DateTime(2026, 10, 10))).map((r) => r.slotHour), [11]);
    expect(await repo.forDay(DateTime(2026, 10, 11)), hasLength(2));
    final last = await repo.forDay(DateTime(2026, 10, 12));
    expect(last.single.slotHour, 9);
    expect(last.single.status, DeskBreakLogStatus.unanswered);
    await repo.sweepScheduledOccurrences(history, now: DateTime(2026, 10, 12, 12));
    expect(await repo.forDay(DateTime(2026, 10, 11)), hasLength(2));
    await db.close();
  });
  test('identical schedule does not erase activation history', () async {
    SharedPreferences.setMockInitialValues({});
    await DeskBreakScheduleHistory.record(DeskBreakType.eye, [(9, 0)], now: DateTime(2026, 10, 10));
    await DeskBreakScheduleHistory.record(DeskBreakType.eye, [(9, 0)], now: DateTime(2026, 10, 11));
    final history = await DeskBreakScheduleHistory.load();
    expect(history, hasLength(1));
    expect(history.single.effectiveAt, DateTime(2026, 10, 10));
  });
}
