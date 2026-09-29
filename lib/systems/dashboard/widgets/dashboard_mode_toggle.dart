import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:provider/provider.dart';

/// Segmented Professional | Client toggle for `Both` users.
///
/// UI-only: reflects [DashboardViewModeProvider.mode] and writes back via
/// `setMode`. Never touches account role, capability, or permissions.
/// Render only when `DashboardCapability == both` (callers gate visibility).
///
/// Uses mode-specific role accents for the active state
/// (`professionalContainer/Primary` vs `clientContainer/Primary`) on top of
/// the single unified `ColorScheme` — no redesign.
class DashboardModeToggle extends StatelessWidget {
  const DashboardModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardViewModeProvider viewMode = context.watch<
        DashboardViewModeProvider>();
    final DashboardViewMode mode = viewMode.mode;
    final RoleThemeExtension roles = context.roleTheme;

    final bool isProfessional = mode == DashboardViewMode.professional;
    final Color selectedBg = isProfessional
        ? roles.professionalContainer
        : roles.clientContainer;
    final Color selectedFg = isProfessional
        ? roles.professionalPrimary
        : roles.clientPrimary;

    return Semantics(
      label: 'Operating mode',
      child: SegmentedButton<DashboardViewMode>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<DashboardViewMode>>[
          ButtonSegment<DashboardViewMode>(
            value: DashboardViewMode.professional,
            icon: Icon(Icons.work_outline, size: 16),
            label: Text('Professional'),
          ),
          ButtonSegment<DashboardViewMode>(
            value: DashboardViewMode.client,
            icon: Icon(Icons.business_center_outlined, size: 16),
            label: Text('Client'),
          ),
        ],
        selected: <DashboardViewMode>{mode},
        onSelectionChanged: (Set<DashboardViewMode> selected) {
          if (selected.isNotEmpty) {
            context.read<DashboardViewModeProvider>().setMode(
              selected.first,
            );
          }
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: selectedBg,
          selectedForegroundColor: selectedFg,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
