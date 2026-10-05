import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// The dashboard visibility derived from the entity focus (EP-04-03).
///
/// Mirrors the unified account: one account, one switchable focus. [hire]
/// sees hiring sections, [offer] sees work sections; both sides share the
/// Shared sections. There is no combined value — multi-activity use is
/// achieved by switching focus in the Explore/Earn launcher, never by a
/// combined identity.
enum DashboardCapability {
  /// Hiring side only (Client).
  hire,

  /// Professional-work side only (Professional).
  offer;

  /// Resolves the dashboard capability from the onboarding [capability].
  static DashboardCapability fromEntity(EntityCapability capability) =>
      switch (capability) {
        EntityCapability.hire => DashboardCapability.hire,
        EntityCapability.offer => DashboardCapability.offer,
      };

  /// Whether the hiring sections are visible.
  bool get showsHiring => this == DashboardCapability.hire;

  /// Whether the professional-work sections are visible.
  bool get showsWork => this == DashboardCapability.offer;

  /// User-facing account label (Hivorr terminology: Client/Professional).
  String get label => switch (this) {
    DashboardCapability.hire => 'Client',
    DashboardCapability.offer => 'Professional',
  };
}
