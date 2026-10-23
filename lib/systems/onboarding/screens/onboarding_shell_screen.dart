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
/// starts. The focus decision (hire / offer) is owned by the activity launcher
/// (`/activities`) — the wizard never renders an account-intent screen. The
/// professional path is industry & profession selection → identity → trade
/// proof. Progress is stored by [OnboardingProgress] and the shell renders the
/// tracker, the active step body (kept alive in an [IndexedStack]), and the
/// standard CTA bar (`Back` / `Continue`/`Submit`).
///
/// The shell is registered once under the single `/onboarding/:step` route, so
/// step transitions update the URL in place without recreating the shell's
/// State (controllers and step bodies survive). Explicit links — notably the
/// professional-requirements checklist — may target a verification step
/// directly; the shell honors a valid requested step by moving the resume point
/// there (without marking anything complete) and reconciling stale URLs back to
/// the saved position via [_reconcileUrl]. When entered from the checklist
/// (`?from=requirements`), Back returns to the checklist instead of stepping
/// backwards in the wizard. While a text field has focus, the first Back only
/// dismisses the keyboard ([_dismissKeyboardIfOpen]); the explicit AppBar `Exit`
/// affordance (and Back on the first professional step) opens
/// [OnboardingExitConfirmDialog] (Save & exit).
class OnboardingShellScreen extends StatefulWidget {
  const OnboardingShellScreen({super.key});

  @override
  State<OnboardingShellScreen> createState() => _OnboardingShellScreenState();
}

class _OnboardingShellScreenState extends State<OnboardingShellScreen> {
  final OnboardingStepController _controller = OnboardingStepController();
  bool _exitDialogOpen = false;
  bool _reconcileScheduled = false;
  bool _launcherScheduled = false;
  bool _focusScheduled = false;
  OnboardingStepCode? _focusTarget;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider provider = context.watch<OnboardingProvider>();
    final OnboardingStepCode persisted =
        provider.currentStep ?? OnboardingStepCode.capability;
    final bool terminal = provider.isComplete;
    final Uri uri = GoRouterState.of(context).uri;
    final OnboardingStepCode? requested = _stepForPath(uri.path);
    final bool fromRequirements = uri.queryParameters['from'] == 'requirements';

    // A valid URL target is an explicit request (requirements checklist) and
    // must win over the saved resume point, even when it moves the wizard
    // backwards (for example re-submitting identity after skipping it).
    final bool honorRequested =
        !terminal && requested != null && requested != persisted;
    final OnboardingStepCode step = honorRequested ? requested : persisted;

    if (honorRequested) {
      _scheduleFocus(provider, requested);
    }

    // The focus decision is launcher-owned; a saved capability position must
    // never render an account-intent screen inside the wizard.
    if (!terminal && step == OnboardingStepCode.capability) {
      _scheduleLauncher(context);
      return const Scaffold(body: SizedBox.shrink());
    }

    final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
    final String? professionIdOverride = uri.queryParameters['professionId'];
    final String? professionLabelOverride =
        uri.queryParameters['professionLabel'];
    // Requirements links carry the already-bound profession id, so trade proof
    // can open directly even when the in-memory taxonomy picker is cold.
    final bool hasProfession =
        taxonomy.selectedProfession != null ||
        (professionIdOverride != null && professionIdOverride.isNotEmpty);
    final bool showProfessionFallback =
        step == OnboardingStepCode.tradeProof && !hasProfession;

    _reconcileUrl(context, provider, step);

    final VoidCallback? onFinished = fromRequirements
        ? () => context.go(RoutePaths.professionalRequirements)
        : null;

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
        unawaited(
          _goBack(context, provider, fromRequirements: fromRequirements),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Registration', style: context.textTheme.titleLarge),
          leading: terminal
              ? null
              : BackButton(
                  onPressed: () => unawaited(
                    _goBack(
                      context,
                      provider,
                      fromRequirements: fromRequirements,
                    ),
                  ),
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
                    index: _bodyIndex(step, terminal, showProfessionFallback),
                    children: <Widget>[
                      IndustryProfessionSelectionScreen(
                        active:
                            step == OnboardingStepCode.industry ||
                            showProfessionFallback,
                        controller: _controller,
                      ),
                      IdentityVerificationStepScreen(
                        active: step == OnboardingStepCode.identityDocument,
                        controller: _controller,
                        onFinished: onFinished,
                      ),
                      TradeProofStepScreen(
                        active:
                            step == OnboardingStepCode.tradeProof &&
                            !showProfessionFallback,
                        controller: _controller,
                        professionId: professionIdOverride,
                        professionLabel: professionLabelOverride,
                        onFinished: onFinished,
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
                    onBack: () => unawaited(
                      _goBack(
                        context,
                        provider,
                        fromRequirements: fromRequirements,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The wizard step an explicit URL targets, or `null` for the canonical
  /// `/onboarding/:step` bookmarks that are not wizard screens.
  ///
  /// `capability` is launcher-owned (legacy bookmarks redirect), and the
  /// completion route is derived from [OnboardingProvider.isComplete].
  static OnboardingStepCode? _stepForPath(String path) => switch (path) {
    RoutePaths.onboardingIndustry => OnboardingStepCode.industry,
    RoutePaths.onboardingIdentity => OnboardingStepCode.identityDocument,
    RoutePaths.onboardingTradeProof => OnboardingStepCode.tradeProof,
    _ => null,
  };

  /// Moves the resume point to [target] once per request so step screens
  /// advance from the step the user is actually viewing. Deferred to a
  /// post-frame callback to avoid mutating providers during build.
  void _scheduleFocus(OnboardingProvider provider, OnboardingStepCode target) {
    if (_focusScheduled && _focusTarget == target) {
      return;
    }
    _focusScheduled = true;
    _focusTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusScheduled = false;
      _focusTarget = null;
      if (!mounted) {
        return;
      }
      await provider.focusStep(target);
    });
  }

  /// The launcher owns the focus choice; redirect a saved capability position
  /// (or a legacy `/onboarding/capability` bookmark) there.
  void _scheduleLauncher(BuildContext context) {
    if (_launcherScheduled) {
      return;
    }
    _launcherScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launcherScheduled = false;
      if (!mounted) {
        return;
      }
      context.go(RoutePaths.activities);
    });
  }

  /// Steps back to the previous stage (persisting the position), except on
  /// the first professional step where Back means "leave the wizard"
  /// (exit-and-save). A checklist entry returns to the checklist instead.
  ///
  /// Keyboard-first: while a text field holds focus, the first Back only
  /// dismisses the keyboard — the next Back then navigates. This matches the
  /// native Android convention (IME swallows the first system Back) for both
  /// the in-app buttons and the system gesture.
  Future<void> _goBack(
    BuildContext context,
    OnboardingProvider provider, {
    required bool fromRequirements,
  }) async {
    if (_dismissKeyboardIfOpen()) {
      return;
    }
    if (fromRequirements) {
      context.go(RoutePaths.professionalRequirements);
      return;
    }
    final OnboardingStepCode? step = provider.currentStep;
    if (step == null) {
      return;
    }
    // The launcher owns the focus decision; industry is the wizard's first
    // (and identity-free) stage, so Back there means "leave the wizard".
    final bool atFirstInteractiveStep =
        step == OnboardingStepCode.capability ||
        step == OnboardingStepCode.industry;
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

  /// Keeps the URL aligned with the resolved step (EP-02-18 §5.7). A valid
  /// requested step has already been resolved into [step]; stale bookmarks
  /// (for example a legacy `/onboarding/capability` URL behind the saved
  /// position) are replaced with the canonical route. Query parameters — the
  /// checklist return marker and profession hint — are preserved.
  void _reconcileUrl(
    BuildContext context,
    OnboardingProvider provider,
    OnboardingStepCode step,
  ) {
    if (provider.progress == null || _reconcileScheduled) {
      return;
    }
    final String canonical = provider.isComplete
        ? RoutePaths.onboardingComplete
        : RoutePaths.onboardingRouteFor(step);
    final Uri uri = GoRouterState.of(context).uri;
    if (uri.path == canonical) {
      return;
    }
    final String target = uri.hasQuery ? '$canonical?${uri.query}' : canonical;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (!mounted) {
        return;
      }
      if (GoRouterState.of(context).uri.path != canonical) {
        context.go(target);
      }
    });
  }

  int _bodyIndex(
    OnboardingStepCode step,
    bool terminal,
    bool showProfessionFallback,
  ) {
    if (terminal) {
      return 3; // completion screen (last IndexedStack child)
    }
    if (showProfessionFallback) {
      return 0; // combined industry+profession step (trade-proof needs a bound profession)
    }
    return switch (step) {
      OnboardingStepCode.capability || OnboardingStepCode.industry => 0,
      OnboardingStepCode.identityDocument => 1,
      OnboardingStepCode.tradeProof => 2,
    };
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
        final ColorScheme colors = context.colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            padding: const EdgeInsets.fromLTRB(
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
