/// Professional readiness checklist model (identity audit Phase 4).
///
/// Pure-Dart derivation of "what is needed" from already-loaded onboarding +
/// verification state — no I/O, no trust decisions. The server remains
/// authoritative (`AGENT.md` Rule 4); these rows only explain and deep-link.
enum ProfessionalRequirementState {
  /// Satisfied — no action needed.
  done,

  /// Submitted and under review — waiting, no action available.
  awaiting,

  /// Missing — the professional must act.
  action,
}

/// One row of the professional readiness checklist.
class ProfessionalRequirement {
  const ProfessionalRequirement({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.state,
    this.destination,
  });

  /// Stable key: `focus | profession | identity | trade`.
  final String key;

  /// Row title.
  final String title;

  /// State-specific explanation.
  final String subtitle;

  /// Row state.
  final ProfessionalRequirementState state;

  /// Deep-link route for `action` rows, or null when none applies.
  final String? destination;

  /// Whether every requirement is satisfied.
  static bool allDone(List<ProfessionalRequirement> items) =>
      items.isNotEmpty &&
      items.every(
        (ProfessionalRequirement item) =>
            item.state == ProfessionalRequirementState.done,
      );
}

/// Resolves the professional readiness checklist.
///
/// Mirrors the server's completion + gate vocabulary without re-deciding it:
/// focus from onboarding capability, binding/submission presence from the
/// verification aggregate and UX mirrors, approval from the trade gate.
List<ProfessionalRequirement> resolveProfessionalRequirements({
  required bool isOfferFocus,
  required int boundProfessions,
  required bool identityVerified,
  required bool identitySubmitted,
  required bool tradeApproved,
  required bool tradeSubmitted,
  bool identityNeedsAction = false,
  bool tradeNeedsAction = false,
  required String activitiesRoute,
  required String industryRoute,
  required String identityRoute,
  required String tradeRoute,
}) {
  final List<ProfessionalRequirement> items = <ProfessionalRequirement>[
    ProfessionalRequirement(
      key: 'focus',
      title: 'Earn focus active',
      subtitle: isOfferFocus
          ? 'You are set to offer services.'
          : 'Switch to Earn to offer services.',
      state: isOfferFocus
          ? ProfessionalRequirementState.done
          : ProfessionalRequirementState.action,
      destination: isOfferFocus ? null : activitiesRoute,
    ),
    ProfessionalRequirement(
      key: 'profession',
      title: 'Profession linked',
      subtitle: boundProfessions > 0
          ? '$boundProfessions profession(s) linked to your account.'
          : 'Choose the profession you want to offer.',
      state: boundProfessions > 0
          ? ProfessionalRequirementState.done
          : ProfessionalRequirementState.action,
      destination: boundProfessions > 0 ? null : industryRoute,
    ),
    ProfessionalRequirement(
      key: 'identity',
      title: 'Identity verified',
      subtitle: identityVerified
          ? 'Your identity is verified.'
          : identityNeedsAction
          ? 'Your identity document was not approved. Resubmit to continue.'
          : identitySubmitted
          ? 'Your identity document is under review.'
          : 'Upload an identity document for verification.',
      state: identityVerified
          ? ProfessionalRequirementState.done
          : identityNeedsAction
          ? ProfessionalRequirementState.action
          : identitySubmitted
          ? ProfessionalRequirementState.awaiting
          : ProfessionalRequirementState.action,
      destination:
          identityVerified || (identitySubmitted && !identityNeedsAction)
          ? null
          : identityRoute,
    ),
    ProfessionalRequirement(
      key: 'trade',
      title: 'Trade approved',
      subtitle: tradeApproved
          ? 'Bidding unlocked — your trade proof is approved.'
          : tradeNeedsAction
          ? 'Your trade proof was not approved. Resubmit to unlock bidding.'
          : tradeSubmitted
          ? 'Your trade proof is under review — bidding unlocks on approval.'
          : 'Submit proof of trade to unlock bidding.',
      state: tradeApproved
          ? ProfessionalRequirementState.done
          : tradeNeedsAction
          ? ProfessionalRequirementState.action
          : tradeSubmitted
          ? ProfessionalRequirementState.awaiting
          : ProfessionalRequirementState.action,
      destination: tradeApproved || (tradeSubmitted && !tradeNeedsAction)
          ? null
          : tradeRoute,
    ),
  ];
  return items;
}
