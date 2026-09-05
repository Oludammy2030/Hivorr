import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';

/// The full escrow read model (header + milestones + transactions).
///
/// Mirrors the `financial_escrow_get` envelope `data` object
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1111-1147`),
/// which returns `{escrow, milestones}`. The transactions list is currently
/// empty by design — the frozen read model has no transactions array, so the
/// client renders an empty summary rather than inventing one.
class EscrowDetail {
  const EscrowDetail({
    required this.escrow,
    required this.milestones,
    required this.transactions,
  });

  /// The escrow header.
  final Escrow escrow;

  /// Milestones ordered by `sort_order` / `milestone_number`.
  final List<EscrowMilestone> milestones;

  /// Escrow-scoped ledger summary entries (currently empty).
  final List<EscrowTransaction> transactions;

  /// Sum of amounts across all milestones.
  double get milestonesTotal => milestones.fold(
        0.0,
        (double sum, EscrowMilestone m) => sum + m.amount,
      );
}