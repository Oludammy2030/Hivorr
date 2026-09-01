import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/flutterwave_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/paystack_gateway.dart';

import 'payment_env_source.dart';

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  late PaymentGatewayConfig config;
  late PaystackGateway paystack;
  late FlutterwaveGateway flutterwave;

  setUp(() {
    config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
    paystack = PaystackGateway(
      dio: Dio(BaseOptions(baseUrl: PaystackGateway.baseUrl)),
      mapper: mapper,
      config: config,
    );
    flutterwave = FlutterwaveGateway(
      dio: Dio(BaseOptions(baseUrl: FlutterwaveGateway.baseUrl)),
      mapper: mapper,
      config: config,
    );
  });

  group('parseWebhookEvent', () {
    test('Paystack charge.success maps to success with reference', () {
      final WebhookEvent event = paystack.parseWebhookEvent(
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

    test('Flutterwave transfer.completed maps to success', () {
      final WebhookEvent event = flutterwave.parseWebhookEvent(
        <String, dynamic>{
          'event': 'transfer.completed',
          'data': <String, dynamic>{'tx_ref': 'trans-9'},
        },
        const <String, String>{},
      );
      expect(event.provider, 'flutterwave');
      expect(event.eventType, 'transfer.completed');
      expect(event.reference, 'trans-9');
      expect(event.status, PaymentStatus.success);
    });

    test('Paystack failure event maps to failed', () {
      final WebhookEvent event = paystack.parseWebhookEvent(
        <String, dynamic>{
          'event': 'charge.failed',
          'data': <String, dynamic>{'reference': 'uuid-2'},
        },
        const <String, String>{},
      );
      expect(event.status, PaymentStatus.failed);
    });

    test('starves an unknown event to pending (notification only)', () {
      final WebhookEvent event = paystack.parseWebhookEvent(
        <String, dynamic>{'event': 'transfer.unknown'},
        const <String, String>{},
      );
      expect(event.status, PaymentStatus.pending);
    });
  });

  group('verifyWebhookSignature', () {
    test('Paystack accepts a valid HMAC-SHA512 signature', () {
      final String raw = jsonEncode(<String, dynamic>{
        'event': 'charge.success',
        'data': <String, dynamic>{'reference': 'uuid-1'},
      });
      final String expected = 'sha512=${_hmacSha512('sk_test_abc123', raw)}';
      expect(
        paystack.verifyWebhookSignature(
          rawBody: raw,
          signatureHeader: expected,
        ),
        isTrue,
      );
    });

    test('Paystack rejects a tampered signature', () {
      expect(
        paystack.verifyWebhookSignature(
          rawBody: '{"event":"charge.success"}',
          signatureHeader: 'sha512=deadbeef',
        ),
        isFalse,
      );
    });

    test('Flutterwave accepts a matching verif-hash header', () {
      expect(
        flutterwave.verifyWebhookSignature(
          rawBody: 'body',
          signatureHeader: 'FLWSECK_TEST_abc123',
        ),
        isTrue,
      );
    });

    test('Flutterwave rejects a mismatched verif-hash header', () {
      expect(
        flutterwave.verifyWebhookSignature(
          rawBody: 'body',
          signatureHeader: 'wrong',
        ),
        isFalse,
      );
    });
  });

  group('malformed payload', () {
    test('Paystack throws validation when the event field is missing', () {
      expect(
        () => paystack.parseWebhookEvent(
          const <String, dynamic>{'data': <String, dynamic>{'reference': 'x'}},
          const <String, String>{},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('Flutterwave throws validation when no event or status is present', () {
      expect(
        () => flutterwave.parseWebhookEvent(
          const <String, dynamic>{'data': <String, dynamic>{'tx_ref': 'x'}},
          const <String, String>{},
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });
  });
}

String _hmacSha512(String secret, String body) {
  final Hmac hmac = Hmac(sha512, utf8.encode(secret));
  return hmac.convert(utf8.encode(body)).toString();
}
