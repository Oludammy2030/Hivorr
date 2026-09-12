/// Typed, token-free view of an authenticated session.
///
/// Holds only non-sensitive identity metadata. The access/refresh tokens are
/// intentionally absent — token handling is owned by the EP-01-07 API layer
/// (EP-01-09 §5.4).
class AuthSession {
  const AuthSession({
    required this.entityId,
    this.expiresAt,
    this.provider,
    this.email,
  });

  /// The entity id, equal to `auth.users.id` (EP-01-06 D1).
  final String entityId;

  /// When the access token expires, if known.
  final DateTime? expiresAt;

  /// The auth provider used (e.g. 'email'), if known.
  final String? provider;

  /// The verified sign-in email from `auth.users` (read-only display; NOT
  /// duplicating PII into business tables — see AGENT.md minimal-PII rule).
  final String? email;
}
