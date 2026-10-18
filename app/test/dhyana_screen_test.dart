import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nirvana/domain/session_clock.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:nirvana/screens/dhyana/dhyana_screen.dart';

import 'test_database.dart';

void main() {
  testWidgets('failed completion stays paused and retry saves once', (tester) async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await db.execute(
      "CREATE TRIGGER reject_session BEFORE INSERT ON dhyana_session BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    var now = Duration.zero;
    final clock = SessionClock(readTime: () => now);
    final router = GoRouter(
      initialLocation: '/dhyana',
      routes: [
        GoRoute(
          path: '/dhyana',
          builder: (_, _) => DhyanaScreen(clock: clock),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start session'));
    await tester.tap(find.text('Start session'));
    await tester.pump();
    now = const Duration(minutes: 1);
    await tester.tap(find.text('End now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(clock.active, true);
    expect(clock.running, false);
    expect(find.textContaining('Could not save the session'), findsOneWidget);
    expect(await db.query('dhyana_session'), isEmpty);
    await db.execute('DROP TRIGGER reject_session');
    await tester.tap(find.text('End now'));
    await tester.pumpAndSettle();
    expect((await db.query('dhyana_session')).length, 1);
    expect(clock.active, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause/resume and delayed completion log one bounded session', (tester) async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    var now = Duration.zero;
    final clock = SessionClock(readTime: () => now);
    final router = GoRouter(
      initialLocation: '/dhyana',
      routes: [
        GoRoute(
          path: '/dhyana',
          builder: (_, _) => DhyanaScreen(clock: clock),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final planned = tester.widget<Slider>(find.byType(Slider)).value.toInt();
    await tester.ensureVisible(find.text('Start session'));
    await tester.tap(find.text('Start session'));
    await tester.pump();
    now = const Duration(seconds: 10);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    now = const Duration(hours: 1);
    expect(clock.elapsed, const Duration(seconds: 10));
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    now += Duration(minutes: planned + 10);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    final rows = await db.query('dhyana_session');
    expect(rows.length, 1);
    expect(rows.single['actual_duration_min'], planned);
    expect(clock.active, false);
    expect(tester.takeException(), isNull);
  });
}
