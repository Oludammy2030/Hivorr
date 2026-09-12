import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/models/onboarding_step.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_card.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

/// Step 7 — completed (EP-02-18 FV-27, FV-34, FV-36).
///
/// `HivorrSuccessState` ("You're registered"), read-only step cards for the
/// capability's own path, a trust-loop panel summarising the identity/trade
/// submissions plus the Rule 2 bid gate (only on professional paths),
/// next-action links and a "Go to home" CTA.
class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({
    super.key,
    required this.active,
    required this.controller,
  });

  final bool active;
  final OnboardingStepController controller;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return const SizedBox.shrink();
    }
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final OnboardingProgress? progress = provider.progress;
    final EntityCapability capability =
        progress?.capability ?? EntityCapability.both;
    final List<OnboardingStep> pathSteps = _stepsFor(capability);
    controller.hidePrimary();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HivorrSuccessState(
              title: 'You\u2019re registered',
              subtitle: _subtitleFor(capability),
              actionButton: HivorrButton(
                label: 'Go to home',
                size: HivorrButtonSize.large,
                onPressed: () => context.goNamed(RouteNames.home),
              ),
            ),
            const SizedBox(height: HivorrSpacing.lg),
            Text(
              'Your ${pathSteps.length} steps',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: HivorrSpacing.sm),
            for (final OnboardingStep step in pathSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
                child: OnboardingStepCard(
                  icon: _iconFor(step),
                  title: step.label,
                  description: step.description,
                  isDone: true,
                ),
              ),
            if (capability.requiresProfessionalWizard)
              _TrustLoopPanel(
                identitySubmitted: progress?.hasIdentitySubmission ?? false,
                gateOpen: provider.isTradeGateOpen,
                onViewStatus: () =>
                    context.goNamed(RouteNames.verificationStatus),
                onFinancialProfile: () =>
                    context.goNamed(RouteNames.finance),
              ),
          ],
        ),
      ),
    );
  }

  /// The steps actually traversed by [capability] on its way to completion.
  static List<OnboardingStep> _stepsFor(EntityCapability capability) {
    final List<OnboardingStep> steps = <OnboardingStep>[
      OnboardingStep.capability,
      OnboardingStep.profile,
      if (capability.requiresProfessionalWizard) ...<OnboardingStep>[
        OnboardingStep.industry,
        OnboardingStep.profession,
        OnboardingStep.identityDocument,
        OnboardingStep.tradeProof,
      ],
    ];
    return steps;
  }

  static String _subtitleFor(EntityCapability capability) =>
      capability == EntityCapability.hire
          ? 'Your account is ready. Browse professionals and hire with '
              'confidence — no verification needed to get started.'
          : 'Your profile is live. You can start work right away — '
              'bidding unlocks once your trade proof is approved.';

  static IconData _iconFor(OnboardingStep step) => switch (step) {
        OnboardingStep.capability => Icons.all_inclusive_outlined,
        OnboardingStep.profile => Icons.person_outline,
        OnboardingStep.industry => Icons.dashboard_outlined,
        OnboardingStep.profession => Icons.work_outline,
        OnboardingStep.identityDocument => Icons.badge_outlined,
        OnboardingStep.tradeProof => Icons.verified_outlined,
        OnboardingStep.completed => Icons.check_circle_outline,
      };
}

/// Read-only trust-loop summary: identity/trade submission status + Rule 2
/// gate copy (AGENT.md Rule 2) and forward links. Only shown on the
/// professional paths (hire-only entities submit no credentials in-wizard).
class _TrustLoopPanel extends StatelessWidget {
  const _TrustLoopPanel({
    required this.identitySubmitted,
    required this.gateOpen,
    required this.onViewStatus,
    required this.onFinancialProfile,
  });

  final bool identitySubmitted;
  final bool? gateOpen;
  final VoidCallback onViewStatus;
  final VoidCallback onFinancialProfile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool open = gateOpen == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: HivorrSpacing.sm),
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Trust loop', style: context.textTheme.titleMedium),
          const SizedBox(height: HivorrSpacing.md),
          _TrustRow(
            icon: identitySubmitted
                ? Icons.verified_outlined
                : Icons.help_outline,
            accent: identitySubmitted ? ext.success : colors.onSurfaceVariant,
            title: 'Identity document',
            body: identitySubmitted
                ? 'Submitted — reviewed within 24 hours.'
                : 'Not submitted yet.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          _TrustRow(
            icon: open ? Icons.lock_open_outlined : Icons.lock_outline,
            accent: open ? ext.success : colors.onSurfaceVariant,
            title: 'Trade proof',
            body: open
                ? 'Approved — you can place bids right away.'
                : 'You can start work immediately — bidding unlocks once your '
                      'trade proof is approved.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          Text('Next', style: context.textTheme.labelMedium),
          const SizedBox(height: HivorrSpacing.xs),
          Wrap(
            spacing: HivorrSpacing.xs,
            children: <Widget>[
              TextButton(
                onPressed: onViewStatus,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('View verification status'),
              ),
              TextButton(
                onPressed: onFinancialProfile,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Financial profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: accent, size: 24),
        const SizedBox(width: HivorrSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: context.textTheme.titleSmall),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                body,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}