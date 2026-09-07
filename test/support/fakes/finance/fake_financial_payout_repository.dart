import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/repositories/financial_payout_repository.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';

/// In-memory [FinancialPayoutRepository] for tests (no network, no RPC).
///
/// Mirrors the real repository's contract: binds insert into the local mirror,
/// lists return the mirror, and withdraws validate against the verified gate
/// then return a canned [WithdrawalResult]. Failures are scripted through
/// [nextError].
class FakeFinancialPayoutRepository implements FinancialPayoutRepository {
  FakeFinancialPayoutRepository({
    List<PayoutAccount> seed = const <PayoutAccount>[],
    this.nextError,
    this.nextWithdrawError,
    this.nextWithdrawalResult,
  })  : _accounts = List<PayoutAccount>.of(seed),
        _accountIds = <String>{
          for (final PayoutAccount a in seed) a.id,
        };

  final List<PayoutAccount> _accounts;
  final Set<String> _accountIds;

  /// Thrown by the next operation when set (then kept until cleared).
  ApiException? nextError;

  /// Thrown only by [withdraw] (kept until cleared). Lets tests fail the
  /// withdrawal without poisoning the initial load.
  ApiException? nextWithdrawError;

  /// Returned by [withdraw] when set.
  WithdrawalResult? nextWithdrawalResult;

  int bindCallCount = 0;
  int withdrawCallCount = 0;
  int listCallCount = 0;

  /// Account id and amount from the most recent [withdraw] call.
  String? lastWithdrawalAccountId;
  double? lastWithdrawalAmount;

  /// A bound seed account that passes the verified gate.
  static PayoutAccount verified({
    String id = 'acc-verified',
    String currencyCode = 'NGN',
  }) =>
      PayoutAccount(
        id: id,
        currencyCode: currencyCode,
        bankName: 'Guaranty Trust',
        accountNumber: '0123456789',
        accountName: 'John Doe',
        status: PayoutAccountStatus.active,
        isVerified: true,
        isDefault: true,
        verifiedAt: DateTime.now().subtract(const Duration(days: 10)),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );

  /// A bound seed account that has NOT passed verification.
  static PayoutAccount unverified({
    String id = 'acc-unverified',
    String currencyCode = 'NGN',
  }) =>
      PayoutAccount(
        id: id,
        currencyCode: currencyCode,
        bankName: 'Zenith Bank',
        accountNumber: '9876543210',
        accountName: 'John Doe',
        status: PayoutAccountStatus.pending,
        isVerified: false,
        createdAt: DateTime.now(),
      );

  List<PayoutAccount> get accounts => List<PayoutAccount>.unmodifiable(_accounts);

  @override
  Future<PayoutAccount> bindAccount({
    required String currencyCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    bindCallCount++;
    if (nextError != null) throw nextError!;
    // Deliberately deterministic per account number so re-binding the same
    // NUBAN yields the same account id (mirroring the server-side unique
    // (entity, currency, account-number) constraint).
    final String accountId = 'acc-$accountNumber';
    final PayoutAccount account = PayoutAccount(
      id: accountId,
      currencyCode: currencyCode.trim().toUpperCase(),
      bankName: bankName.trim(),
      accountNumber: accountNumber.trim(),
      accountName: accountName.trim(),
      status: PayoutAccountStatus.pending,
      createdAt: DateTime.now(),
    );
    _accountIds.add(account.id);
    _accounts.insert(0, account);
    return account;
  }

  @override
  Future<List<PayoutAccount>> listPayoutAccounts() async {
    listCallCount++;
    if (nextError != null) throw nextError!;
    return List<PayoutAccount>.unmodifiable(_accounts);
  }

  @override
  Future<WithdrawalResult> withdraw({
    required String payoutAccountId,
    required double amount,
  }) async {
    withdrawCallCount++;
    lastWithdrawalAccountId = payoutAccountId;
    lastWithdrawalAmount = amount;
    if (nextError != null) throw nextError!;
    if (nextWithdrawError != null) throw nextWithdrawError!;
    final WithdrawalResult result = nextWithdrawalResult ??
        WithdrawalResult(
          payoutId: 'pay-1',
          amount: amount,
          fee: 0,
          netAmount: amount,
          cashoutRemaining: 999999,
        );
    return result;
  }
}