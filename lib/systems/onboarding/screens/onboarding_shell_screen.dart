import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/onboarding/screens/capability_selection_screen.dart';
import 'package:hivorr/systems/onboarding/screens/identity_verification_step_screen.dart';
import 'package:hivorr/systems/onboarding/screens/industry_profession_selection_screen.dart';
import 'package:hivorr/systems/onboarding/screens/onboarding_complete_screen.dart';
import 'package:hivorr/systems/onboarding/screens/profile_setup_screen.dart';
import 'package:hivorr/systems/onboarding/screens/trade_proof_step_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_exit_confirm_dialog.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_progress_indicator.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

/// Shell for the capability-aware registration wizard (EP-02-18 FV-28).
///
/// Basic Information comes first; the second step captures the entity's
/// capability (hire / offer / both); consumer-only entities then finish after
/// the capability step, while professional/`both` entities continue through
/// industry & profession selection → identity → trade proof. Progress is
/// stored by [OnboardingProgress] and the shell renders the tracker, the active
/// step body (kept alive in an [IndexedStack]), and the standard CTA bar
/// (`Back` / `Continue`/`Submit`). Step transitions update the GoRouter
/// location (`/onboarding/{step}`) while the provider remains the source of
/// truth. Back returns to the previous stage; the explicit AppBar `Exit`
/// affordance (and Back on the first stage) opens [OnboardingExitConfirmDialog]
/// (Save & exit).
class OnboardingShellScreen extends StatefulWidget {
  const OnboardingShellScreen({super.key});

  /// Maps a step code to its route name (step URL bookmarks the resume point).
  static String routeNameFor(OnboardingStepCode step) => switch (step) {
        OnboardingStepCode.capability => RouteNames.onboardingCapability,
        OnboardingStepCode.profile => RouteNames.onboardingProfile,
        OnboardingStepCode.industry => RouteNames.onboardingIndustry,
        OnboardingStepCode.identityDocument => RouteNames.onboardingIdentity,
        OnboardingStepCode.tradeProof => RouteNames.onboardingTradeProof,
      };

  @override
  State<OnboardingShellScreen> createState() => _OnboardingShellScreenState();
}

class _OnboardingShellScreenState extends State<OnboardingShellScreen> {
  final OnboardingStepController _controller = OnboardingStepController();
  bool _exitDialogOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final OnboardingStepCode step =
        provider.currentStep ?? OnboardingStepCode.profile;
    final bool terminal = provider.isComplete;
    // Defensive: never present the trade-proof step without a bound
    // profession — bounce the active body back to the combined industry &
    // profession selection step (ordinal 2).
    final bool showProfessionFallback =
        step == OnboardingStepCode.tradeProof &&
        context.read<TaxonomyProvider>().selectedProfession == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (terminal) {
          context.go(RoutePaths.home);
          return;
        }
        unawaited(_goBack(context, provider));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Registration', style: context.textTheme.titleLarge),
          leading: terminal
              ? null
              : BackButton(
                  onPressed: () => unawaited(_goBack(context, provider)),
                ),
          actions: <Widget>[
            if (!terminal)
              TextButton(
                onPressed: () => unawaited(_maybeExit(context, provider)),
                child: const Text('Exit'),
              ),
            const SizedBox(width: HivorrSpacing.sm),
          ],
        ),
        body: SafeArea(
          child: HivorrContentPane(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HivorrSpacing.lg,
                    HivorrSpacing.sm,
                    HivorrSpacing.lg,
                    HivorrSpacing.md,
                  ),
                  child: OnboardingProgressIndicator(
                    progress: provider.progress,
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _bodyIndex(
                      provider,
                      step,
                      terminal,
                      showProfessionFallback,
                    ),
                    children: <Widget>[
                      ProfileSetupScreen(
                        active: step == OnboardingStepCode.profile,
                        controller: _controller,
                      ),
                      CapabilitySelectionScreen(
                        active: step == OnboardingStepCode.capability,
                        controller: _controller,
                      ),
                      IndustryProfessionSelectionScreen(
                        active:
                            step == OnboardingStepCode.industry ||
                            showProfessionFallback,
                        controller: _controller,
                      ),
                      IdentityVerificationStepScreen(
                        active: step == OnboardingStepCode.identityDocument,
                        controller: _controller,
                      ),
                      TradeProofStepScreen(
                        active: step == OnboardingStepCode.tradeProof,
                        controller: _controller,
                      ),
                      OnboardingCompleteScreen(
                        active: terminal,
                        controller: _controller,
                      ),
                    ],
                  ),
                ),
                if (!terminal)
                  _BottomBar(
                    controller: _controller,
                    onBack: () => unawaited(_goBack(context, provider)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Steps back to the previous stage (persisting the position), except on
  /// the first step where Back means "leave the wizard" (exit-and-save). On
  /// success the URL is restored to the previous step's route.
  Future<void> _goBack(
    BuildContext context,
    OnboardingProvider provider,
  ) async {
    final OnboardingStepCode? step = provider.currentStep;
    if (step == null) {
      return;
    }
    if (step == OnboardingStepCode.profile) {
      unawaited(_maybeExit(context, provider));
      return;
    }
    await provider.back();
    if (!context.mounted) {
      return;
    }
    final OnboardingStepCode? now = provider.currentStep;
    if (now == step) {
      return;
    }
    context.goNamed(OnboardingShellScreen.routeNameFor(now ?? step));
  }

  int _bodyIndex(
    OnboardingProvider provider,
    OnboardingStepCode step,
    bool terminal,
    bool showProfessionFallback,
  ) {
    if (terminal) {
      return 5; // completion screen (last IndexedStack child)
    }
    if (showProfessionFallback) {
      return 2; // combined industry+profession step (trade-proof needs a bound profession)
    }
    return step.ordinal;
  }

  Future<void> _maybeExit(
    BuildContext context,
    OnboardingProvider provider,
  ) async {
    if (_exitDialogOpen) {
      return;
    }
    _exitDialogOpen = true;
    await OnboardingExitConfirmDialog.show(
      context,
      onExit: () {
        unawaited(provider.saveAndExit());
        context.go(RoutePaths.home);
      },
    );
    _exitDialogOpen = false;
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, required this.onBack});

  final OnboardingStepController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final bool hasPrimary = controller.primaryLabel.isNotEmpty;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              HivorrSpacing.lg,
              HivorrSpacing.sm,
              HivorrSpacing.lg,
              HivorrSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                HivorrButton(
                  label: 'Back',
                  variant: HivorrButtonVariant.outline,
                  onPressed: onBack,
                ),
                const SizedBox(width: HivorrSpacing.md),
                if (hasPrimary) ...<Widget>[
                  Expanded(
                    child: HivorrButton(
                      label: controller.primaryLabel,
                      isLoading: controller.primaryLoading,
                      isExpanded: true,
                      onPressed: controller.canPrimary
                          ? controller.onPrimary
                          : null,
                    ),
                  ),
                ] else ...<Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Wizard progress is saved automatically.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
