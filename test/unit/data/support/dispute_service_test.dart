import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/log_level.dart';
import 'package:hivorr/core/logging/log_router.dart';
import 'package:hivorr/core/logging/log_sink.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';

import '../../../support/fakes/fake_logging.dart';
import '../../../support/fakes/support/fake_dispute_repository.dart';

void main() {
  HivorrLogger makeLogger(RecordingSink sink) => HivorrLogger(
        'hivorr.test',
        LogRouter(sinks: <LogSink>[sink], minimumLevel: LogLevel.debug),
        PiiRedactor(),
      );

  DisputeService build(FakeDisputeRepository repo, [HivorrLogger? logger]) =>
      DisputeService(repository: repo, logger: logger);

  DisputeService hivorrService() =>
      build(FakeDisputeRepository());

  group('fail-fast validators (mirror CHECK constraints)', () {
    test('validateReason accepts 10–2000 chars after trim', () {
      expect(DisputeService.validateReason('1234567890'), isTrue);
      expect(
        DisputeService.validateReason('a' * 2000),
        isTrue,
      );
    });

    test('validateReason rejects too-short and overlong reasons', () {
      expect(DisputeService.validateReason('short'), isFalse);
      expect(DisputeService.validateReason('   '), isFalse);
      expect(DisputeService.validateReason('a' * 2001), isFalse);
    });

    test('validateTitle accepts 1–255 chars', () {
      expect(DisputeService.validateTitle('x'), isTrue);
      expect(DisputeService.validateTitle('a' * 255), isTrue);
    });

    test('validateTitle rejects empty titles', () {
      expect(DisputeService.validateTitle(''), isFalse);
      expect(DisputeService.validateTitle('   '), isFalse);
    });

    test('validateDescription accepts empty or ≤2000 chars', () {
      expect(DisputeService.validateDescription(''), isTrue);
      expect(DisputeService.validateDescription('a' * 2000), isTrue);
      expect(DisputeService.validateDescription('a' * 2001), isFalse);
    });
  });

  group('vocabulary (compile-time mirrors of frozen CHECK)', () {
    test('exposes the 5-state status vocabulary', () {
      expect(DisputeService.disputeStatusList, hasLength(5));
      expect(
        DisputeService.disputeStatusList.map((DisputeStatus s) => s.code),
        <String>['open', 'under_review', 'resolved', 'closed', 'withdrawn'],
      );
    });

    test('exposes the 5-type dispute vocabulary', () {
      expect(DisputeService.disputeTypeList, hasLength(5));
      expect(
        DisputeService.disputeTypeList.map((DisputeType t) => t.code),
        contains('milestone_disagreement'),
      );
    });

    test('exposes the 4+other desired-outcome vocabulary', () {
      expect(DisputeService.desiredOutcomeList, hasLength(4));
      expect(
        DisputeService.desiredOutcomeList.map((DesiredOutcome o) => o.code),
        <String>['release_to_payee', 'refund_to_payer', 'split', 'other'],
      );
    });

    test('exposes the 4-state priority vocabulary', () {
      expect(DisputeService.disputePriorityList, hasLength(4));
      expect(
        DisputeService.disputePriorityList.map((DisputePriority p) => p.code),
        <String>['low', 'medium', 'high', 'critical'],
      );
    });

    test('exposes the 4-type evidence and resolution vocabularies', () {
      expect(DisputeService.evidenceTypeList, hasLength(4));
      expect(DisputeService.resolutionTypeList, hasLength(4));
      expect(
        DisputeService.evidenceTypeList.map((EvidenceType e) => e.code),
        contains('screenshot'),
      );
    });

    test('statusFor / typeFor / resolutionTypeFor resolve codes', () {
      expect(hivorrService().statusFor('open')?.label, 'Open');
      expect(hivorrService().typeFor('fraud')?.label, 'Fraud');
      expect(hivorrService().resolutionTypeFor('split')?.label,
          'Split between parties');
    });

    test('lookups return null for unknown codes', () {
      expect(hivorrService().statusFor('nope'), isNull);
      expect(hivorrService().typeFor('nope'), isNull);
      expect(hivorrService().resolutionTypeFor('nope'), isNull);
    });
  });

  group('data operations delegate to the repository', () {
    test('listDisputes passes the filter and returns the mapped cases', () async {
      final repo = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(id: 'dispute-1', status: 'open'),
        ],
      );
      final service = build(repo);
      final List<DisputeCase> cases = await service.listDisputes(status: 'open');

      expect(repo.lastStatusFilter, 'open');
      expect(cases.single.id, 'dispute-1');
    });

    test('getCase returns the detail envelope', () async {
      final repo = FakeDisputeRepository(
        detail: seedDisputeDetailEntity(id: 'dispute-1', status: 'under_review'),
      );
      final service = build(repo);
      final DisputeCaseDetail detail = await service.getCase('dispute-1');

      expect(detail.disputeCase.status, 'under_review');
      expect(repo.getCaseCallCount, 1);
    });

    test('fileDispute forwards every argument', () async {
      final repo = FakeDisputeRepository();
      final service = build(repo);
      final DisputeCase filed = await service.fileDispute(
        escrowId: 'escrow-1',
        disputeType: 'milestone_disagreement',
        reason: 'Work did not match the agreed milestone description.',
        desiredOutcome: 'refund_to_payer',
        priority: 'critical',
      );

      expect(filed.escrowId, 'escrow-1');
      expect(repo.lastDisputeType, 'milestone_disagreement');
      expect(repo.lastDesiredOutcome, 'refund_to_payer');
      expect(repo.lastPriority, 'critical');
    });

    test('submitEvidence forwards title/type/fileUrl and maps the row',
        () async {
      final repo = FakeDisputeRepository();
      final service = build(repo);
      final DisputeEvidence evidence = await service.submitEvidence(
        caseId: 'dispute-1',
        evidenceType: 'screenshot',
        title: 'Mismatch screenshot',
        fileUrl: 'entity-filer/dispute-1/abc.jpg',
      );

      expect(evidence.hasAttachment, isTrue);
      expect(repo.lastTitle, 'Mismatch screenshot');
      expect(repo.lastFileUrl, 'entity-filer/dispute-1/abc.jpg');
    });

    test('withdrawDispute returns the withdrawn case', () async {
      final repo = FakeDisputeRepository();
      final service = build(repo);
      final DisputeCase updated = await service.withdrawDispute('dispute-1');

      expect(updated.status, 'withdrawn');
      expect(repo.lastCaseId, 'dispute-1');
    });

    test('failures are logged (span name in context) and rethrown', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository()
        ..nextError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'boom',
          code: 'PLT999',
        );
      final service = build(repo, makeLogger(sink));

      await expectLater(
        service.getCase('dispute-1'),
        throwsA(isA<ApiException>()),
      );

      expect(
        sink.entries.map((e) => e.message),
        contains('support.dispute.get failed'),
      );
    });
  });

  group('structured logging', () {
    test('successful list logs a fetched entry with scopes', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(id: 'dispute-1'),
        ],
      );
      final service = build(repo, makeLogger(sink));

      await service.listDisputes(status: 'open');

      expect(
        sink.entries.map((e) => e.message),
        contains('Dispute list fetched'),
      );
    });

    test('filing logs the intent and the held result', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository();
      final service = build(repo, makeLogger(sink));

      await service.fileDispute(
        escrowId: 'escrow-1',
        disputeType: 'service_quality',
        reason: 'Work did not match the agreed milestone description.',
      );

      expect(sink.entries.map((e) => e.message),
          containsAll(<String>['Filing dispute', 'Dispute filed — escrow held']));
    });

    test('withdrawal logs the release', () async {
      final sink = RecordingSink();
      final repo = FakeDisputeRepository();
      final service = build(repo, makeLogger(sink));

      await service.withdrawDispute('dispute-1');

      expect(
        sink.entries.map((e) => e.message),
        contains('Dispute withdrawn — escrow released'),
      );
    });
  });
}