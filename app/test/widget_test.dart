import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nirvana/data/db/schema.dart';
import 'package:nirvana/main.dart';
import 'package:nirvana/providers/repository_providers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // The isolate-based factory deadlocks under flutter_test's binding;
    // the no-isolate variant runs queries on the calling isolate instead.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('Dashboard is the initial screen and nav drawer lists all screens', (
    WidgetTester tester,
  ) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          for (final statement in createTableStatements) {
            await db.execute(statement);
          }
          for (final statement in createIndexStatements) {
            await db.execute(statement);
          }
        },
      ),
    );
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const NirvanaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Dhyana'), findsWidgets);
    await tester.drag(find.byType(Drawer), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}
