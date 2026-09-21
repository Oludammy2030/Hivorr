import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import 'package:hivorr/systems/onboarding/screens/trade_proof_step_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_exit_confirm_dialog.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_progress_indicator.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

/// Shell for the capability-aware registration wizard (EP-02-18 FV-28,
/// registration restructuring).
///
/// Identity (first/middle/last, displayName, phone, email) is captured at
/// account creation and hydrated into `entity_profiles` before onboarding
/// starts — onboarding therefore begins at the capability decision
/// (hire / offer / both) and never re-asks for basic identity information.
/// Bio and avatar are profile concerns handled later via Profile → Edit
/// Profile, never in-wizard. Consumer-only entities finish after capability,
/// professional/`both` continue through industry & profession selection →
/// identity → trade proof. Progress is stored by [OnboardingProgress] and the
/// shell renders the tracker, the active step body (kept alive in an
/// [IndexedStack]), and the standard CTA bar (`Back` / `Continue`/`Submit`).
/// The shell is registered once under the single `/onboarding/:step` route,
/// so step transitions update the URL in place without recreating the shell's
/// State (controllers and step bodies survive). The provider remains the
/// source of truth: [go_router] URL and current step stay aligned via
/// [_reconcileUrl]. Back returns to the previous stage — while a text field
/// has focus, the first Back only dismisses the keyboard
/// ([_dismissKeyboardIfOpen]); the explicit AppBar `Exit` affordance (and
/// Back on the first stage) opens [OnboardingExitConfirmDialog]
/// (Save & exit).
class OnboardingShellScreen extends StatefulWidget {
  const OnboardingShellScreen({super.key});

  @override
  State<OnboardingShellScreen> createState() => _OnboardingShellScreenState();
}

class _OnboardingShellScreenState extends State<OnboardingShellScreen> {
  final OnboardingStepController _controller = OnboardingStepController();
  bool _exitDialogOpen = false;
  bool _reconcileScheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final OnboardingStepCode step =
        provider.currentStep ?? OnboardingStepCode.capability;
    final bool terminal = provider.isComplete;
    // Defensive: never present the trade-proof step without a bound
    // profession — bounce the active body back to the combined industry &
    // profession selection step (ordinal 2).
    final bool showProfessionFallback =
        step == OnboardingStepCode.tradeProof &&
        context.read<TaxonomyProvider>().selectedProfession == null;

    _reconcileUrl(context, provider);

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
  ///
  /// Keyboard-first: while a text field holds focus, the first Back only
  /// dismisses the keyboard — the next Back then navigates. This matches the
  /// native Android convention (IME swallows the first system Back) for both
  /// the in-app buttons and the system gesture.
  Future<void> _goBack(
    BuildContext context,
    OnboardingProvider provider,
  ) async {
    if (_dismissKeyboardIfOpen()) {
      return;
    }
    final OnboardingStepCode? step = provider.currentStep;
    if (step == null) {
      return;
    }
    // Capability is the wizard's first (and identity-free) step — Back there
    // means "leave the wizard" (exit-and-save).
    final bool atFirstInteractiveStep =
        step == OnboardingStepCode.capability;
    if (atFirstInteractiveStep) {
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
    context.go(RoutePaths.onboardingRouteFor(now ?? step));
  }

  /// Dismisses the keyboard when an editable text field holds focus.
  ///
  /// Returns `true` when it dismissed a keyboard (the caller returns without
  /// navigating); the next Back may then step back.
  static bool _dismissKeyboardIfOpen() {
    final FocusNode? node = FocusManager.instance.primaryFocus;
    final BuildContext? nodeContext = node?.context;
    if (node == null ||
        nodeContext == null ||
        nodeContext.findAncestorWidgetOfExactType<EditableText>() == null) {
      return false;
    }
    node.unfocus();
    return true;
  }

  /// Keeps the URL aligned with the provider step (EP-02-18 §5.7), the wizard's
  /// source of truth. After a cold deep link — or any URL stuck on an outdated
  /// step — the canonical step route replaces it; once aligned, this is a no-op.
  /// Unknown/stray segments never map to a valid step: they fall through to
  /// `go_router`'s unmatched-route handling (404) or are realigned here.
  void _reconcileUrl(BuildContext context, OnboardingProvider provider) {
    if (provider.progress == null || _reconcileScheduled) {
      return;
    }
    final String canonical = provider.isComplete
        ? RoutePaths.onboardingComplete
        : RoutePaths.onboardingRouteFor(
            provider.currentStep ?? OnboardingStepCode.capability,
          );
    final String current = GoRouterState.of(context).uri.path;
    if (current == canonical) {
      return;
    }
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (!mounted) {
        return;
      }
      if (GoRouterState.of(context).uri.path != canonical) {
        context.go(canonical);
      }
    });
  }

  int _bodyIndex(
    OnboardingProvider provider,
    OnboardingStepCode step,
    bool terminal,
    bool showProfessionFallback,
  ) {
    if (terminal) {
      return 4; // completion screen (last IndexedStack child)
    }
    if (showProfessionFallback) {
      return 1; // combined industry+profession step (trade-proof needs a bound profession)
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
        unawaited(provider.exitWizard());
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
