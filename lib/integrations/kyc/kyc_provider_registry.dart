// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/integrations/kyc/kyc_provider.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Registry for external KYC verification providers (EP-02-12 §5.6).
///
/// Resolves the [KycVerificationProvider] responsible for a target tier —
/// extensible per-tier routing for future providers (EP-08). The default
/// resolver returns the [primary] provider for every tier.
class KycProviderRegistry {
  KycProviderRegistry({
    KycVerificationProvider? primary,
    List<KycVerificationProvider> fallbacks = const <KycVerificationProvider>[],
  })  : _primary = primary,
        _fallbacks = List<KycVerificationProvider>.of(fallbacks);

  final KycVerificationProvider? _primary;
  final List<KycVerificationProvider> _fallbacks;

  /// Whether at least one provider is available.
  bool get hasProvider => _primary != null || _fallbacks.isNotEmpty;

  /// Resolves the provider for [tier].
  ///
  /// Returns `null` when no provider is configured. The base implementation
  /// routes every tier to [primary] (fallbacks reserved for EP-08 routing).
  KycVerificationProvider? resolveForTier(KycTier tier) => _primary;
}
