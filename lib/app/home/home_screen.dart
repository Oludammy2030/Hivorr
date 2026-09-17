import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:provider/provider.dart';

/// Post-auth placeholder home (EP-02-18 §5.5).
///
/// For an incomplete wizard that was deliberately exited
/// ([OnboardingProgress.exited]), the screen surfaces a "Continue
/// registration" action that clears the exit flag (re-engaging the guard's
/// resume redirect) and returns to the saved step. Every other state renders a
/// minimal empty state — once the wizard is complete, feature screens replace
/// this placeholder (EP-02+).
///
/// Platform admins additionally see a console entry-point to the review
/// queue and manage-users directory.  The admin flag is hydrated lazily
/// from [AdminReviewProvider] (which is only provided in production);
/// the widget degrades gracefully when the provider is absent.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _adminChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateAdmin());
  }

  /// Calls [AdminReviewProvider.checkAdmin] once on mount when the
  /// provider is available.  This is safe in test harnesses that do
  /// not supply the provider — [_maybeAdmin] falls back to `null`.
  void _hydrateAdmin() {
    if (!mounted) return;
    final AdminReviewProvider? admin = _maybeAdmin(context);
    if (admin != null && !_adminChecked) {
      _adminChecked = true;
      unawaited(admin.checkAdmin());
    }
  }

  /// Optional read of [AdminReviewProvider].
  ///
  /// The provider is conditionally wired at the root (only prod admin
  /// builds).  `Provider.of<T?>` does not resolve a non-nullable
  /// registration, so this fall back to `null` instead of throwing.
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
    final bool complete =
        onboarding.isCompleteAuthoritative ?? onboarding.isComplete;
    final bool showResume = onboarding.progress != null && !complete && onboarding.exited;

    final AdminReviewProvider? admin = _maybeAdmin(context, listen: true);
    final bool isAdmin = AdminGate.isAdmin(admin);

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
                if (isAdmin) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.xl),
                  HivorrButton(
                    label: 'Review queue',
                    isExpanded: true,
                    onPressed: () => context.go(RoutePaths.adminReviewQueue),
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrButton(
                    label: 'Manage users',
                    variant: HivorrButtonVariant.outline,
                    isExpanded: true,
                    onPressed: () => context.go(RoutePaths.adminManageUsers),
                  ),
                ],
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
    await onboarding.continueRegistration();
    if (!context.mounted) {
      return;
    }
    final OnboardingStepCode step =
        onboarding.currentStep ?? OnboardingStepCode.profile;
    context.go(RoutePaths.onboardingRouteFor(step));
  }
}
