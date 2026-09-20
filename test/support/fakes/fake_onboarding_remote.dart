import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/onboarding_remote_data_source.dart';
import 'package:hivorr/data/models/onboarding_status_dto.dart';

/// In-memory fake of [OnboardingRemoteDataSource] for tests.
///
/// Defaults to an incomplete (fresh) server state so a wizard under test
/// starts without a server completion. Tests flip [status] to simulate a
/// completed refresh hydration, and [nextGetError]/[nextUpdateError] to
/// simulate offline/validation failures.
class FakeOnboardingRemoteDataSource implements OnboardingRemoteDataSource {
  /// The status returned by [getStatus] / carried back by [updateStatus].
  OnboardingStatusDto status = const OnboardingStatusDto(completed: false);

  /// Number of [getStatus] invocations.
  int getStatusCallCount = 0;

  /// Number of [updateStatus] invocations.
  int updateStatusCallCount = 0;

  /// The capability parameter of the last [updateStatus] call.
  String? lastCapability;

  /// The completed parameter of the last [updateStatus] call.
  bool? lastCompleted;

  /// When set, [getStatus] throws it before returning [status].
  ApiException? nextGetError;

  /// When set, [updateStatus] throws it before recording/mutating.
  ApiException? nextUpdateError;

  @override
  Future<OnboardingStatusDto> getStatus() async {
    getStatusCallCount++;
    final ApiException? error = nextGetError;
    if (error != null) {
      nextGetError = null;
      throw error;
    }
    return status;
  }

  @override
  Future<OnboardingStatusDto> updateStatus({
    String? capability,
    bool? completed,
  }) async {
    updateStatusCallCount++;
    final ApiException? error = nextUpdateError;
    if (error != null) {
      nextUpdateError = null;
      throw error;
    }
    lastCapability = capability;
    lastCompleted = completed;
    final bool capGiven = capability != null;
    final bool done = completed ?? status.completed;
    final DateTime? stamp = done ? DateTime.utc(2026, 9, 17) : null;
    status = OnboardingStatusDto(
      capability: capability ?? status.capability,
      onboardingCompletedAt: stamp,
      completed: done,
      profileExists: capGiven || status.profileExists,
    );
    return status;
  }
}
