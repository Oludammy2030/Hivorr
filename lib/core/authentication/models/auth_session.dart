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
    this.isEmailConfirmed = false,
    this.firstName,
    this.lastName,
    this.displayName,
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

  /// Whether the sign-in email is verified (`auth.users.email_confirmed_at`).
  ///
  /// Server-authoritative verification state. The email-verification gate must
  /// precede the main onboarding; see the account-lifecycle requirement.
  final bool isEmailConfirmed;

  /// Given name staged at registration (`user_metadata.first_name`),
  /// hydrated into `entity_profiles.first_name`. Used for display/initials.
  final String? firstName;

  /// Family name staged at registration (`user_metadata.last_name`),
  /// hydrated into `entity_profiles.last_name`. Used for display/initials.
  final String? lastName;

  /// Public display name staged at registration (`user_metadata.display_name`).
  final String? displayName;

  /// Full name derived from the stored first + last names
  /// (`Amara Diallo`), or null when neither is available.
  /// Never fabricated — callers fall back to email-prefix display.
  String? get fullName {
    final String first = (firstName ?? '').trim();
    final String last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) return null;
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  /// Up-to-two-letter initials from the stored first + last names
  /// (`Amara Diallo` → `AD`, `John` → `J`), or null when unavailable.
  String? get initials {
    final String first = (firstName ?? '').trim();
    final String last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) return null;
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0].toUpperCase()}${last[0].toUpperCase()}';
    }
    final String single = first.isNotEmpty ? first : last;
    return single[0].toUpperCase();
  }
}
