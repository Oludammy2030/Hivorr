import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/integrations/kyc/kyc_provider_registry.dart';
import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/integrations/kyc/mock_kyc_provider.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

void main() {
  group('MockKycProvider', () {
    test('reports providerName = mock', () {
      expect(MockKycProvider().providerName, 'mock');
    });

    test('records the verify arguments for assertion', () async {
      final mock = MockKycProvider(
        result: const KycVerificationResult(status: 'approved'),
      );
      final result = await mock.verify(
        entityId: 'u1',
        targetTier: KycTier.tier1,
        payload: <String, dynamic>{'bvn': '12345678901'},
      );

      expect(mock.lastEntityId, 'u1');
      expect(mock.lastTargetTier, KycTier.tier1);
      expect(mock.lastPayload!['bvn'], '12345678901');
      expect(result.status, 'approved');
      expect(result.isApproved, isTrue);
    });

    test('defaults to a pending result', () async {
      final mock = MockKycProvider();
      final result =
          await mock.verify(entityId: 'u1', targetTier: KycTier.tier2);
      expect(result.status, 'pending');
      expect(result.isPending, isTrue);
      expect(result.isApproved, isFalse);
    });

    test('setResult overrides subsequent calls', () async {
      final mock = MockKycProvider();
      mock.setResult(const KycVerificationResult(status: 'rejected'));
      final result =
          await mock.verify(entityId: 'u1', targetTier: KycTier.tier1);
      expect(result.status, 'rejected');
      expect(result.isApproved, isFalse);
      expect(result.isPending, isFalse);
    });

    test('supports an approved result with a provider reference', () async {
      final mock = MockKycProvider(
        result: const KycVerificationResult(
          status: 'approved',
          providerReference: 'ref_123',
        ),
      );
      final result =
          await mock.verify(entityId: 'u1', targetTier: KycTier.tier1);
      expect(result.status, 'approved');
      expect(result.isApproved, isTrue);
      expect(result.providerReference, 'ref_123');
    });
  });

  group('KycProviderRegistry', () {
    test('hasProvider is false when no provider configured', () {
      expect(KycProviderRegistry().hasProvider, isFalse);
    });

    test('hasProvider is true with a primary', () {
      final registry = KycProviderRegistry(primary: MockKycProvider());
      expect(registry.hasProvider, isTrue);
    });

    test('hasProvider is true with fallbacks only', () {
      final registry = KycProviderRegistry(
        fallbacks: <MockKycProvider>[MockKycProvider()],
      );
      expect(registry.hasProvider, isTrue);
    });

    test('resolveForTier returns null when empty', () {
      expect(KycProviderRegistry().resolveForTier(KycTier.tier1), isNull);
    });

    test('resolveForTier returns the primary provider', () {
      final primary = MockKycProvider();
      final registry = KycProviderRegistry(primary: primary);
      expect(registry.resolveForTier(KycTier.tier1), same(primary));
    });

    test('resolveForTier ignores fallbacks when a primary is present', () {
      final primary = MockKycProvider();
      final fallback = MockKycProvider();
      final registry = KycProviderRegistry(
        primary: primary,
        fallbacks: <MockKycProvider>[fallback],
      );
      expect(registry.resolveForTier(KycTier.tier3), same(primary));
    });

    test('resolveForTier returns null when only fallbacks exist', () {
      final registry = KycProviderRegistry(
        fallbacks: <MockKycProvider>[MockKycProvider()],
      );
      expect(
        registry.resolveForTier(KycTier.tier2),
        isNull,
        reason: 'fallbacks are reserved for EP-08 per-tier routing',
      );
    });
  });
}
