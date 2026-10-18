import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/services/phone_usage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('quiet hours suppress warnings before querying usage', () async {
    final shown = await PhoneUsageService.checkAndMaybeWarn(
      at: DateTime(2026, 10, 12, 23),
      permissionCheck: () async => throw StateError('must not query'),
      readScreenStart: (_, _) async => throw StateError('must not query'),
    );
    expect(shown, false);
  });
  test('one warning per observed screen-on session; a new session can warn', () async {
    var count = 0;
    final at = DateTime(2026, 10, 12, 12);
    var start = at.subtract(const Duration(minutes: 30));
    Future<bool> check() => PhoneUsageService.checkAndMaybeWarn(
      at: at,
      permissionCheck: () async => true,
      readScreenStart: (_, _) async => start,
      showWarning: (_, _) async {
        count++;
      },
    );
    expect(await check(), true);
    expect(await check(), false);
    start = at.subtract(const Duration(minutes: 20));
    expect(await check(), true);
    expect(count, 2);
  });
}
