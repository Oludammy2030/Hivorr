/// Categorizes the kind of failure surfaced by the API layer.
///
/// Each kind maps to a server-side or transport condition. The mapping
/// consumes the EP-01-05 normalized error contract (`PLT001`–`PLT999`)
/// where applicable.
enum ApiExceptionKind {
  /// No network connectivity or connection reset.
  network,

  /// Request or response timed out.
  timeout,

  /// Authentication required / missing or expired credentials (`PLT001`).
  auth,

  /// Authenticated but not permitted (`PLT002`).
  forbidden,

  /// Request failed server-side validation (`PLT003`).
  validation,

  /// Requested resource not found (`PLT004`).
  notFound,

  /// State conflict such as a duplicate or stale write (`PLT005`).
  conflict,

  /// Server-side failure (`PLT999`).
  server,

  /// Fallback for unclassified failures.
  unknown,
}

/// Typed, transport-only exception thrown to callers of the API layer.
///
/// The model never embeds raw payloads, SQL, or sensitive data. It carries
/// only a safe, human-readable [message], a stable [kind], an optional
/// platform [code] (e.g. `PLT001`), the originating HTTP [statusCode], and a
/// small, non-sensitive [data] map.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.code,
    this.statusCode,
    this.data,
  });

  /// The failure category.
  final ApiExceptionKind kind;

  /// A safe, non-sensitive, human-readable description.
  final String message;

  /// The platform error code (e.g. `PLT001`), when available.
  final String? code;

  /// The originating HTTP status code, when available.
  final int? statusCode;

  /// Optional non-sensitive contextual data.
  final Map<String, dynamic>? data;

  @override
  String toString() => 'ApiException($kind, $statusCode, $code): $message';
}

/// Thrown when the API layer is used before it has been initialized.
///
/// Fails closed with a safe, non-revealing message (EP-01-07 §12).
class ApiInitializationException implements Exception {
  const ApiInitializationException([
    this.message =
        'API layer has not been initialized. Call ApiInitializer.initializeApi first.',
  ]);

  /// A safe description of the initialization failure.
  final String message;

  @override
  String toString() => 'ApiInitializationException: $message';
}
