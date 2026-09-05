import 'dart:math';

class RetryPolicy {
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(hours: 6),
    this.maxAttempts = 8,
  });

  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;

  Duration delayFor(int attempt, {int jitterSeed = 0}) {
    final exponent = max(0, attempt - 1).clamp(0, 20);
    final rawMilliseconds = baseDelay.inMilliseconds * pow(2, exponent);
    final capped = min(rawMilliseconds.toInt(), maxDelay.inMilliseconds);
    final random = Random(jitterSeed + attempt);
    final jitter = 0.8 + random.nextDouble() * 0.4;
    return Duration(milliseconds: (capped * jitter).round());
  }

  bool shouldRetry(int nextAttempt) => nextAttempt <= maxAttempts;
}
