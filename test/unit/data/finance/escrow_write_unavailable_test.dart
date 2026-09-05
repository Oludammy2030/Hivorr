import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/escrow_write_unavailable_exception.dart';

void main() {
  group('EscrowWriteUnavailableException (TT-05)', () {
    test('is an ApiException subclass with kind forbidden', () {
      const EscrowWriteUnavailableException e = EscrowWriteUnavailableException();

      expect(e, isA<ApiException>());
      expect(e.kind, ApiExceptionKind.forbidden);
    });

    test('message surfaces the support-team guidance', () {
      const EscrowWriteUnavailableException e = EscrowWriteUnavailableException();

      expect(e.message, contains('not available yet'));
      expect(e.message, contains('support team'));
    });

    test('is never a silent no-op — carries a non-empty message', () {
      const EscrowWriteUnavailableException e = EscrowWriteUnavailableException();

      expect(e.message, isNotEmpty);
      expect(e.message.trim(), isNotEmpty);
    });

    test('surfaces distinct from the PLT002 forbidden mapping', () {
      const EscrowWriteUnavailableException unavailable = EscrowWriteUnavailableException();
      const ApiException plt002 = ApiException(
        kind: ApiExceptionKind.forbidden,
        message: 'Operation not permitted.',
        code: 'PLT002',
      );

      expect(unavailable.runtimeType, isNot(plt002.runtimeType));
      expect(unavailable.code, isNull);
      expect(plt002.code, 'PLT002');
      expect(unavailable.message, contains('support team'));
      expect(plt002.message, isNot(contains('support team')));
    });
  });
}