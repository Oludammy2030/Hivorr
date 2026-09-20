// EP-02-20 VP9: Bound Payout + KYC-Driven Cashout Limits + Name Enquiry.
//
// Exercises FinancialPayoutService → FinancialPayoutRepository through the real
// datasource→repository→provider stack with a scripted Supabase transport.
// Bind is server-authoritative and returns `status: pending`; verification is
// service-role-only (`financial_payout_account_verify`, out of client scope),
// so verified accounts enter the client mirror via the PayoutAccountLocalStore
// (matched by name enquiry → verify out-of-band). Verifies: bind → listed,
// withdraw within limit succeeds for a verified account, over-limit blocked →
// KycLimitGuard reflects the tier.
//
// Run: flutter test test/integration/trust/payout_account_flow_integration_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/supabase_financial_payout_remote_data_source.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/local/payout_account_local_store.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/repositories/financial_payout_repository_impl.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
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
  int bindRpcCount = 0;
  int withdrawRpcCount = 0;
  double cashoutLimit = 200000;

  // A name-enquiry-verified account as it would arrive in the client mirror
  // after the service-role verification step (EP-02-20 §VP9).
  PayoutAccount verifiedPayoutAccount({required String id}) => PayoutAccount(
        id: id,
        currencyCode: 'NGN',
        bankName: 'GTBank',
        accountNumber: '0123456789',
        accountName: 'Ada Lovelace',
        status: PayoutAccountStatus.active,
        isVerified: true,
      );

  ({
    FinancialPayoutService service,
    FinancialPayoutProvider provider,
  }) buildFlow({
    List<PayoutAccount> seedAccounts = const <PayoutAccount>[],
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  }) {
    final defaults = <String, Object? Function(Map<String, dynamic>)>{
      // Mirrors the real `financial_payout_account_bind` response `data`
      // object: `{payout_account_id, currency_code, status}`.
      'financial_payout_account_bind': (Map<String, dynamic> body) {
        bindRpcCount++;
        return ok(<String, dynamic>{
          'payout_account_id': 'pa-$bindRpcCount',
          'currency_code': body['p_currency_code'] as String,
          'status': 'pending',
        });
      },
      'financial_withdraw': (Map<String, dynamic> body) {
        withdrawRpcCount++;
        final double amount = (body['p_amount'] as num).toDouble();
        if (amount > cashoutLimit) {
          return <String, dynamic>{
            'success': false,
            'code': 'PLT003',
            'message': 'Amount exceeds cashout limit.',
            'data': null,
          };
        }
        return ok(<String, dynamic>{
          'payout_id': 'payout-$withdrawRpcCount',
          'amount': amount,
          'net_amount': amount,
          'cashout_remaining': cashoutLimit - amount,
          'status': 'processing',
        });
      },
    };
    defaults.addAll(
        rpcHandlers ?? const <String, Object? Function(Map<String, dynamic>)>{});
    final client = MockSupabaseClientFactory.create(
      currentUser: fakeUser('u1'),
      rpcHandlers: defaults,
    );
    final remote = SupabaseFinancialPayoutRemoteDataSource(
      dio: Dio(),
      supabase: client,
      exceptionMapper: const ApiExceptionMapper(),
    );
    final repo = FinancialPayoutRepositoryImpl(
        remote: remote,
        store: InMemoryPayoutAccountLocalStore(seed: seedAccounts),
      );
    final service = FinancialPayoutService(repository: repo);
    final provider = FinancialPayoutProvider(service: service);
    return (service: service, provider: provider);
  }

  setUp(() {
    bindRpcCount = 0;
    withdrawRpcCount = 0;
    cashoutLimit = 200000;
  });

  group('VP9: Payout account flow', () {
    test('bind account → listed (server returns pending)', () async {
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      // Bind a payout account.
      final PayoutAccount account = await flow.service.bindAccount(
        currencyCode: 'NGN',
        bankName: 'GTBank',
        accountNumber: '0123456789',
        accountName: 'Ada Lovelace',
      );
      expect(account.id, 'pa-1');
      expect(account.currencyCode, 'NGN');
      expect(account.status, PayoutAccountStatus.pending);
      expect(account.isVerified, isFalse);
      expect(bindRpcCount, 1);

      // List shows the bound account (client mirror).
      final List<PayoutAccount> accounts =
          await flow.service.listPayoutAccounts();
      expect(accounts, hasLength(1));
      expect(accounts.first.id, 'pa-1');
    });

    test('withdraw within limit succeeds for a verified account', () async {
      final flow = buildFlow(
        seedAccounts: <PayoutAccount>[verifiedPayoutAccount(id: 'pa-1')],
      );
      addTearDown(flow.provider.dispose);

      // Withdraw within limit from the verified, mirrored account.
      final WithdrawalResult result = await flow.service.withdraw(
        payoutAccountId: 'pa-1',
        amount: 150000,
      );
      expect(result.payoutId, 'payout-1');
      expect(result.amount, 150000);
      expect(result.cashoutRemaining, 50000);
      expect(withdrawRpcCount, 1);
    });

    test('withdraw over limit blocked by server PLT003', () async {
      final flow = buildFlow(
        seedAccounts: <PayoutAccount>[verifiedPayoutAccount(id: 'pa-1')],
      );
      addTearDown(flow.provider.dispose);

      await expectLater(
        flow.service.withdraw(
          payoutAccountId: 'pa-1',
          amount: 300000,
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT003')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              ),
        ),
      );
    });

    test('KycLimitGuard blocks over-limit on client side too', () async {
      const KycLimits limits = KycLimits(
        daily: 500000,
        weekly: 2000000,
        monthly: 8000000,
        cashout: 200000,
      );
      final bool allowed = KycLimitGuard.isCashoutAllowed(
        limits: limits,
        amount: 300000,
      );
      expect(allowed, isFalse,
          reason: 'KycLimitGuard must block amounts exceeding cashout limit');

      final bool canTransact = KycLimitGuard.canTransact(
        limits: limits,
        amount: 300000,
      );
      expect(canTransact, isTrue,
          reason: 'canTransact checks daily limit (300000 < 500000)');
    });

    test('provider drives bind → list → withdraw lifecycle', () async {
      final flow = buildFlow(
        seedAccounts: <PayoutAccount>[verifiedPayoutAccount(id: 'pa-v')],
      );
      addTearDown(flow.provider.dispose);

      await flow.provider.load();
      expect(flow.provider.accounts, hasLength(1));

      final bound = await flow.provider.bindAccount(
        currencyCode: 'NGN',
        bankName: 'GTBank',
        accountNumber: '0123456789',
        accountName: 'Ada Lovelace',
      );
      expect(bound, isNotNull);
      expect(bound!.id, 'pa-1');
      expect(flow.provider.accounts, hasLength(2));

      final result = await flow.provider.withdraw(
        payoutAccountId: 'pa-v',
        amount: 100000,
      );
      expect(result, isNotNull);
      expect(result!.payoutId, 'payout-1');
    });

    test('unbound withdrawal prevented (no matching account)', () async {
      final flow = buildFlow();
      addTearDown(flow.provider.dispose);

      await expectLater(
        flow.service.withdraw(
          payoutAccountId: 'nonexistent',
          amount: 50000,
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
