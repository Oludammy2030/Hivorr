import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/api_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/integrations/payment_gateways/flutterwave_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_factory.dart';
import 'package:hivorr/integrations/payment_gateways/paystack_gateway.dart';

import 'payment_env_source.dart';

const ApiConfig _apiConfig = ApiConfig(
  connectTimeout: Duration(seconds: 5),
  receiveTimeout: Duration(seconds: 5),
  sendTimeout: Duration(seconds: 5),
  maxRetries: 1,
  baseRetryDelay: Duration(milliseconds: 100),
  maxRetryDelay: Duration(seconds: 1),
);

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  PaymentGatewayConfig fullConfig() =>
      PaymentGatewayConfig.fromEnvironment(paymentEnvSource());

  group('create', () {
    test('creates a Paystack gateway with the bearer secret', () {
      final factory = PaymentGatewayFactory(
        config: fullConfig(),
        mapper: mapper,
        apiConfig: _apiConfig,
      );
      final gateway = factory.create(PaymentProvider.paystack);
      expect(gateway.provider, PaymentProvider.paystack);

      final dio = (gateway as PaystackGateway).dio;
      expect(dio.options.baseUrl, PaystackGateway.baseUrl);
      expect(dio.options.headers['Authorization'], 'Bearer sk_test_abc123');
    });

    test('creates a Flutterwave gateway with the bearer secret', () {
      final factory = PaymentGatewayFactory(
        config: fullConfig(),
        mapper: mapper,
        apiConfig: _apiConfig,
      );
      final gateway = factory.create(PaymentProvider.flutterwave);
      expect(gateway.provider, PaymentProvider.flutterwave);

      final dio = (gateway as FlutterwaveGateway).dio;
      expect(dio.options.baseUrl, FlutterwaveGateway.baseUrl);
      expect(
        dio.options.headers['Authorization'],
        'Bearer FLWSECK_TEST_abc123',
      );
    });
  });

  group('resolveForCurrency', () {
    test('routes NGN to paystack by default', () {
      final factory = PaymentGatewayFactory(
        config: fullConfig(),
        mapper: mapper,
        apiConfig: _apiConfig,
      );
      final gateway = factory.resolveForCurrency('NGN');
      expect(gateway.provider, PaymentProvider.paystack);
    });

    test('routes non-NGN currencies to flutterwave', () {
      final factory = PaymentGatewayFactory(
        config: fullConfig(),
        mapper: mapper,
        apiConfig: _apiConfig,
      );
      for (final String currency in <String>['GHS', 'USD', 'GBP']) {
        final gateway = factory.resolveForCurrency(currency);
        expect(
          gateway.provider,
          PaymentProvider.flutterwave,
          reason: '$currency should route to flutterwave',
        );
      }
    });

    test('routes NGN to flutterwave when it is the default provider', () {
      final source = paymentEnvSource(
        overrides: <String, String>{
          'HIVORR_PAYMENT_DEFAULT_PROVIDER': 'flutterwave',
        },
      );
      final factory = PaymentGatewayFactory(
        config: PaymentGatewayConfig.fromEnvironment(source),
        mapper: mapper,
        apiConfig: _apiConfig,
      );
      final gateway = factory.resolveForCurrency('NGN');
      expect(gateway.provider, PaymentProvider.flutterwave);
    });

    test('returns the abstract PaymentGateway type', () {
      final factory = PaymentGatewayFactory(
        config: fullConfig(),
        mapper: mapper,
        apiConfig: _apiConfig,
      );
      final PaymentGateway gateway = factory.resolveForCurrency('GHS');
      expect(gateway, isA<FlutterwaveGateway>());
    });
  });

  group('resolveForCurrency fallback branches', () {
    PaymentGatewayFactory factoryWith({
      required String paystackSecret,
      required String flutterwaveSecret,
      PaymentProvider defaultProvider = PaymentProvider.paystack,
    }) {
      final config = PaymentGatewayConfig(
        paystackPublicKey: 'pk',
        paystackSecretKey: paystackSecret,
        flutterwavePublicKey: 'fk',
        flutterwaveSecretKey: flutterwaveSecret,
        defaultProvider: defaultProvider,
      );
      return PaymentGatewayFactory(
        config: config,
        mapper: mapper,
        apiConfig: _apiConfig,
      );
    }

    test('falls back to paystack when the flutterwave secret is absent', () {
      final factory = factoryWith(paystackSecret: 'sk', flutterwaveSecret: '');
      expect(factory.resolveForCurrency('USD').provider, PaymentProvider.paystack);
    });

    test('falls back to flutterwave when the paystack secret is absent', () {
      final factory = factoryWith(paystackSecret: '', flutterwaveSecret: 'fw');
      expect(factory.resolveForCurrency('NGN').provider, PaymentProvider.flutterwave);
    });

    test('creates the default provider when no secret is configured', () {
      final factory = factoryWith(paystackSecret: '', flutterwaveSecret: '');
      expect(factory.resolveForCurrency('NGN').provider, PaymentProvider.paystack);
    });

    test('creates the flutterwave default when no secret is configured', () {
      final factory = factoryWith(
        paystackSecret: '',
        flutterwaveSecret: '',
        defaultProvider: PaymentProvider.flutterwave,
      );
      expect(factory.resolveForCurrency('NGN').provider, PaymentProvider.flutterwave);
    });
  });
}
