import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// The wizard steps in walk order (EP-02-18, registration-restructured).
///
/// `capability` is the first step — identity (names, display name, email,
/// phone) is captured at account registration and hydrated into
/// `entity_profiles` before onboarding starts, so the wizard never re-asks
/// for it. [OnboardingProgress.isComplete] and the advance machine follow
/// [EntityCapability.requiresProfessionalWizard], so a consumer-only entity
/// never traverses the professional steps.
enum OnboardingStepCode {
  capability,
  industry,
  identityDocument,
  tradeProof;

  /// The frozen ordinal used for ordering comparisons.
  int get ordinal => index;
}

/// Immutable client-local wizard position for EP-02-18 onboarding.
///
/// Holds *only* position state (the resumable step machine). Verification
/// status is the server authority — the flags [hasIdentitySubmission] /
/// [hasTradeProofSubmission] are UX mirrors, never consulted as trust state
/// (AGENT.md Rule 4).
class OnboardingProgress {
  OnboardingProgress({
    required this.entityId,
    this.step = OnboardingStepCode.capability,
    this.completedSteps = const <OnboardingStepCode>[],
    this.capability = EntityCapability.both,
    this.hasIdentitySubmission = false,
    this.hasTradeProofSubmission = false,
    this.exited = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// The owning entity id (progress is keyed `onboarding_progress:{entityId}`).
  final String entityId;

  /// The furthest step reached — the resume point.
  final OnboardingStepCode step;

  /// Completed steps in definition order (monotonically advancing).
  final List<OnboardingStepCode> completedSteps;

  /// The declared capability, defaulting to [EntityCapability.both] so saved
  /// positions written before capabilities existed resume on the professional
  /// path (safe superset) instead of stranding the user.
  final EntityCapability capability;

  /// Whether an identity document was submitted (UX mirror only).
  final bool hasIdentitySubmission;

  /// Whether a trade proof was submitted (UX mirror only).
  final bool hasTradeProofSubmission;

  /// Whether the user deliberately saved-and-exited the wizard (Save & exit,
  /// Back on the first step, or the dialog's confirm action).
  ///
  /// While [exited] is `true`, the entry guard leaves the placeholder home
  /// reachable instead of force-resuming the wizard, and the home screen offers
  /// a "Continue registration" action that clears the flag ([withExited]).
  /// Lifecycle-background saves never set this — only an explicit exit does.
  final bool exited;

  /// Last write time (UTC epoch used as a stable default).
  final DateTime updatedAt;

  /// The steps this capability actually traverses.
  ///
  /// A [EntityCapability.hire] entity stops after `capability`; the professional
  /// steps (industry & profession selection → identity → tradeProof) are only
  /// required when [EntityCapability.requiresProfessionalWizard] holds.
  List<OnboardingStepCode> get requiredSteps => <OnboardingStepCode>[
    OnboardingStepCode.capability,
    if (capability.requiresProfessionalWizard) ...<OnboardingStepCode>[
      OnboardingStepCode.industry,
      OnboardingStepCode.identityDocument,
      OnboardingStepCode.tradeProof,
    ],
  ];

  /// The step that follows [step] for the current capability, or `null` when
  /// the wizard has reached its final input step and should finish.
  ///
  /// This is the single place the advance order branches: a hire-only entity
  /// finishes right after the capability step instead of continuing into the
  /// professional steps.
  OnboardingStepCode? get nextStep {
    if (isComplete) {
      return null;
    }
    return switch (step) {
      OnboardingStepCode.capability =>
        capability.requiresProfessionalWizard
            ? OnboardingStepCode.industry
            : null,
      OnboardingStepCode.industry => OnboardingStepCode.identityDocument,
      OnboardingStepCode.identityDocument => OnboardingStepCode.tradeProof,
      OnboardingStepCode.tradeProof => null,
    };
  }

  /// Whether every step on this capability's path is complete.
  bool get isComplete => requiredSteps.every(
    (OnboardingStepCode step) => completedSteps.contains(step),
  );

  /// A copy advanced so [next] becomes the resume point.
  ///
  /// All steps strictly before [next] are marked completed — the wizard
  /// advances linearly and never skips a required step. Verification mirror
  /// flags, the owned capability, and the entity id are preserved.
  OnboardingProgress advanceTo(OnboardingStepCode next) => OnboardingProgress(
    entityId: entityId,
    step: next,
    completedSteps: <OnboardingStepCode>[
      for (final OnboardingStepCode s in OnboardingStepCode.values)
        if (s.ordinal < next.ordinal) s,
    ],
    capability: capability,
    hasIdentitySubmission: hasIdentitySubmission,
    hasTradeProofSubmission: hasTradeProofSubmission,
    exited: exited,
    updatedAt: DateTime.now(),
  );

  /// A copy stepped back to the previous step (stays put at the first step).
  ///
  /// [completedSteps] is intentionally untouched — revisiting a step re-runs
  /// its action; the wizard remains resumable and monotonic.
  OnboardingProgress stepBack() {
    final int previous = step.ordinal - 1;
    return OnboardingProgress(
      entityId: entityId,
      step: previous >= 0 ? OnboardingStepCode.values[previous] : step,
      completedSteps: completedSteps,
      capability: capability,
      hasIdentitySubmission: hasIdentitySubmission,
      hasTradeProofSubmission: hasTradeProofSubmission,
      exited: exited,
      updatedAt: DateTime.now(),
    );
  }

  /// A copy with every step on this capability's path marked complete
  /// ([isComplete] then holds).
  OnboardingProgress finish() => OnboardingProgress(
    entityId: entityId,
    step: step,
    completedSteps: requiredSteps,
    capability: capability,
    hasIdentitySubmission: hasIdentitySubmission,
    hasTradeProofSubmission: hasTradeProofSubmission,
    exited: exited,
    updatedAt: DateTime.now(),
  );

  /// A copy with [capability] set. [OnboardingProgress.updateAt] refreshes;
  /// [step]/[completedSteps] are left untouched (the caller separately
  /// advances when resuming a capability-only position).
  OnboardingProgress withCapability(EntityCapability value) =>
      OnboardingProgress(
        entityId: entityId,
        step: step,
        completedSteps: completedSteps,
        capability: value,
        hasIdentitySubmission: hasIdentitySubmission,
        hasTradeProofSubmission: hasTradeProofSubmission,
        exited: exited,
        updatedAt: DateTime.now(),
      );

  /// A copy with the identity-submission mirror flag set.
  OnboardingProgress withIdentitySubmission(bool value) => OnboardingProgress(
    entityId: entityId,
    step: step,
    completedSteps: completedSteps,
    capability: capability,
    hasIdentitySubmission: value,
    hasTradeProofSubmission: hasTradeProofSubmission,
    exited: exited,
    updatedAt: DateTime.now(),
  );

  /// A copy with the trade-proof-submission mirror flag set.
  OnboardingProgress withTradeProofSubmission(bool value) => OnboardingProgress(
    entityId: entityId,
    step: step,
    completedSteps: completedSteps,
    capability: capability,
    hasIdentitySubmission: hasIdentitySubmission,
    hasTradeProofSubmission: value,
    exited: exited,
    updatedAt: DateTime.now(),
  );

  /// A copy with the explicit-exit flag set ([exited]). [OnboardingProgress.updatedAt]
  /// refreshes; position, capability and verification mirrors are untouched.
  /// [continueRegistration] flips the flag back to `false`.
  OnboardingProgress withExited(bool value) => OnboardingProgress(
    entityId: entityId,
    step: step,
    completedSteps: completedSteps,
    capability: capability,
    hasIdentitySubmission: hasIdentitySubmission,
    hasTradeProofSubmission: hasTradeProofSubmission,
    exited: value,
    updatedAt: DateTime.now(),
  );

  /// A copy for [entityId] (account switch rebinds the key).
  OnboardingProgress forEntity(String newEntityId) => OnboardingProgress(
    entityId: newEntityId,
    step: step,
    completedSteps: completedSteps,
    capability: capability,
    hasIdentitySubmission: hasIdentitySubmission,
    hasTradeProofSubmission: hasTradeProofSubmission,
    exited: exited,
    updatedAt: updatedAt,
  );
}
