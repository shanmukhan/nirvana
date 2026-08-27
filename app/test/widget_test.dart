import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nirvana/main.dart';

void main() {
  testWidgets('Dashboard is the initial screen and nav drawer lists all screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NirvanaApp()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Dhyana'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Settings'), 100);
    expect(find.text('Settings'), findsWidgets);
  });
}
