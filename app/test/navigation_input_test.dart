import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/domain/navigation_input.dart';

void main() {
  test('known reminders navigate to their log screens', () {
    expect(notificationRoute('water'), '/water-log');
    expect(notificationRoute('dhyana'), '/dhyana');
    expect(notificationRoute('knee'), '/knee');
    expect(notificationRoute('weight'), '/weight');
    expect(notificationRoute('deskbreak:eye:8:30'), '/desk-break-log/eye/8/30');
  });
  test('malformed notification payloads are ignored', () {
    for (final payload in [
      null,
      '',
      'unknown',
      'deskbreak:eye:24:0',
      'deskbreak:eye:8:-1',
      'deskbreak:eye:noon:0',
      'deskbreak:unknown:8:0',
      'deskbreak:eye:8:0:extra',
      'deskbreak:../settings:8:0',
    ]) {
      expect(notificationRoute(payload), isNull, reason: '$payload');
    }
  });
  test('activity dates reject invalid and normalized values', () {
    expect(parseActivityDate('2024-02-29'), DateTime(2024, 2, 29));
    for (final text in [
      null,
      '2026-02-29',
      '2026-13-01',
      '2026-10-32',
      '2026-10-01T12:00:00',
      'garbage',
    ]) {
      expect(parseActivityDate(text), isNull);
    }
  });
}
