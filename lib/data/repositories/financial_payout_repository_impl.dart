// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/financial_payout_remote_data_source.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/local/payout_account_local_store.dart';
import 'package:hivorr/data/mappers/financial_payout_mapper.dart';
import 'package:hivorr/data/models/payout_bind_dto.dart';
import 'package:hivorr/data/models/withdrawal_dto.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/systems/finance/helpers/bank_account_number_validator.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Default implementation of [FinancialPayoutRepository].
///
/// Writes go through the authenticated `financial_payout_account_bind` /
/// `financial_withdraw` RPCs (server-authoritative). Because the authenticated
/// role has no SELECT grant on `financial_payout_accounts`, the list view is a
/// client-side mirror maintained by the injected [PayoutAccountLocalStore].
class FinancialPayoutRepositoryImpl implements FinancialPayoutRepository {
  FinancialPayoutRepositoryImpl({
    required FinancialPayoutRemoteDataSource remote,
    required PayoutAccountLocalStore store,
  }) : _remote = remote,
       _store = store;

  final FinancialPayoutRemoteDataSource _remote;
  final PayoutAccountLocalStore _store;

  @override
  Future<PayoutAccount> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    final String currency = currencyCode.trim().toUpperCase();
    if (!SupportedCurrency.isSupported(currency)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message:
            'Unsupported currency. Supported currencies are NGN, GHS, USD, GBP.',
        code: 'PLT003',
      );
    }
    final String? formatError = BankAccountNumberValidator.validate(
      value: accountNumber,
      currencyCode: currency,
    );
    if (formatError != null) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: formatError,
        code: 'PLT003',
      );
    }
    final PayoutBindDto bind = await _remote.bindAccount(
      currencyCode: currency,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
    );
    final PayoutAccount account = FinancialPayoutMapper.boundAccountFromBind(
      bind: bind,
      bankName: bankName,
      accountNumber: accountNumber,
      accountName: accountName,
      createdAt: DateTime.now(),
    );
    await _store.upsert(account);
    return account;
  }

  @override
  Future<List<PayoutAccount>> listPayoutAccounts() async => _store.readAll();

  @override
  Future<WithdrawalResult> withdraw({
    required String payoutAccountId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Withdrawal amount must be greater than zero.',
        code: 'PLT003',
      );
    }
    // Mirror the server's is_verified gate so obvious mistakes surface before
    // the round trip; the server re-enforces it authoritatively.
    final List<PayoutAccount> accounts = _store.readAll();
    PayoutAccount? account;
    for (final PayoutAccount a in accounts) {
      if (a.id == payoutAccountId) {
        account = a;
        break;
      }
    }
    if (account == null || !account.isVerified) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Payout account is not verified.',
        code: 'PLT003',
      );
    }
    final WithdrawalDto dto = await _remote.withdraw(
      payoutAccountId: payoutAccountId,
      amount: amount,
    );
    return FinancialPayoutMapper.withdrawalToEntity(dto);
  }
}
