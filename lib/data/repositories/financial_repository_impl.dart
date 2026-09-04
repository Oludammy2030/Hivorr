// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/financial_remote_data_source.dart';
import 'package:hivorr/data/entities/account_activation_guidance.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/mappers/financial_mapper.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';
import 'package:hivorr/integrations/payment_gateways/models/payment_models.dart'
    show PaymentProvider;
import 'package:hivorr/integrations/payment_gateways/payment_gateway.dart'
    show PaymentGateway;
import 'package:hivorr/integrations/payment_gateways/payment_gateway_factory.dart'
    show PaymentGatewayFactory;
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Default implementation of [FinancialRepository].
///
/// Implements the server-authoritative financial profile flow (EP-02-13 §5.3):
/// profile creation via `financial_profile_create`, reads via
/// `financial_profile_get` / `financial_balance_get` / `financial_status_get`.
/// Balance mutations are owned by `EP-02-14/16` — this implementation is
/// read-only for balances and write-once for profile creation.
class FinancialRepositoryImpl implements FinancialRepository {
  FinancialRepositoryImpl({
    required FinancialRemoteDataSource remote,
    PaymentGatewayFactory? paymentGatewayFactory,
  })  : _remote = remote,
        _paymentGatewayFactory = paymentGatewayFactory;

  final FinancialRemoteDataSource _remote;
  final PaymentGatewayFactory? _paymentGatewayFactory;

  @override
  Future<FinancialProfile?> getProfile() async {
    final dto = await _remote.getProfile();
    if (dto == null) return null;
    return FinancialMapper.profileToEntity(dto);
  }

  @override
  Future<List<CurrencyAccount>> getAccounts() async {
    final dto = await _remote.getProfile();
    if (dto == null) return const <CurrencyAccount>[];
    return dto.currencyAccounts
        .map(FinancialMapper.accountToEntity)
        .toList(growable: false);
  }

  @override
  Future<Balance?> getBalance(String currencyCode) async {
    if (!SupportedCurrency.isSupported(currencyCode)) return null;
    final dto = await _remote.getBalance(currencyCode);
    return FinancialMapper.balanceToEntity(dto);
  }

  @override
  Future<FinancialStatus> getStatus() async {
    final dto = await _remote.getStatus();
    return FinancialMapper.statusToEntity(dto);
  }

  @override
  Future<FinancialProfile> createProfile({
    String defaultCurrency = 'NGN',
  }) async {
    if (!SupportedCurrency.isSupported(defaultCurrency)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'Unsupported currency. Supported currencies are NGN, GHS, USD, GBP.',
        code: 'PLT003',
      );
    }
    final dto = await _remote.createProfile(defaultCurrency: defaultCurrency);
    return FinancialMapper.profileToEntity(dto);
  }

  @override
  Future<AccountActivationGuidance> requestAccountActivation({
    required String currencyCode,
  }) async {
    if (!SupportedCurrency.isSupported(currencyCode)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'Unsupported currency. Supported currencies are NGN, GHS, USD, GBP.',
        code: 'PLT003',
      );
    }

    final PaymentGatewayFactory? factory = _paymentGatewayFactory;
    if (factory == null) {
      return AccountActivationGuidance(
        currencyCode: currencyCode,
        message: 'Connect your $currencyCode bank account',
      );
    }

    final PaymentGateway gateway = factory.resolveForCurrency(currencyCode);
    final String providerName = _providerName(gateway.provider);
    return AccountActivationGuidance(
      currencyCode: currencyCode,
      providerName: providerName,
      message: 'Connect $currencyCode via $providerName',
    );
  }

  /// Human-readable provider name for display guidance (display-only, avoids
  /// mutating the `PaymentProvider` enum which owns provider-neutral identity).
  static String _providerName(PaymentProvider provider) {
    switch (provider) {
      case PaymentProvider.paystack:
        return 'Paystack';
      case PaymentProvider.flutterwave:
        return 'Flutterwave';
    }
  }
}
