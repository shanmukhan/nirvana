import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/domain/startup_tasks.dart';
import 'package:nirvana/main.dart';

import 'test_database.dart';

void main() {
  test('optional task failures do not stop remaining services', () async {
    var scheduled = false;
    final failures = await runStartupTasks({
      'Notifications': () async => throw StateError('plugin failed'),
      'WorkManager': () async => throw StateError('work failed'),
      'Scheduling': () async {
        scheduled = true;
      },
    });
    expect(failures, ['Notifications', 'WorkManager']);
    expect(scheduled, true);
  });

  testWidgets('database failure shows recovery and retry opens dashboard', (tester) async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    var attempts = 0;
    await tester.pumpWidget(
      NirvanaStartup(
        openDatabase: () async {
          if (attempts++ == 0) throw StateError('database unavailable');
          return db;
        },
        initializeServices: () async => ['Reminder scheduling'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open your local data'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('You can still log'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
