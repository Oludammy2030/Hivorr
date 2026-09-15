/// DTO for an approved credential on the public profile (EP-02-19).
///
/// Maps the snake_case JSON keys from the RPC projection exactly.
class PublicCredentialDto {
  const PublicCredentialDto({
    required this.kind,
    required this.title,
    required this.verificationStatus,
  });

  factory PublicCredentialDto.fromJson(Map<String, dynamic> json) =>
      PublicCredentialDto(
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        verificationStatus: json['verification_status'] as String? ?? '',
      );

  final String kind;
  final String title;
  final String verificationStatus;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    'title': title,
    'verification_status': verificationStatus,
  };
}
