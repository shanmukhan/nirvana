import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/domain/session_clock.dart';

void main() {
  test('elapsed time catches up after delayed UI callbacks', () {
    var now = Duration.zero;
    final clock = SessionClock(readTime: () => now)..start();
    now = const Duration(minutes: 8, seconds: 12);
    expect(clock.elapsed, now);
  });
  test('pause excludes paused time and repeated operations are safe', () {
    var now = Duration.zero;
    final clock = SessionClock(readTime: () => now)..start();
    now = const Duration(seconds: 20);
    clock.pause();
    clock.pause();
    now = const Duration(hours: 2);
    expect(clock.elapsed, const Duration(seconds: 20));
    expect(clock.active, true);
    expect(clock.running, false);
    clock.resume();
    clock.resume();
    now += const Duration(seconds: 10);
    expect(clock.elapsed, const Duration(seconds: 30));
    clock.reset();
    clock.resume();
    expect(clock.active, false);
    expect(clock.elapsed, Duration.zero);
    clock.start();
    now += const Duration(seconds: 3);
    expect(clock.elapsed, const Duration(seconds: 3));
  });
}
