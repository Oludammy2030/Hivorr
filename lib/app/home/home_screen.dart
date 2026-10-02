import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:provider/provider.dart';

/// Post-auth entry redirector (EP-04-03).
///
/// For an incomplete wizard that was deliberately exited
/// ([OnboardingProgress.exited]), the screen surfaces a "Continue
/// registration" action that clears the exit flag (re-engaging the guard's
/// resume redirect) and returns to the saved step. Incomplete wizards that
/// were not exited forward to [RoutePaths.dashboard] so [RouteGuard]
/// resumes onboarding. Completed super-admins always land on
/// [RoutePaths.adminDashboard] (staging + production); other completed
/// entities land on [RoutePaths.dashboard].
///
/// Super Admins no longer see a legacy gateway here. The forward waits for
/// `AdminReviewProvider.isAdmin` hydration so an admin never flashes the
/// Both dashboard on entry.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _adminChecked = false;
  bool _forwarded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateAdmin());
  }

  void _hydrateAdmin() {
    if (!mounted) return;
    final AdminReviewProvider? admin = _maybeAdmin(context);
    if (admin != null && !_adminChecked) {
      _adminChecked = true;
      unawaited(admin.checkAdmin());
    }
  }

  AdminReviewProvider? _maybeAdmin(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return listen
          ? context.watch<AdminReviewProvider>()
          : context.read<AdminReviewProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
    final AdminReviewProvider? admin = _maybeAdmin(context, listen: true);
    final bool complete =
        onboarding.isCompleteAuthoritative ?? onboarding.isComplete;
    final bool showResume =
        onboarding.progress != null && !complete && onboarding.exited;

    if (!showResume && !_forwarded) {
      if (!complete) {
        // Incomplete wizard: forward to the dashboard so RouteGuard resumes
        // the wizard. Applies to admins too (onboarding takes precedence).
        _forwarded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(RoutePaths.dashboard);
        });
      } else if (admin == null) {
        // No admin seam (isolated tests): preserve legacy forward.
        _forwarded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(RoutePaths.dashboard);
        });
      } else if (admin.isAdmin == null) {
        // Admin hydration pending: hold here so a super-admin never flashes
        // the Both dashboard. RouteGuard defers '/' the same way.
      } else {
        final String target = admin.isAdmin == true
            ? RoutePaths.adminDashboard
            : RoutePaths.dashboard;
        _forwarded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(target);
        });
      }
    }

    if (!showResume && admin != null && admin.isAdmin == null && complete) {
      return Scaffold(
        appBar: AppBar(title: Text('Home', style: context.textTheme.titleLarge)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Home', style: context.textTheme.titleLarge)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showResume)
                  HivorrButton(
                    label: 'Continue registration',
                    isExpanded: true,
                    onPressed: () => unawaited(_resume(context, onboarding)),
                  )
                else
                  Text(
                    'Welcome to Hivorr',
                    style: context.textTheme.titleMedium,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Clears the [OnboardingProgress.exited] flag and routes to the saved step.
  Future<void> _resume(
    BuildContext context,
    OnboardingProvider onboarding,
  ) async {
    // Suppress the dashboard auto-forward: this tap owns the navigation.
    _forwarded = true;
    await onboarding.continueRegistration();
    if (!context.mounted) {
      return;
    }
    final OnboardingStepCode step =
        onboarding.currentStep ?? OnboardingStepCode.capability;
    context.go(RoutePaths.onboardingRouteFor(step));
  }
}
