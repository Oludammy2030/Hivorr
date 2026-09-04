import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/api_config.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';
import 'package:hivorr/data/repositories/financial_repository_impl.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_config.dart';
import 'package:hivorr/integrations/payment_gateways/payment_gateway_factory.dart';

import '../../../support/fakes/finance/fake_financial_remote_data_source.dart';

const ApiConfig _apiConfig = ApiConfig(
  connectTimeout: Duration(seconds: 5),
  receiveTimeout: Duration(seconds: 5),
  sendTimeout: Duration(seconds: 5),
  maxRetries: 1,
  baseRetryDelay: Duration(milliseconds: 100),
  maxRetryDelay: Duration(seconds: 1),
);

void main() {
  const ApiExceptionMapper mapper = ApiExceptionMapper();

  FinancialRepositoryImpl build({
    FinancialProfileDto? profile,
    BalanceDto? balance,
    FinancialStatusDto? status,
    PaymentGatewayFactory? paymentGatewayFactory,
  }) =>
      FinancialRepositoryImpl(
        remote: FakeFinancialRemoteDataSource(
          profile: profile ?? seedProfileDto(),
          balance: balance,
          status: status ?? seedStatusDto(),
        ),
        paymentGatewayFactory: paymentGatewayFactory,
      );

  PaymentGatewayFactory factoryWith({
    String paystackSecret = 'sk',
    String flutterwaveSecret = 'fw',
  }) =>
      PaymentGatewayFactory(
        config: PaymentGatewayConfig(
          paystackPublicKey: 'pk',
          paystackSecretKey: paystackSecret,
          flutterwavePublicKey: 'fk',
          flutterwaveSecretKey: flutterwaveSecret,
          defaultProvider: PaymentProvider.paystack,
        ),
        mapper: mapper,
        apiConfig: _apiConfig,
      );

  group('FinancialRepositoryImpl.getProfile', () {
    test('returns null when entity has no profile', () async {
      final repo = FinancialRepositoryImpl(
        remote: FakeFinancialRemoteDataSource(profile: null),
      );
      final FinancialProfile? profile = await repo.getProfile();
      expect(profile, isNull);
    });

    test('returns mapped profile when one exists', () async {
      final repo = build(profile: seedProfileDto(defaultCurrency: 'USD'));
      final FinancialProfile? profile = await repo.getProfile();
      expect(profile, isNotNull);
      expect(profile!.defaultCurrency, 'USD');
      expect(profile.isActive, isTrue);
    });
  });

  group('FinancialRepositoryImpl.getAccounts', () {
    test('returns empty list when profile is null', () async {
      final repo = FinancialRepositoryImpl(
        remote: FakeFinancialRemoteDataSource(profile: null),
      );
      final List<CurrencyAccount> accounts = await repo.getAccounts();
      expect(accounts, isEmpty);
    });

    test('returns mapped accounts when present', () async {
      final repo = build(
        profile: seedProfileDto(
          currencyAccounts: <CurrencyAccountDto>[
            seedAccountDto(currencyCode: 'NGN', accountStatus: 'active'),
            seedAccountDto(
              id: 'acc-2',
              currencyCode: 'USD',
              accountStatus: 'pending',
            ),
          ],
        ),
      );
      final List<CurrencyAccount> accounts = await repo.getAccounts();
      expect(accounts, hasLength(2));
      expect(accounts.first.currencyCode, 'NGN');
      expect(accounts.last.isPending, isTrue);
    });
  });

  group('FinancialRepositoryImpl.getBalance', () {
    test('returns balance for supported currency', () async {
      final repo = build(balance: seedBalanceDto(currencyCode: 'USD'));
      final Balance? balance = await repo.getBalance('USD');
      expect(balance, isNotNull);
      expect(balance!.currencyCode, 'USD');
    });

    test('returns null for unsupported currency without calling remote', () async {
      final repo = build();
      final Balance? balance = await repo.getBalance('XYZ');
      expect(balance, isNull);
    });
  });

  group('FinancialRepositoryImpl.getStatus', () {
    test('returns mapped aggregate', () async {
      final repo = build(
        status: seedStatusDto(
          defaultCurrency: 'NGN',
          balances: <BalanceDto>[
            seedBalanceDto(currencyCode: 'NGN'),
          ],
          activeEscrowCount: 1,
          cashoutLimit: 50000,
        ),
      );
      final status = await repo.getStatus();
      expect(status.defaultCurrency, 'NGN');
      expect(status.balances, hasLength(1));
      expect(status.activeEscrowCount, 1);
      expect(status.cashoutLimit, 50000);
    });
  });

  group('FinancialRepositoryImpl.createProfile', () {
    test('creates valid currency and returns entity', () async {
      final repo = build();
      final FinancialProfile profile =
          await repo.createProfile(defaultCurrency: 'GHS');
      expect(profile.defaultCurrency, 'GHS');
      expect(profile.status, 'active');
      expect(profile.isActive, isTrue);
    });

    test('throws validation for unsupported currency before RPC', () async {
      final repo = build();
      expect(
        () => repo.createProfile(defaultCurrency: 'XYZ'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)),
      );
    });

    test('throws conflict when profile already exists', () async {
      final remote = FakeFinancialRemoteDataSource(
        profile: seedProfileDto(),
      )..nextError = const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'Profile already exists.',
          code: 'PLT005',
        );
      final repo = FinancialRepositoryImpl(remote: remote);
      expect(
        () => repo.createProfile(defaultCurrency: 'NGN'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)),
      );
    });
  });

  group('FinancialRepositoryImpl.requestAccountActivation', () {
    test('throws validation for unsupported currency before any gateway', () async {
      final repo = build();
      expect(
        () => repo.requestAccountActivation(currencyCode: 'XYZ'),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)
            .having((ApiException e) => e.code, 'code', 'PLT003')),
      );
    });

    test('returns generic guidance when no gateway factory is configured', () async {
      final repo = build();
      final guidance = await repo.requestAccountActivation(currencyCode: 'NGN');
      expect(guidance.currencyCode, 'NGN');
      expect(guidance.providerName, isNull);
      expect(guidance.message, 'Connect your NGN bank account');
    });

    test('resolves NGN to Paystack via the gateway factory', () async {
      final repo = build(paymentGatewayFactory: factoryWith());
      final guidance = await repo.requestAccountActivation(currencyCode: 'NGN');
      expect(guidance.providerName, 'Paystack');
      expect(guidance.message, 'Connect NGN via Paystack');
    });

    test('resolves to Flutterwave when only its secret is configured', () async {
      final repo = build(
        paymentGatewayFactory:
            factoryWith(paystackSecret: '', flutterwaveSecret: 'fw'),
      );
      final guidance = await repo.requestAccountActivation(currencyCode: 'GHS');
      expect(guidance.providerName, 'Flutterwave');
      expect(guidance.message, 'Connect GHS via Flutterwave');
    });
  });
}
