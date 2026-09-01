import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/paystack_gateway.dart';

import '../../../support/support.dart';
import 'payment_env_source.dart';

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  late MockDioAdapter httpMock;
  late Dio dio;
  late PaymentGatewayConfig config;
  late PaystackGateway gateway;

  setUp(() {
    httpMock = MockDioAdapter();
    dio = Dio(
      BaseOptions(baseUrl: PaystackGateway.baseUrl),
    )
      ..httpClientAdapter = httpMock
      ..options.headers['Authorization'] = 'Bearer sk_test_abc123';
    config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
    gateway = PaystackGateway(dio: dio, mapper: mapper, config: config);
  });

  group('initializePayment', () {
    final request = PaymentInitializationRequest(
      amount: const Amount(minorUnits: 500000, currency: 'NGN'),
      email: 'buyer@example.com',
      reference: 'uuid-1',
      callbackUrl: 'https://hivorr.app/callback',
    );

    test('posts kobo amount verbatim and maps the auth url', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'message': 'ok',
        'data': <String, dynamic>{
          'reference': 'uuid-1',
          'authorization_url': 'https://paystack.pay/session/ABC',
          'access_code': 'ACC-1',
        },
      };

      final result = await gateway.initializePayment(request);

      expect(result.reference, 'uuid-1');
      expect(result.authorizationUrl, 'https://paystack.pay/session/ABC');
      expect(result.accessCode, 'ACC-1');

      final Map<String, dynamic>? body = httpMock.capturedBody;
      expect(body?['amount'], 500000);
      expect(body?['email'], 'buyer@example.com');
      expect(body?['reference'], 'uuid-1');
      expect(body?['callback_url'], 'https://hivorr.app/callback');
      expect(body?['currency'], 'NGN');
      expect(httpMock.capturedUrl, contains('/transaction/initialize'));
    });

    test('includes metadata when provided', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{
          'reference': 'uuid-1',
          'authorization_url': 'https://paystack.pay/1',
          'access_code': 'ACC-1',
        },
      };

      await gateway.initializePayment(
        PaymentInitializationRequest(
          amount: request.amount,
          email: request.email,
          reference: request.reference,
          callbackUrl: request.callbackUrl,
          metadata: <String, String>{'entity_id': 'e1'},
        ),
      );

      final Map<String, dynamic>? body = httpMock.capturedBody;
      expect(body?['metadata'], <String, String>{'entity_id': 'e1'});
    });

    test('validates amount fail-fast before any request', () {
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

    test('maps status:false logical errors to validation PLT003', () async {
      httpMock.body = <String, dynamic>{
        'status': false,
        'message': 'Invalid amount',
      };

      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003')
              .having((e) => e.message, 'message', 'Invalid amount'),
        ),
      );
    });

    test('sends the bearer secret header', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{
          'reference': 'uuid-1',
          'authorization_url': 'https://paystack.pay/1',
          'access_code': 'ACC-1',
        },
      };

      await gateway.initializePayment(request);

      expect(httpMock.capturedAuthorizationHeader, 'Bearer sk_test_abc123');
    });
  });

  group('verifyPayment', () {
    test('maps kobo amount and status', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{
          'reference': 'uuid-1',
          'amount': 500000,
          'currency': 'NGN',
          'status': 'success',
          'fees': 15000,
          'paid_at': '2026-01-01T10:00:00.000Z',
        },
      };

      final result = await gateway.verifyPayment('uuid-1');

      expect(result.reference, 'uuid-1');
      expect(result.status, PaymentStatus.success);
      expect(result.amount, const Amount(minorUnits: 500000, currency: 'NGN'));
      expect(result.gatewayFee, const Amount(minorUnits: 15000, currency: 'NGN'));
      expect(result.paidAt, isNotNull);
      expect(httpMock.capturedUrl, contains('/transaction/verify/uuid-1'));
    });

    test('defaults to pending status and NGN when fields are absent', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{'reference': 'uuid-1'},
      };

      final result = await gateway.verifyPayment('uuid-1');
      expect(result.status, PaymentStatus.pending);
      expect(result.currency, 'NGN');
    });
  });

  group('createTransfer', () {
    final request = TransferRequest(
      amount: const Amount(minorUnits: 100000, currency: 'NGN'),
      recipientAccountNumber: '0123456789',
      recipientBankCode: '058',
      reference: 'trans-1',
      reason: 'payout',
    );

    test('creates a recipient then the transfer', () async {
      final responses = <MockDioAdapter>[
        MockDioAdapter(
          statusCode: 200,
          body: <String, dynamic>{
            'status': true,
            'data': <String, dynamic>{'recipient_code': 'RCP_123'},
          },
        ),
        MockDioAdapter(
          statusCode: 200,
          body: <String, dynamic>{
            'status': true,
            'data': <String, dynamic>{
              'reference': 'trans-1',
              'status': 'success',
            },
          },
        ),
      ];
      dio.httpClientAdapter = _SequentialAdapter(responses);

      final result = await gateway.createTransfer(request);

      expect(result.reference, 'trans-1');
      expect(result.status, TransferStatus.success);
      expect(responses[0].requests.length, 1, reason: 'recipient creation');
      expect(
        responses[0].requests.first.path,
        '/transferrecipient',
      );
      expect(responses[1].requests.length, 1, reason: 'transfer creation');
      expect(responses[1].requests.first.path, '/transfer');
    });

    test('validates nuban and bank code fail-fast', () {
      expect(
        () => gateway.createTransfer(
          TransferRequest(
            amount: request.amount,
            recipientAccountNumber: '123',
            recipientBankCode: '058',
            reference: request.reference,
            reason: request.reason,
          ),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(httpMock.requests, isEmpty);
    });
  });

  group('verifyTransfer', () {
    test('maps amount and status', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{
          'reference': 'trans-1',
          'amount': 100000,
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
    test('posts a full refund and maps to reversed', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
        'data': <String, dynamic>{
          'amount': 500000,
          'currency': 'NGN',
        },
      };

      final result = await gateway.refundPayment(
        RefundRequest(transactionReference: 'tx-1'),
      );
      expect(result.status, PaymentStatus.reversed);
      expect(result.amount, const Amount(minorUnits: 500000, currency: 'NGN'));
    });

    test('throws server error on a status:false refund response', () async {
      httpMock.body = <String, dynamic>{
        'status': false,
        'message': 'Refund failed',
      };
      await expectLater(
        gateway.refundPayment(
          RefundRequest(transactionReference: 'tx-1'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.server),
        ),
      );
    });
  });

  group('resolveAccount', () {
    test('queries bank/resolve and returns the account name', () async {
      httpMock.body = <String, dynamic>{
        'status': true,
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
      expect(result.accountNumber, '0123456789');
      expect(result.bankCode, '058');
      expect(httpMock.capturedQueryParameters, isNotNull);
    });
  });

  group('parseWebhookEvent', () {
    test('parses a charge.success event', () {
      final event = gateway.parseWebhookEvent(
        <String, dynamic>{
          'event': 'charge.success',
          'data': <String, dynamic>{'reference': 'uuid-1'},
        },
        const <String, String>{},
      );

      expect(event.provider, 'paystack');
      expect(event.eventType, 'charge.success');
      expect(event.reference, 'uuid-1');
      expect(event.status, PaymentStatus.success);
    });

    test('throws validation when the event field is missing', () {
      expect(
        () => gateway.parseWebhookEvent(
          const <String, dynamic>{'data': <String, dynamic>{}},
          const <String, String>{},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('extracts reference from nested transfer data', () {
      final event = gateway.parseWebhookEvent(
        <String, dynamic>{
          'event': 'transfer.success',
          'data': <String, dynamic>{
            'transfer': <String, dynamic>{'reference': 'trans-9'},
          },
        },
        const <String, String>{},
      );
      expect(event.reference, 'trans-9');
    });
  });

  group('verifyWebhookSignature', () {
    final String rawBody = jsonEncode(<String, dynamic>{
      'event': 'charge.success',
      'data': <String, dynamic>{'reference': 'uuid-1'},
    });

    test('accepts a valid HMAC-SHA512 signature', () {
      final String expected =
          'sha512=${_hmacSha512('sk_test_abc123', rawBody)}';
      expect(
        gateway.verifyWebhookSignature(
          rawBody: rawBody,
          signatureHeader: expected,
        ),
        isTrue,
      );
    });

    test('rejects a tampered signature', () {
      expect(
        gateway.verifyWebhookSignature(
          rawBody: rawBody.replaceFirst('uuid-1', 'uuid-2'),
          signatureHeader: 'sha512=bogus',
        ),
        isFalse,
      );
    });

    test('rejects a signature with the wrong length', () {
      expect(
        gateway.verifyWebhookSignature(
          rawBody: rawBody,
          signatureHeader: 'sha512=short',
        ),
        isFalse,
      );
    });
  });

  group('provider identity and headerValue', () {
    test('reports paystack provider', () {
      expect(gateway.provider, PaymentProvider.paystack);
    });

    test('headerValue matches case-insensitively', () {
      expect(
        PaystackGateway.headerValue(
          const <String, String>{'X-PAYSTACK-SIGNATURE': 'abc'},
          'x-paystack-signature',
        ),
        'abc',
      );
      expect(
        PaystackGateway.headerValue(const <String, String>{}, 'x-signature'),
        isNull,
      );
    });
  });

  group('transport error mapping', () {
    final request = PaymentInitializationRequest(
      amount: const Amount(minorUnits: 500000, currency: 'NGN'),
      email: 'buyer@example.com',
      reference: 'uuid-1',
      callbackUrl: 'https://hivorr.app/callback',
    );

    DioException dioError(int statusCode, [Map<String, dynamic>? data]) {
      final RequestOptions ro = RequestOptions(
        path: '/transaction/initialize',
      );
      return DioException(
        requestOptions: ro,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          statusCode: statusCode,
          requestOptions: ro,
          data: data ?? const <String, dynamic>{},
        ),
      );
    }

    test('maps 401 to auth PLT001', () async {
      httpMock.thrown = dioError(401);
      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.auth)
              .having((e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('maps 409 duplicate reference to conflict PLT005', () async {
      httpMock.thrown = dioError(409, <String, dynamic>{'message': 'dup'});
      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.conflict)
              .having((e) => e.code, 'code', 'PLT005'),
        ),
      );
    });

    test('maps 500 to server PLT999', () async {
      httpMock.thrown = dioError(500);
      await expectLater(
        gateway.initializePayment(request),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.server)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });
  });
}

String _hmacSha512(String secret, String body) {
  final Hmac hmac = Hmac(sha512, utf8.encode(secret));
  return hmac.convert(utf8.encode(body)).toString();
}

/// Serves one canned [MockDioAdapter] per request, in order.
class _SequentialAdapter implements HttpClientAdapter {
  _SequentialAdapter(this.adapters);

  final List<MockDioAdapter> adapters;
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final MockDioAdapter adapter = adapters[_index];
    _index += 1;
    return adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    for (final MockDioAdapter a in adapters) {
      a.close(force: force);
    }
  }
}
