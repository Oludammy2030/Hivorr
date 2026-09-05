import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';

/// In-memory [ConversionRateSource] for provider/repository/service tests
/// (EP-02-15).
///
/// Serves scripted directed rates with call counters; set [nextError] to throw
/// [ApiException] (e.g. [ConversionRateUnavailableException]) exactly as the
/// real seam fails closed.
class FakeConversionRateSource implements ConversionRateSource {
  FakeConversionRateSource({
    Map<String, double> rates = const <String, double>{},
    this.defaultRate,
  }) : _rates = Map<String, double>.of(rates);

  final Map<String, double> _rates;
  double? defaultRate;

  ApiException? nextError;
  int rateForCallCount = 0;
  String? lastFromCurrency;
  String? lastToCurrency;

  /// Scripts the directed rate for `from|to`.
  void setRate(String from, String to, double rate) =>
      _rates['$from|$to'] = rate;

  /// Removes a scripted rate (making the pair unavailable).
  void removeRate(String from, String to) => _rates.remove('$from|$to');

  @override
  Future<double> rateFor({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    rateForCallCount++;
    lastFromCurrency = fromCurrency;
    lastToCurrency = toCurrency;
    if (nextError != null) throw nextError!;
    final double? rate = _rates['$fromCurrency|$toCurrency'] ?? defaultRate;
    if (rate == null || rate <= 0) {
      throw const ConversionRateUnavailableException();
    }
    return rate;
  }
}