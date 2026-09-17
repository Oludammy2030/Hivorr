/// Lifecycle states exposed by the authentication framework.
///
/// Consumed by [AuthProvider] and [AuthGuard] to drive UI and route protection
/// (EP-01-09 §5.3, §5.6).
enum AuthStatus {
  /// No auth check has completed yet (before [AuthService.initialize]).
  initial,

  /// No active session; the user must authenticate.
  unauthenticated,

  /// A valid session exists for the current entity.
  authenticated,

  /// A sign-up succeeded but email confirmation is required before sign-in.
  awaitingEmailConfirmation,

  /// A password-recovery (reset) session is active.
  ///
  /// Issued by the recovery deep-link exchange; the user is confined to the
  /// reset door until [AuthService.updatePassword] completes (the session is
  /// single-purpose and is not a normal sign-in).
  recovery,
}
