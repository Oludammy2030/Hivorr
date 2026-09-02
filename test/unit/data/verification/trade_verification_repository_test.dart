// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/data/repositories/trade_verification_repository_impl.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';
import '../../../support/fakes/fake_network.dart';
import '../../../support/fakes/fake_supabase.dart';
import '../../../support/fakes/fake_trade_verification.dart';
import '../../../support/fakes/fake_verification.dart' show FakeStorageService;

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
  const String mimeType = 'application/pdf';
  const String fileName = 'proof.pdf';
  const String professionId = 'p1';

  Map<String, dynamic> credentialRow() => <String, dynamic>{
        'id': 'cred-1',
        'entity_id': 'u1',
        'kind': TradeProofType.tradeKind,
        'title': 'Plumbing — Certificate',
        'document_path': 'credential-documents/u1/abc.bin',
        'profession_id': professionId,
      };

  TradeVerificationRepositoryImpl build({
    FakeTradeVerificationRemoteDataSource? remote,
    bool signedIn = true,
  }) {
    final FakeTradeVerificationRemoteDataSource dataSource =
        remote ?? FakeTradeVerificationRemoteDataSource();
    return TradeVerificationRepositoryImpl(
      remote: dataSource,
      storage: FakeStorageService(),
      supabase: MockSupabaseClientFactory.create(
        currentUser: signedIn ? fakeUser('u1') : null,
        queryResults: <String, List<Map<String, dynamic>>>{
          'entity_credentials': <Map<String, dynamic>>[credentialRow()],
        },
      ),
    );
  }

  group('submitTradeProof', () {
    test('validates, uploads, inserts + queues for a signed-in entity',
        () async {
      final remote = FakeTradeVerificationRemoteDataSource();
      final repo = build(remote: remote);

      final VerificationSubmission submission = await repo.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(submission.status, VerificationStatusKind.pending);
      expect(submission.credentialId, 'cred-1');
      expect(remote.lastCredentialId, 'cred-1');
      expect(remote.lastSubmissionType, TradeProofType.submissionType);
      expect(remote.submitCallCount, 1);
    });

    test('targets the private credential-documents bucket', () async {
      final storage = FakeStorageService();
      final repo = TradeVerificationRepositoryImpl(
        remote: FakeTradeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );
      expect(
        StorageBuckets.credentialDocuments,
        isNot('public'),
      );

      await repo.submitTradeProof(
        type: TradeProofType.license,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(storage.lastBucket, StorageBuckets.credentialDocuments);
      expect(storage.uploadCallCount, 1);
    });

    test('forwards mime type and byte length to storage', () async {
      final storage = FakeStorageService();
      final repo = TradeVerificationRepositoryImpl(
        remote: FakeTradeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitTradeProof(
        type: TradeProofType.workSample,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(storage.lastMimeType, mimeType);
      expect(storage.lastByteLength, bytes.length);
    });

    test('does not RPC when validation fails (fail-fast)', () async {
      final remote = FakeTradeVerificationRemoteDataSource();
      final storage = FakeStorageService()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'bad mime',
          code: 'PLT003',
        );
      final repo = TradeVerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await expectLater(
        repo.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: bytes,
          mimeType: 'text/html',
          fileName: fileName,
        ),
        throwsA(isA<ApiException>().having((ApiException e) => e.code,
            'code', 'PLT003')),
      );
      expect(remote.submitCallCount, 0);
      expect(storage.uploadCallCount, 0);
    });

    test('propagates an upload failure without calling the RPC', () async {
      final remote = FakeTradeVerificationRemoteDataSource();
      final storage = FakeStorageService()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'upload failed',
          code: 'X0',
        );
      final repo = TradeVerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      expect(
        () => repo.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.server)),
      );
      expect(remote.submitCallCount, 0);
    });

    test('throws PLT999 when the credential row insert returns no rows',
        () async {
      final repo = TradeVerificationRepositoryImpl(
        remote: FakeTradeVerificationRemoteDataSource(),
        storage: FakeStorageService(),
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[],
          },
        ),
      );

      expect(
        () => repo.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>().having(
            (ApiException e) => e.code, 'code', 'PLT999')),
      );
    });

    test('surfaces a remote conflict (PLT005) from the RPC layer', () async {
      final remote = FakeTradeVerificationRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.conflict,
          message: 'duplicate',
          code: 'PLT005',
        );
      final repo = build(remote: remote);

      expect(
        () => repo.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.conflict)),
      );
    });

    test('throws PLT001 auth when no entity is signed in', () async {
      final repo = build(signedIn: false);

      expect(
        () => repo.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind', ApiExceptionKind.auth)
            .having((ApiException e) => e.code, 'code', 'PLT001')),
      );
    });

    test('builds a per-submission storage path under the entity id', () async {
      final storage = FakeStorageService();
      final repo = TradeVerificationRepositoryImpl(
        remote: FakeTradeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      final String? firstPath = storage.lastPath;
      await repo.submitTradeProof(
        type: TradeProofType.license,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );
      final String? secondPath = storage.lastPath;

      expect(firstPath, startsWith('u1/'));
      expect(firstPath!.split('/'), hasLength(3));
      expect(firstPath, endsWith('_$fileName'));
      expect(firstPath, isNot(secondPath), reason: 'each submit has a new UUID');
    });

    test('forwards the upload progress callback to storage', () async {
      final storage = FakeStorageService();
      void progress(int sent, int total) {}
      final repo = TradeVerificationRepositoryImpl(
        remote: FakeTradeVerificationRemoteDataSource(),
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: progress,
      );

      expect(storage.lastOnProgress, same(progress));
    });

    test('accepts a zero-byte proof (validation boundary)', () async {
      final remote = FakeTradeVerificationRemoteDataSource();
      final storage = FakeStorageService();
      final repo = TradeVerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await repo.submitTradeProof(
        type: TradeProofType.portfolio,
        professionId: professionId,
        bytes: Uint8List(0),
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(storage.lastByteLength, 0);
      expect(remote.submitCallCount, 1);
    });

    test('rejects an over-limit payload before any upload (PLT003)', () async {
      final remote = FakeTradeVerificationRemoteDataSource();
      final storage = FakeStorageService()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.validation,
          message: 'File exceeds the credential-documents limit.',
          code: 'PLT003',
        );
      final repo = TradeVerificationRepositoryImpl(
        remote: remote,
        storage: storage,
        supabase: MockSupabaseClientFactory.create(
          currentUser: fakeUser('u1'),
          queryResults: <String, List<Map<String, dynamic>>>{
            'entity_credentials': <Map<String, dynamic>>[credentialRow()],
          },
        ),
      );

      await expectLater(
        repo.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: Uint8List(StorageLimits.credentialDocuments + 1),
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.validation)
            .having((ApiException e) => e.code, 'code', 'PLT003')),
      );

      expect(storage.uploadCallCount, 0);
      expect(storage.lastPath, isNull);
      expect(remote.submitCallCount, 0);
    });
  });

  group('credential insert (server-authoritative)', () {
    ({TradeVerificationRepositoryImpl repository, _RecordingSupabaseClient client})
        buildRecording({TradeProfessionNameResolver? resolveName}) {
      final _RecordingHttpClient recorder = _RecordingHttpClient(
        queryResults: <String, List<Map<String, dynamic>>>{
          'entity_credentials': <Map<String, dynamic>>[credentialRow()],
        },
      );
      final _RecordingSupabaseClient client = _RecordingSupabaseClient(recorder);
      final FakeTradeVerificationRemoteDataSource remote =
          FakeTradeVerificationRemoteDataSource();
      final TradeVerificationRepositoryImpl repository =
          TradeVerificationRepositoryImpl(
        remote: remote,
        storage: FakeStorageService(),
        supabase: client,
        resolveProfessionName: resolveName,
      );
      return (repository: repository, client: client);
    }

    Map<String, dynamic> credentialInsertBody(_RecordingSupabaseClient client) {
      final List<({String path, String body})> inserts = client.recorder.posts
          .where((({String path, String body}) post) =>
              post.path.contains('entity_credentials'))
          .toList(growable: false);
      expect(inserts, hasLength(1));
      final dynamic decoded = jsonDecode(inserts.single.body);
      final Map<String, dynamic> row = decoded is List<dynamic>
          ? Map<String, dynamic>.from(decoded.single as Map<String, dynamic>)
          : Map<String, dynamic>.from(decoded as Map<String, dynamic>);
      return row;
    }

    test('insert binds profession_id + trade kind and resolves the title',
        () async {
      final built = buildRecording(resolveName: (_) async => 'Plumbing');

      await built.repository.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      final Map<String, dynamic> row = credentialInsertBody(built.client);
      expect(row['entity_id'], 'u1');
      expect(row['profession_id'], professionId);
      expect(row['kind'], TradeProofType.tradeKind);
      expect(row['title'], 'Plumbing — Certificate');
      expect(row['document_path'], isNotNull);
    });

    test('title falls back to the proof label when the resolver is null',
        () async {
      final built = buildRecording();
      await built.repository.submitTradeProof(
        type: TradeProofType.license,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(credentialInsertBody(built.client)['title'], 'License');
    });

    test('title falls back to the label for an empty resolver result',
        () async {
      final built = buildRecording(resolveName: (_) async => '');

      await built.repository.submitTradeProof(
        type: TradeProofType.other,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      expect(credentialInsertBody(built.client)['title'], 'Other');
    });

    test('insert never writes verification_status or reviewed_at (Rule 4)',
        () async {
      final built = buildRecording(resolveName: (_) async => 'Plumbing');

      await built.repository.submitTradeProof(
        type: TradeProofType.certificate,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
      );

      final Map<String, dynamic> row = credentialInsertBody(built.client);
      expect(row.containsKey('verification_status'), isFalse);
      expect(row.containsKey('reviewed_at'), isFalse);
      expect(row.containsKey('trade_verification_status'), isFalse);
    });

    test('a failing name resolver propagates and skips the RPC', () async {
      final built = buildRecording(
        resolveName: (_) async => throw StateError('resolve failed'),
      );

      expect(
        () => built.repository.submitTradeProof(
          type: TradeProofType.certificate,
          professionId: professionId,
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('getStatus', () {
    test('maps the trade aggregate from the remote envelope', () async {
      final remote = FakeTradeVerificationRemoteDataSource(
        statusResult: tradeStatusDto(
          identityVerified: true,
          statuses: <String, String>{'p1': 'approved'},
        ),
      );
      final repo = build(remote: remote);

      final TradeVerificationStatus status = await repo.getStatus();

      expect(status.identityVerified, isTrue);
      expect(status.kindFor('p1'), TradeVerificationStatusKind.approved);
      expect(remote.statusCallCount, 1);
    });

    test('derives unverified for an absent profession (fail-closed)', () async {
      final repo = build();

      final TradeVerificationStatus status = await repo.getStatus();

      expect(status.kindFor('unknown'), TradeVerificationStatusKind.unverified);
      expect(TradeVerificationGateCheck.canBidAt(status, 'unknown'), isFalse);
    });

    test('rethrows remote failures', () async {
      final remote = FakeTradeVerificationRemoteDataSource()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'not found',
          code: 'PLT004',
        );
      final repo = build(remote: remote);

      expect(
        () => repo.getStatus(),
        throwsA(isA<ApiException>()
            .having((ApiException e) => e.kind, 'kind',
                ApiExceptionKind.notFound)),
      );
    });

    test('never forwards a client-supplied entity id (server derives it)',
        () async {
      final remote = FakeTradeVerificationRemoteDataSource(
        statusResult: tradeStatusDto(
          identityVerified: true,
          statuses: <String, String>{'p1': 'approved'},
        ),
      );
      final repo = build(remote: remote);

      final TradeVerificationStatus status = await repo.getStatus();

      expect(remote.lastEntityId, isNull);
      expect(status.identityVerified, isTrue);
      expect(status.kindFor('p1'), TradeVerificationStatusKind.approved);
    });
  });
}

/// Wraps [ScriptedHttpClient] to record POST request bodies (insert + RPC) so
/// tests can assert exactly what the repository writes (Rule 4, TV-08).
class _RecordingHttpClient extends ScriptedHttpClient {
  _RecordingHttpClient({
    super.queryResults,
  });

  final List<({String path, String body})> posts = <({String path, String body})>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request &&
        request.method == 'POST' &&
        request.body.isNotEmpty) {
      posts.add((path: request.url.path, body: request.body));
    }
    return super.send(request);
  }
}

/// [SupabaseClient] over the recording transport (mirrors
/// [ScriptedSupabaseClient] with an overridable httpClient).
class _RecordingSupabaseClient extends SupabaseClient {
  _RecordingSupabaseClient(this.recorder)
      : super(
          'https://example.supabase.co',
          'public-anon-key',
          httpClient: recorder,
        );

  final _RecordingHttpClient recorder;

  @override
  GoTrueClient get auth => _goTrue;

  final FakeGoTrueClient _goTrue =
      FakeGoTrueClient()..seedSession(fakeSession('u1'));
}

/// Local shorthand so repository tests don't depend on the gate import.
abstract final class TradeVerificationGateCheck {
  const TradeVerificationGateCheck._();

  static bool canBidAt(TradeVerificationStatus status, String professionId) =>
      status.kindFor(professionId).canBid;
}
