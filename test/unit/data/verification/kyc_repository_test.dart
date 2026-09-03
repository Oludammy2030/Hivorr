import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/integrations/kyc/kyc_provider_registry.dart';
import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/integrations/kyc/mock_kyc_provider.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

import '../../../support/fakes/fake_kyc_remote_data_source.dart';
import '../../../support/fakes/fake_logging.dart';

void main() {
  KycRepositoryImpl build({
    FakeKycRemoteDataSource? remote,
    KycProviderRegistry? registry,
    HivorrLogger? logger,
  }) =>
      KycRepositoryImpl(
        remote: remote ?? FakeKycRemoteDataSource(),
        providerRegistry: registry,
        logger: logger,
      );

  group('KycRepository.getKycLevel', () {
    test('maps the remote KycLevelDto to a domain KycLevel', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(
          tierCode: 'tier_1',
          status: 'active',
          daily: 500000,
          weekly: 2000000,
          monthly: 8000000,
          cashout: 1000000,
        ),
      );
      final repo = build(remote: remote);

      final KycLevel level = await repo.getKycLevel();

      expect(remote.kycCallCount, 1);
      expect(level.tierCode, 'tier_1');
      expect(level.status, 'active');
      expect(level.limits.cashout, 1000000);
      expect(level.isVerified, isTrue);
    });
  });

  group('KycRepository.getLimits', () {
    test('maps limits DTO to KycLimits', () async {
      final remote = FakeKycRemoteDataSource(
        limitsResult: seedKycLimitsDto(daily: 100, cashout: 400),
      );
      final repo = build(remote: remote);

      final KycLimits limits = await repo.getLimits();

      expect(remote.limitsCallCount, 1);
      expect(limits.daily, 100);
      expect(limits.cashout, 400);
    });

    test('maps the exact tier1 NGN limits', () async {
      final remote = FakeKycRemoteDataSource(
        limitsResult: seedKycLimitsDto(
          daily: 50000,
          weekly: 200000,
          monthly: 800000,
          cashout: 100000,
        ),
      );
      final repo = build(remote: remote);

      final KycLimits limits = await repo.getLimits();

      expect(limits.daily, 50000);
      expect(limits.weekly, 200000);
      expect(limits.monthly, 800000);
      expect(limits.cashout, 100000);
    });
  });

  group('KycRepository.getStatus', () {
    test('maps the aggregate DTO to VerificationStatus', () async {
      final remote = FakeKycRemoteDataSource(
        statusResult: seedKycStatusDto(
          tierCode: 'tier_1',
          identityVerified: true,
          total: 2,
        ),
      );
      final repo = build(remote: remote);

      final VerificationStatus status = await repo.getStatus();

      expect(remote.statusCallCount, 1);
      expect(status.entityId, 'u1');
      expect(status.identityVerified, isTrue);
      expect(status.totalSubmissions, 2);
    });
  });

  group('KycRepository.requestUpgrade', () {
    test('rejects a non-higher target before invoking the provider', () async {
      final mock = MockKycProvider(
        result: const KycVerificationResult(status: 'approved'),
      );
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      final repo = build(
        remote: remote,
        registry: KycProviderRegistry(primary: mock),
      );

      await expectLater(
        repo.requestUpgrade(targetTier: KycTier.tier1),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)
            .having((ApiException e) => e.code, 'code', 'PLT003')),
      );
      expect(mock.lastTargetTier, isNull, reason: 'provider must not be called');
    });

    test('delegates to the provider seam for an upgrade target', () async {
      final mock = MockKycProvider(
        result: const KycVerificationResult(status: 'approved'),
      );
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      final repo = build(
        remote: remote,
        registry: KycProviderRegistry(primary: mock),
      );

      final KycLevel result =
          await repo.requestUpgrade(targetTier: KycTier.tier1);

      expect(mock.lastTargetTier, KycTier.tier1);
      expect(mock.lastEntityId, 'u1');
      expect(result.tierCode, 'tier_0', reason: 'no server approval re-read here');
    });

    test('returns current level unchanged when no provider is configured', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      final repo = build(remote: remote);

      final KycLevel result =
          await repo.requestUpgrade(targetTier: KycTier.tier1);

      expect(result.tierCode, 'tier_0');
      expect(remote.kycCallCount, 1);
    });

    test('rejects an equal target tier with PLT003 before the provider', () async {
      final mock = MockKycProvider();
      final repo = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_2', status: 'active'),
        ),
        registry: KycProviderRegistry(primary: mock),
      );

      await expectLater(
        repo.requestUpgrade(targetTier: KycTier.tier2),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)
            .having((ApiException e) => e.code, 'code', 'PLT003')),
      );
      expect(mock.lastTargetTier, isNull, reason: 'equal target must not reach provider');
    });

    test('forwards a payload to the provider seam', () async {
      final mock = MockKycProvider(
        result: const KycVerificationResult(status: 'pending'),
      );
      final repo = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
        ),
        registry: KycProviderRegistry(primary: mock),
      );

      await repo.requestUpgrade(
        targetTier: KycTier.tier1,
        payload: <String, dynamic>{'bvn': '12345678901'},
      );

      expect(mock.lastPayload!['bvn'], '12345678901');
    });

    test('re-reads the server level when the provider approves', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      // The server authorizes the upgrade between the initial fetch (tier_0)
      // and the post-approval re-read (tier_1, active).
      remote.kycScript = <KycLevelDto>[
        seedKycDto(tierCode: 'tier_0', status: 'pending'),
        seedKycDto(tierCode: 'tier_1', status: 'active'),
      ];
      final mock = MockKycProvider(
        result: const KycVerificationResult(status: 'approved'),
      );
      final repo = build(
        remote: remote,
        registry: KycProviderRegistry(primary: mock),
      );

      final KycLevel result =
          await repo.requestUpgrade(targetTier: KycTier.tier1);

      expect(result.tierCode, 'tier_1', reason: 'approval re-reads server state');
      expect(remote.kycCallCount, 2, reason: 'initial fetch + server re-read');
    });
  });

  group('KycRepository defaults & aggregates', () {
    test('getKycLevel maps a tier0 all-zero default for unassigned', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', cashout: 0),
      );
      final repo = build(remote: remote);

      final KycLevel level = await repo.getKycLevel();

      expect(level.tierCode, 'tier_0');
      expect(level.limits.daily, 0);
      expect(level.limits.cashout, 0);
      expect(level.isVerified, isFalse);
    });

    test('getStatus maps an empty trade-verification array for KYC-only', () async {
      final remote = FakeKycRemoteDataSource(
        statusResult: seedKycStatusDto(),
      );
      final repo = build(remote: remote);

      final VerificationStatus status = await repo.getStatus();

      expect(status.tradeVerifications, isEmpty);
      expect(status.kycLevel.tierCode, 'tier_0');
      expect(status.identityVerified, isFalse);
    });
  });

  group('KycRepository.eligibleUpgradePath', () {
    test('tier0 exposes tier1..tier3', () {
      final repo = build();
      final level = KycLevel(
        tierCode: 'tier_0',
        status: 'pending',
        limits: const KycLimits(daily: 0, weekly: 0, monthly: 0, cashout: 0),
      );
      expect(repo.eligibleUpgradePath(level),
          <KycTier>[KycTier.tier1, KycTier.tier2, KycTier.tier3]);
    });

    test('tier1 exposes tier2 and tier3', () {
      final repo = build();
      final level = KycLevel(
        tierCode: 'tier_1',
        status: 'active',
        limits: const KycLimits(
          daily: 50000, weekly: 200000, monthly: 800000, cashout: 100000),
      );
      expect(repo.eligibleUpgradePath(level),
          <KycTier>[KycTier.tier2, KycTier.tier3]);
    });

    test('tier2 exposes only tier3', () {
      final repo = build();
      final level = KycLevel(
        tierCode: 'tier_2',
        status: 'active',
        limits: const KycLimits(
          daily: 200000, weekly: 800000, monthly: 3000000, cashout: 500000),
      );
      expect(repo.eligibleUpgradePath(level), <KycTier>[KycTier.tier3]);
    });

    test('tier3 exposes none', () {
      final repo = build();
      final level = KycLevel(
        tierCode: 'tier_3',
        status: 'active',
        limits: const KycLimits(
          daily: 1000000, weekly: 4000000, monthly: 15000000, cashout: 2000000),
      );
      expect(repo.eligibleUpgradePath(level), isEmpty);
    });
  });

  group('KycRepository structured logging', () {
    test('logs provider delegation when a logger is injected', () async {
      final sink = RecordingSink();
      final logger = HivorrLogger(
        'hivorr.test',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );
      final repo = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
        ),
        registry: KycProviderRegistry(
          primary: MockKycProvider(
            result: const KycVerificationResult(status: 'pending'),
          ),
        ),
        logger: logger,
      );

      await repo.requestUpgrade(targetTier: KycTier.tier1);

      final messages = sink.entries.map((LogEntry e) => e.message).toList();
      expect(
        messages.any((String m) => m.contains('KYC upgrade delegated')),
        isTrue,
      );
    });

    test('logs guidance when no provider is configured', () async {
      final sink = RecordingSink();
      final logger = HivorrLogger(
        'hivorr.test',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );
      final repo = build(
        remote: FakeKycRemoteDataSource(
          kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
        ),
        logger: logger,
      );

      await repo.requestUpgrade(targetTier: KycTier.tier1);

      final messages = sink.entries.map((LogEntry e) => e.message).toList();
      expect(
        messages.any((String m) => m.contains('KYC upgrade without provider')),
        isTrue,
      );
    });
  });
}
