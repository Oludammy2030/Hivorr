import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';

void main() {
  late PiiRedactor redactor;

  setUp(() => redactor = PiiRedactor());

  test('redacts email addresses', () {
    expect(
      redactor.redact('Contact user@example.com for details'),
      'Contact ***@***.*** for details',
    );
  });

  test('redacts Nigerian phone numbers', () {
    expect(
      redactor.redact('Call +234 801 234 5678'),
      'Call ***-****-****',
    );
  });

  test('redacts generic phone numbers', () {
    expect(redactor.redact('Number: 1234567890'), 'Number: ***');
  });

  test('redacts bearer tokens', () {
    expect(redactor.redact('Auth: Bearer eyJhbGciOi...'), 'Auth: Bearer ***');
  });

  test('redacts JWTs', () {
    expect(
      redactor.redact('Token: eyJhbGciOi.eyJzdWIi.signed'),
      'Token: ***',
    );
  });

  test('redacts 10-digit account numbers', () {
    expect(redactor.redact('Account: 1234567890'), 'Account: ***');
  });

  test('redacts sensitive context keys', () {
    final out = redactor.redactContext(<String, Object?>{
      'email': 'user@test.com',
      'action': 'login',
    });
    expect(out['email'], '[REDACTED]');
    expect(out['action'], 'login');
  });

  test('redacts all default sensitive key names', () {
    const keys = <String>[
      'password',
      'token',
      'secret',
      'apiKey',
      'authorization',
      'cookie',
      'creditCard',
      'bankAccount',
      'pin',
      'otp',
      'ssn',
    ];
    for (final key in keys) {
      final out = redactor.redactContext(<String, Object?>{key: 'x'});
      expect(out[key], '[REDACTED]', reason: 'key $key should be redacted');
    }
  });

  test('does not redact unrelated numbers', () {
    expect(redactor.redact('Order #12345 placed'), 'Order #12345 placed');
  });

  test('redacts multiple PII instances in one message', () {
    expect(
      redactor.redact('user@example.com 1234567890'),
      '***@***.*** ***',
    );
  });

  test('handles empty and null-like input gracefully', () {
    expect(redactor.redact(''), '');
    expect(redactor.redactContext(<String, Object?>{}), isEmpty);
  });

  test('disabled redactor passes text through unchanged', () {
    final disabled = PiiRedactor(enabled: false);
    expect(
      disabled.redact('user@example.com'),
      'user@example.com',
    );
    expect(
      disabled.redactContext(<String, Object?>{'password': 'x'})['password'],
      'x',
    );
  });
}
