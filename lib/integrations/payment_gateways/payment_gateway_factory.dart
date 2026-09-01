import 'package:dio/dio.dart';

import 'package:hivorr/core/api/api_client/api_client_factory.dart';
import 'package:hivorr/core/api/api_client/logging_interceptor.dart';
import 'package:hivorr/core/api/api_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/api/logging/api_log_sink.dart';
import 'package:hivorr/integrations/payment_gateways/flutterwave_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/paystack_gateway.dart';

/// Creates and selects [PaymentGateway] adapters per provider or currency.
///
/// No singleton global — the factory is injected and supports per-environment
/// provider enablement. `systems/finance/` interacts only with the returned
/// [PaymentGateway] abstract type; the concrete adapter is never referenced
/// by consumers (Open/Closed for EP-08).
///
/// ## Extensibility
/// [resolveForCurrency] is the extension point: adding `Thunes`/mobile money/
/// stablecoin (EP-02:197) is a new enum value + branch here, with zero change
/// in `lib/systems/finance/`.
class PaymentGatewayFactory {
  PaymentGatewayFactory({
    required this.config,
    required this.mapper,
    required this.apiConfig,
    this.logSink,
  });

  /// Provider configuration (secrets, default provider).
  final PaymentGatewayConfig config;

  /// Mapper used to normalize transport failures.
  final ApiExceptionMapper mapper;

  /// Transport timeouts and retry policy for provider connections.
  final ApiConfig apiConfig;

  /// Optional sink for secret-free provider request logging.
  final ApiLogSink? logSink;

  /// Creates a [PaymentGateway] for [provider] with its own `Dio`.
  PaymentGateway create(PaymentProvider provider) {
    return switch (provider) {
      PaymentProvider.paystack => PaystackGateway(
        dio: _providerDio(PaystackGateway.baseUrl, config.paystackSecretKey),
        mapper: mapper,
        config: config,
      ),
      PaymentProvider.flutterwave => FlutterwaveGateway(
        dio: _providerDio(
          FlutterwaveGateway.baseUrl,
          config.flutterwaveSecretKey,
        ),
        mapper: mapper,
        config: config,
      ),
    };
  }

  /// Resolves a [PaymentGateway] for [currency], preferring the network's
  /// default provider when its secret is configured and falling back to
  /// Flutterwave (EP-02-09 §5.7).
  ///
  /// - `NGN` (and the environment default) → Paystack when available.
  /// - Anything else (e.g. `GHS`, `USD`) → Flutterwave.
  PaymentGateway resolveForCurrency(String currency, {String? region}) {
    final PaymentProvider preferred = _preferredForCurrency(currency);
    final bool paystackReady =
        preferred == PaymentProvider.paystack && config.hasPaystackSecret;
    final bool flutterwaveReady =
        preferred == PaymentProvider.flutterwave &&
        config.hasFlutterwaveSecret;

    if (paystackReady) return create(PaymentProvider.paystack);
    if (flutterwaveReady) return create(PaymentProvider.flutterwave);

    // Fall back to whichever provider has a secret configured.
    if (config.hasPaystackSecret) return create(PaymentProvider.paystack);
    if (config.hasFlutterwaveSecret) {
      return create(PaymentProvider.flutterwave);
    }
    // Environment default when no currency-specific routing applies.
    return create(config.defaultProvider);
  }

  /// Determines the ideal provider for [currency] (Paystack for NGN, else
  /// Flutterwave). `region` is reserved for future geo-routing (e.g. GHS→
  /// Flutterwave) and currently unused.
  PaymentProvider _preferredForCurrency(String currency) {
    if (currency == 'NGN') {
      return config.defaultProvider == PaymentProvider.flutterwave
          ? PaymentProvider.flutterwave
          : PaymentProvider.paystack;
    }
    return PaymentProvider.flutterwave;
  }

  /// Builds a provider-scoped `Dio` with `baseUrl`, timeouts from [ApiConfig],
  /// the provider `Bearer` secret, and a secret-free [LoggingInterceptor].
  Dio _providerDio(String baseUrl, String secret) {
    final Dio dio = ApiClientFactory.create(
      baseUrl: baseUrl,
      config: apiConfig,
      interceptors: <Interceptor>[
        if (logSink != null) LoggingInterceptor(logSink: logSink!),
      ],
    );
    dio.options.headers['Authorization'] = 'Bearer $secret';
    dio.options.headers['Content-Type'] = 'application/json';
    return dio;
  }
}
