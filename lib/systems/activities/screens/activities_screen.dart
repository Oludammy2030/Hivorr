import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/components/hivorr_feature_card.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/activities/models/hivorr_activity.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Unified-account launcher: "Welcome to Hivorr — How would you like to use
/// Hivorr?" (Explore with Hivorr / Earn with Hivorr).
///
/// Private authenticated route (`/activities`, no SEO). Activities are intent
/// entry points, not permissions: tapping a live card switches the account
/// focus if needed (via the existing onboarding RPC) and routes into the
/// matching live experience (or starts the matching onboarding flow); tapping
/// a coming-soon card is an honest waitlist state that grants nothing. Server
/// RPCs + RLS stay authoritative (AGENT.md Rule 4).
///
/// One account, switchable focus: the screen stays reachable after onboarding
/// (dashboard "Explore more" + More sheet) so entities can change sides any
/// time. There is no combined identity — switching never destroys earned
/// roles, bindings, credentials or history.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  HivorrActivity? _busyActivity;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hivorr')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.md),
          child: HivorrContentPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Welcome to Hivorr',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'One account. Multiple ways to use Hivorr — '
                  'pick what you need now, switch any time.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.lg),
                const HivorrSectionHeader(title: 'Explore with Hivorr'),
                _ActivityGrid(
                  activities: HivorrActivity.explore,
                  busyActivity: _busyActivity,
                  onTap: _onActivityTap,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                const HivorrSectionHeader(title: 'Earn with Hivorr'),
                _ActivityGrid(
                  activities: HivorrActivity.earn,
                  busyActivity: _busyActivity,
                  onTap: _onActivityTap,
                ),
                const SizedBox(height: HivorrSpacing.xl),
                HivorrButton(
                  label: 'Continue to dashboard',
                  variant: HivorrButtonVariant.outline,
                  isExpanded: true,
                  onPressed: _busyActivity == null
                      ? () => context.go(RoutePaths.dashboard)
                      : null,
                ),
                const SizedBox(height: HivorrSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onActivityTap(HivorrActivity activity) async {
    if (_busyActivity != null || !mounted) return;
    if (!activity.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message:
              '${activity.title} is coming soon — '
              'your Hivorr account is ready when it launches.',
        ),
      );
      return;
    }
    setState(() => _busyActivity = activity);
    try {
      final String target = await _resolveLiveTarget(activity);
      if (!mounted) return;
      context.go(target);
    } finally {
      if (mounted) setState(() => _busyActivity = null);
    }
  }

  /// Maps a live activity to its destination, switching the account focus
  /// first via the existing onboarding RPC (server-first
  /// `entity_onboarding_status_update`). Switching never destroys earned
  /// state — professional roles, bindings, credentials and history survive;
  /// only focus-gated writes follow the current focus. Never grants
  /// verification-gated writes — publish/bid gates stay server-enforced
  /// (Rule 2).
  Future<String> _resolveLiveTarget(HivorrActivity activity) async {
    final OnboardingProvider onboarding = context.read<OnboardingProvider>();
    final EntityCapability? current = onboarding.progress?.capability;
    final bool complete =
        onboarding.isCompleteAuthoritative ?? onboarding.isComplete;

    switch (activity) {
      case HivorrActivity.exploreServices:
        // Public-capable discovery: no focus change, no gate.
        return RoutePaths.serviceDiscovery;
      case HivorrActivity.hire:
        // Hire focus finishes the wizard in the same RPC; earned
        // professional state is retained server-side for switching back.
        if (current != EntityCapability.hire) {
          await onboarding.selectCapability(EntityCapability.hire);
        }
        return RoutePaths.dashboardJobNew;
      case HivorrActivity.offerServices:
        if (complete && current == EntityCapability.offer) {
          // Verified-path alumni go straight to work, not back to wizard
          // (complete + onboarding* would bounce to dashboard anyway).
          return RoutePaths.dashboardOpportunities;
        }
        if (current != EntityCapability.offer) {
          // Clears the completion stamp when leaving hire focus so the
          // professional wizard resumes at industry selection.
          await onboarding.selectCapability(EntityCapability.offer);
        }
        return RoutePaths.onboardingIndustry;
      case HivorrActivity.buy:
      case HivorrActivity.sell:
      case HivorrActivity.logistics:
        // Unreachable: guarded by isLive above. Fail-closed to discovery.
        return RoutePaths.serviceDiscovery;
    }
  }
}

/// Responsive activity grid: 1 column <600dp, 2 columns 600–1023dp,
/// 3 columns ≥1024dp (VISUAL-IDENTITY.md §20 + portfolio-grid precedent).
class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({
    required this.activities,
    required this.busyActivity,
    required this.onTap,
  });

  final List<HivorrActivity> activities;
  final HivorrActivity? busyActivity;
  final ValueChanged<HivorrActivity> onTap;

  static const double _gap = HivorrSpacing.md;

  static int _columnsForWidth(double maxWidth) {
    if (maxWidth < 600) return 1;
    if (maxWidth < 1024) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = _columnsForWidth(constraints.maxWidth);
        final double tileWidth =
            (constraints.maxWidth - (_gap * (columns - 1))) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: <Widget>[
            for (final HivorrActivity activity in activities)
              SizedBox(
                width: tileWidth,
                child: _ActivityCard(
                  activity: activity,
                  isBusy: busyActivity == activity,
                  isDisabled: busyActivity != null,
                  onTap: () => onTap(activity),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.isBusy,
    required this.isDisabled,
    required this.onTap,
  });

  final HivorrActivity activity;
  final bool isBusy;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    final (Color tileBg, Color tileFg) = _tintFor(activity, roles);
    return Stack(
      children: <Widget>[
        HivorrFeatureCard(
          icon: activity.icon,
          title: activity.title,
          body: activity.subtitle,
          iconBackground: tileBg,
          iconColor: tileFg,
          onTap: isDisabled && !isBusy ? null : onTap,
        ),
        if (!activity.isLive && activity.comingSoonLabel != null)
          Positioned(
            top: HivorrSpacing.sm,
            right: HivorrSpacing.sm,
            child: HivorrBadge(
              label: activity.comingSoonLabel!,
              variant: HivorrBadgeVariant.neutral,
            ),
          ),
        if (isBusy)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Side tints from [RoleThemeExtension] only (never raw hex): Explore cards
  /// in Client blue, Earn cards in Professional green. There is no combined
  /// tint — coming-soon cards carry their side's accent plus the badge.
  static (Color, Color) _tintFor(
    HivorrActivity activity,
    RoleThemeExtension roles,
  ) => switch (activity) {
    HivorrActivity.buy ||
    HivorrActivity.hire ||
    HivorrActivity.exploreServices => (
      roles.clientContainer,
      roles.clientPrimary,
    ),
    HivorrActivity.sell ||
    HivorrActivity.offerServices ||
    HivorrActivity.logistics => (
      roles.professionalContainer,
      roles.professionalPrimary,
    ),
  };
}
