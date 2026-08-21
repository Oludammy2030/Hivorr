/// Pure Dart domain model for the 1:1 Universal Entity profile.
///
/// Carries the financial-anchor fields (per EP-01-06 D3) without any
/// framework or backend dependency. No business logic is present.
class EntityProfile {
  const EntityProfile({
    required this.legalName,
    required this.displayName,
    this.bio,
    this.avatarPath,
    this.countryCode,
  });

  /// Legal name — the Rule 3 deposit/payout matching anchor.
  final String legalName;

  /// Public display name.
  final String displayName;

  /// Optional biography.
  final String? bio;

  /// Optional avatar storage path.
  final String? avatarPath;

  /// Optional ISO-3166 alpha-2 country code.
  final String? countryCode;
}
