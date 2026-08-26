/// Observable phases of the application initialization lifecycle.
///
/// Consumed by [InitializationScreen] to pick the rendered UI. The `error`
/// state carries a user-safe message (no technical details, stack traces,
/// config values, or URLs) per EP-01-15 §5.3 and the approved DoD.
sealed class InitializationState {
  const InitializationState();
}

/// Bootstrap is in progress; the brand splash is shown.
final class InitializationLoading extends InitializationState {
  const InitializationLoading();
}

/// Bootstrap completed; the app shell is mounted.
final class InitializationReady extends InitializationState {
  const InitializationReady();
}

/// Bootstrap failed closed; the error screen is shown with [message].
final class InitializationError extends InitializationState {
  const InitializationError(this.message);

  /// User-safe, non-technical description of the failure.
  final String message;
}
