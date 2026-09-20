import 'package:hivorr/data/entities/onboarding_status.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

/// Abstract contract for the onboarding-authoritative status slice.
///
/// Depends only on the domain entity (no backend types) so the onboarding
/// service and route guard consume the abstraction, not the Supabase
/// implementation (EP-01-08 §5.6). This is the single source the client uses
/// to decide resume-vs-home after a refresh: the server, not the local store.
abstract class OnboardingRepository {
  /// Fetches the authoritative onboarding status for the current entity.
  Future<OnboardingStatus> getStatus();

  /// Mutates the server onboarding state (capability / completion).
  ///
  /// [capability] is persisted as soon as the wizard reaches that step;
  /// [completed] stamps `onboarding_completed_at` after server-side step
  /// verification (`PLT003` surfaces as a validation [ApiException] when a
  /// required step is missing). At least one value must be supplied.
  Future<OnboardingStatus> update({
    EntityCapability? capability,
    bool? completed,
  });
}
