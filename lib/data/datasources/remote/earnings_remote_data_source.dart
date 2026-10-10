import 'package:hivorr/data/models/earnings_summary_dto.dart';
import 'package:hivorr/data/models/earnings_transaction_dto.dart';

/// Abstract contract for the earnings read seam (EP-03-16).
///
/// Depends only on transport DTOs — never on concrete backend types — so
/// repositories consume this interface, not a Supabase implementation
/// (ARCHITECTURE.md / EP-01-08 §5.6). Read-only: the two RPCs aggregate
/// server-side and the client never writes ledger state.
abstract class EarningsRemoteDataSource {
  /// Fetches the server-aggregated earnings summary for [currencyCode].
  Future<EarningsSummaryDto> getSummary(String currencyCode);

  /// Fetches one keyset-paginated history page for [currencyCode].
  ///
  /// [type] is one of `all`, `earned`, `withdrawn`, `fund_locked`, `frozen`.
  /// [cursor] is the opaque RPC `{created_at, id}` keyset (`null` for the
  /// first page).
  Future<EarningsTransactionPageDto> listTransactions({
    required String currencyCode,
    String type = 'all',
    String? contractId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    Map<String, dynamic>? cursor,
  });
}
