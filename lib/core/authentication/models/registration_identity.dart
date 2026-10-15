/// Identity fields captured at registration (account creation).
///
/// Extends basic auth credentials with the authoritative profile data that must
/// be persisted before onboarding. Phone and names are validated via
/// `HivorrValidators` in the UI; this model holds the already-trimmed values.
/// Stored transiently via `auth.users.raw_user_meta_data` (GoTrue `data:`) so
/// the OTP gap (no JWT) does not lose data — hydrated post-verification into
/// `entity_profiles` via `entity_profile_update`.
class RegistrationIdentity {
  const RegistrationIdentity({
    required this.email,
    required this.password,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.displayName,
    required this.phoneNumber,
  });

  final String email;
  final String password;
  final String firstName;
  final String? middleName;
  final String lastName;

  /// Optional public handle. When omitted, the server derives
  /// `first + last` at profile creation (identity audit Phase 1a) and the
  /// hydration path below resolves the same default locally.
  final String? displayName;
  final String phoneNumber;

  /// Combined legal name derived from components (server also derives).
  String get legalName {
    final String m = middleName?.trim() ?? '';
    if (m.isEmpty) return '$firstName $lastName';
    return '$firstName $m $lastName';
  }

  /// Effective display name: explicit value, else `first + last`.
  String get effectiveDisplayName {
    final String d = displayName?.trim() ?? '';
    if (d.isNotEmpty) return d;
    return '$firstName $lastName';
  }

  /// Map passed as GoTrue `data` (user_metadata) on `signUp`.
  Map<String, dynamic> toUserMetadata() => <String, dynamic>{
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'display_name': effectiveDisplayName,
    'phone_number': phoneNumber,
  };

  /// Hydrates from `userMetadata` read post-verification (defensive).
  factory RegistrationIdentity.fromMetadata({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) => RegistrationIdentity(
    email: email,
    password: password,
    firstName: (metadata['first_name'] as String? ?? '').trim(),
    middleName: (metadata['middle_name'] as String?)?.trim(),
    lastName: (metadata['last_name'] as String? ?? '').trim(),
    displayName: (metadata['display_name'] as String?)?.trim(),
    phoneNumber: (metadata['phone_number'] as String? ?? '').trim(),
  );
}
