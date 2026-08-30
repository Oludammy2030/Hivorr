import 'package:hivorr/core/api/exceptions/api_exception.dart';

/// A storage operation failure surfaced to callers.
///
/// Unlike the SDK's transport exception, this type carries a stable
/// [ApiExceptionKind] (aligned with the `PLT001`–`PLT999` contract), a safe
/// human-readable [message], an optional platform [code], and the originating
/// [statusCode]. It never embeds raw SDK messages, SQL, or file contents.
class StorageException implements Exception {
  const StorageException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.data,
  });

  /// Builds a [StorageException] from an [ApiException], preserving kind/code.
  factory StorageException.fromApi(ApiException exception) => StorageException(
        kind: exception.kind,
        message: exception.message,
        code: exception.code,
        statusCode: exception.statusCode,
        data: exception.data,
      );

  /// The stable failure category.
  final ApiExceptionKind kind;

  /// A safe, non-sensitive, human-readable description.
  final String message;

  /// The platform error code, when available (e.g. `PLT003`).
  final String? code;

  /// The originating HTTP status code, when available.
  final int? statusCode;

  /// Optional non-sensitive contextual data.
  final Map<String, dynamic>? data;

  @override
  String toString() => 'StorageException($kind, $statusCode, $code): $message';
}

/// A client-side or server-side validation failure (`PLT003`).
///
/// Thrown by [StorageValidators.validateForBucket] before any network call, or
/// when the Storage API rejects an invalid payload. Consumers map this to an
/// inline form error (e.g. "PDF or image up to 10 MB").
class StorageValidationException extends StorageException {
  const StorageValidationException(
    String message, {
    this.field,
    super.code = 'PLT003',
    super.statusCode,
  }) : super(
          kind: ApiExceptionKind.validation,
          message: message,
        );

  /// The offending field (e.g. `mimeType`, `byteLength`, `path`), when known.
  final String? field;

  @override
  String toString() => 'StorageValidationException(${super.toString()})';
}

/// An authentication failure (`PLT001`).
class StorageAuthException extends StorageException {
  const StorageAuthException(
    String message, {
    super.code = 'PLT001',
    super.statusCode,
  }) : super(
          kind: ApiExceptionKind.auth,
          message: message,
        );

  @override
  String toString() => 'StorageAuthException(${super.toString()})';
}

/// An authorization/permission failure (`PLT002`).
///
/// Commonly surfaces when an RLS policy rejects a write outside the caller's
/// own `{entity_id}/` prefix.
class StorageForbiddenException extends StorageException {
  const StorageForbiddenException(
    String message, {
    super.code = 'PLT002',
    super.statusCode,
  }) : super(
          kind: ApiExceptionKind.forbidden,
          message: message,
        );

  @override
  String toString() => 'StorageForbiddenException(${super.toString()})';
}

/// A requested resource was not found (`PLT004`).
class StorageNotFoundException extends StorageException {
  const StorageNotFoundException(
    String message, {
    super.code = 'PLT004',
    super.statusCode,
  }) : super(
          kind: ApiExceptionKind.notFound,
          message: message,
        );

  @override
  String toString() => 'StorageNotFoundException(${super.toString()})';
}
