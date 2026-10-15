import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';

/// Abstract contract for admin dispute reads (R3 follow-up).
///
/// Depends only on domain entities — never on backend types. Read-only:
/// there is deliberately no resolve/withdraw/mutate surface (resolution stays
/// service-role SQL/manual). All authorization is server-side via
/// `is_platform_admin()`.
abstract class AdminDisputeRepository {
  /// Lists dispute cases across all parties with the server total.
  ///
  /// Pre-validates [status] against the frozen vocabulary, [limit] 1–100,
  /// and [offset] ≥ 0 before the RPC (mirrors the server guards).
  Future<AdminDisputePage> listDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  });

  /// Fetches one case with evidence, resolution, and contract join.
  Future<DisputeCaseDetail> getCase(String caseId);
}

/// One page of the admin dispute queue plus the server total.
class AdminDisputePage {
  const AdminDisputePage({required this.items, required this.totalCount});

  final List<DisputeCase> items;
  final int totalCount;

  bool get hasMore => items.length < totalCount;
}
