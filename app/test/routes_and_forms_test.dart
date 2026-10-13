import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/app_shell/router.dart';
import 'package:nirvana/main.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

void main() {
  Future<void> mount(WidgetTester tester, String route) async {
    SharedPreferences.setMockInitialValues({});
    final db = await openTestDatabase();
    addTearDown(db.close);
    appRouter.go(route);
    await tester.pumpWidget(
      ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const NirvanaApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invalid routes render usable fallback screens', (tester) async {
    await mount(tester, '/');
    for (final (route, title) in [
      ('/desk-break-log/invalid/24/60', 'Desk Breaks'),
      ('/progress/day/2026-02-30', 'Progress / History'),
      ('/unknown', 'Page unavailable'),
    ]) {
      appRouter.go(route);
      await tester.pumpAndSettle();
      expect(find.text(title), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Open Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsWidgets);
    appRouter.go('/desk-break-log/eye/9/0?date=0001-01-01');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('weight form rejects invalid values then saves a valid weigh-in', (tester) async {
    await mount(tester, '/weight');
    await tester.tap(find.byTooltip('Log weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '-2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a weight greater than zero.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '72.4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('72.4 kg'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meal form rejects non-finite protein then saves a valid meal', (tester) async {
    await mount(tester, '/food');
    await tester.tap(find.text('Custom').first);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test meal');
    await tester.enterText(fields.at(1), 'NaN');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter zero or more grams, or leave blank.'), findsOneWidget);
    await tester.enterText(fields.at(1), '20');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Test meal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
