import 'package:hivorr/data/entities/onboarding_status.dart';
import 'package:hivorr/data/models/onboarding_status_dto.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// Transforms [OnboardingStatusDto] ↔ [OnboardingStatus].
///
/// The single transformation boundary between the transport DTO and the
/// pure-Dart domain entity (EP-01-08 §5.3). No I/O and no business logic.
/// A null/unknown server capability maps to `null` so the caller decides the
/// resume path (never silently defaulting to a capability the server did not
/// persist).
class OnboardingStatusMapper {
  const OnboardingStatusMapper._();

  /// Maps a server DTO into the domain entity.
  static OnboardingStatus toEntity(OnboardingStatusDto dto) => OnboardingStatus(
    completed: dto.completed,
    capability: _capabilityFrom(dto.capability),
    onboardingCompletedAt: dto.onboardingCompletedAt,
    profileExists: dto.profileExists,
    professionalRoleActive: dto.professionalRoleActive,
    professionExists: dto.professionExists,
  );

  static EntityCapability? _capabilityFrom(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    for (final EntityCapability value in EntityCapability.values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}
