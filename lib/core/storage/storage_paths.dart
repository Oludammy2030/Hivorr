import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:uuid/uuid.dart';
/// Pure path-convention helpers for the three EP-02-06 buckets.
///
/// Every helper produces a path whose first segment is the entity id
/// (`{entity_id}/...`), matching the server-side `WITH CHECK` RLS gate
/// `(storage.foldername(name))[1] = auth.uid()::text` in
/// `20260830100001_storage_buckets.sql`. These helpers are the client-side
/// complement: they sanitize filenames so a malicious payload cannot escape
/// the owner prefix, real defense coming from the authoritative server policy.
abstract final class StoragePaths {
  const StoragePaths._();

  /// An [Uuid] v4 generator, injectable for deterministic tests.
  static const Uuid _uuid = Uuid();

  /// The maximum length of a sanitized filename segment.
  static const int maxFileNameLength = 180;

  static final RegExp _allowedChars = RegExp(r'[^a-z0-9._-]');
  static final RegExp _controlChars = RegExp(r'[\x00-\x1f\x7f]');

  /// Sanitizes a single filename/path segment.
  ///
  /// Removes `..`, path separators, and control characters; truncates to
  /// [maxFileNameLength]; lower-cases; and drops any character outside
  /// `a-z0-9._-`. Returns an empty string when nothing survives.
  ///
  /// A traversal payload such as `../../etc/passwd` collapses to a single
  /// safe segment (`etc.passwd`).
  static String sanitize(String value) {
    final cleaned = value
        .replaceAll(_controlChars, '')
        .toLowerCase()
        .replaceAll(RegExp(r'\.\.'), '')
        .replaceAll(RegExp(r'[/\\]'), '')
        .replaceAll(_allowedChars, '');
    final collapsed = cleaned
        .split(RegExp(r'\.+'))
        .where((String part) => part.isNotEmpty)
        .join('.');
    if (collapsed.length > maxFileNameLength) {
      return collapsed.substring(0, maxFileNameLength);
    }
    return collapsed;
  }

  /// Validates an entity id is non-empty and free of path separators.
  static void _validateEntityId(String entityId) {
    if (entityId.isEmpty) {
      throw const StorageValidationException(
        'Entity id cannot be empty.',
        field: 'entityId',
      );
    }
    if (entityId.contains('/') || entityId.contains(r'\')) {
      throw const StorageValidationException(
        'Entity id cannot contain path separators.',
        field: 'entityId',
      );
    }
  }

  /// Builds a `credential-documents` path:
  /// `{entityId}/{submissionId}/{uuid}_{sanitizedFileName}`.
  ///
  /// The leading UUID segment prevents collision and adds entropy while the
  /// sanitized original name remains human-readable.
  static String credentialDocument({
    required String entityId,
    required String submissionId,
    required String fileName,
  }) {
    _validateEntityId(entityId);
    if (submissionId.isEmpty) {
      throw const StorageValidationException(
        'Submission id cannot be empty.',
        field: 'submissionId',
      );
    }
    final safeId = sanitize(entityId);
    final safeSubmission = sanitize(submissionId);
    final safeName = sanitize(fileName);
    final random = _uuid.v4();
    final name = safeName.isEmpty ? random : '${random}_$safeName';
    return '$safeId/$safeSubmission/$name';
  }

  /// Builds the canonical `profile-avatars` path: `{entityId}/avatar.{ext}`.
  ///
  /// [ext] is lower-cased and validated against the allowed extensions. This
  /// canonical path is overwritten via `upsert: true`.
  static String avatar({required String entityId, required String ext}) {
    _validateEntityId(entityId);
    final extension = sanitize(ext);
    if (extension.isEmpty) {
      throw const StorageValidationException(
        'Avatar extension cannot be empty.',
        field: 'ext',
      );
    }
    final safeId = sanitize(entityId);
    return '$safeId/avatar.$extension';
  }

  /// Builds a `portfolio-items` path: `{entityId}/{itemId}/{sanitizedFileName}`.
  static String portfolioItem({
    required String entityId,
    required String itemId,
    required String fileName,
  }) {
    _validateEntityId(entityId);
    if (itemId.isEmpty) {
      throw const StorageValidationException(
        'Item id cannot be empty.',
        field: 'itemId',
      );
    }
    final safeId = sanitize(entityId);
    final safeItem = sanitize(itemId);
    final safeName = sanitize(fileName);
    if (safeName.isEmpty) {
      throw const StorageValidationException(
        'File name must contain usable characters.',
        field: 'fileName',
      );
    }
    return '$safeId/$safeItem/$safeName';
  }
}
