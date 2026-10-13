import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/water_repository.dart';
import 'package:nirvana/providers/calendar_providers.dart';
import 'package:nirvana/providers/dhyana_providers.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:nirvana/providers/water_providers.dart';

import 'test_database.dart';

void main() {
  test('day change refreshes cached totals and preserves an explicit meditation date', () async {
    final db = await openTestDatabase();
    final first = DateTime(2026, 10, 11);
    final second = DateTime(2026, 10, 12);
    await WaterRepository(db).log(250, loggedAt: first);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentDayProvider.overrideWith((ref) => first),
      ],
    );
    final listener = container.listen(waterTodayTotalProvider, (_, _) {});
    expect(await container.read(waterTodayTotalProvider.future), 250);
    expect(container.read(dhyanaEffectiveDateProvider), first);
    container.read(currentDayProvider.notifier).state = second;
    expect(await container.read(waterTodayTotalProvider.future), 0);
    expect(container.read(dhyanaEffectiveDateProvider), second);
    container.read(dhyanaSelectedDateProvider.notifier).state = first;
    container.read(currentDayProvider.notifier).state = DateTime(2026, 10, 13);
    expect(container.read(dhyanaEffectiveDateProvider), first);
    listener.close();
    container.dispose();
    await db.close();
  });
}
