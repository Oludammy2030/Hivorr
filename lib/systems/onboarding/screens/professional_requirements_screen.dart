import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/models/professional_requirements.dart';
import 'package:provider/provider.dart';

/// Professional readiness checklist (identity audit Phase 4).
///
/// `GET /professional/requirements`. Shows what is needed to bid, publish,
/// and earn — each missing item deep-links to its fix. All states derive
/// from already-loaded onboarding + verification providers (refreshed on
/// entry); the server stays authoritative and this screen decides nothing.
class ProfessionalRequirementsScreen extends StatefulWidget {
  const ProfessionalRequirementsScreen({super.key});

  @override
  State<ProfessionalRequirementsScreen> createState() =>
      _ProfessionalRequirementsScreenState();
}

class _ProfessionalRequirementsScreenState
    extends State<ProfessionalRequirementsScreen> {
  bool _initialized = false;
  bool _refreshing = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh());
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    // Both refreshes absorb transport errors into provider state
    // (lastError); this screen reads that state instead of catching.
    await context.read<VerificationProvider>().refreshStatus();
    if (!mounted) return;
    try {
      await context.read<OnboardingProvider>().refreshGateStatus();
    } on Object {
      // Gate unknown — items render with the last-known state.
    }
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  List<ProfessionalRequirement> _items(
    OnboardingProvider onboarding,
    VerificationProvider verification,
  ) {
    final OnboardingProgress? progress = onboarding.progress;
    final bool isOffer =
        progress?.capability == EntityCapability.offer;
    final int bound =
        verification.status?.tradeVerifications.length ?? 0;
    final bool identityVerified =
        verification.status?.identityVerified ?? false;
    final bool identitySubmitted =
        progress?.hasIdentitySubmission ?? false;
    final bool tradeApproved = onboarding.isTradeGateOpen ?? false;
    final bool tradeSubmitted =
        progress?.hasTradeProofSubmission ?? false;
    return resolveProfessionalRequirements(
      isOfferFocus: isOffer,
      boundProfessions: bound,
      identityVerified: identityVerified,
      identitySubmitted: identitySubmitted,
      tradeApproved: tradeApproved,
      tradeSubmitted: tradeSubmitted,
      activitiesRoute: RoutePaths.activities,
      industryRoute: RoutePaths.onboardingIndustry,
      identityRoute: RoutePaths.onboardingIdentity,
      tradeRoute: RoutePaths.onboardingTradeProof,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Professional requirements')),
      body: HivorrContentPane(
        child: Consumer2<OnboardingProvider, VerificationProvider>(
          builder:
              (
                BuildContext context,
                OnboardingProvider onboarding,
                VerificationProvider verification,
                _,
              ) {
                if (_refreshing) {
                  return const HivorrLoadingState(
                    message: 'Checking your professional setup…',
                  );
                }
                // Hard failure with nothing usable: verification carries no
                // status at all. Otherwise render with last-known state.
                if (verification.status == null &&
                    verification.lastError != null) {
                  return HivorrErrorState(
                    message: 'Could not check requirements',
                    detail: verification.lastError!.message,
                    onRetry: () => unawaited(_refresh()),
                  );
                }
                final List<ProfessionalRequirement> items = _items(
                  onboarding,
                  verification,
                );
                if (ProfessionalRequirement.allDone(items)) {
                  return HivorrEmptyState(
                    icon: const Icon(Icons.check_circle_outline),
                    title: 'Ready to earn',
                    subtitle:
                        'Your professional setup is complete — bidding is unlocked.',
                    actionButton: HivorrButton(
                      label: 'Find work',
                      onPressed: () => context.go(
                        RoutePaths.dashboardOpportunities,
                      ),
                      variant: HivorrButtonVariant.primary,
                      isExpanded: true,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: HivorrSpacing.md,
                    ),
                    children: <Widget>[
                      Text(
                        'Complete these steps to bid, publish, and earn.',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: HivorrSpacing.md),
                      for (final ProfessionalRequirement item in items)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: HivorrSpacing.sm,
                          ),
                          child: _RequirementRow(
                            item: item,
                            onAction: item.destination == null
                                ? null
                                : () => context.push(item.destination!),
                          ),
                        ),
                    ],
                  ),
                );
              },
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.item, required this.onAction});

  final ProfessionalRequirement item;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final IconData icon;
    final Color accent;
    switch (item.state) {
      case ProfessionalRequirementState.done:
        icon = Icons.check_circle_outline;
        accent = colors.primary;
      case ProfessionalRequirementState.awaiting:
        icon = Icons.hourglass_empty_outlined;
        accent = colors.onSurfaceVariant;
      case ProfessionalRequirementState.action:
        icon = Icons.arrow_circle_right_outlined;
        accent = colors.error;
    }
    return HivorrCard(
      onTap: onAction,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: accent, size: 24),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (onAction != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.xs),
                  Text(
                    'Continue →',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
