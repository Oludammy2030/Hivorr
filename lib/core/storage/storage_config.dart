/// Single source of truth for the Supabase Storage bucket catalogue.
///
/// These constants mirror the server-side definitions in
/// `supabase/migrations/20260830100001_storage_buckets.sql` and
/// `supabase/config.toml` (EP-02-06). They are imported by the validators,
/// path helpers, and `SupabaseStorageService` so bucket rules are never
/// duplicated. A parity unit test asserts equality with the migration/config
/// values to catch drift (EP-02-08 DoD DV-01..03).
library;

/// The exact bucket IDs provisioned in EP-02-06.
abstract final class StorageBuckets {
  const StorageBuckets._();

  /// Private owner-only container for identity/trade verification documents.
  static const String credentialDocuments = 'credential-documents';

  /// Public-read container for the canonical single entity avatar.
  static const String profileAvatars = 'profile-avatars';

  /// Public-read container for portfolio showcase items.
  static const String portfolioItems = 'portfolio-items';

  /// The complete allowlisted bucket set accepted by the storage service.
  static const Set<String> all = <String>{
    credentialDocuments,
    profileAvatars,
    portfolioItems,
  };
}

/// Byte-level `file_size_limit` per bucket (mirrors `storage.buckets`).
abstract final class StorageLimits {
  const StorageLimits._();

  /// 10 MiB for `credential-documents`.
  static const int credentialDocuments = 10485760;

  /// 5 MiB for `profile-avatars`.
  static const int profileAvatars = 5242880;

  /// 10 MiB for `portfolio-items`.
  static const int portfolioItems = 10485760;

  /// Returns the configured byte limit for [bucket], or `null` if unknown.
  static int? forBucket(String bucket) => switch (bucket) {
        StorageBuckets.credentialDocuments => credentialDocuments,
        StorageBuckets.profileAvatars => profileAvatars,
        StorageBuckets.portfolioItems => portfolioItems,
        _ => null,
      };
}

/// `allowed_mime_types` per bucket (mirrors `storage.buckets`).
abstract final class StorageMimeTypes {
  const StorageMimeTypes._();

  /// `credential-documents`: jpeg, png, webp, pdf.
  static const Set<String> credentialDocuments = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  /// `profile-avatars`: jpeg, png, webp (no pdf).
  static const Set<String> profileAvatars = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// `portfolio-items`: jpeg, png, webp, pdf.
  static const Set<String> portfolioItems = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  /// Returns the allowed MIME set for [bucket], or `null` if unknown.
  static Set<String>? forBucket(String bucket) => switch (bucket) {
        StorageBuckets.credentialDocuments => credentialDocuments,
        StorageBuckets.profileAvatars => profileAvatars,
        StorageBuckets.portfolioItems => portfolioItems,
        _ => null,
      };
}

/// Whether a bucket is public-read, by bucket ID (mirrors `storage.buckets`).
abstract final class StorageBucketVisibilities {
  const StorageBucketVisibilities._();

  /// Private bucket (`credential-documents`).
  static const bool credentialDocuments = false;

  /// Public-read bucket (`profile-avatars`).
  static const bool profileAvatars = true;

  /// Public-read bucket (`portfolio-items`).
  static const bool portfolioItems = true;

  /// Returns the public-read flag for [bucket], or `null` if unknown.
  static bool? forBucket(String bucket) => switch (bucket) {
        StorageBuckets.credentialDocuments => credentialDocuments,
        StorageBuckets.profileAvatars => profileAvatars,
        StorageBuckets.portfolioItems => portfolioItems,
        _ => null,
      };
}
