import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/flutterwave_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';

import '../../../support/support.dart';
import 'payment_env_source.dart';

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  late MockDioAdapter httpMock;
  late Dio dio;
  late PaymentGatewayConfig config;
  late FlutterwaveGateway gateway;

  setUp(() {
    httpMock = MockDioAdapter();
    dio = Dio(
      BaseOptions(baseUrl: FlutterwaveGateway.baseUrl),
    )..httpClientAdapter = httpMock;
    config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
    gateway = FlutterwaveGateway(dio: dio, mapper: mapper, config: config);
  });

  group('initializePayment', () {
    final request = PaymentInitializationRequest(
      amount: const Amount(minorUnits: 500000, currency: 'NGN'),
      email: 'buyer@example.com',
      reference: 'uuid-1',
      callbackUrl: 'https://hivorr.app/callback',
    );

    test('converts kobo to major units and maps the checkout link', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'message': 'ok',
        'data': <String, dynamic>{
          'tx_ref': 'uuid-1',
          'link': 'https://flutterwave.link/XYZ',
          'flw_ref': 'FLW-1',
        },
      };

      final result = await gateway.initializePayment(request);

      expect(result.reference, 'uuid-1');
      expect(result.authorizationUrl, 'https://flutterwave.link/XYZ');
      expect(result.accessCode, 'FLW-1');

      final Map<String, dynamic>? body = httpMock.capturedBody;
      expect(body?['amount'], 5000, reason: '500000 kobo == NGN 5000');
      expect(body?['tx_ref'], 'uuid-1');
      expect(body?['currency'], 'NGN');
      expect(httpMock.capturedUrl, contains('/v3/charges'));
    });

    test('validates amount fail-fast before any request', () async {
      expect(
        () => gateway.initializePayment(
          PaymentInitializationRequest(
            amount: const Amount(minorUnits: 0, currency: 'NGN'),
            email: request.email,
            reference: request.reference,
            callbackUrl: request.callbackUrl,
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
      expect(httpMock.requests, isEmpty);
    });

    test('maps a business-error envelope to validation PLT003', () async {
      httpMock.body = <String, dynamic>{
        'status': 'error',
        'message': 'Card declined',
      };
      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });
  });

  group('verifyPayment', () {
    test('converts major units back to kobo and maps status', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'tx_ref': 'uuid-1',
          'amount': 5000,
          'currency': 'NGN',
          'status': 'successful',
          'created_at': '2026-01-01T10:00:00.000Z',
        },
      };

      final result = await gateway.verifyPayment('uuid-1');

      expect(result.status, PaymentStatus.success);
      expect(result.amount, const Amount(minorUnits: 500000, currency: 'NGN'));
      expect(result.paidAt, isNotNull);
      expect(httpMock.capturedUrl, contains('/v3/transactions/uuid-1/verify'));
    });

    test('maps an empty amount to zero', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{'tx_ref': 'uuid-1', 'status': 'pending'},
      };
      final result = await gateway.verifyPayment('uuid-1');
      expect(result.amount.minorUnits, 0);
      expect(result.status, PaymentStatus.pending);
    });
  });

  group('createTransfer', () {
    test('converts to major units on the v3/transfers endpoint', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'id': 42,
          'status': 'pending',
        },
      };

      final result = await gateway.createTransfer(
        TransferRequest(
          amount: const Amount(minorUnits: 100000, currency: 'NGN'),
          recipientAccountNumber: '0123456789',
          recipientBankCode: '058',
          reference: 'trans-1',
          reason: 'payout',
        ),
      );

      expect(result.reference, '42');
      expect(result.status, TransferStatus.pending);
      final Map<String, dynamic>? body = httpMock.capturedBody;
      expect(body?['amount'], 1000);
      expect(body?['account_number'], '0123456789');
      expect(body?['account_bank'], '058');
    });

    test('validates nuban and bank code fail-fast', () {
      expect(
        () => gateway.createTransfer(
          TransferRequest(
            amount: const Amount(minorUnits: 100000, currency: 'NGN'),
            recipientAccountNumber: 'bad',
            recipientBankCode: '058',
            reference: 'trans-1',
            reason: 'payout',
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(httpMock.requests, isEmpty);
    });
  });

  group('verifyTransfer', () {
    test('maps major units to kobo', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'reference': 'trans-1',
          'amount': 1000,
          'currency': 'NGN',
          'status': 'success',
        },
      };
      final result = await gateway.verifyTransfer('trans-1');
      expect(result.status, TransferStatus.success);
      expect(result.amount, const Amount(minorUnits: 100000, currency: 'NGN'));
    });
  });

  group('refundPayment', () {
    test('maps a refund to reversed', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'amount': 5000,
          'currency': 'NGN',
        },
      };
      final result = await gateway.refundPayment(
        RefundRequest(transactionReference: 'tx-1'),
      );
      expect(result.status, PaymentStatus.reversed);
      expect(result.amount, const Amount(minorUnits: 500000, currency: 'NGN'));
    });

    test('throws validation on a status:error envelope', () async {
      httpMock.body = <String, dynamic>{
        'status': 'error',
        'message': 'Cannot refund',
      };
      await expectLater(
        gateway.refundPayment(
          RefundRequest(transactionReference: 'tx-1'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });
  });

  group('resolveAccount', () {
    test('resolves an account name via v3/accounts/resolve', () async {
      httpMock.body = <String, dynamic>{
        'status': 'success',
        'data': <String, dynamic>{
          'account_number': '0123456789',
          'account_name': 'ADEOLA OYEKANMI',
        },
      };
      final result = await gateway.resolveAccount(
        bankCode: '058',
        accountNumber: '0123456789',
      );
      expect(result.accountName, 'ADEOLA OYEKANMI');
      expect(result.bankCode, '058');
      expect(httpMock.capturedUrl, contains('/v3/accounts/resolve'));
    });
  });

  group('parseWebhookEvent', () {
    test('parses a charge.completed event', () {
      final event = gateway.parseWebhookEvent(
        <String, dynamic>{
          'event': 'charge.completed',
          'data': <String, dynamic>{'tx_ref': 'uuid-1'},
        },
        const <String, String>{},
      );
      expect(event.provider, 'flutterwave');
      expect(event.eventType, 'charge.completed');
      expect(event.reference, 'uuid-1');
      expect(event.status, PaymentStatus.success);
    });

    test('falls back to data.status when event is absent', () {
      final event = gateway.parseWebhookEvent(
        <String, dynamic>{
          'data': <String, dynamic>{
            'status': 'successful',
            'tx_ref': 'uuid-2',
          },
        },
        const <String, String>{},
      );
      expect(event.reference, 'uuid-2');
      expect(event.status, PaymentStatus.success);
    });

    test('throws validation when no event or status is present', () {
      expect(
        () => gateway.parseWebhookEvent(
          const <String, dynamic>{'data': <String, dynamic>{'tx_ref': 'x'}},
          const <String, String>{},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });
  });

  group('verifyWebhookSignature', () {
    test('accepts when the verif-hash header equals the secret', () {
      expect(
        gateway.verifyWebhookSignature(
          rawBody: 'body',
          signatureHeader: 'FLWSECK_TEST_abc123',
        ),
        isTrue,
      );
    });

    test('rejects a mismatched hash', () {
      expect(
        gateway.verifyWebhookSignature(
          rawBody: 'body',
          signatureHeader: 'wrong-hash',
        ),
        isFalse,
      );
    });
  });

  group('provider identity and headerValue', () {
    test('reports flutterwave provider', () {
      expect(gateway.provider, PaymentProvider.flutterwave);
    });

    test('headerValue matches case-insensitively', () {
      expect(
        FlutterwaveGateway.headerValue(
          const <String, String>{'Verif-Hash': 'abc'},
          'verif-hash',
        ),
        'abc',
      );
    });
  });

  group('additional error mapping', () {
    final request = PaymentInitializationRequest(
      amount: const Amount(minorUnits: 500000, currency: 'NGN'),
      email: 'buyer@example.com',
      reference: 'uuid-1',
      callbackUrl: 'https://hivorr.app/callback',
    );

    test('maps status:error without message to server PLT999', () async {
      httpMock.body = <String, dynamic>{
        'status': 'error',
        'data': null,
      };
      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.server)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('maps a 401 transport error to auth PLT001', () async {
      final RequestOptions ro = RequestOptions(path: '/v3/charges');
      httpMock.thrown = DioException(
        requestOptions: ro,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          statusCode: 401,
          requestOptions: ro,
          data: const <String, dynamic>{},
        ),
      );
      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.auth)
              .having((e) => e.code, 'code', 'PLT001'),
        ),
      );
    });
  });
}
