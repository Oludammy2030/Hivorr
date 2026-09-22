import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/admin/widgets/super_admin_sidebar.dart';
import 'package:provider/provider.dart';

/// Persistent Super Admin shell: narrow left nav + large workspace.
///
/// Desktop/tablet (>=600dp): fixed 248dp sidebar + expanded child.
/// Mobile (<600dp): AppBar + Drawer, drawer auto-closes after navigation.
///
/// Authorization: fail-closed via [AdminGate] over [AdminReviewProvider].
/// No frontend privilege escalation — backend still enforces PLT002.
class SuperAdminShell extends StatelessWidget {
  const SuperAdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final AdminReviewProvider? admin = _maybeAdmin(context, listen: true);
    final bool isAdmin = AdminGate.isAdmin(admin);
    final bool loadingAdmin = admin?.isAdmin == null;
    final Breakpoint bp = context.breakpoint;
    final bool isDesktop = bp != Breakpoint.mobile;

    if (loadingAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Super Admin')),
        body: const HivorrLoadingState(),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Super Admin')),
        body: SafeArea(
          child: HivorrEmptyState(
            icon: Icon(
              Icons.admin_panel_settings_outlined,
              color: context.colorScheme.primary,
            ),
            title: 'Admin access required',
            subtitle: 'You do not have platform admin privileges.',
          ),
        ),
      );
    }

    final Widget sidebar = SuperAdminSidebar(location: location);

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 248,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: context.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: sidebar,
                ),
              ),
              Expanded(child: _Workspace(child: child)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
      ),
      drawer: Drawer(
        width: 280,
        child: SuperAdminSidebar(
          location: location,
          onNavigate: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _Workspace(child: child)),
    );
  }

  AdminReviewProvider? _maybeAdmin(BuildContext context,
      {bool listen = false}) {
    try {
      return listen
          ? context.watch<AdminReviewProvider>()
          : context.read<AdminReviewProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colorScheme.surface,
      child: child,
    );
  }
}
