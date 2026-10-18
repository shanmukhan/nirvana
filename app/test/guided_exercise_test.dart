import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/exercise_repository.dart';
import 'package:nirvana/screens/exercise/guided_exercise_screen.dart';
import 'package:nirvana/domain/session_clock.dart';

import 'test_database.dart';

void main() {
  testWidgets('hold catches up after delayed callbacks and pauses in background', (tester) async {
    var elapsed = Duration.zero;
    final clock = SessionClock(readTime: () => elapsed);
    await tester.pumpWidget(
      MaterialApp(
        home: GuidedExerciseScreen(definition: strengthExerciseSeed[1], clock: clock),
      ),
    );
    await tester.tap(find.text('Start hold\n(5s)'));
    await tester.pump();
    elapsed = const Duration(seconds: 10);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rep 2 of 15'), findsOneWidget);
    await tester.tap(find.text('Start hold\n(5s)'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    elapsed = const Duration(minutes: 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Rep 2 of 15'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    elapsed += const Duration(seconds: 5);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rep 3 of 15'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final reps in [0, 1, 10, 11, 20]) {
    testWidgets('finishing after $reps reps preserves completed work', (tester) async {
      GuidedExerciseResult? result;
      final definition = strengthExerciseSeed.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<GuidedExerciseResult>(
                    MaterialPageRoute(builder: (_) => GuidedExerciseScreen(definition: definition)),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (var rep = 0; rep < reps; rep++) {
        if (find.text('Skip rest').evaluate().isNotEmpty) {
          await tester.tap(find.text('Skip rest'));
          await tester.pump();
        }
        await tester.tap(find.text('+1 rep'));
        await tester.pump();
      }
      await tester.tap(find.text(reps == 20 ? 'Continue' : 'Finish now'));
      await tester.pumpAndSettle();
      expect(result!.completedSets, reps ~/ 10);
      expect(result!.partialReps, reps % 10);
      expect(result!.completedSets * result!.completedReps + result!.partialReps, reps);
    });
  }
  test('zero work is rejected and partial work survives persistence', () async {
    final db = await openTestDatabase();
    final repo = ExerciseRepository(db);
    await repo.seedDefinitionsIfEmpty();
    await expectLater(
      repo.logSession(exerciseDefinitionId: 'quad-set', completedSets: 0, completedReps: 0),
      throwsArgumentError,
    );
    await repo.logSession(
      exerciseDefinitionId: 'quad-set',
      completedSets: 0,
      completedReps: 0,
      partialReps: 1,
    );
    expect((await repo.forDay(DateTime.now())).single.totalReps, 1);
    expect(await repo.loggedDays(7), hasLength(1));
    await db.close();
  });
}
