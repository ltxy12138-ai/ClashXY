class CrashRecoveryAttempt {
  const CrashRecoveryAttempt({required this.number, required this.delay});

  final int number;
  final Duration delay;
}

class CrashRecoveryBackoff {
  CrashRecoveryBackoff({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.maximumDelay = const Duration(seconds: 30),
    this.stablePeriod = const Duration(minutes: 2),
  }) : assert(maxAttempts > 0),
       assert(initialDelay > Duration.zero),
       assert(maximumDelay > Duration.zero),
       assert(maximumDelay >= initialDelay),
       assert(stablePeriod > Duration.zero);

  final int maxAttempts;
  final Duration initialDelay;
  final Duration maximumDelay;
  final Duration stablePeriod;

  int _attempts = 0;

  int get attempts => _attempts;

  CrashRecoveryAttempt? next() {
    if (_attempts >= maxAttempts) return null;
    var milliseconds = initialDelay.inMilliseconds;
    for (var index = 0; index < _attempts; index++) {
      milliseconds = (milliseconds * 2)
          .clamp(1, maximumDelay.inMilliseconds)
          .toInt();
    }
    _attempts++;
    return CrashRecoveryAttempt(
      number: _attempts,
      delay: Duration(milliseconds: milliseconds),
    );
  }

  void reset() => _attempts = 0;
}
