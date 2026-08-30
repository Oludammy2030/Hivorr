import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';

/// Pure, dependency-free validation for bucket-scoped file uploads.
///
/// Mirrors the server-side `storage.buckets.file_size_limit` and
/// `allowed_mime_types` enforcement (EP-02-06) so callers fail fast before any
/// network round-trip. These checks are UX/defense-in-depth only — the storage
/// API remains authoritative.
abstract final class StorageValidators {
  const StorageValidators._();

  /// Maps a file extension (without leading dot, lower-cased) to its MIME type.
  ///
  /// Falls back to `null` when the extension is unknown so callers can rely on
  /// the declared [mimeType] instead of guessing.
  static const Map<String, String> extensionToMime = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
  };

  /// MIME types the client rejects outright to mitigate spoofing.
  static const Set<String> _blockedMimeTypes = <String>{
    'text/html',
    'application/octet-stream',
    'application/x-msdownload',
    'text/javascript',
    'application/x-javascript',
  };

  /// Normalizes a MIME type to lower-case for comparison.
  static String normalizeMime(String mimeType) => mimeType.trim().toLowerCase();

  /// Returns the canonical MIME for [fileName]'s extension, or `null`.
  static String? mimeForFileName(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) {
      return null;
    }
    final extension = fileName.substring(index + 1).toLowerCase();
    return extensionToMime[extension];
  }

  /// True when [fileName]'s extension maps to a MIME compatible with [mimeType].
  ///
  /// This is UX-only hint normalization; it does not replace server checks.
  static bool extensionMatchesMime(String fileName, String mimeType) {
    final mapped = mimeForFileName(fileName);
    if (mapped == null) {
      return false;
    }
    return mapped == normalizeMime(mimeType);
  }

  /// Whether [bucket] is a known bucket in the allowlist.
  static bool isKnownBucket(String bucket) =>
      StorageBuckets.all.contains(bucket);

  /// Validates that [mimeType] is allowed in [bucket].
  ///
  /// Throws [StorageValidationException] with `kind == validation`,
  /// `code == PLT003` when not allowed.
  static void validateMime(String bucket, String mimeType) {
    final normalized = normalizeMime(mimeType);
    if (_blockedMimeTypes.contains(normalized)) {
      throw StorageValidationException(
        'This file type is not supported.',
        field: 'mimeType',
      );
    }
    final allowed = StorageMimeTypes.forBucket(bucket);
    if (allowed == null) {
      throw StorageValidationException(
        'Unsupported storage bucket: $bucket',
        field: 'bucket',
      );
    }
    if (!allowed.contains(normalized)) {
      throw StorageValidationException(
        _mimeNotAllowedMessage(bucket),
        field: 'mimeType',
      );
    }
  }

  /// Validates that [byteLength] fits within [bucket]'s `file_size_limit`.
  ///
  /// Throws [StorageValidationException] when [byteLength] exceeds the limit.
  static void validateSize(String bucket, int byteLength) {
    if (byteLength < 0) {
      throw StorageValidationException(
        'File size cannot be negative.',
        field: 'byteLength',
      );
    }
    final limit = StorageLimits.forBucket(bucket);
    if (limit == null) {
      throw StorageValidationException(
        'Unsupported storage bucket: $bucket',
        field: 'bucket',
      );
    }
    if (byteLength > limit) {
      throw StorageValidationException(
        'File too large — max ${(limit / 1048576).toStringAsFixed(0)} MB.',
        field: 'byteLength',
      );
    }
  }

  /// Validates MIME and size together for [bucket] before any network call.
  ///
  /// Throws [StorageValidationException] (`PLT003`) on the first violation.
  static void validateForBucket({
    required String bucket,
    required String mimeType,
    required int byteLength,
  }) {
    validateMime(bucket, mimeType);
    validateSize(bucket, byteLength);
  }

  static String _mimeNotAllowedMessage(String bucket) {
    if (bucket == StorageBuckets.profileAvatars) {
      return 'Avatars must be a JPEG, PNG, or WebP image up to 5 MB.';
    }
    return 'File must be a JPEG, PNG, WebP, or PDF up to 10 MB.';
  }
}
