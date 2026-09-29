import 'package:flutter/foundation.dart';

import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';

/// Current UI operating mode for `Both` users (Professional | Client).
///
/// UI-only clarification state — it never changes the underlying account
/// role, capability, or permissions:
/// * reads [DashboardCapability] (derived from `OnboardingProvider`) only to
///   decide whether the toggle applies (`both`) or passes through
///   (`hire`/`offer` single-role accounts never see the toggle);
/// * never calls `OnboardingService.selectCapability`, `activateRole`, or any
///   `entity_onboarding_status_update` seam.
/// * route guard (`RouteGuard._dashboardCapabilityRedirect`) stays on
///   `EntityCapability`, so deep links remain allowed in either mode.
enum DashboardViewMode {
  /// Professional operating mode — show work side, hide hiring side.
  professional,

  /// Client operating mode — show hiring side, hide work side.
  client;

  /// User-facing label for the segmented control.
  String get label => switch (this) {
    DashboardViewMode.professional => 'Professional',
    DashboardViewMode.client => 'Client',
  };
}

/// Ephemeral UI state for the Both-role mode toggle.
///
/// Defaults to [DashboardViewMode.professional] (Both accounts complete the
/// professional wizard). In-memory only — intentionally not persisted to the
/// server and not part of onboarding state.
class DashboardViewModeProvider extends ChangeNotifier {
  DashboardViewMode _mode = DashboardViewMode.professional;

  /// Currently selected operating mode.
  DashboardViewMode get mode => _mode;

  /// Whether the hiring sections are visible for [capability] + current mode.
  ///
  /// Single-role capabilities pass through unchanged; `both` resolves to
  /// `mode == client`.
  bool effectiveShowsHiring(DashboardCapability capability) {
    if (capability != DashboardCapability.both) {
      return capability.showsHiring;
    }
    return _mode == DashboardViewMode.client;
  }

  /// Whether the professional-work sections are visible for [capability].
  ///
  /// Single-role capabilities pass through unchanged; `both` resolves to
  /// `mode == professional`.
  bool effectiveShowsWork(DashboardCapability capability) {
    if (capability != DashboardCapability.both) {
      return capability.showsWork;
    }
    return _mode == DashboardViewMode.professional;
  }

  /// Selects a new operating mode (no-op when unchanged).
  void setMode(DashboardViewMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
