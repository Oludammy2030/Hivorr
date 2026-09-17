/// Data Transfer Object for the onboarding-authoritative RPCs
/// (`entity_onboarding_status_get` / `entity_onboarding_status_update`).
///
/// Canonical server `data` shape (migration 20260915090001):
///   get:    { capability, onboarding_completed_at, completed, profile_exists,
///             professional_role_active, profession_exists }
///   update: { capability, onboarding_completed_at }
///
/// Field names are camelCase in Dart but map the server snake_case keys
/// exactly via [OnboardingStatusDto.fromJson] to avoid silent
/// deserialization drift.
class OnboardingStatusDto {
  const OnboardingStatusDto({
    this.capability,
    this.onboardingCompletedAt,
    required this.completed,
    this.profileExists = false,
    this.professionalRoleActive = false,
    this.professionExists = false,
  });

  factory OnboardingStatusDto.fromJson(Map<String, dynamic> json) {
    final DateTime? completedAt = _parseDate(json['onboarding_completed_at']);
    return OnboardingStatusDto(
      capability: json['capability'] as String?,
      onboardingCompletedAt: completedAt,
      // The update RPC returns only {capability, onboarding_completed_at} —
      // a non-null stamp is itself the completion signal there.
      completed: (json['completed'] as bool?) ?? completedAt != null,
      profileExists: (json['profile_exists'] as bool?) ?? false,
      professionalRoleActive:
          (json['professional_role_active'] as bool?) ?? false,
      professionExists: (json['profession_exists'] as bool?) ?? false,
    );
  }

  final String? capability;
  final DateTime? onboardingCompletedAt;
  final bool completed;
  final bool profileExists;
  final bool professionalRoleActive;
  final bool professionExists;
}

DateTime? _parseDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}