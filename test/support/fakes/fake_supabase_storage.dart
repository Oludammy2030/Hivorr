import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// In-memory [supabase.SupabaseStorageClient] for fast, SDK-free unit tests.
///
/// Mirrors `test/support/fakes/fake_supabase.dart`. Subclasses the real
/// [supabase.SupabaseStorageClient] and overrides [from] to return
/// [FakeStorageFileApi] instances sharing this client's backing store
/// (`bucket -> path -> bytes`). Enforces size/MIME limits when [strict] is
/// true by throwing SDK-style [supabase.StorageException]s.
class FakeSupabaseStorageClient extends supabase.SupabaseStorageClient {
  FakeSupabaseStorageClient({
    this.strict = false,
  }) : super(
          'https://example.supabase.co/storage/v1',
          <String, String>{'apikey': 'public-anon-key'},
        );

  /// When true, enforcement of size/MIME limits on the fake.
  final bool strict;

  /// backing store: bucket -> path -> bytes.
  final Map<String, Map<String, Uint8List>> buckets =
      <String, Map<String, Uint8List>>{};

  /// Tracked content type per `bucket/path` for round-trip assertions.
  final Map<String, String> contentTypes = <String, String>{};

  /// Records the last `upsert` flag seen on any upload.
  bool? capturedUpsert;

  /// Records the bucket/path of the last upload.
  String? lastUploadPath;

  /// If set, the next file API op throws this SDK exception (then is cleared).
  supabase.StorageException? nextError;

  @override
  supabase.StorageFileApi from(String id) => FakeStorageFileApi(
        this,
        id,
        url,
        headers,
        strict: strict,
      );
}

/// In-memory [supabase.StorageFileApi] implementing the narrow surface the
/// storage service uses, with spy capture for assertions.
class FakeStorageFileApi implements supabase.StorageFileApi {
  FakeStorageFileApi(
    this._client,
    this.bucketId,
    this.url,
    Map<String, String> headers, {
    this.strict = false,
  }) : _headers = Map<String, String>.from(headers);

  final FakeSupabaseStorageClient _client;
  final bool strict;
  final Map<String, String> _headers;

  @override
  final String url;

  @override
  final String? bucketId;

  @override
  Map<String, String> get headers => Map<String, String>.from(_headers);

  @override
  supabase.StorageFileApi setHeader(String key, String value) {
    _headers[key] = value;
    return this;
  }

  void _maybeThrow() {
    final error = _client.nextError;
    if (error != null) {
      _client.nextError = null;
      throw error;
    }
  }

  Map<String, Uint8List> _storeFor(String bucket) =>
      _client.buckets.putIfAbsent(bucket, () => <String, Uint8List>{});

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    supabase.FileOptions fileOptions = const supabase.FileOptions(),
    int? retryAttempts,
    supabase.StorageRetryController? retryController,
  }) async {
    _maybeThrow();
    _client.capturedUpsert = fileOptions.upsert;
    _client.lastUploadPath = '$bucketId/$path';
    if (fileOptions.contentType != null) {
      final mime = fileOptions.contentType!.toLowerCase();
      final allowed = strictAllowedMimeTypes[bucketId];
      if (allowed != null && !allowed.contains(mime)) {
        throw supabase.StorageException(
          'The MIME type is not allowed for this bucket.',
          statusCode: '400',
        );
      }
    }
    if (data.lengthInBytes > strictLimits[bucketId]!) {
      throw supabase.StorageException(
        'The object was too large to upload.',
        statusCode: '413',
      );
    }
    _storeFor(bucketId!)[path] = Uint8List.fromList(data);
    if (fileOptions.contentType != null) {
      _client.contentTypes['$bucketId/$path'] = fileOptions.contentType!;
    }
    return path;
  }

  @override
  Future<Uint8List> download(
    String path, {
    supabase.TransformOptions? transform,
    Map<String, String>? queryParams,
    String? cacheNonce,
  }) async {
    _maybeThrow();
    final bytes = _storeFor(bucketId!)[path];
    if (bytes == null) {
      throw supabase.StorageException('Object not found.', statusCode: '404');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<List<supabase.FileObject>> remove(List<String> paths) async {
    _maybeThrow();
    final removed = <supabase.FileObject>[];
    for (final path in paths) {
      final existed = _storeFor(bucketId!).remove(path) != null;
      if (existed) {
        removed.add(
          supabase.FileObject.fromJson(<String, dynamic>{'name': path}),
        );
      }
    }
    return removed;
  }

  @override
  String getPublicUrl(
    String path, {
    supabase.TransformOptions? transform,
    supabase.DownloadBehavior? download,
    String? cacheNonce,
  }) {
    _maybeThrow();
    return '$url/object/public/$bucketId/$path';
  }

  @override
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    supabase.TransformOptions? transform,
    supabase.DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    _maybeThrow();
    return '$url/object/sign/$bucketId/$path?token=fake-hmac&expires=$expiresIn';
  }

  @override
  Future<List<supabase.FileObject>> list({
    String? path,
    supabase.SearchOptions searchOptions = const supabase.SearchOptions(),
  }) async {
    _maybeThrow();
    final prefix = path ?? '';
    final limit = searchOptions.limit ?? 100;
    final result = <supabase.FileObject>[];
    for (final entry in _storeFor(bucketId!).keys) {
      if (!entry.startsWith(prefix)) continue;
      if (result.length >= limit) break;
      final name = entry.substring(prefix.length).replaceFirst(
            RegExp(r'^/'),
            '',
          );
      result.add(supabase.FileObject.fromJson(<String, dynamic>{'name': name}));
    }
    return result;
  }

  // --- Unused for the storage service; stubbed to satisfy the interface -----

  @override
  Future<String> upload(
    String path,
    dynamic file, {
    supabase.FileOptions fileOptions = const supabase.FileOptions(),
    int? retryAttempts,
    supabase.StorageRetryController? retryController,
  }) =>
      throw UnimplementedError('upload(File) is not used in storage tests');

  @override
  Future<String> uploadToSignedUrl(
    String path,
    String token,
    dynamic file, [
    supabase.FileOptions? fileOptions,
    int? retryAttempts,
    supabase.StorageRetryController? retryController,
  ]) =>
      throw UnimplementedError('uploadToSignedUrl not used in storage tests');

  @override
  Future<String> uploadBinaryToSignedUrl(
    String path,
    String token,
    Uint8List data, [
    supabase.FileOptions? fileOptions,
    int? retryAttempts,
    supabase.StorageRetryController? retryController,
  ]) =>
      throw UnimplementedError('uploadBinaryToSignedUrl not used in tests');

  @override
  Future<supabase.SignedUploadURLResponse> createSignedUploadUrl(
    String path, {
    bool upsert = false,
  }) =>
      throw UnimplementedError('createSignedUploadUrl not used in tests');

  @override
  Future<String> update(
    String path,
    dynamic file, {
    supabase.FileOptions fileOptions = const supabase.FileOptions(),
    int? retryAttempts,
    supabase.StorageRetryController? retryController,
  }) =>
      throw UnimplementedError('update not used in tests');

  @override
  Future<String> updateBinary(
    String path,
    Uint8List data, {
    supabase.FileOptions fileOptions = const supabase.FileOptions(),
    int? retryAttempts,
    supabase.StorageRetryController? retryController,
  }) =>
      throw UnimplementedError('updateBinary not used in tests');

  @override
  Future<String> move(String fromPath, String toPath,
          {String? destinationBucket}) =>
      throw UnimplementedError('move not used in tests');

  @override
  Future<String> copy(String fromPath, String toPath,
          {String? destinationBucket}) =>
      throw UnimplementedError('copy not used in tests');

  @override
  Future<List<supabase.SignedUrl>> createSignedUrls(
    List<String> paths,
    int expiresIn, {
    supabase.DownloadBehavior? download,
    String? cacheNonce,
  }) =>
      throw UnimplementedError('createSignedUrls not used in tests');

  @override
  Future<List<supabase.SignedUrlResult>> createSignedUrlsResult(
    List<String> paths,
    int expiresIn, {
    supabase.DownloadBehavior? download,
    String? cacheNonce,
  }) =>
      throw UnimplementedError('createSignedUrlsResult not used in tests');

  @override
  Stream<Uint8List> downloadStream(
    String path, {
    supabase.TransformOptions? transform,
    Map<String, String>? queryParams,
    String? cacheNonce,
  }) =>
      throw UnimplementedError('downloadStream not used in tests');

  @override
  Future<supabase.FileObjectV2> info(String path) =>
      throw UnimplementedError('info not used in tests');

  @override
  Future<bool> exists(String path) =>
      throw UnimplementedError('exists not used in tests');

  @override
  Future<String> purgeCache(String path, {bool transformations = false}) =>
      throw UnimplementedError('purgeCache not used in tests');

  @override
  Future<supabase.PaginatedListResult> listPaginated({
    supabase.PaginatedSearchOptions options =
        const supabase.PaginatedSearchOptions(),
  }) =>
      throw UnimplementedError('listPaginated not used in tests');
}

/// Strict-mode limits aligned with the bucket catalogue.
final Map<String, int> strictLimits = <String, int>{
  'credential-documents': 10485760,
  'profile-avatars': 5242880,
  'portfolio-items': 10485760,
};

/// Strict-mode MIME allowlists aligned with the bucket catalogue.
final Map<String, Set<String>> strictAllowedMimeTypes =
    <String, Set<String>>{
  'credential-documents': <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  },
  'profile-avatars': <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  },
  'portfolio-items': <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  },
};
