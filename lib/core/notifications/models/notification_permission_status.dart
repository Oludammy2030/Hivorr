/// Runtime notification permission state.
///
/// Mirrors the platform permission model without implementing policy. The
/// client never bypasses permission state and never evaluates permission as
/// a business gate (AGENT.md Rule 4).
enum NotificationPermissionStatus {
  /// Permission has not been requested yet.
  notDetermined,

  /// User granted notification permission.
  granted,

  /// User denied; the OS may still prompt again on a future request.
  denied,

  /// User denied with "Don't ask again" (Android) or a system restriction
  /// prevents re-prompting. No further requests should be made.
  permanentlyDenied,

  /// iOS provisional authorization — quiet notifications only.
  provisional,
}
