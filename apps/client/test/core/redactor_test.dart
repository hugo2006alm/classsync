import 'package:classsync/core/logging/redactor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts bearer and named credentials', () {
    final output = SecretRedactor.redact(
      'Authorization: Bearer abc.def token=supersecret notion=ntn_123456',
    );

    expect(output, isNot(contains('abc.def')));
    expect(output, isNot(contains('supersecret')));
    expect(output, isNot(contains('ntn_123456')));
    expect(output, contains('[REDACTED]'));
  });
}
