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

  test('redacts payment references from diagnostics', () {
    final output = SecretRedactor.redact(
      'Portal error: Referência Multibanco: 123 456 789 entidade=12345',
    );

    expect(output, isNot(contains('123 456 789')));
    expect(output, isNot(contains('12345')));
    expect(output, contains('[REDACTED]'));
  });
}
