import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/monitoring_service.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_exceptions.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'fakes.dart';

void main() {
  const credential = StorageBuckets.credentialDocuments;
  const avatarBucket = StorageBuckets.profileAvatars;
  const portfolio = StorageBuckets.portfolioItems;

  late FakeSupabaseStorageClient storage;
  late SupabaseStorageService service;
  late SupabaseStorageService instrumented;
  late FakeAccessTokenProvider tokens;
  late Dio dio;
  late FakeDioHarness dioHarness;

  setUp(() {
    storage = FakeSupabaseStorageClient();
    tokens = FakeAccessTokenProvider('test-token');
    dioHarness = FakeDioHarness();
    dio = dioHarness.dio;
    service = SupabaseStorageService(
      storageClient: storage,
      tokenProvider: tokens,
    );
    instrumented = _instrumentedService(storage, tokens, dio);
  });

  group('upload', () {
    test('upload success returns the storage key via SDK', () async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final key = await service.upload(
        bucket: credential,
        path: 'u/sub/doc.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      expect(key, 'u/sub/doc.pdf');
      expect(storage.buckets[credential]!.containsKey('u/sub/doc.pdf'), isTrue);
    });

    test('validation runs before the SDK: oversize never hits the fake', () async {
      final limit = StorageLimits.forBucket(credential)!;
      await expectLater(
        service.upload(
          bucket: credential,
          path: 'u/sub/doc.pdf',
          bytes: Uint8List(limit + 1),
          mimeType: 'application/pdf',
        ),
        throwsA(
          isA<StorageValidationException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation)
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(storage.capturedUpsert, isNull, reason: 'SDK must not be invoked');
    });

    test('invalid MIME for bucket throws PLT003 before network', () async {
      await expectLater(
        service.upload(
          bucket: avatarBucket,
          path: 'u/avatar.jpg',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'application/pdf',
        ),
        throwsA(
          isA<StorageValidationException>()
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(storage.capturedUpsert, isNull);
    });

    test('unknown bucket throws StorageValidationException', () async {
      await expectLater(
        service.upload(
          bucket: 'evil-bucket',
          path: 'x',
          bytes: Uint8List(1),
          mimeType: 'image/png',
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });

    test('avatar canonical path uses upsert:true (captured)', () async {
      await service.upload(
        bucket: avatarBucket,
        path: 'u/avatar.png',
        bytes: Uint8List.fromList(<int>[9, 9]),
        mimeType: 'image/png',
      );
      expect(storage.capturedUpsert, isFalse);
    });

    test('superset avatar path with upsert flag forwarded true', () async {
      await service.upload(
        bucket: avatarBucket,
        path: 'u/avatar.png',
        bytes: Uint8List(2),
        mimeType: 'image/png',
        upsert: true,
      );
      expect(storage.capturedUpsert, isTrue);
    });

    test('credential upload uses upsert:false by default', () async {
      await service.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List(2),
        mimeType: 'application/pdf',
      );
      expect(storage.capturedUpsert, isFalse);
    });

    test('onProgress with Dio routes through the Dio POST and invokes callback',
        () async {
      final withDio = SupabaseStorageService(
        storageClient: storage,
        dio: dio,
        tokenProvider: tokens,
      );
      final progress = <List<int>>[];
      final key = await withDio.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'application/pdf',
        fileName: 'doc.pdf',
        onProgress: (sent, total) => progress.add(<int>[sent, total]),
      );
      expect(key, isNotEmpty);
      expect(progress, isNotEmpty);
      expect(progress.last, <int>[10, 100]);
      expect(dioHarness.capturedEndpoint, contains('/storage/v1/object/'));
      expect(dioHarness.capturedData, isA<FormData>());
      expect(dioHarness.capturedAuthHeader, 'Bearer test-token');
    });

    test('onProgress without Dio falls back to the SDK (no progress events)',
        () async {
      final progress = <List<int>>[];
      final key = await service.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List(2),
        mimeType: 'application/pdf',
        onProgress: (sent, total) => progress.add(<int>[sent, total]),
      );
      expect(key, 'u/s/doc.pdf');
      expect(progress, isEmpty);
    });

    test('bytes round-trip intact via upload then download', () async {
      final bytes = Uint8List.fromList(
        List<int>.generate(256, (int i) => i),
      );
      await service.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      final downloaded = await service.download(
        bucket: credential,
        path: 'u/s/doc.pdf',
      );
      expect(downloaded, bytes);
    });
  });

  group('download', () {
    test('download returns bytes from a private bucket', () async {
      await service.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List.fromList(<int>[5, 6, 7]),
        mimeType: 'application/pdf',
      );
      final bytes = await service.download(
        bucket: credential,
        path: 'u/s/doc.pdf',
      );
      expect(bytes, <int>[5, 6, 7]);
    });

    test('download of a missing object maps SDK 404 to notFound PLT004',
        () async {
      await expectLater(
        service.download(bucket: credential, path: 'missing.pdf'),
        throwsA(
          isA<StorageNotFoundException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.notFound)
              .having((e) => e.code, 'code', 'PLT004'),
        ),
      );
    });

    test('download on an unknown bucket throws StorageValidationException',
        () async {
      await expectLater(
        service.download(bucket: 'nope', path: 'x'),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('remove', () {
    test('remove deletes owner-scoped paths', () async {
      await service.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List(2),
        mimeType: 'application/pdf',
      );
      await service.remove(
        bucket: credential,
        paths: <String>['u/s/doc.pdf'],
      );
      expect(storage.buckets[credential]!.containsKey('u/s/doc.pdf'), isFalse);
      await expectLater(
        service.download(bucket: credential, path: 'u/s/doc.pdf'),
        throwsA(isA<StorageNotFoundException>()),
      );
    });

    test('remove on an unknown bucket throws StorageValidationException',
        () async {
      await expectLater(
        service.remove(bucket: 'nope', paths: <String>['x']),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('getPublicUrl', () {
    test('public avatar bucket returns /object/public/ URL', () {
      final url =
          service.getPublicUrl(bucket: avatarBucket, path: 'u/avatar.png');
      expect(url, contains('/storage/v1/object/public/'));
      expect(url, contains('profile-avatars'));
    });

    test('public portfolio bucket returns public URL', () {
      final url =
          service.getPublicUrl(bucket: portfolio, path: 'u/item.png');
      expect(url, contains('/object/public/portfolio-items/'));
    });

    test('calling getPublicUrl on private credential-documents throws', () {
      expect(
        () => service.getPublicUrl(bucket: credential, path: 'u/s/doc.pdf'),
        throwsA(
          isA<StorageValidationException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });
  });

  group('createSignedUrl', () {
    test('returns an HMAC-style signed URL for a private bucket', () async {
      final url = await service.createSignedUrl(
        bucket: credential,
        path: 'u/s/doc.pdf',
        expiresInSeconds: 60,
      );
      expect(url, contains('/object/sign/'));
      expect(url, contains('token='));
      expect(url, contains('expires=60'));
    });

    test('rejects expiresInSeconds less than 1', () async {
      await expectLater(
        service.createSignedUrl(
          bucket: credential,
          path: 'u/s/doc.pdf',
          expiresInSeconds: 0,
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('list', () {
    test('list returns FileObjects under a prefix', () async {
      await service.upload(
        bucket: portfolio,
        path: 'u/item/a.png',
        bytes: Uint8List(1),
        mimeType: 'image/png',
      );
      await service.upload(
        bucket: portfolio,
        path: 'u/item/b.png',
        bytes: Uint8List(1),
        mimeType: 'image/png',
      );
      final objects = await service.list(
        bucket: portfolio,
        path: 'u/item/',
      );
      expect(objects, hasLength(2));
    });

    test('list respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await service.upload(
          bucket: portfolio,
          path: 'u/item/$i.png',
          bytes: Uint8List(1),
          mimeType: 'image/png',
        );
      }
      final objects = await service.list(
        bucket: portfolio,
        path: 'u/item/',
        limit: 3,
      );
      expect(objects.length, lessThanOrEqualTo(3));
    });

    test('list on an unknown bucket throws StorageValidationException',
        () async {
      await expectLater(
        service.list(bucket: 'nope', path: 'x'),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('error mapping', () {
    test('SDK 403 maps to forbidden PLT002', () async {
      storage.nextError = supabase.StorageException(
        'rls prefix violation',
        statusCode: '403',
      );
      await expectLater(
        service.download(bucket: credential, path: 'violation.pdf'),
        throwsA(
          isA<StorageForbiddenException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.forbidden)
              .having((e) => e.code, 'code', 'PLT002')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('SDK 401 maps to auth PLT001', () async {
      storage.nextError = supabase.StorageException('no auth', statusCode: '401');
      await expectLater(
        service.download(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageAuthException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.auth)
              .having((e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('SDK 413 maps to validation PLT003', () async {
      storage.nextError =
          supabase.StorageException('too large', statusCode: '413');
      await expectLater(
        service.download(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageValidationException>()
              .having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('SDK 500 maps to server PLT999', () async {
      storage.nextError =
          supabase.StorageException('server exploded', statusCode: '500');
      await expectLater(
        service.download(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.server)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('unknown SDK status maps to unknown PLT999', () async {
      storage.nextError =
          supabase.StorageException('teapot', statusCode: '418');
      await expectLater(
        service.download(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.unknown)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('DioException maps through ApiExceptionMapper', () async {
      final withDio = SupabaseStorageService(
        storageClient: storage,
        dio: dio,
        tokenProvider: tokens,
      );
      dioHarness.throwOnPost = DioException(
        requestOptions: RequestOptions(path: 'x'),
        type: DioExceptionType.connectionError,
      );
      await expectLater(
        withDio.upload(
          bucket: credential,
          path: 'u/s/doc.pdf',
          bytes: Uint8List(2),
          mimeType: 'application/pdf',
          onProgress: (sent, total) {},
        ),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.network)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('instrumented DioException routes through logger and mapper', () async {
      dioHarness.throwOnPost = DioException(
        requestOptions: RequestOptions(path: 'x'),
        type: DioExceptionType.connectionError,
      );
      await expectLater(
        instrumented.upload(
          bucket: credential,
          path: 'u/s/doc.pdf',
          bytes: Uint8List(2),
          mimeType: 'application/pdf',
          onProgress: (sent, total) {},
        ),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.network)
              .having((e) => e.code, 'code', 'PLT999'),
        ),
      );
    });

    test('validateForBucket delegate surfaces validation PLT003', () {
      expect(
        () => service.validateForBucket(
          bucket: avatarBucket,
          mimeType: 'application/pdf',
          byteLength: 10,
        ),
        throwsA(isA<StorageValidationException>()),
      );
    });
  });

  group('instrumentation & response parsing edges', () {
    test('upload logs a MIME/extension mismatch normalization', () async {
      final key = await instrumented.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List(2),
        mimeType: 'image/png',
        fileName: 'doc.pdf',
      );
      expect(key, 'u/s/doc.pdf');
    });

    test('instrumented upload completes and traces span', () async {
      final key = await instrumented.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List(2),
        mimeType: 'application/pdf',
      );
      expect(key, 'u/s/doc.pdf');
    });

    test('instrumented upload error traces span and maps SDK error', () async {
      storage.nextError = supabase.StorageException('boom', statusCode: '400');
      await expectLater(
        instrumented.upload(
          bucket: credential,
          path: 'u/s/doc.pdf',
          bytes: Uint8List(2),
          mimeType: 'application/pdf',
        ),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.validation),
        ),
      );
    });

    test('instrumented download success traces span', () async {
      await instrumented.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'application/pdf',
      );
      final bytes = await instrumented.download(
        bucket: credential,
        path: 'u/s/doc.pdf',
      );
      expect(bytes, <int>[1, 2, 3]);
    });

    test('instrumented download error traces span and maps SDK error', () async {
      storage.nextError = supabase.StorageException('boom', statusCode: '500');
      await expectLater(
        instrumented.download(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.server),
        ),
      );
    });

    test('instrumented remove error maps SDK error', () async {
      storage.nextError = supabase.StorageException('boom', statusCode: '403');
      await expectLater(
        instrumented.remove(bucket: credential, paths: <String>['x']),
        throwsA(
          isA<StorageForbiddenException>()
              .having((e) => e.code, 'code', 'PLT002'),
        ),
      );
    });

    test('instrumented createSignedUrl error maps SDK error', () async {
      storage.nextError = supabase.StorageException('boom', statusCode: '404');
      await expectLater(
        instrumented.createSignedUrl(
          bucket: credential,
          path: 'x',
          expiresInSeconds: 60,
        ),
        throwsA(
          isA<StorageNotFoundException>()
              .having((e) => e.code, 'code', 'PLT004'),
        ),
      );
    });

    test('instrumented list error maps SDK error', () async {
      storage.nextError = supabase.StorageException('boom', statusCode: '401');
      await expectLater(
        instrumented.list(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageAuthException>()
              .having((e) => e.code, 'code', 'PLT001'),
        ),
      );
    });

    test('Dio progress response carrying a Key map returns the key', () async {
      final withDio = SupabaseStorageService(
        storageClient: storage,
        dio: dio,
        tokenProvider: tokens,
      );
      dioHarness.responseData = <String, dynamic>{'Key': 'u/s/keyed.pdf'};
      final key = await withDio.upload(
        bucket: credential,
        path: 'u/s/doc.pdf',
        bytes: Uint8List(2),
        mimeType: 'application/pdf',
        onProgress: (sent, total) {},
      );
      expect(key, 'u/s/keyed.pdf');
    });

    test('Dio progress response with no usable data falls back to path', () async {
      final withDio = SupabaseStorageService(
        storageClient: storage,
        dio: dio,
        tokenProvider: tokens,
      );
      dioHarness.responseData = <String, dynamic>{};
      final key = await withDio.upload(
        bucket: credential,
        path: 'u/s/fallback.pdf',
        bytes: Uint8List(2),
        mimeType: 'application/pdf',
        onProgress: (sent, total) {},
      );
      expect(key, 'u/s/fallback.pdf');
    });

    test('SDK error message is truncated to a safe length', () async {
      final longMessage = 'A' * 500;
      storage.nextError =
          supabase.StorageException(longMessage, statusCode: '500');
      await expectLater(
        service.download(bucket: credential, path: 'x'),
        throwsA(
          isA<StorageException>().having(
            (e) => e.message.length,
            'message length',
            lessThanOrEqualTo(201),
          ),
        ),
      );
    });

    test('Dio badResponse (with status) maps via response path', () async {
      final withDio = SupabaseStorageService(
        storageClient: storage,
        dio: dio,
        tokenProvider: tokens,
      );
      dioHarness.throwOnPost = DioException(
        requestOptions: RequestOptions(path: 'x'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: 'x'),
          statusCode: 403,
        ),
      );
      await expectLater(
        withDio.upload(
          bucket: credential,
          path: 'u/s/doc.pdf',
          bytes: Uint8List(2),
          mimeType: 'application/pdf',
          onProgress: (sent, total) {},
        ),
        throwsA(
          isA<StorageException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.forbidden)
              .having((e) => e.code, 'code', 'PLT002'),
        ),
      );
    });
  });
}

SupabaseStorageService _instrumentedService(
  FakeSupabaseStorageClient storage,
  FakeAccessTokenProvider tokens,
  Dio dio,
) {
  final monConfig = MonitoringConfig(
    sentryDsn: '',
    environment: 'test',
    release: '0.0.0',
    traceSampleRate: 0,
    profileSampleRate: 0,
    enableSentry: false,
    minimumLogLevel: 'debug',
    enablePiiRedaction: false,
    maxBreadcrumbCount: 100,
  );
  final flags = FeatureFlags(
    enableVerboseLogging: true,
    enableOfflineSync: false,
    enableAnalyticsTracking: false,
    enableDynamicWorkspaceLoading: false,
    enablePayloadOptimization: false,
    enablePushNotifications: false,
  );
  return SupabaseStorageService(
    storageClient: storage,
    dio: dio,
    tokenProvider: tokens,
    logger: HivorrLogger(
      'storage-test',
      LogRouter(sinks: <LogSink>[], minimumLevel: LogLevel.debug),
      PiiRedactor(enabled: false),
    ),
    monitoring: MonitoringService(monConfig),
    tracer: PerformanceTracer(monConfig, flags),
  );
}

class FakeAccessTokenProvider implements AccessTokenProvider {
  FakeAccessTokenProvider(this.token);

  final String? token;

  @override
  String? get currentToken => token;

  @override
  Future<String?> refresh() async => token;
}

/// A real [Dio] with a fake request interceptor that captures the request and
/// returns a canned 200 response (firing `onSendProgress` first), so the
/// progress fallback path can be tested without any network.
class FakeDioHarness {
  FakeDioHarness() {
    dio = Dio(
      BaseOptions(baseUrl: 'https://example.supabase.co/storage/v1'),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedEndpoint = options.uri.toString();
          capturedData = options.data;
          capturedAuthHeader = options.headers['Authorization']?.toString();
          final toThrow = throwOnPost;
          if (toThrow != null) {
            handler.reject(toThrow);
            return;
          }
          options.onSendProgress?.call(10, 100);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: responseData ?? options.path,
            ),
          );
        },
      ),
    );
  }

  late final Dio dio;
  DioException? throwOnPost;
  Object? responseData;
  String? capturedEndpoint;
  Object? capturedData;
  String? capturedAuthHeader;
}
