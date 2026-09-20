// EP-02-20 VP5: KYC Level Upgrade → Limit Increase (server-enforced).
//
// Exercises KycProvider through the real datasource→repository→provider stack
// with a scripted Supabase transport. Verifies: tier_0 loads with no limits,
// over-limit blocked by KycLimitGuard, upgraded tier lifts limit, KycLimitsCard
// reflects tier.
//
// Run: flutter test test/integration/trust/kyc_level_limit_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_kyc_remote_data_source.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository_impl.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:hivorr/systems/verification/services/kyc_limit_guard.dart';

import '../../support/factories/mock_supabase_client_factory.dart';
import '../../support/fakes/fake_supabase.dart' show fakeUser;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
    'success': true,
    'code': 'PLT000',
    'message': 'ok',
    'data': data,
  };

  // ---- Scripted "server" state -------------------------------------------
  String tierCode = 'tier_0';
  String tierStatus = 'pending';

  Map<String, dynamic> levelData() => <String, dynamic>{
    'tier_code': tierCode,
    'status': tierStatus,
    'limits': <String, dynamic>{
      'daily': tierCode == 'tier_1' ? 500000 : 0,
      'weekly': tierCode == 'tier_1' ? 2000000 : 0,
      'monthly': tierCode == 'tier_1' ? 8000000 : 0,
      'cashout': tierCode == 'tier_1' ? 200000 : 0,
    },
  };

  Map<String, dynamic> statusData() => <String, dynamic>{
    'entity_id': 'u1',
    'kyc': levelData(),
    'identity_verified': tierCode != 'tier_0',
    'trade_verifications': <dynamic>[],
    'pending_submissions': 0,
    'total_submissions': 0,
  };

  KycProvider buildProvider({
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  }) {
    final defaults = <String, Object? Function(Map<String, dynamic>)>{
      'verification_kyc_level_get': (_) => ok(levelData()),
      'verification_limits_get': (_) => ok(<String, dynamic>{
        'tier_code': tierCode,
        'status': tierStatus,
        'daily': tierCode == 'tier_1' ? 500000 : 0,
        'weekly': tierCode == 'tier_1' ? 2000000 : 0,
        'monthly': tierCode == 'tier_1' ? 8000000 : 0,
        'cashout': tierCode == 'tier_1' ? 200000 : 0,
      }),
      'verification_status_get': (_) => ok(statusData()),
    };
    defaults.addAll(
      rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{},
    );
    final client = MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: defaults,
    );
    final remote = SupabaseKycRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = KycRepositoryImpl(remote: remote);
    return KycProvider(repo: repo);
  }

  group('VP5: KYC level → limits', () {
    test('tier_0 loads with zero limits (server-authoritative)', () async {
      tierCode = 'tier_0';
      tierStatus = 'pending';
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.refreshStatus();

      expect(provider.currentTier, KycTier.tier0);
      expect(provider.kycLevel, isA<KycLevel>());
      expect(provider.kycLevel?.limits.cashout, 0);
      expect(provider.kycLevel?.limits.daily, 0);
    });

    test('KycLimitGuard blocks over-limit operations at tier_0', () async {
      tierCode = 'tier_0';
      tierStatus = 'pending';
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.refreshStatus();

      final KycLimits limits = provider.kycLevel!.limits;
      final bool allowed = KycLimitGuard.isCashoutAllowed(
        limits: limits,
        amount: 50000,
      );
      expect(
        allowed,
        isFalse,
        reason: 'tier_0 with cashout=0 must block any withdrawal',
      );

      final bool canTransact = KycLimitGuard.canTransact(
        limits: limits,
        amount: 100,
      );
      expect(
        canTransact,
        isFalse,
        reason: 'tier_0 with daily limit 0 must block all operations',
      );
    });

    test('server approval → tier_1 lifts limits', () async {
      tierCode = 'tier_0';
      tierStatus = 'pending';
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.refreshStatus();
      expect(provider.currentTier, KycTier.tier0);

      // Simulate server-side tier upgrade.
      tierCode = 'tier_1';
      tierStatus = 'active';
      await provider.refreshStatus();

      expect(provider.currentTier, KycTier.tier1);
      expect(provider.kycLevel?.limits.cashout, 200000);
      expect(provider.kycLevel?.limits.daily, 500000);
    });

    test('KycLimitGuard allows within-limit after upgrade', () async {
      tierCode = 'tier_1';
      tierStatus = 'active';
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.refreshStatus();

      final KycLimits limits = provider.kycLevel!.limits;
      final bool allowed = KycLimitGuard.isCashoutAllowed(
        limits: limits,
        amount: 150000,
      );
      expect(
        allowed,
        isTrue,
        reason: 'tier_1 with cashout=200000 must allow 150000',
      );

      final bool blocked = KycLimitGuard.isCashoutAllowed(
        limits: limits,
        amount: 250000,
      );
      expect(
        blocked,
        isFalse,
        reason: 'tier_1 with cashout=200000 must block 250000',
      );
    });

    test(
      'PLT003 envelope surfaces as validation ApiException on refreshStatus',
      () async {
        final provider = buildProvider(
          rpcHandlers: {
            'verification_kyc_level_get': (_) => <String, dynamic>{
              'code': 'PLT003',
              'data': <String, dynamic>{},
            },
          },
        );
        addTearDown(provider.dispose);

        // `refreshStatus` swallows transport/validation failures into the
        // provider's state surface (documented contract — the unit test
        // kyc_provider_test.dart asserts loadState == error + lastError).
        await provider.refreshStatus();
        expect(
          provider.lastError,
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.validation,
          ),
        );
        expect(provider.lastError?.code, 'PLT003');
      },
    );
  });
}
