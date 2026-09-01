import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';

import 'payment_env_source.dart';

void main() {
  group('PaymentGatewayConfig.fromEnvironment', () {
    test('reads paystack and flutterwave secrets from the source', () {
      final config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
      expect(config.paystackSecretKey, 'sk_test_abc123');
      expect(config.paystackPublicKey, 'pk_test_abc123');
      expect(config.flutterwaveSecretKey, 'FLWSECK_TEST_abc123');
      expect(config.flutterwavePublicKey, 'FLWPUBK_TEST_abc123');
      expect(config.defaultProvider, PaymentProvider.paystack);
    });

    test('defaults default provider to paystack when absent', () {
      final source = paymentEnvSource(
        overrides: <String, String>{
          AppConstants.envPaymentDefaultProvider: '',
        },
      );
      final config = PaymentGatewayConfig.fromEnvironment(source);
      expect(config.defaultProvider, PaymentProvider.paystack);
    });

    test('parses flutterwave as the default provider', () {
      final source = paymentEnvSource(
        overrides: <String, String>{
          AppConstants.envPaymentDefaultProvider: 'flutterwave',
        },
      );
      final config = PaymentGatewayConfig.fromEnvironment(source);
      expect(config.defaultProvider, PaymentProvider.flutterwave);
    });

    test('unknown default provider falls back to paystack', () {
      final source = paymentEnvSource(
        overrides: <String, String>{
          AppConstants.envPaymentDefaultProvider: 'nonsense',
        },
      );
      final config = PaymentGatewayConfig.fromEnvironment(source);
      expect(config.defaultProvider, PaymentProvider.paystack);
    });

    test('reads nibss base url and api key when present', () {
      final source = paymentEnvSource(
        overrides: <String, String>{
          AppConstants.envNibssBaseUrl: 'https://nibss.example.com',
          AppConstants.envNibssApiKey: 'nibss-secret',
        },
      );
      final config = PaymentGatewayConfig.fromEnvironment(source);
      expect(config.nibssBaseUrl, 'https://nibss.example.com');
      expect(config.nibssApiKey, 'nibss-secret');
    });

    test('leaves nibss fields null when absent', () {
      final config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
      expect(config.nibssBaseUrl, isNull);
      expect(config.nibssApiKey, isNull);
    });

    test('rejects an empty paystack secret', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envPaystackSecretKey: '',
            },
          ),
        ),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('rejects a placeholder paystack secret', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envPaystackSecretKey: 'sk_test_placeholder',
            },
          ),
        ),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('rejects an empty flutterwave secret', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envFlutterwaveSecretKey: '',
            },
          ),
        ),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('rejects a placeholder flutterwave secret', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envFlutterwaveSecretKey: 'FLWSECK_TEST_changeme',
            },
          ),
        ),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('rejects a non-HTTPS NIBSS base url', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envNibssBaseUrl: 'http://nibss.example.com',
            },
          ),
        ),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('rejects a placeholder NIBSS base url', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envNibssBaseUrl: 'https://nibss.example.com/todo',
            },
          ),
        ),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('rejects a malformed NIBSS base url that fails URL parsing', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envNibssBaseUrl: 'http://[::1',
            },
          ),
        ),
        throwsA(
          isA<EnvironmentConfigException>().having(
            (e) => e.reason,
            'reason',
            contains('not a valid URL'),
          ),
        ),
      );
    });

    test('rejects a NIBSS base url with an empty host', () {
      expect(
        () => PaymentGatewayConfig.fromEnvironment(
          paymentEnvSource(
            overrides: <String, String>{
              AppConstants.envNibssBaseUrl: 'https:/only-path',
            },
          ),
        ),
        throwsA(
          isA<EnvironmentConfigException>().having(
            (e) => e.reason,
            'reason',
            contains('valid host'),
          ),
        ),
      );
    });
  });

  group('PaymentGatewayConfig.toString', () {
    test('redacts every secret value', () {
      final config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
      final String desc = config.toString();
      expect(desc.contains('sk_test_abc123'), isFalse);
      expect(desc.contains('FLWSECK_TEST_abc123'), isFalse);
      expect(desc, contains('[redacted]'));
    });

    test('redacts the NIBSS URL host', () {
      final config = PaymentGatewayConfig.fromEnvironment(
        paymentEnvSource(
          overrides: <String, String>{
            AppConstants.envNibssBaseUrl: 'https://nibss.example.com',
            AppConstants.envNibssApiKey: 'nibss-secret',
          },
        ),
      );
      final String desc = config.toString();
      expect(desc.contains('nibss.example.com'), isFalse);
      expect(desc.contains('nibss-secret'), isFalse);
      expect(desc, contains('[redacted]'));
    });
  });

  group('PaymentGatewayConfig secret flags', () {
    test('hasPaystackSecret / hasFlutterwaveSecret reflect config', () {
      final config = PaymentGatewayConfig.fromEnvironment(paymentEnvSource());
      expect(config.hasPaystackSecret, isTrue);
      expect(config.hasFlutterwaveSecret, isTrue);
    });
  });
}
