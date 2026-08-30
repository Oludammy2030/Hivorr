import 'dart:async';
import 'dart:typed_data';

// The injected dependencies use public named constructor params but private
// underscored fields (Dart forbids `this._field` for named params), so the
// prefer_initializing_formals lint is inapplicable here.
// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';

import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/monitoring_service.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// [StorageService] backed by the Supabase Storage API.
///
/// Wraps `SupabaseClient.storage` (via an injected [supabase.SupabaseStorageClient],
/// normally `SupabaseClientProvider.client.storage`). Per-bucket validation runs
/// *before* any network call, and SDK transport failures are normalized into the
/// [StorageException] hierarchy aligned with the `PLT001`–`PLT999` contract.
///
/// **Progress fallback decision:** `supabase_flutter:2.17.2`'s `uploadBinary`
/// exposes no `onSendProgress`. To honor [StorageService.upload]'s `onProgress`
/// callback, when a callback is supplied this service posts a multipart request
/// over the injected [Dio] to
/// `{supabaseUrl}/storage/v1/object/{bucket}/{path}` with `onSendProgress`.
/// When no `onProgress` is requested, the SDK's [supabase.SupabaseStorageClient]
/// is used directly (simpler, retried, and retry-aware). No polling is used.
///
/// **Public vs private guidance:** `getPublicUrl` is only valid for public
/// buckets (`profile-avatars`, `portfolio-items`). `credential-documents` is
/// private — use [download] or `createSignedUrl` (60–300 s TTL) instead. Calling
/// `getPublicUrl` on the private bucket throws [StorageValidationException].
class SupabaseStorageService implements StorageService {
  SupabaseStorageService({
    required supabase.SupabaseStorageClient storageClient,
    Dio? dio,
    AccessTokenProvider? tokenProvider,
    HivorrLogger? logger,
    MonitoringService? monitoring,
    PerformanceTracer? tracer,
  })  : _storageClient = storageClient,
        _dio = dio,
        _tokenProvider = tokenProvider ?? const SupabaseAccessTokenProvider(),
        _logger = logger,
        _monitoring = monitoring,
        _tracer = tracer;

  final supabase.SupabaseStorageClient _storageClient;
  final Dio? _dio;
  final AccessTokenProvider _tokenProvider;
  final HivorrLogger? _logger;
  final MonitoringService? _monitoring;
  final PerformanceTracer? _tracer;

  static const String _storageV1Path = '/storage/v1/object';

  /// The local file for a given [bucket], or `null` when not allowlisted.
  supabase.StorageFileApi? _api(String bucket) =>
      StorageBuckets.all.contains(bucket)
          ? _storageClient.from(bucket)
          : null;

  @override
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
    void Function(int sent, int total)? onProgress,
    bool upsert = false,
  }) async {
    final span = _tracer?.startTransaction('storage.upload', 'storage');

    // Validate the bucket allowlist first to prevent typo leakage.
    if (!StorageBuckets.all.contains(bucket)) {
      throw StorageValidationException(
        'Unsupported storage bucket: $bucket',
        field: 'bucket',
      );
    }

    // Fail fast on MIME/size BEFORE touching the network (PLT003).
    validateForBucket(bucket: bucket, mimeType: mimeType, byteLength: bytes.lengthInBytes);

    // Extension↔MIME normalization is UX-only; the declared MIME stays
    // authoritative (the server is the real gate).
    if (fileName != null && fileName.isNotEmpty) {
      final normalized = StorageValidators.normalizeMime(mimeType);
      final mapped = StorageValidators.mimeForFileName(fileName);
      if (mapped != null && mapped != normalized) {
        _logger?.debug(
          'Upload MIME/extension mismatch normalized',
          <String, Object?>{'bucket': bucket, 'mimeType': normalized},
        );
      }
    }

    try {
      String storageKey;
      if (onProgress != null && _dio != null) {
        storageKey = await _uploadWithProgress(
          bucket: bucket,
          path: path,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
          onProgress: onProgress,
          upsert: upsert,
        );
      } else {
        storageKey = await _uploadViaSdk(
          bucket: bucket,
          path: path,
          bytes: bytes,
          mimeType: mimeType,
          upsert: upsert,
        );
      }

      _logger?.info(
        'Storage upload complete',
        <String, Object?>{'bucket': bucket, 'byteLength': bytes.lengthInBytes},
      );
      await _tracer?.finishSpan(span);
      return storageKey;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(
        span,
        status: SpanStatus.internalError(),
      );
      unawaited(_monitoring?.setTag('storage.error.kind', _kindName(error)));
      throw _mapError(error, stackTrace: stackTrace, bucket: bucket);
    }
  }

  /// Uploads through the SDK (no progress events).
  Future<String> _uploadViaSdk({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
    required bool upsert,
  }) async {
    final api = _api(bucket)!;
    return api.uploadBinary(
      path,
      bytes,
      fileOptions: supabase.FileOptions(contentType: mimeType, upsert: upsert),
    );
  }

  /// Uploads with progress via a Dio multipart POST to the Storage REST API.
  ///
  /// Replicates the SDK request shape (`x-upsert` header + file part) so the
  /// server enforces the same `allowed_mime_types` / `file_size_limit` rules
  /// while surfacing byte-accurate `onSendProgress`.
  Future<String> _uploadWithProgress({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
    required void Function(int sent, int total) onProgress,
    required bool upsert,
  }) async {
    final dio = _dio!;
    final baseUrl = dio.options.baseUrl;
    final encodedPath = _encodePath('$bucket/$path');
    final endpoint = '$baseUrl$_storageV1Path/$encodedPath';

    final token = _tokenProvider.currentToken;
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName?.isNotEmpty == true ? fileName : null,
        contentType: DioMediaType.parse(StorageValidators.normalizeMime(mimeType)),
      ),
    });

    final response = await dio.post<dynamic>(
      endpoint,
      data: formData,
      options: Options(
        headers: <String, String>{
          'x-upsert': '$upsert',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
      onSendProgress: (sent, total) {
        onProgress(sent, total);
      },
    );

    final data = response.data;
    if (data is String && data.isNotEmpty) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final key = data['Key'];
      if (key is String) {
        return key;
      }
    }
    return path;
  }

  /// Percent-encodes each path segment while preserving `/` separators, matching
  /// the SDK's `_getFinalPath` behavior.
  static String _encodePath(String path) {
    final segments = path.split('/');
    final encoded = segments
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
    return encoded;
  }

  @override
  Future<Uint8List> download({
    required String bucket,
    required String path,
  }) async {
    final span = _tracer?.startTransaction('storage.download', 'storage');
    _ensureKnownBucket(bucket);
    try {
      final bytes = await _api(bucket)!.download(path);
      _logger?.info(
        'Storage download complete',
        <String, Object?>{'bucket': bucket, 'byteLength': bytes.lengthInBytes},
      );
      await _tracer?.finishSpan(span);
      return bytes;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      unawaited(_monitoring?.setTag('storage.error.kind', _kindName(error)));
      throw _mapError(error, stackTrace: stackTrace, bucket: bucket);
    }
  }

  @override
  Future<void> remove({required String bucket, required List<String> paths}) async {
    _ensureKnownBucket(bucket);
    try {
      await _api(bucket)!.remove(paths);
    } catch (error, stackTrace) {
      unawaited(_monitoring?.setTag('storage.error.kind', _kindName(error)));
      throw _mapError(error, stackTrace: stackTrace, bucket: bucket);
    }
  }

  @override
  String getPublicUrl({required String bucket, required String path}) {
    _ensureKnownBucket(bucket);
    if (StorageBucketVisibilities.forBucket(bucket) != true) {
      throw StorageValidationException(
        'getPublicUrl is only allowed for public buckets. '
        'Use createSignedUrl for private credential-documents.',
        field: 'bucket',
      );
    }
    return _api(bucket)!.getPublicUrl(path);
  }

  @override
  Future<String> createSignedUrl({
    required String bucket,
    required String path,
    required int expiresInSeconds,
  }) async {
    _ensureKnownBucket(bucket);
    if (expiresInSeconds < 1) {
      throw const StorageValidationException(
        'expiresInSeconds must be at least 1.',
        field: 'expiresInSeconds',
      );
    }
    try {
      return await _api(bucket)!.createSignedUrl(path, expiresInSeconds);
    } catch (error, stackTrace) {
      unawaited(_monitoring?.setTag('storage.error.kind', _kindName(error)));
      throw _mapError(error, stackTrace: stackTrace, bucket: bucket);
    }
  }

  @override
  Future<List<supabase.FileObject>> list({
    required String bucket,
    required String path,
    int limit = 100,
  }) async {
    _ensureKnownBucket(bucket);
    try {
      return await _api(bucket)!.list(
        path: path,
        searchOptions: supabase.SearchOptions(limit: limit),
      );
    } catch (error, stackTrace) {
      unawaited(_monitoring?.setTag('storage.error.kind', _kindName(error)));
      throw _mapError(error, stackTrace: stackTrace, bucket: bucket);
    }
  }

  @override
  void validateForBucket({
    required String bucket,
    required String mimeType,
    required int byteLength,
  }) {
    StorageValidators.validateForBucket(
      bucket: bucket,
      mimeType: mimeType,
      byteLength: byteLength,
    );
  }

  void _ensureKnownBucket(String bucket) {
    if (!StorageBuckets.all.contains(bucket)) {
      throw StorageValidationException(
        'Unsupported storage bucket: $bucket',
        field: 'bucket',
      );
    }
  }

  /// Normalizes SDK/Dio failures into the app [StorageException] hierarchy.
  StorageException _mapError(
    Object error, {
    StackTrace? stackTrace,
    String? bucket,
  }) {
    if (error is StorageException) {
      return error;
    }
    if (error is supabase.StorageException) {
      final status = int.tryParse(error.statusCode ?? '');
      final exception = _fromStatus(
        status,
        message: error.message,
      );
      _logger?.error(
        'Storage SDK error',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'bucket': bucket, 'code': exception.code},
      );
      return exception;
    }
    if (error is DioException) {
      final apiException = const ApiExceptionMapper().map(error);
      _logger?.error(
        'Storage transport error',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'bucket': bucket,
          'code': apiException.code,
        },
      );
      return StorageException.fromApi(apiException);
    }
    if (error is ApiException) {
      return StorageException.fromApi(error);
    }

    _logger?.error(
      'Storage unexpected error',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{'bucket': bucket},
    );
    return StorageException(
      kind: ApiExceptionKind.unknown,
      message: 'An unexpected storage error occurred.',
      code: 'PLT999',
    );
  }

  StorageException _fromStatus(int? status, {required String message}) {
    final safeMessage = _safeMessage(message);
    return switch (status) {
      401 => StorageAuthException(safeMessage, statusCode: status),
      403 => StorageForbiddenException(safeMessage, statusCode: status),
      404 => StorageNotFoundException(safeMessage, statusCode: status),
      409 => StorageException(
          kind: ApiExceptionKind.conflict,
          message: safeMessage,
          code: 'PLT005',
          statusCode: status,
        ),
      400 || 413 || 415 || 422 =>
        StorageValidationException(safeMessage, statusCode: status),
      _ when status != null && status >= 500 && status <= 599 =>
        StorageException(
          kind: ApiExceptionKind.server,
          message: safeMessage,
          code: 'PLT999',
          statusCode: status,
        ),
      _ => StorageException(
          kind: ApiExceptionKind.unknown,
          message: safeMessage,
          code: 'PLT999',
          statusCode: status,
        ),
    };
  }

  /// Never leak raw SDK messages (which may contain server HTML/SQL).
  static String _safeMessage(String message) {
    const max = 200;
    final trimmed = message.trim();
    if (trimmed.length > max) {
      return '${trimmed.substring(0, max)}…';
    }
    return trimmed;
  }

  String _kindName(Object error) {
    if (error is StorageException) {
      return error.kind.name;
    }
    return error.runtimeType.toString();
  }
}
