import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';

/// Typed, immutable configuration for the payment gateway layer.
///
/// Secrets (`paystackSecretKey`, `flutterwaveSecretKey`, `nibssApiKey`) are
/// sourced **only** from an [EnvironmentValueSource] — never from inline
/// `String.fromEnvironment` in adapters — and are rejected when empty or
/// placeholder. [toString] redacts every secret (EP-02-09 §5.6, §12).
class PaymentGatewayConfig {
  const PaymentGatewayConfig({
    required this.paystackPublicKey,
    required this.paystackSecretKey,
    required this.flutterwavePublicKey,
    required this.flutterwaveSecretKey,
    this.nibssBaseUrl,
    this.nibssApiKey,
    required this.defaultProvider,
  });

  /// Paystack public (publishable) key.
  final String? paystackPublicKey;

  /// Paystack secret key — live money-movement secret.
  final String paystackSecretKey;

  /// Flutterwave public (publishable) key.
  final String? flutterwavePublicKey;

  /// Flutterwave secret key — live money-movement secret.
  final String flutterwaveSecretKey;

  /// Optional direct NIBSS name-enquiry base URL (HTTPS).
  final String? nibssBaseUrl;

  /// Optional NIBSS name-enquiry API key.
  final String? nibssApiKey;

  /// The provider used by default when no currency override applies.
  final PaymentProvider defaultProvider;

  /// Whether the Paystack secret is configured (non-empty if set).
  bool get hasPaystackSecret => paystackSecretKey.isNotEmpty;

  /// Whether the Flutterwave secret is configured (non-empty if set).
  bool get hasFlutterwaveSecret => flutterwaveSecretKey.isNotEmpty;

  /// Builds [PaymentGatewayConfig] from an [EnvironmentValueSource].
  ///
  /// Fail-closed: missing or placeholder secret keys and non-HTTPS NIBSS URLs
  /// throw [EnvironmentConfigException]. The default provider defaults to
  /// `paystack` when absent.
  static PaymentGatewayConfig fromEnvironment(EnvironmentValueSource source) {
    final paystackPublic = _readOptional(source, AppConstants.envPaystackPublicKey);
    final paystackSecret = _requireSecret(source, AppConstants.envPaystackSecretKey);
    final flutterwavePublic = _readOptional(
      source,
      AppConstants.envFlutterwavePublicKey,
    );
    final flutterwaveSecret = _requireSecret(
      source,
      AppConstants.envFlutterwaveSecretKey,
    );
    final nibssBaseUrl = _readOptional(source, AppConstants.envNibssBaseUrl);
    if (nibssBaseUrl != null) {
      _validateHttpsUrl(nibssBaseUrl);
    }
    final nibssApiKey = _readOptional(source, AppConstants.envNibssApiKey);

    final defaultProviderName = _readOptional(
      source,
      AppConstants.envPaymentDefaultProvider,
    );
    final defaultProvider = _parseProvider(defaultProviderName);

    return PaymentGatewayConfig(
      paystackPublicKey: paystackPublic,
      paystackSecretKey: paystackSecret,
      flutterwavePublicKey: flutterwavePublic,
      flutterwaveSecretKey: flutterwaveSecret,
      nibssBaseUrl: nibssBaseUrl,
      nibssApiKey: nibssApiKey,
      defaultProvider: defaultProvider,
    );
  }

  /// Reads an optional (non-required) variable, returning `null` when absent
  /// or empty.
  static String? _readOptional(
    EnvironmentValueSource source,
    String key,
  ) {
    final String? value = source.read(key);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  /// Reads and validates a required secret — empty or placeholder throws.
  static String _requireSecret(EnvironmentValueSource source, String key) {
    final String? value = _readOptional(source, key);
    if (value == null || value.isEmpty) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Required payment provider secret is missing or empty.',
      );
    }
    if (_isPlaceholder(value)) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Payment provider secret must not be a placeholder value.',
      );
    }
    return value;
  }

  /// Validates that [url] is a valid HTTPS URL with a host.
  static void _validateHttpsUrl(String url) {
    if (_isPlaceholder(url)) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envNibssBaseUrl,
        reason: 'NIBSS base URL must not be a placeholder value.',
      );
    }
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      throw EnvironmentConfigException(
        variableName: AppConstants.envNibssBaseUrl,
        reason: 'NIBSS base URL is not a valid URL.',
      );
    }
    if (uri.scheme != 'https') {
      throw EnvironmentConfigException(
        variableName: AppConstants.envNibssBaseUrl,
        reason: 'NIBSS base URL must use HTTPS.',
      );
    }
    if (uri.host.isEmpty) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envNibssBaseUrl,
        reason: 'NIBSS base URL must include a valid host.',
      );
    }
  }

  /// Known placeholder tokens that must never pass secret validation.
  static const Set<String> _placeholderTokens = <String>{
    'placeholder',
    'your_',
    'your-',
    'changeme',
    'change-me',
    'todo',
    'tbd',
    'xxx',
  };

  static bool _isPlaceholder(String value) {
    final String lower = value.toLowerCase();
    for (final String token in _placeholderTokens) {
      if (lower.contains(token)) {
        return true;
      }
    }
    return false;
  }

  static PaymentProvider _parseProvider(String? name) {
    if (name == null || name.isEmpty) {
      return PaymentProvider.paystack;
    }
    return switch (name.trim().toLowerCase()) {
      'flutterwave' => PaymentProvider.flutterwave,
      _ => PaymentProvider.paystack,
    };
  }

  @override
  String toString() {
    return 'PaymentGatewayConfig('
        'paystackPublicKey: ${paystackPublicKey == null ? '[unset]' : '[redacted]'}, '
        'paystackSecretKey: [redacted], '
        'flutterwavePublicKey: ${flutterwavePublicKey == null ? '[unset]' : '[redacted]'}, '
        'flutterwaveSecretKey: [redacted], '
        'nibssBaseUrl: ${nibssBaseUrl == null ? 'null' : _redactUrl(nibssBaseUrl!)}, '
        'nibssApiKey: ${nibssApiKey == null ? 'null' : '[redacted]'}, '
        'defaultProvider: $defaultProvider)';
  }

  /// Redacts the path/host of a NIBSS URL while keeping its scheme visible.
  static String _redactUrl(String url) {
    final Uri uri = Uri.parse(url);
    return '${uri.scheme}://[redacted]';
  }
}
