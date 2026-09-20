import 'package:hivorr/data/models/onboarding_status_dto.dart';

/// Abstract contract for the remote (Supabase) side of onboarding state.
///
/// Implementations must access the backend only through the EP-01-07
/// `BaseApiService` channel — never constructing clients directly
/// (EP-01-08 §5.4). Both RPCs are self-scoped by RLS (`auth.uid()`), the
/// mutation is guarded server-side by `entities_guard_onboarding_state`
/// (migration 20260915090001).
abstract class OnboardingRemoteDataSource {
  /// Fetches the authoritative onboarding status for the current entity via
  /// `entity_onboarding_status_get`.
  Future<OnboardingStatusDto> getStatus();

  /// Mutates onboarding state via `entity_onboarding_status_update`.
  ///
  /// [capability] persists the capability choice server-side as soon as the
  /// wizard step is reached; [completed] stamps (or, when `false`, clears)
  /// `onboarding_completed_at`. Completion is only accepted after server-side
  /// step verification (PLT003 otherwise). At least one parameter must be
  /// supplied.
  Future<OnboardingStatusDto> updateStatus({
    String? capability,
    bool? completed,
  });
}
