import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_entry.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:hivorr/systems/verification/services/kyc_service.dart';

import '../../../support/fakes/fake_kyc_remote_data_source.dart';
import '../../../support/fakes/fake_logging.dart';

void main() {
  KycService build(FakeKycRemoteDataSource remote, {HivorrLogger? logger}) =>
      KycService(
        repo: KycRepositoryImpl(remote: remote, logger: logger),
        logger: logger,
      );

  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );

  group('KycService.supportedTiers', () {
    test('exposes the full tier vocabulary', () {
      final service = build(FakeKycRemoteDataSource());
      expect(service.supportedTiers,
          <KycTier>[KycTier.tier0, KycTier.tier1, KycTier.tier2, KycTier.tier3]);
    });
  });

  group('KycService reads', () {
    test('getKycLevel delegates to the repository', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      final service = build(remote);

      final KycLevel level = await service.getKycLevel();

      expect(level.tierCode, 'tier_1');
      expect(remote.kycCallCount, 1);
    });

    test('getLimits delegates to the repository', () async {
      final remote = FakeKycRemoteDataSource(
        limitsResult: seedKycLimitsDto(cashout: 100000),
      );
      final service = build(remote);

      final limits = await service.getLimits();

      expect(limits.cashout, 100000);
      expect(remote.limitsCallCount, 1);
    });

    test('getStatus delegates to the repository', () async {
      final remote = FakeKycRemoteDataSource(
        statusResult: seedKycStatusDto(tierCode: 'tier_1'),
      );
      final service = build(remote);

      final status = await service.getStatus();

      expect(status.identityVerified, isFalse);
      expect(remote.statusCallCount, 1);
    });
  });

  group('KycService.requestUpgrade', () {
    test('delegates an upgrade and returns the resulting level', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      final service = build(remote);

      final KycLevel next =
          await service.requestUpgrade(targetTier: KycTier.tier1);

      expect(next.tierCode, 'tier_0');
    });

    test('surfaces a validation ApiException from the repository', () async {
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      final service = build(remote);

      await expectLater(
        service.requestUpgrade(targetTier: KycTier.tier1),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)),
      );
    });

    test('rethrows a server error from the repository', () async {
      final remote = FakeKycRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'down',
        );
      final service = build(remote);

      await expectLater(
        service.requestUpgrade(targetTier: KycTier.tier1),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
      );
    });
  });

  group('KycService structured logging', () {
    test('logs success and failure through the injected logger', () async {
      final sink = RecordingSink();
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_1', status: 'active'),
      );
      final service = build(remote, logger: makeLogger(sink));

      await expectLater(
        service.requestUpgrade(targetTier: KycTier.tier1),
        throwsA(isA<ApiException>()),
      );

      final messages =
          sink.entries.map((LogEntry e) => e.message).toList();
      expect(messages.any((String m) => m.contains('KYC upgrade requested')),
          isTrue);
      expect(messages.any((String m) => m.contains('KYC upgrade failed')),
          isTrue);
    });

    test('logs the resolved outcome on a successful upgrade', () async {
      final sink = RecordingSink();
      final remote = FakeKycRemoteDataSource(
        kycResult: seedKycDto(tierCode: 'tier_0', status: 'pending'),
      );
      final service = build(remote, logger: makeLogger(sink));

      await service.requestUpgrade(targetTier: KycTier.tier1);

      final messages =
          sink.entries.map((LogEntry e) => e.message).toList();
      expect(messages.any((String m) => m.contains('KYC upgrade resolved')),
          isTrue);
    });

    test('logs a failing read via the tracel catch path', () async {
      final sink = RecordingSink();
      final remote = FakeKycRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
        );
      final service = build(remote, logger: makeLogger(sink));

      await expectLater(
        service.getKycLevel(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.server)),
      );

      final messages =
          sink.entries.map((LogEntry e) => e.message).toList();
      expect(messages.any((String m) => m.contains('kyc.level.get failed')),
          isTrue);
    });
  });
}
