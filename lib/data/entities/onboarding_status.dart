import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// Server-authoritative onboarding status for the current entity
/// (`entities.capability` + `entities.onboarding_completed_at` plus the
/// hydration probe flags returned by `entity_onboarding_status_get`).
///
/// This is the trust boundary for the route guard (AGENT.md Rule 2/3): the
/// local [OnboardingProgress] store remains a cache-only resume position.
/// [OnboardingStatus.completed] is `true` only when the server stamped
/// `onboarding_completed_at` after its own step verification.
class OnboardingStatus {
  const OnboardingStatus({
    required this.completed,
    this.capability,
    this.onboardingCompletedAt,
    this.profileExists = false,
    this.professionalRoleActive = false,
    this.professionExists = false,
  });

  /// Whether the server considers onboarding complete.
  final bool completed;

  /// The server-persisted capability (null until the wizard reaches the
  /// capability step).
  final EntityCapability? capability;

  /// The server-side completion stamp; null while incomplete.
  final DateTime? onboardingCompletedAt;

  /// Whether an `entity_profiles` row exists for the entity.
  final bool profileExists;

  /// Whether the fluid `professional` role is active.
  final bool professionalRoleActive;

  /// Whether at least one profession binding exists.
  final bool professionExists;
}
