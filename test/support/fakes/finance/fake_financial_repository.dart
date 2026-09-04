// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/account_activation_guidance.dart';
import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/data/entities/financial_status.dart';
import 'package:hivorr/data/repositories/financial_repository.dart';

/// In-memory [FinancialRepository] for provider/widget tests.
///
/// Surfaces scripted entities with call counters; set [nextError] to exercise
/// failure paths exactly as the real repository throws [ApiException].
class FakeFinancialRepository implements FinancialRepository {
  FakeFinancialRepository({
    FinancialProfile? profile,
    List<CurrencyAccount> accounts = const <CurrencyAccount>[],
    FinancialStatus? status,
    Map<String, Balance> balances = const <String, Balance>{},
  })  : _profile = profile,
        _accounts = accounts,
        _status = status,
        _balances = balances;

  FinancialProfile? _profile;
  List<CurrencyAccount> _accounts;
  FinancialStatus? _status;
  Map<String, Balance> _balances;

  ApiException? nextError;
  int profileCallCount = 0;
  int accountsCallCount = 0;
  int statusCallCount = 0;
  int createCallCount = 0;
  int activationCallCount = 0;
  String? lastDefaultCurrency;
  AccountActivationGuidance? activationGuidance;

  /// Mutates the profile the fake serves.
  void setProfile(FinancialProfile? profile) => _profile = profile;

  /// Mutates the accounts the fake serves.
  void setAccounts(List<CurrencyAccount> accounts) => _accounts = accounts;

  /// Mutates the status the fake serves.
  void setStatus(FinancialStatus? status) => _status = status;

  /// Mutates the balances the fake serves.
  void setBalances(Map<String, Balance> balances) => _balances = balances;

  @override
  Future<FinancialProfile?> getProfile() async {
    profileCallCount++;
    if (nextError != null) throw nextError!;
    return _profile;
  }

  @override
  Future<List<CurrencyAccount>> getAccounts() async {
    accountsCallCount++;
    if (nextError != null) throw nextError!;
    return _accounts;
  }

  @override
  Future<Balance?> getBalance(String currencyCode) async {
    if (nextError != null) throw nextError!;
    return _balances[currencyCode];
  }

  @override
  Future<FinancialStatus> getStatus() async {
    statusCallCount++;
    if (nextError != null) throw nextError!;
    return _status ?? seedStatusEntity();
  }

  @override
  Future<FinancialProfile> createProfile({
    String defaultCurrency = 'NGN',
  }) async {
    createCallCount++;
    lastDefaultCurrency = defaultCurrency;
    if (nextError != null) throw nextError!;
    _profile = FinancialProfile(
      id: 'profile-1',
      entityId: 'u1',
      status: 'active',
      defaultCurrency: defaultCurrency,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    return _profile!;
  }

  @override
  Future<AccountActivationGuidance> requestAccountActivation({
    required String currencyCode,
  }) async {
    activationCallCount++;
    if (nextError != null) throw nextError!;
    return activationGuidance ??
        AccountActivationGuidance(
          currencyCode: currencyCode,
          message: 'Connect your $currencyCode bank account',
        );
  }
}

/// Fixture builders shared across the finance tests (EP-02-13).
FinancialProfile seedProfileEntity({
  String id = 'profile-1',
  String entityId = 'u1',
  String status = 'active',
  String defaultCurrency = 'NGN',
}) =>
    FinancialProfile(
      id: id,
      entityId: entityId,
      status: status,
      defaultCurrency: defaultCurrency,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

CurrencyAccount seedAccountEntity({
  String id = 'acc-1',
  String financialProfileId = 'profile-1',
  String entityId = 'u1',
  String currencyCode = 'NGN',
  String accountStatus = 'active',
  String? receivingBankName,
  String? receivingAccountNumber,
}) =>
    CurrencyAccount(
      id: id,
      financialProfileId: financialProfileId,
      entityId: entityId,
      currencyCode: currencyCode,
      accountStatus: accountStatus,
      receivingBankName: receivingBankName,
      receivingAccountNumber: receivingAccountNumber,
    );

Balance seedBalanceEntity({
  String currencyCode = 'NGN',
  double available = 50000,
  double held = 0,
  double pending = 0,
  double totalDeposited = 50000,
  double totalWithdrawn = 0,
}) =>
    Balance(
      currencyCode: currencyCode,
      availableBalance: available,
      heldBalance: held,
      pendingBalance: pending,
      totalDeposited: totalDeposited,
      totalWithdrawn: totalWithdrawn,
    );

FinancialStatus seedStatusEntity({
  String defaultCurrency = 'NGN',
  String profileStatus = 'active',
  List<Balance> balances = const <Balance>[],
  int activeEscrowCount = 0,
  double cashoutLimit = 100000,
}) =>
    FinancialStatus(
      defaultCurrency: defaultCurrency,
      profileStatus: profileStatus,
      balances: balances,
      activeEscrowCount: activeEscrowCount,
      cashoutLimit: cashoutLimit,
    );
