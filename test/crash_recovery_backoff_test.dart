import 'package:clashxy/core/mihomo/crash_recovery_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses capped exponential delays and stops at the retry limit', () {
    final backoff = CrashRecoveryBackoff(
      maxAttempts: 5,
      initialDelay: const Duration(seconds: 1),
      maximumDelay: const Duration(seconds: 8),
    );

    final attempts = List<CrashRecoveryAttempt?>.generate(
      6,
      (_) => backoff.next(),
    );

    expect(attempts.take(5).map((attempt) => attempt!.number), <int>[
      1,
      2,
      3,
      4,
      5,
    ]);
    expect(attempts.take(5).map((attempt) => attempt!.delay), <Duration>[
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(seconds: 8),
    ]);
    expect(attempts.last, isNull);
    expect(backoff.attempts, 5);
  });

  test('reset restores the full retry budget', () {
    final backoff = CrashRecoveryBackoff(maxAttempts: 1);
    expect(backoff.next()?.number, 1);
    expect(backoff.next(), isNull);

    backoff.reset();

    expect(backoff.attempts, 0);
    expect(backoff.next()?.number, 1);
  });
}
