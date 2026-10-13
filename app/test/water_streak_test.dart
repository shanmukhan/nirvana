import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/water_repository.dart';
import 'package:nirvana/domain/calendar_days.dart';

import 'test_database.dart';

void main() {
  test('streak crosses multiple query windows and allows today in progress', () async {
    final db = await openTestDatabase();
    final repo = WaterRepository(db);
    final today = DateTime(2026, 10, 12);
    for (var day = 1; day <= 70; day++) {
      await repo.log(2250, loggedAt: calendarDayOffset(today, -day));
    }
    expect(await repo.currentStreakDays(goalMl: 2250, now: today), 70);
    await repo.log(2250, loggedAt: today);
    expect(await repo.currentStreakDays(goalMl: 2250, now: today), 71);
    expect(await repo.currentStreakDays(goalMl: 2500, now: today), 0);
    await db.close();
  });
}
