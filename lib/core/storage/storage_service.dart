import 'dart:typed_data';

// FileObject is re-exported through supabase_flutter for the list() contract.
import 'package:supabase_flutter/supabase_flutter.dart' show FileObject;

/// Provider-agnostic storage contract for the three EP-02-06 buckets.
///
/// Consuming features (`lib/systems/verification/`, `lib/systems/portfolio/`,
/// onboarding) depend on this abstraction and never import
/// `SupabaseClient.storage` directly, so a future `lib/integrations/cloud_storage/`
/// provider can replace the implementation without churn (ARCHITECTURE.md:119).
///
/// The payload shape is platform-agnostic (`Uint8List` + MIME + fileName) — no
/// `dart:io File` — so the same service works on mobile and Web where callers
/// obtain bytes via `XFile.readAsBytes()`.
abstract class StorageService {
  /// Uploads [bytes] to [bucket] at [path].
  ///
  /// [mimeType] declares the content type (validated against the bucket
  /// allowlist before any network call). [fileName] is used for extension↔MIME
  /// normalization. Returns the server storage key (path) on success.
  ///
  /// [onProgress] reports bytes sent / total, when progress reporting is
  /// available (via a Dio fallback when the SDK lacks native progress).
  ///
  /// [upsert] controls overwrite semantics: `true` for the canonical
  /// `profile-avatars/{entityId}/avatar.{ext}`, `false` otherwise.
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
    void Function(int sent, int total)? onProgress,
    bool upsert = false,
  });

  /// Downloads [path] from [bucket] and returns its bytes.
  ///
  /// Intended for private buckets (`credential-documents`); authenticated
  /// fetch is required.
  Future<Uint8List> download({required String bucket, required String path});

  /// Deletes [paths] from [bucket].
  ///
  /// Owner-scoped: only paths under the caller's `{entity_id}/` prefix are
  /// permitted by the server policies.
  Future<void> remove({required String bucket, required List<String> paths});

  /// Returns a deterministic public URL for [path] in [bucket].
  ///
  /// Valid **only** for public buckets (`profile-avatars`, `portfolio-items`).
  /// Calling this on `credential-documents` throws [StorageValidationException].
  String getPublicUrl({required String bucket, required String path});

  /// Creates a short-lived signed URL for [path] in [bucket].
  ///
  /// Used for private `credential-documents` preview with a recommended TTL of
  /// 60–300 seconds. Never exposes the underlying object publicly.
  Future<String> createSignedUrl({
    required String bucket,
    required String path,
    required int expiresInSeconds,
  });

  /// Lists files under [path] (prefix) in [bucket], up to [limit] items.
  Future<List<FileObject>> list({
    required String bucket,
    required String path,
    int limit = 100,
  });

  /// Validates [mimeType] and [byteLength] against [bucket]'s rules.
  ///
  /// Throws [StorageValidationException] (`PLT003`) before any network call,
  /// enabling fail-fast form UX.
  void validateForBucket({
    required String bucket,
    required String mimeType,
    required int byteLength,
  });
}