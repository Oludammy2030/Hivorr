import 'package:hivorr/data/entities/deposit.dart';

/// Abstract contract for deposit-read data operations (EP-02-16).
///
/// Depends only on domain entities — never on concrete backend types
/// (ARCHITECTURE.md / EP-01-08 §5.6). Deposits are read-only from the client:
/// recording and name verification are service-role responsibilities
/// (`financial_deposit_record` / `financial_deposit_verify_name`).
abstract class FinancialDepositRepository {
  /// Lists the authenticated entity's deposits (RLS-scoped REST select),
  /// newest first.
  Future<List<Deposit>> listDeposits();
}