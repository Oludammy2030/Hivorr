/// The unified financial profile for an entity (EP-02-13).
///
/// Mirrors `financial_profiles` / `financial_profile_get` RPC read model
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:67-78`).
/// Pure Dart domain — no RPC JSON shape leaks. This task only **reads**
/// and creates via the server-authoritative `financial_profile_create` RPC;
/// it never writes `financial_profiles` directly (AGENT.md Rule 4).
class FinancialProfile {
  const FinancialProfile({
    required this.id,
    required this.entityId,
    required this.status,
    required this.defaultCurrency,
    required this.createdAt,
  });

  /// The profile row id.
  final String id;

  /// The owning entity id (auth.uid()-scoped).
  final String entityId;

  /// Lifecycle status: `active | suspended | closed`.
  final String status;

  /// Default currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String defaultCurrency;

  /// Profile creation timestamp.
  final DateTime createdAt;

  /// Whether the profile is in an operational state.
  bool get isActive => status == 'active';
}
