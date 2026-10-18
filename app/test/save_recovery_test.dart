import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/app_shell/router.dart';
import 'package:nirvana/data/repositories/weight_repository.dart';
import 'package:nirvana/data/repositories/water_repository.dart';
import 'package:nirvana/main.dart';
import 'package:nirvana/domain/entities.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:nirvana/screens/save_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_database.dart';

class FailingWeightRepository extends WeightRepository {
  FailingWeightRepository(super.db);
  bool fail = true;
  @override
  Future<WeightEntry> add({
    required double weightKg,
    double? waistCm,
    String? notes,
    DateTime? takenAt,
  }) async {
    if (fail) throw StateError('write failed');
    return super.add(weightKg: weightKg, waistCm: waistCm, notes: notes, takenAt: takenAt);
  }
}

class DelayedWaterRepository extends WaterRepository {
  DelayedWaterRepository(super.db);
  final release = Completer<void>();
  int writes = 0;
  @override
  Future<WaterEntry> log(int amountMl, {DateTime? loggedAt}) async {
    writes++;
    await release.future;
    return super.log(amountMl, loggedAt: loggedAt);
  }
}

void main() {
  testWidgets('rapid water taps create one entry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await openTestDatabase();
    final repo = DelayedWaterRepository(db);
    appRouter.go('/water-log');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          waterRepositoryProvider.overrideWithValue(repo),
        ],
        child: const NirvanaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('+250 ml'));
    await tester.tap(find.text('+250 ml'));
    expect(repo.writes, 1);
    appRouter.go('/');
    await tester.pumpAndSettle();
    repo.release.complete();
    await tester.pumpAndSettle();
    expect(await db.query('water_entry'), hasLength(1));
    expect(find.text('250 ml of 2250 ml goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  testWidgets('weight write failure keeps draft and retry saves once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await openTestDatabase();
    final repo = FailingWeightRepository(db);
    appRouter.go('/weight');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          weightRepositoryProvider.overrideWithValue(repo),
        ],
        child: const NirvanaApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Log weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '70.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your entries are kept'), findsOneWidget);
    expect(find.text('70.5'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await db.query('weight_entry'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
  testWidgets('save action suppresses duplicate taps and ignores completion after disposal', (
    tester,
  ) async {
    final write = Completer<bool>();
    var calls = 0;
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveButton(
            onSave: () {
              calls++;
              return write.future;
            },
            onSaved: () => saved++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox());
    write.complete(true);
    await tester.pump();
    expect(saved, 0);
    expect(tester.takeException(), isNull);
  });
}
