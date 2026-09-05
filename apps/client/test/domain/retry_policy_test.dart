import 'package:classsync/domain/sync/retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backoff grows exponentially and stays capped', () {
    const policy = RetryPolicy(
      baseDelay: Duration(seconds: 10),
      maxDelay: Duration(minutes: 2),
    );

    final first = policy.delayFor(1, jitterSeed: 2);
    final fourth = policy.delayFor(4, jitterSeed: 2);
    final late = policy.delayFor(20, jitterSeed: 2);

    expect(fourth, greaterThan(first));
    expect(late, lessThanOrEqualTo(const Duration(seconds: 144)));
  });

  test('stops after configured attempt count', () {
    const policy = RetryPolicy(maxAttempts: 3);
    expect(policy.shouldRetry(3), isTrue);
    expect(policy.shouldRetry(4), isFalse);
  });
}
