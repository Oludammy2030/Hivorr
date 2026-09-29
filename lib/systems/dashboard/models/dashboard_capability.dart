import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// The dashboard visibility derived from the entity capability (EP-04-03).
///
/// Mirrors the Universal Entity Principle: one account, fluid roles.
/// [hire] sees hiring sections, [offer] sees work sections, [both] sees the
/// single combined navigation with My Work / My Hiring / Shared sections.
enum DashboardCapability {
  /// Hiring side only (Client).
  hire,

  /// Professional-work side only (Professional).
  offer,

  /// Combined experience (Both) — one account, not two.
  both;

  /// Resolves the dashboard capability from the onboarding [capability].
  static DashboardCapability fromEntity(EntityCapability capability) =>
      switch (capability) {
        EntityCapability.hire => DashboardCapability.hire,
        EntityCapability.offer => DashboardCapability.offer,
        EntityCapability.both => DashboardCapability.both,
      };

  /// Whether the hiring sections are visible.
  bool get showsHiring => this != DashboardCapability.offer;

  /// Whether the professional-work sections are visible.
  bool get showsWork => this != DashboardCapability.hire;

  /// User-facing account label (Hivorr terminology: Client/Professional/Both).
  String get label => switch (this) {
    DashboardCapability.hire => 'Client',
    DashboardCapability.offer => 'Professional',
    DashboardCapability.both => 'Both',
  };
}
