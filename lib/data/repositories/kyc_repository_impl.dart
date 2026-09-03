// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/datasources/remote/kyc_remote_data_source.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/mappers/verification_mapper.dart';
import 'package:hivorr/data/repositories/kyc_repository.dart';
import 'package:hivorr/integrations/kyc/kyc_provider_registry.dart';
import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Default implementation of [KycRepository].
///
/// Reads KYC state exclusively through the KYC RPCs (never direct table writes)
/// and delegates upgrades to the configured external provider seam before
/// re-reading the server-authoritative level (EP-02-12 §5.3).
class KycRepositoryImpl implements KycRepository {
  /// Creates the repository from its datasource, provider registry, and logger.
  KycRepositoryImpl({
    required KycRemoteDataSource remote,
    KycProviderRegistry? providerRegistry,
    HivorrLogger? logger,
  })  : _remote = remote,
        _providerRegistry = providerRegistry,
        _logger = logger;

  final KycRemoteDataSource _remote;
  final KycProviderRegistry? _providerRegistry;
  final HivorrLogger? _logger;

  @override
  Future<KycLevel> getKycLevel() async {
    final dto = await _remote.getKycLevel();
    return VerificationMapper.kycToEntity(dto);
  }

  @override
  Future<KycLimits> getLimits() async {
    final dto = await _remote.getLimits();
    return VerificationMapper.limitsToEntity(dto);
  }

  @override
  Future<VerificationStatus> getStatus() async {
    final dto = await _remote.getStatus();
    return VerificationMapper.statusToEntity(dto);
  }

  @override
  Future<KycLevel> requestUpgrade({
    required KycTier targetTier,
    Map<String, dynamic>? payload,
  }) async {
    final KycLevel current = await getKycLevel();

    // 1. Validate before any provider call (PLT003 fail-fast).
    final KycTier currentTier = KycTier.fromCode(current.tierCode);
    if (!targetTier.isAtLeast(currentTier) || targetTier == currentTier) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Upgrade target must be a higher tier than the current one.',
        code: 'PLT003',
      );
    }

    // 2. Delegate to the configured provider seam, if any.
    final KycProviderRegistry? registry = _providerRegistry;
    if (registry != null && registry.hasProvider) {
      final VerificationStatus status = await getStatus();
      final KycVerificationResult result = await registry
          .resolveForTier(targetTier)!
          .verify(
            entityId: status.entityId,
            targetTier: targetTier,
            payload: payload,
          );
      _logger?.info('KYC upgrade delegated to provider', <String, Object?>{
        'providerName': registry.resolveForTier(targetTier)!.providerName,
        'targetTier': targetTier.code,
        'status': result.status,
      });
      // Server re-reads the level after the provider signals approval.
      if (result.isApproved) {
        return getKycLevel();
      }
      return current;
    }

    // 3. No live provider — return the level unchanged with guidance.
    _logger?.info('KYC upgrade without provider — guidance surfaced',
        <String, Object?>{'targetTier': targetTier.code});
    return current;
  }

  @override
  List<KycTier> eligibleUpgradePath(KycLevel current) {
    final KycTier currentTier = KycTier.fromCode(current.tierCode);
    return <KycTier>[
      for (final KycTier tier in KycTier.values)
        if (tier.index > currentTier.index) tier,
    ];
  }
}
