/// Elapsed session time comes from a monotonic clock, independent of UI ticks.
/// An injectable time source lets tests simulate suspension without waiting.
class SessionClock {
  final Duration Function() _readTime;
  Duration _accumulated = Duration.zero;
  Duration? _startedAt;
  bool _active = false;

  factory SessionClock({Duration Function()? readTime}) {
    final stopwatch = Stopwatch()..start();
    return SessionClock._(readTime ?? () => stopwatch.elapsed);
  }

  SessionClock._(this._readTime);

  bool get active => _active;
  bool get running => _startedAt != null;
  Duration get elapsed =>
      _accumulated + (_startedAt == null ? Duration.zero : _readTime() - _startedAt!);

  void start() {
    _accumulated = Duration.zero;
    _active = true;
    _startedAt = _readTime();
  }

  void pause() {
    if (!running) return;
    _accumulated = elapsed;
    _startedAt = null;
  }

  void resume() {
    if (_active && !running) _startedAt = _readTime();
  }

  void reset() {
    _active = false;
    _startedAt = null;
    _accumulated = Duration.zero;
  }
}
