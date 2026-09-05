import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// Thrown when no conversion rate can be served for a currency pair.
///
/// Surfaces when conversion is disabled, the pair is unsupported, or no
/// configured rate exists. The caller must not guess or derive a fallback
/// rate — the operation is blocked (fail closed).
class ConversionRateUnavailableException extends ApiException {
  const ConversionRateUnavailableException()
      : super(
          kind: ApiExceptionKind.validation,
          message:
              'No conversion rate is currently available for this currency pair.',
        );
}

/// The trusted rate seam for wallet currency conversion (EP-02-15 §5.3).
///
/// `financial_convert_currency` accepts `p_rate` **as a caller-supplied
/// input** (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1459-1500`)
/// — there is no server-side rate RPC or rate table in the frozen migration.
/// Rate integrity is therefore THE security dimension of conversion: every
/// rate passed to the RPC must originate exclusively from this seam, and a
/// UI must **never** present a "enter rate" field. The seam is the enforced
/// boundary — a user-arbitrary rate path would move funds at a
/// self-favorable price (DoD SV-01).
///
/// Open/Closed swap point: a future `ServerConversionRateSource` (server rate
/// RPC) or `ProviderConversionRateSource` (external FX feed, EP-02:406)
/// replaces [ConfigConversionRateSource] via DI with **no** repository or
/// screen change.
abstract class ConversionRateSource {
  /// Returns the current rate for `fromCurrency`→`toCurrency`
  /// (units of `to` per unit of `from`, so `toAmount = fromAmount * rate`).
  ///
  /// Always returns a positive double. Throws
  /// [ConversionRateUnavailableException] when the pair has no configured
  /// rate. No I/O for the default implementation (guarded `Map` lookup).
  Future<double> rateFor({
    required String fromCurrency,
    required String toCurrency,
  });
}

/// The default, data-driven [ConversionRateSource].
///
/// Rates come exclusively from a single guarded config source
/// ([WalletConversionPairsConfig]) — never from user input. Base pairs are
/// looked up directly; inverse pairs are derived via the guarded reciprocal
/// only when the base rate is positive. This is the single client rate
/// authority (DoD FV-14, §7.4).
class ConfigConversionRateSource implements ConversionRateSource {
  const ConfigConversionRateSource(this._config);

  final WalletConversionPairsConfig _config;

  @override
  Future<double> rateFor({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (!_config.enabled) {
      throw const ConversionRateUnavailableException();
    }
    final double? rate = _config.directedRate(fromCurrency, toCurrency);
    if (rate == null || rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    return rate;
  }
}