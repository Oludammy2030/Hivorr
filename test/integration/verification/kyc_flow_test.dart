import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/notifications/models/notification_permission_status.dart';
import 'package:hivorr/core/notifications/permission/notification_permission_manager.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/datasources/remote/supabase_kyc_remote_data_source.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/integrations/kyc/kyc_provider_registry.dart';
import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/integrations/kyc/mock_kyc_provider.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:hivorr/systems/verification/services/kyc_limit_guard.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_logging.dart';
import '../../support/fakes/fake_notifications.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

/// KYC fake-E2E flow (TT-14): the REAL datasource + repository + provider
/// registry + in-memory MockKycProvider run the whole
/// load → upgrade → poll → notification lifecycle against a scripted Supabase
/// transport. Only the transport is scripted (MutableKycServer); no RPC logic
/// is faked.
void main() {
  /// Scripted "server" — the single source of truth for the current KYC level.
  /// Simulates admin-driven approval by flipping [tierCode] out from under the
  /// client, exactly as Supabase would after `verification_review_approve`.
  String tierCode = 'tier_0';
  String status = 'pending';

  Map<String, dynamic> levelEnvelope() => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': <String, dynamic>{
          'tier_code': tierCode,
          'status': status,
          'limits': <String, dynamic>{
            'daily': tierCode == 'tier_1' ? 500000 : 0,
            'weekly': tierCode == 'tier_1' ? 2000000 : 0,
            'monthly': tierCode == 'tier_1' ? 8000000 : 0,
            'cashout': tierCode == 'tier_1' ? 200000 : 0,
          },
        },
      };

  Map<String, dynamic> limitsEnvelope() => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': <String, dynamic>{
          'tier_code': tierCode,
          'status': status,
          'daily': tierCode == 'tier_1' ? 500000 : 0,
          'weekly': tierCode == 'tier_1' ? 2000000 : 0,
          'monthly': tierCode == 'tier_1' ? 8000000 : 0,
          'cashout': tierCode == 'tier_1' ? 200000 : 0,
        },
      };

  Map<String, dynamic> statusEnvelope() => <String, dynamic>{
        'success': true,
        'code': 'PLT000',
        'message': 'ok',
        'data': <String, dynamic>{
          'entity_id': 'u1',
          'kyc': levelEnvelope()['data'],
          'identity_verified': tierCode != 'tier_0',
          'trade_verifications': <dynamic>[],
          'pending_submissions': 0,
          'total_submissions': 0,
        },
      };

  KycProvider buildFlow({
    required MockKycProvider mock,
    NotificationProvider? notifications,
    Duration? pollInterval,
  }) {
    final client = MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
        'verification_kyc_level_get': (_) => levelEnvelope(),
        'verification_limits_get': (_) => limitsEnvelope(),
        'verification_status_get': (_) => statusEnvelope(),
      },
    );
    final SupabaseKycRemoteDataSource remote = SupabaseKycRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final KycRepositoryImpl repository = KycRepositoryImpl(
      remote: remote,
      providerRegistry: KycProviderRegistry(primary: mock),
      logger: HivorrLogger(
        'kyc-flow',
        LogRouter(sinks: <LogSink>[RecordingSink()], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      ),
    );
    return KycProvider(
      repo: repository,
      logger: HivorrLogger(
        'kyc-flow-provider',
        LogRouter(sinks: <LogSink>[RecordingSink()], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      ),
      notificationProvider: notifications,
      pollInterval: pollInterval,
    );
  }

  test('tier_0 loads with no limits (server-authoritative)', () async {
    final MockKycProvider mock = MockKycProvider();
    final KycProvider provider = buildFlow(mock: mock);

    await provider.refreshStatus();

    expect(provider.currentTier, KycTier.tier0);
    expect(provider.kycLevel!.limits.cashout, 0);
    provider.dispose();
  });

  test('requestUpgrade routes through the provider seam and returns current '
      'level while pending (no local grant)', () async {
    final MockKycProvider mock = MockKycProvider();
    final KycProvider provider = buildFlow(mock: mock);
    await provider.refreshStatus();

    final KycLevel? next = await provider.requestUpgrade(targetTier: KycTier.tier1);

    expect(mock.lastEntityId, 'u1');
    expect(mock.lastTargetTier, KycTier.tier1);
    expect(provider.currentTier, KycTier.tier0); // no server grant yet
    expect(next!.tierCode, 'tier_0'); // level unchanged while pending
    provider.dispose();
  });

  test('requestUpgrade still surfaces guidance when no provider is configured',
      () async {
    // Providerless registry → repository logs guidance, level unchanged.
    final client = MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: <String, Object? Function(Map<String, dynamic>)>{
        'verification_kyc_level_get': (_) => levelEnvelope(),
        'verification_status_get': (_) => statusEnvelope(),
      },
    );
    final SupabaseKycRemoteDataSource remote = SupabaseKycRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final KycRepositoryImpl repository = KycRepositoryImpl(remote: remote);
    final KycProvider provider = KycProvider(repo: repository);
    await provider.refreshStatus();

    await provider.requestUpgrade(targetTier: KycTier.tier1);

    expect(provider.currentTier, KycTier.tier0);
    provider.dispose();
  });

  test('server approval → refreshStatus → tier_1 + limits unlock', () async {
    final MockKycProvider mock = MockKycProvider();
    final KycProvider provider = buildFlow(mock: mock);
    await provider.refreshStatus();
    expect(provider.currentTier, KycTier.tier0);

    // Admin approves on the server; the level flips out from under the client.
    tierCode = 'tier_1';
    status = 'active';
    mock.setResult(const KycVerificationResult(status: 'approved'));

    await provider.refreshStatus();

    expect(provider.currentTier, KycTier.tier1);
    expect(provider.kycLevel!.limits.cashout, 200000);
    provider.dispose();
  });

  test('KycLimitGuard enforces the approved tier limits end-to-end', () async {
    final MockKycProvider mock = MockKycProvider();
    final KycProvider provider = buildFlow(mock: mock);
    await provider.refreshStatus();
    tierCode = 'tier_1';
    status = 'active';
    mock.setResult(const KycVerificationResult(status: 'approved'));
    await provider.refreshStatus();
    provider.dispose();

    final KycLimits limits = provider.kycLevel!.limits;
    expect(KycLimitGuard.isCashoutAllowed(limits: limits, amount: 150000), isTrue);
    expect(KycLimitGuard.isCashoutAllowed(limits: limits, amount: 250000), isFalse);
  });

  test('polling on the real stack resolves pending → active, stops, and '
      'notifies', () {
    fakeAsync((FakeAsync async) {
      final MockKycProvider mock = MockKycProvider();
      final FakeNotificationService service = FakeNotificationService();
      final NotificationProvider notifications = NotificationProvider(
        service,
        NotificationPermissionManager(
          platform: FakeNotificationPermissionPlatform(
            nextStatus: NotificationPermissionStatus.granted,
          ),
        ),
      );
      final KycProvider provider = buildFlow(
        mock: mock,
        notifications: notifications,
        pollInterval: const Duration(seconds: 15),
      );
      provider.startPolling();

      // Server starts pending at tier_0.
      tierCode = 'tier_0';
      status = 'pending';

      // First tick sees pending and keeps polling.
      async.elapse(const Duration(seconds: 15));
      expect(provider.currentTier, KycTier.tier0);

      // Admin approves the tier server-side; next tick observes tier_1.
      tierCode = 'tier_1';
      status = 'active';
      mock.setResult(const KycVerificationResult(status: 'approved'));

      async.elapse(const Duration(seconds: 15));
      expect(provider.currentTier, KycTier.tier1);

      // Timer cancels on the terminal tier and the upgrade notification fires.
      async.elapse(const Duration(seconds: 60));
      expect(service.shown, hasLength(1));
      expect(service.shown.single.title, contains('Verification upgraded'));
      provider.dispose();
    });
  });
}
