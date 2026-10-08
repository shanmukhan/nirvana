import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/screens/reminder_coverage.dart';
import 'package:nirvana/services/reminder_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('coverage updates when quiet hours change on the same screen', (tester) async {
    SharedPreferences.setMockInitialValues({'reminder_quiet_hours_enabled': false});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReminderCoverage(fromMinutes: 600, toMinutes: 720, intervalMinutes: 60),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3 reminders per day'), findsOneWidget);
    await ReminderPrefs.setQuietHoursStartMinutes(600);
    await ReminderPrefs.setQuietHoursEndMinutes(720);
    await ReminderPrefs.setQuietHoursEnabled(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 reminder per day'), findsOneWidget);
    await ReminderPrefs.setQuietHoursEndMinutes(721);
    await tester.pumpAndSettle();
    expect(find.textContaining('No reminders are scheduled'), findsOneWidget);
  });
}
