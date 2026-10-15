import 'package:hivorr/data/models/dispute_admin_list_envelope_dto.dart';
import 'package:hivorr/data/models/service_dispute_detail_envelope_dto.dart';

/// Contract for admin dispute reads (R3 follow-up).
///
/// Wraps the two admin-gated RPCs from
/// (`supabase/migrations/20261012090002_dispute_admin_queue.sql`):
/// `service_dispute_admin_list` and `service_dispute_admin_get`. Both are
/// SECURITY DEFINER with an `is_platform_admin()` body gate — the client
/// never caches the admin flag and never calls `dispute_resolve` (resolution
/// stays service-role SQL/manual, out of scope).
abstract class AdminDisputeRemoteDataSource {
  /// Lists ALL dispute cases with server-joined engagement context,
  /// optionally filtered by [status], paged by [limit]/[offset].
  Future<DisputeAdminListEnvelopeDto> adminListDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  });

  /// Fetches one case with evidence, resolution, and contract join — no
  /// party restriction beyond the admin gate.
  Future<ServiceDisputeDetailEnvelopeDto> adminGetCase(String caseId);
}
