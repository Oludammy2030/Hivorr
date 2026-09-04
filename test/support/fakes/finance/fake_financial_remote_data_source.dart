// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/financial_remote_data_source.dart';
import 'package:hivorr/data/models/balance_dto.dart';
import 'package:hivorr/data/models/financial_profile_dto.dart';
import 'package:hivorr/data/models/financial_status_dto.dart';

/// In-memory [FinancialRemoteDataSource] for repository tests.
///
/// Surfaces scripted DTOs with call counters; set [nextError] to exercise
/// failure paths exactly as the real RPC layer throws [ApiException].
class FakeFinancialRemoteDataSource implements FinancialRemoteDataSource {
  FakeFinancialRemoteDataSource({
    FinancialProfileDto? profile,
    BalanceDto? balance,
    FinancialStatusDto? status,
  })  : _profile = profile,
        _balance = balance,
        _status = status;

  FinancialProfileDto? _profile;
  final BalanceDto? _balance;
  final FinancialStatusDto? _status;

  ApiException? nextError;
  int profileCallCount = 0;
  int balanceCallCount = 0;
  int statusCallCount = 0;
  int createCallCount = 0;
  String? lastCurrencyCode;
  String? lastDefaultCurrency;

  @override
  Future<FinancialProfileDto?> getProfile() async {
    profileCallCount++;
    if (nextError != null) throw nextError!;
    return _profile;
  }

  @override
  Future<BalanceDto> getBalance(String currencyCode) async {
    balanceCallCount++;
    lastCurrencyCode = currencyCode;
    if (nextError != null) throw nextError!;
    return _balance ?? seedBalanceDto(currencyCode: currencyCode);
  }

  @override
  Future<FinancialStatusDto> getStatus() async {
    statusCallCount++;
    if (nextError != null) throw nextError!;
    return _status ?? seedStatusDto();
  }

  @override
  Future<FinancialProfileDto> createProfile({
    String defaultCurrency = 'NGN',
  }) async {
    createCallCount++;
    lastDefaultCurrency = defaultCurrency;
    if (nextError != null) throw nextError!;
    _profile = seedProfileDto(defaultCurrency: defaultCurrency);
    return _profile!;
  }
}

FinancialProfileDto seedProfileDto({
  String id = 'profile-1',
  String entityId = 'u1',
  String status = 'active',
  String defaultCurrency = 'NGN',
  List<CurrencyAccountDto> currencyAccounts = const <CurrencyAccountDto>[],
}) =>
    FinancialProfileDto(
      id: id,
      entityId: entityId,
      status: status,
      defaultCurrency: defaultCurrency,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      currencyAccounts: currencyAccounts,
    );

CurrencyAccountDto seedAccountDto({
  String id = 'acc-1',
  String financialProfileId = 'profile-1',
  String entityId = 'u1',
  String currencyCode = 'NGN',
  String accountStatus = 'active',
  String? receivingBankName,
  String? receivingAccountNumber,
}) =>
    CurrencyAccountDto(
      id: id,
      financialProfileId: financialProfileId,
      entityId: entityId,
      currencyCode: currencyCode,
      accountStatus: accountStatus,
      receivingBankName: receivingBankName,
      receivingAccountNumber: receivingAccountNumber,
    );

BalanceDto seedBalanceDto({
  String currencyCode = 'NGN',
  double available = 50000,
  double held = 0,
  double pending = 0,
  double totalDeposited = 50000,
  double totalWithdrawn = 0,
}) =>
    BalanceDto(
      currencyCode: currencyCode,
      availableBalance: available,
      heldBalance: held,
      pendingBalance: pending,
      totalDeposited: totalDeposited,
      totalWithdrawn: totalWithdrawn,
    );

FinancialStatusDto seedStatusDto({
  String defaultCurrency = 'NGN',
  String profileStatus = 'active',
  List<BalanceDto> balances = const <BalanceDto>[],
  int activeEscrowCount = 0,
  double cashoutLimit = 100000,
}) =>
    FinancialStatusDto(
      defaultCurrency: defaultCurrency,
      profileStatus: profileStatus,
      balances: balances,
      activeEscrowCount: activeEscrowCount,
      cashoutLimit: cashoutLimit,
    );
