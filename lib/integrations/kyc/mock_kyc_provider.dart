// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/integrations/kyc/kyc_provider.dart';
import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// In-memory [KycVerificationProvider] used for integration tests and local
/// development (EP-02-12 §5.6).
///
/// Simulates provider latency and returns a controllable outcome
/// (`pending` by default, configurable via [onVerify] or by mutating
/// [forcedStatus]). Proves the seam without live NIN/BVN credentials —
/// `EP-02:175` deferred provider selection mitigation.
class MockKycProvider implements KycVerificationProvider {
  MockKycProvider({
    KycVerificationResult? result,
  }) : _result = result;

  KycVerificationResult? _result;

  /// The last verify call payload, exposed for assertion in tests.
  Map<String, dynamic>? lastPayload;

  /// The last requested [KycTier], exposed for assertion in tests.
  KycTier? lastTargetTier;

  /// The last entity id, exposed for assertion in tests.
  String? lastEntityId;

  /// Overrides the returned result for subsequent [verify] calls.
  void setResult(KycVerificationResult result) {
    _result = result;
  }

  @override
  String get providerName => 'mock';

  @override
  Future<KycVerificationResult> verify({
    required String entityId,
    required KycTier targetTier,
    Map<String, dynamic>? payload,
  }) async {
    lastEntityId = entityId;
    lastTargetTier = targetTier;
    lastPayload = payload;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return _result ?? const KycVerificationResult(status: 'pending');
  }
}
