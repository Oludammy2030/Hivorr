import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/repositories/dispute_repository_impl.dart';

import '../../../support/fakes/support/fake_dispute_remote_data_source.dart';

void main() {
  DisputeRepositoryImpl build({
    FakeDisputeRemoteDataSource? remote,
    String status = 'open',
  }) {
    final r = remote ?? FakeDisputeRemoteDataSource();
    return DisputeRepositoryImpl(remote: r);
  }

  group('DisputeRepositoryImpl reads', () {
    test('listDisputes maps the envelope into DisputeCase entities', () async {
      final remote = FakeDisputeRemoteDataSource(
        list: <DisputeCaseDto>[
          seedDisputeCaseDto(id: 'dispute-1', status: 'open'),
          seedDisputeCaseDto(id: 'dispute-2', status: 'under_review'),
        ],
      );
      final repo = build(remote: remote);

      final List<DisputeCase> cases = await repo.listDisputes();

      expect(cases, hasLength(2));
      expect(cases[0].id, 'dispute-1');
      expect(cases[0].isOpen, isTrue);
      expect(cases[1].status, 'under_review');
      expect(remote.listCallCount, 1);
    });

    test('listDisputes passes the status filter and filters', () async {
      final remote = FakeDisputeRemoteDataSource(
        list: <DisputeCaseDto>[
          seedDisputeCaseDto(id: 'dispute-1', status: 'open'),
          seedDisputeCaseDto(id: 'dispute-2', status: 'closed'),
        ],
      );
      final repo = build(remote: remote);

      final List<DisputeCase> cases = await repo.listDisputes(status: 'open');

      expect(remote.lastStatusFilter, 'open');
      expect(cases, hasLength(1));
      expect(cases.single.status, 'open');
    });

    test('listDisputes rejects an invalid status before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.listDisputes(status: 'not_a_status'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT003')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              ),
        ),
      );
      expect(remote.listCallCount, 0);
    });

    test('getCase maps case + evidence + resolution in one call', () async {
      final remote = FakeDisputeRemoteDataSource(
        details: <String, DisputeCaseDetailEnvelopeDto>{
          'dispute-1': seedDisputeDetailDto(
            caseDto: seedDisputeCaseDto(
              id: 'dispute-1',
              status: 'under_review',
            ),
            evidence: <DisputeEvidenceDto>[
              seedDisputeEvidenceDto(id: 'ev-1'),
            ],
            resolution: seedDisputeResolutionDto(),
          ),
        },
      );
      final repo = build(remote: remote);

      final DisputeCaseDetail detail = await repo.getCase('dispute-1');

      expect(detail.disputeCase.id, 'dispute-1');
      expect(detail.disputeCase.status, 'under_review');
      expect(detail.evidence, hasLength(1));
      expect(detail.evidence.single.title, 'Mismatch screenshot');
      expect(detail.hasResolution, isTrue);
      expect(detail.resolution!.resolutionType, 'release_to_payee');
      expect(remote.getCaseCallCount, 1);
    });

    test('getCase is null-safe for a missing resolution', () async {
      final remote = FakeDisputeRemoteDataSource(
        details: <String, DisputeCaseDetailEnvelopeDto>{
          'dispute-1': seedDisputeDetailDto(
            caseDto: seedDisputeCaseDto(id: 'dispute-1', status: 'open'),
            resolution: null,
          ),
        },
      );
      final repo = build(remote: remote);

      final DisputeCaseDetail detail = await repo.getCase('dispute-1');

      expect(detail.hasResolution, isFalse);
      expect(detail.resolution, isNull);
    });

    test('surfaces remote not-found as ApiException', () async {
      final repo = build(remote: FakeDisputeRemoteDataSource());

      await expectLater(
        repo.getCase('missing'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT004'),
        ),
      );
    });
  });

  group('DisputeRepositoryImpl.fileDispute validation', () {
    test('rejects an empty escrowId before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.fileDispute(
          escrowId: '  ',
          disputeType: 'fraud',
          reason: 'Work did not match the agreed milestone description.',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.fileCallCount, 0);
    });

    test('rejects a reason shorter than 10 chars before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.fileDispute(
          escrowId: 'escrow-1',
          disputeType: 'fraud',
          reason: 'short',
        ),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT003')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.validation,
              ),
        ),
      );
      expect(remote.fileCallCount, 0);
    });

    test('rejects a reason longer than 2000 chars before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.fileDispute(
          escrowId: 'escrow-1',
          disputeType: 'fraud',
          reason: 'x' * 2001,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.fileCallCount, 0);
    });

    test('rejects an invalid dispute type before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.fileDispute(
          escrowId: 'escrow-1',
          disputeType: 'bogus',
          reason: 'Work did not match the agreed milestone description.',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.fileCallCount, 0);
    });

    test('rejects an invalid desired outcome before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.fileDispute(
          escrowId: 'escrow-1',
          disputeType: 'fraud',
          reason: 'Work did not match the agreed milestone description.',
          desiredOutcome: 'bogus',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.fileCallCount, 0);
    });

    test('rejects an invalid priority before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.fileDispute(
          escrowId: 'escrow-1',
          disputeType: 'fraud',
          reason: 'Work did not match the agreed milestone description.',
          priority: 'urgent',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.fileCallCount, 0);
    });

    test('valid file passes params through and re-reads the authoritative case',
        () async {
      final remote = FakeDisputeRemoteDataSource(
        fileId: 'dispute-filed-9',
        details: <String, DisputeCaseDetailEnvelopeDto>{
          'dispute-filed-9': seedDisputeDetailDto(
            caseDto: seedDisputeCaseDto(
              id: 'dispute-filed-9',
              escrowId: 'escrow-1',
              disputeType: 'milestone_disagreement',
              desiredOutcome: 'split',
              priority: 'high',
              status: 'open',
            ),
            resolution: null,
          ),
        },
      );
      final repo = build(remote: remote);

      final DisputeCase filed = await repo.fileDispute(
        escrowId: 'escrow-1',
        disputeType: 'milestone_disagreement',
        reason: 'Work did not match the agreed milestone description.',
        desiredOutcome: 'split',
        priority: 'high',
      );

      expect(remote.fileCallCount, 1);
      expect(remote.lastEscrowId, 'escrow-1');
      expect(remote.lastDisputeType, 'milestone_disagreement');
      expect(remote.lastDesiredOutcome, 'split');
      expect(remote.lastPriority, 'high');
      // Post-write re-read: the repository calls getCase for authoritative state.
      expect(remote.getCaseCallCount, 1);
      expect(filed.id, 'dispute-filed-9');
    });
  });

  group('DisputeRepositoryImpl.submitEvidence validation', () {
    test('rejects an empty title before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.submitEvidence(
          caseId: 'dispute-1',
          evidenceType: 'screenshot',
          title: '  ',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.submitEvidenceCallCount, 0);
    });

    test('rejects a description longer than 2000 chars before the RPC',
        () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.submitEvidence(
          caseId: 'dispute-1',
          evidenceType: 'description',
          title: 'Written account',
          description: 'x' * 2001,
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.submitEvidenceCallCount, 0);
    });

    test('rejects an invalid evidence type before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.submitEvidence(
          caseId: 'dispute-1',
          evidenceType: 'video',
          title: 'Clip',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.submitEvidenceCallCount, 0);
    });

    test('valid submit maps the returned evidence row', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      final DisputeEvidence evidence = await repo.submitEvidence(
        caseId: 'dispute-1',
        evidenceType: 'screenshot',
        title: 'Mismatch screenshot',
        description: 'See attachment',
        fileUrl: 'entity-filer/dispute-1/abc.png',
        fileMetadata: <String, dynamic>{'mimeType': 'image/png'},
      );

      expect(remote.submitEvidenceCallCount, 1);
      expect(remote.lastTitle, 'Mismatch screenshot');
      expect(remote.lastFileUrl, 'entity-filer/dispute-1/abc.png');
      expect(evidence.evidenceType, 'screenshot');
      expect(evidence.hasAttachment, isTrue);
    });
  });

  group('DisputeRepositoryImpl.withdrawDispute', () {
    test('maps the withdrawn case returned by the SECURITY DEFINER RPC',
        () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      final DisputeCase withdrawn = await repo.withdrawDispute('dispute-1');

      expect(remote.withdrawCallCount, 1);
      expect(remote.lastCaseId, 'dispute-1');
      expect(withdrawn.status, 'withdrawn');
      expect(withdrawn.isWithdrawn, isTrue);
    });

    test('rejects an empty case id before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = build(remote: remote);

      await expectLater(
        repo.withdrawDispute(''),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.withdrawCallCount, 0);
    });

    test('propagates a PLT005 conflict from the server', () async {
      final remote = FakeDisputeRemoteDataSource();
      remote.nextError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'This dispute cannot be modified in its current state.',
        code: 'PLT005',
      );
      final repo = build(remote: remote);

      await expectLater(
        repo.withdrawDispute('dispute-1'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.code, 'code', 'PLT005')
              .having(
                (ApiException e) => e.kind,
                'kind',
                ApiExceptionKind.conflict,
              ),
        ),
      );
    });
  });
}