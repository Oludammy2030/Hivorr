/// Pure Dart domain model for the 1:1 Universal Entity profile.
///
/// Carries the financial-anchor fields (per EP-01-06 D3) plus the split
/// identity fields captured at registration (first/middle/last, phone).
/// No business logic is present.
class EntityProfile {
  const EntityProfile({
    required this.legalName,
    required this.displayName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.phoneNumber,
    this.bio,
    this.avatarPath,
    this.countryCode,
  });

  /// Legal name — the Rule 3 deposit/payout matching anchor (derived from
  /// first + middle + last).
  final String legalName;

  /// Public display name.
  final String displayName;

  /// Given name captured at registration (1-120 chars).
  final String? firstName;

  /// Middle name (optional, 0-120 chars).
  final String? middleName;

  /// Family name captured at registration (1-120 chars).
  final String? lastName;

  /// Contact phone captured at registration (7-15 digits).
  final String? phoneNumber;

  /// Optional biography (profile-completed later, not required for registration/onboarding).
  final String? bio;

  /// Optional avatar storage path (profile-completed later).
  final String? avatarPath;

  /// Optional ISO-3166 alpha-2 country code.
  final String? countryCode;
}
