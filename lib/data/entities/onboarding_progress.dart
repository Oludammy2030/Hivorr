import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// The wizard steps in walk order (EP-02-18, capability-corrected).
///
/// `profile` (Basic Information) is the first step; `capability` follows it —
/// the entity declares how it will use the account (hire / offer / both) after
/// its identity basics are captured. [OnboardingProgress.isComplete] and the
/// advance machine follow [EntityCapability.requiresProfessionalWizard], so a
/// consumer-only entity never traverses the professional steps.
enum OnboardingStepCode {
  profile,
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
    this.step = OnboardingStepCode.profile,
    this.completedSteps = const <OnboardingStepCode>[],
    this.capability = EntityCapability.both,
    this.hasIdentitySubmission = false,
    this.hasTradeProofSubmission = false,
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

  /// Last write time (UTC epoch used as a stable default).
  final DateTime updatedAt;

  /// The steps this capability actually traverses.
  ///
  /// A [EntityCapability.hire] entity stops after `capability`; the professional
  /// steps (industry & profession selection → identity → tradeProof) are only
  /// required when [EntityCapability.requiresProfessionalWizard] holds.
  List<OnboardingStepCode> get requiredSteps => <OnboardingStepCode>[
        OnboardingStepCode.profile,
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
      OnboardingStepCode.profile => OnboardingStepCode.capability,
      OnboardingStepCode.capability => capability.requiresProfessionalWizard
          ? OnboardingStepCode.industry
          : null,
      OnboardingStepCode.industry => OnboardingStepCode.identityDocument,
      OnboardingStepCode.identityDocument => OnboardingStepCode.tradeProof,
      OnboardingStepCode.tradeProof => null,
    };
  }

  /// Whether every step on this capability's path is complete.
  bool get isComplete =>
      requiredSteps.every((OnboardingStepCode step) =>
          completedSteps.contains(step));

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
    updatedAt: updatedAt,
  );
}