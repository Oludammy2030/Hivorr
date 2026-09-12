/// The client-side onboarding step vocabulary (EP-02-18 §5.4, capability
/// corrected).
///
/// Seven values: the six wizard steps (`capability → profile → industry →
/// profession → identityDocument → tradeProof`) plus the terminal `completed`.
/// Pure Dart — no DTO or framework leakage. [isVerificationStep] is `true`
/// only for the two verification submissions (identity + trade). Consumer-only
/// entities finish after `profile`, so the professional steps
/// (`industry` → `tradeProof`) are not on their path.
enum OnboardingStep {
  capability(
    label: 'What will you do?',
    description: 'Choose how you\u2019ll use Hivorr \u2014 hire, offer, or both.',
    stepNumber: 1,
    isVerificationStep: false,
  ),
  profile(
    label: 'Profile',
    description:
        'Add your legal name, display name, bio, and a profile avatar.',
    stepNumber: 2,
    isVerificationStep: false,
  ),
  industry(
    label: 'Industry',
    description: 'Pick the industry that best describes your work.',
    stepNumber: 3,
    isVerificationStep: false,
  ),
  profession(
    label: 'Profession',
    description:
        'Choose your profession. This unlocks the trade-verification gate.',
    stepNumber: 4,
    isVerificationStep: false,
  ),
  identityDocument(
    label: 'Identity',
    description: 'Upload a government-issued ID to verify your identity.',
    stepNumber: 5,
    isVerificationStep: true,
  ),
  tradeProof(
    label: 'Trade proof',
    description: 'Upload proof of your trade to unlock bidding.',
    stepNumber: 6,
    isVerificationStep: true,
  ),
  completed(
    label: 'Complete',
    description: 'You\u2019re registered. Welcome to Hivorr.',
    stepNumber: 7,
    isVerificationStep: false,
  );

  const OnboardingStep({
    required this.label,
    required this.description,
    required this.stepNumber,
    required this.isVerificationStep,
  });

  /// Human-readable display label.
  final String label;

  /// One-line step explanation shown in step cards.
  final String description;

  /// Ordinal position in the wizard (1-based).
  final int stepNumber;

  /// Whether the step submits a verification document (identity/trade proof).
  final bool isVerificationStep;

  /// The wizard's non-terminal steps in frozen order.
  static const List<OnboardingStep> wizardSteps = <OnboardingStep>[
    OnboardingStep.capability,
    OnboardingStep.profile,
    OnboardingStep.industry,
    OnboardingStep.profession,
    OnboardingStep.identityDocument,
    OnboardingStep.tradeProof,
  ];

  /// Resolves the step following [step], or `null` at the end.
  ///
  /// `wizardSteps` is 0-indexed; `stepNumber` is 1-indexed, so the next step is
  /// `wizardSteps[stepNumber]` (valid while `stepNumber` is below the length).
  OnboardingStep? get next {
    final int index = stepNumber;
    if (index >= wizardSteps.length) {
      return null;
    }
    return wizardSteps[index];
  }

  /// Resolves the step preceding [step], or `null` at the first step.
  ///
  /// `wizardSteps[stepNumber - 2]` is the previous step for `stepNumber ≥ 2`.
  OnboardingStep? get previous {
    final int index = stepNumber - 2;
    if (index < 0) {
      return null;
    }
    return wizardSteps[index];
  }
}