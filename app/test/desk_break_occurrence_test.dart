import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/app_shell/router.dart';
import 'package:nirvana/data/repositories/desk_break_log_repository.dart';
import 'package:nirvana/domain/navigation_input.dart';
import 'package:nirvana/services/reminder_prefs.dart';
import 'package:nirvana/main.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:nirvana/domain/calendar_days.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

void main() {
  testWidgets('undated notification requires a date and Yesterday saves to the prior day', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await openTestDatabase();
    appRouter.go('/desk-break-log/eye/9/0');
    await tester.pumpWidget(
      ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const NirvanaApp()),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Yes')).onPressed, isNull);
    await tester.tap(find.text('Yesterday'));
    await tester.pump();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(
      await DeskBreakLogRepository(db).forDay(calendarDayOffset(DateTime.now(), -1)),
      hasLength(1),
    );
    expect(await DeskBreakLogRepository(db).forDay(DateTime.now()), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  test('dated notification survives routing and an invalid occurrence is ignored', () {
    expect(
      notificationRoute('deskbreak:eye:9:0:2026-10-11'),
      '/desk-break-log/eye/9/0?date=2026-10-11',
    );
    expect(notificationRoute('deskbreak:eye:9:0:2026-02-30'), isNull);
  });
  test('late response updates only its occurrence and retains its identity', () async {
    final db = await openTestDatabase();
    final repo = DeskBreakLogRepository(db);
    final yesterday = DateTime(2026, 10, 11);
    final today = DateTime(2026, 10, 12);
    for (final day in [yesterday, today]) {
      await repo.recordResponse(
        type: DeskBreakType.eye,
        slotHour: 9,
        slotMinute: 0,
        status: DeskBreakLogStatus.skipped,
        logDate: day,
      );
    }
    final id = (await repo.forDay(yesterday)).single.id;
    await repo.recordResponse(
      type: DeskBreakType.eye,
      slotHour: 9,
      slotMinute: 0,
      status: DeskBreakLogStatus.done,
      logDate: yesterday,
    );
    expect((await repo.forDay(yesterday)).single.id, id);
    expect((await repo.forDay(yesterday)).single.status, DeskBreakLogStatus.done);
    expect((await repo.forDay(today)).single.status, DeskBreakLogStatus.skipped);
    await db.close();
  });
}
