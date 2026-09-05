import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/wallet/wallet_conversion_pairs_config.dart';
import 'package:hivorr/config/wallet/wallet_conversion_rates_seed.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/systems/finance/models/conversion_pair.dart';
import 'package:hivorr/systems/finance/services/conversion_rate_source.dart';

/// Unit coverage for the currency-conversion rate authority (EP-02-15 §5.3):
/// [WalletConversionPairsConfig] directed-rate derivation and
/// [ConfigConversionRateSource] fail-closed seam. This is the **single client
/// rate authority** and the security-sensitive dimension of conversion — rates
/// are never derived from user input (DoD SV-01, FV-14).
void main() {
  const WalletConversionPairsConfig enabledConfig = WalletConversionPairsConfig(
    enabled: true,
    baseCrossRates: <String, double>{
      'NGN|USD': 0.0007,
      'GHS|NGN': 1111.1111111111111,
    },
  );

  const WalletConversionPairsConfig disabledConfig = WalletConversionPairsConfig(
    enabled: false,
    baseCrossRates: <String, double>{
      'NGN|USD': 0.0007,
    },
  );

  group('WalletConversionPairsConfig.directedRate', () {
    test('returns the stored base rate for the forward direction', () {
      expect(enabledConfig.directedRate('NGN', 'USD'), 0.0007);
    });

    test('derives the inverse via the guarded reciprocal', () {
      expect(enabledConfig.directedRate('USD', 'NGN'), closeTo(1 / 0.0007, 1e-12));
    });

    test('derives the reciprocal for a lexicographically-uppercase pair',
        () {
      expect(
        enabledConfig.directedRate('NGN', 'GHS'),
        closeTo(1 / 1111.1111111111111, 1e-12),
      );
    });

    test('returns null for self-pairs', () {
      expect(enabledConfig.directedRate('NGN', 'NGN'), isNull);
    });

    test('returns null for unsupported currencies', () {
      expect(enabledConfig.directedRate('XYZ', 'USD'), isNull);
      expect(enabledConfig.directedRate('NGN', 'XYZ'), isNull);
    });

    test('returns null for non-positive base rates (never invents a fallback)',
        () {
      const WalletConversionPairsConfig bad = WalletConversionPairsConfig(
        enabled: true,
        baseCrossRates: <String, double>{'NGN|USD': 0},
      );
      expect(bad.directedRate('NGN', 'USD'), isNull);
      expect(bad.directedRate('USD', 'NGN'), isNull);
    });

    test('returns null for a missing pair', () {
      expect(enabledConfig.directedRate('GBP', 'USD'), isNull);
    });
  });

  group('WalletConversionPairsConfig.availablePairs', () {
    test('yields both directions per valid base pair when enabled', () {
      final List<ConversionPair> pairs = enabledConfig.availablePairs();
      // 2 base pairs -> 4 directed pairs.
      expect(pairs, hasLength(4));
      expect(
        pairs.map((ConversionPair p) => '${p.fromCode}|${p.toCode}').toSet(),
        <String>{
          'NGN|USD',
          'USD|NGN',
          'GHS|NGN',
          'NGN|GHS',
        },
      );
    });

    test('is empty when conversion is flag-gated off', () {
      expect(disabledConfig.availablePairs(), isEmpty);
    });

    test('skips non-positive and malformed base entries', () {
      const WalletConversionPairsConfig dirty = WalletConversionPairsConfig(
        enabled: true,
        baseCrossRates: <String, double>{
          'NGN|USD': 0.0007,
          'GHS|NGN': 0,
          'bogus-no-pipe': 2,
        },
      );
      expect(dirty.availablePairs(), hasLength(2));
    });

    test('the seeded authority exposes 12 directed pairs (6 base + 6 inverse)',
        () {
      const WalletConversionPairsConfig full = WalletConversionPairsConfig(
        enabled: true,
        baseCrossRates: WalletConversionRatesSeed.baseCrossRates,
      );
      final List<ConversionPair> pairs = full.availablePairs();

      expect(pairs, hasLength(12));
      expect(
        pairs.map((ConversionPair p) => '${p.fromCode}|${p.toCode}').toSet(),
        <String>{
          'NGN|USD',
          'USD|NGN',
          'GHS|NGN',
          'NGN|GHS',
          'NGN|GBP',
          'GBP|NGN',
          'GHS|USD',
          'USD|GHS',
          'GHS|GBP',
          'GBP|GHS',
          'USD|GBP',
          'GBP|USD',
        },
      );
      expect(
        pairs.where((ConversionPair p) => p.fromCode == p.toCode),
        isEmpty,
      );
    });
  });

  group('ConfigConversionRateSource', () {
    test('returns the configured rate when enabled and supported', () async {
      final ConfigConversionRateSource source =
          ConfigConversionRateSource(enabledConfig);
      expect(await source.rateFor(fromCurrency: 'NGN', toCurrency: 'USD'), 0.0007);
    });

    test('fails closed with ConversionRateUnavailableException when disabled',
        () async {
      final ConfigConversionRateSource source =
          ConfigConversionRateSource(disabledConfig);
      await expectLater(
        source.rateFor(fromCurrency: 'NGN', toCurrency: 'USD'),
        throwsA(isA<ConversionRateUnavailableException>()),
      );
    });

    test('fails closed for unsupported/self/missing pairs', () async {
      final ConfigConversionRateSource source =
          ConfigConversionRateSource(enabledConfig);
      await expectLater(
        source.rateFor(fromCurrency: 'GBP', toCurrency: 'USD'),
        throwsA(isA<ConversionRateUnavailableException>()),
      );
      await expectLater(
        source.rateFor(fromCurrency: 'NGN', toCurrency: 'NGN'),
        throwsA(isA<ConversionRateUnavailableException>()),
      );
    });

    test('the unavailable exception is a validation ApiException', () {
      const ConversionRateUnavailableException e =
          ConversionRateUnavailableException();
      expect(e.kind, ApiExceptionKind.validation);
    });
  });
}