import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/repositories/financial_deposit_repository.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

/// In-memory [FinancialDepositRepository] for tests (read-only, no network).
///
/// Failures are scripted through [nextError]; [listCallCount] records reads.
class FakeFinancialDepositRepository implements FinancialDepositRepository {
  FakeFinancialDepositRepository({
    List<Deposit> seed = const <Deposit>[],
    this.nextError,
  }) : _deposits = List<Deposit>.of(seed);

  final List<Deposit> _deposits;

  /// Thrown by the next [listDeposits] call when set (then kept until cleared).
  ApiException? nextError;

  int listCallCount = 0;

  List<Deposit> get deposits => List<Deposit>.unmodifiable(_deposits);

  /// A deposit whose payer name matched the profile legal name.
  static Deposit matched({
    String id = 'dep-matched',
    String currencyCode = 'NGN',
    double amount = 150000,
  }) =>
      Deposit(
        id: id,
        currencyCode: currencyCode,
        amount: amount,
        nameMatchStatus: DepositNameMatchStatus.matched,
        payerName: 'John Doe',
        nameMatchScore: 1.0,
        status: 'credited',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        creditedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

  /// A deposit awaiting server-side name verification.
  static Deposit pending({
    String id = 'dep-pending',
    String currencyCode = 'USD',
    double amount = 100,
  }) =>
      Deposit(
        id: id,
        currencyCode: currencyCode,
        amount: amount,
        nameMatchStatus: DepositNameMatchStatus.pending,
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

  @override
  Future<List<Deposit>> listDeposits() async {
    listCallCount++;
    if (nextError != null) throw nextError!;
    return List<Deposit>.unmodifiable(_deposits);
  }
}