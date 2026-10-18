import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/app_shell/router.dart';
import 'package:nirvana/main.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

void main() {
  testWidgets('small-screen knee form remains reachable with large text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = await openTestDatabase();
    appRouter.go('/knee');
    await tester.pumpWidget(
      ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const NirvanaApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Log knee check-in'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await db.query('pain_entry'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}
