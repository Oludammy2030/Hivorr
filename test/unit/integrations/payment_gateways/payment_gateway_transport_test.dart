import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_transport.dart';

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  group('validateAmount', () {
    test('accepts a positive amount in a supported currency', () {
      expect(
        () => validateAmount(const Amount(minorUnits: 500000, currency: 'NGN')),
        returnsNormally,
      );
    });

    test('rejects a zero amount with validation PLT003', () {
      expect(
        () => validateAmount(const Amount(minorUnits: 0, currency: 'NGN')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects a negative amount', () {
      expect(
        () => validateAmount(const Amount(minorUnits: -1, currency: 'NGN')),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects an amount above the provider cap', () {
      expect(
        () => validateAmount(
          const Amount(minorUnits: 9900000001, currency: 'NGN'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });

    test('allows an amount exactly at the provider cap', () {
      expect(
        () => validateAmount(
          const Amount(minorUnits: 9900000000, currency: 'NGN'),
        ),
        returnsNormally,
      );
    });

    test('rejects an unsupported currency', () {
      expect(
        () => validateAmount(const Amount(minorUnits: 100, currency: 'KES')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('accepts all supported currencies', () {
      for (final String currency in <String>['NGN', 'GHS', 'USD', 'GBP']) {
        expect(
          () =>
              validateAmount(Amount(minorUnits: 100, currency: currency)),
          returnsNormally,
          reason: 'currency $currency should be supported',
        );
      }
    });
  });

  group('requireValidNuban', () {
    test('accepts a 10-digit NUBAN', () {
      expect(requireValidNuban('0123456789'), '0123456789');
    });

    test('rejects a short account number', () {
      expect(
        () => requireValidNuban('12345'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });

    test('rejects a non-numeric account number', () {
      expect(
        () => requireValidNuban('012345678a'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('requireValidBankCode', () {
    test('accepts a 3-digit bank code', () {
      expect(requireValidBankCode('058'), '058');
    });

    test('rejects a non-3-digit bank code', () {
      expect(
        () => requireValidBankCode('58'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });
  });

  group('logicalProviderError', () {
    test('builds a validation ApiException with PLT003 by default', () {
      final ApiException e = logicalProviderError(message: 'Nope');
      expect(e.kind, ApiExceptionKind.validation);
      expect(e.code, 'PLT003');
      expect(e.message, 'Nope');
    });

    test('builds a server ApiException when kind overridden', () {
      final ApiException e = logicalProviderError(
        message: 'Boom',
        kind: ApiExceptionKind.server,
        code: 'PLT999',
      );
      expect(e.kind, ApiExceptionKind.server);
      expect(e.code, 'PLT999');
    });
  });

  group('invokePaymentCall', () {
    test('returns the value when the call succeeds', () async {
      final int result = await invokePaymentCall<int>(
        mapper,
        () async => 42,
      );
      expect(result, 42);
    });

    test('maps a DioException to an ApiException via the mapper', () async {
      final DioException e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      await expectLater(
        invokePaymentCall<int>(mapper, () async => throw e),
        throwsA(
          isA<ApiException>()
              .having((ex) => ex.kind, 'kind', ApiExceptionKind.network),
        ),
      );
    });

    test('rethrows an already-normalized ApiException as-is', () async {
      const ApiException original = ApiException(
        kind: ApiExceptionKind.validation,
        message: 'already normalized',
        code: 'PLT003',
      );
      final DioException e = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.badResponse,
        error: original,
      );
      await expectLater(
        invokePaymentCall<int>(mapper, () async => throw e),
        throwsA(
          isA<ApiException>()
              .having((ex) => ex.message, 'message', 'already normalized')
              .having((ex) => ex.code, 'code', 'PLT003'),
        ),
      );
    });
  });
}
