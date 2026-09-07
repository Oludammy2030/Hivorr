import 'package:hivorr/data/models/deposit_dto.dart';

/// Abstract contract for the remote (Supabase) side of deposits (EP-02-16).
///
/// Deposits are recorded and name-verified server-side
/// (`financial_deposit_record` / `financial_deposit_verify_name`, both
/// service-role only — the client has no execute grant). The client only
/// *reads* deposits through the authenticated-role REST select grant on
/// `financial_deposits` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:555`),
/// which is RLS-scoped to the authenticated entity.
abstract class FinancialDepositRemoteDataSource {
  /// Lists the authenticated entity's deposits, newest first.
  ///
  /// Read-only. Never calls the service-role deposit RPCs.
  Future<List<DepositDto>> listDeposits();
}