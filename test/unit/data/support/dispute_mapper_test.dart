import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/mappers/dispute_mapper.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_resolution_dto.dart';

import '../../../support/fakes/support/fake_dispute_remote_data_source.dart';

void main() {
  Map<String, dynamic> caseJson({
    String id = 'dispute-1',
    String escrowId = 'escrow-1',
    String filerEntityId = 'entity-filer',
    String counterpartyEntityId = 'entity-counterparty',
    String disputeType = 'milestone_disagreement',
    String status = 'under_review',
    String? desiredOutcome = 'split',
    String priority = 'high',
    String filedAt = '2026-01-01T00:00:00.000Z',
    String? resolvedAt = '2026-01-02T00:00:00.000Z',
    String? closedAt,
    String? withdrawnAt,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) =>
      <String, dynamic>{
        'id': id,
        'escrow_id': escrowId,
        'filer_entity_id': filerEntityId,
        'counterparty_entity_id': counterpartyEntityId,
        'dispute_type': disputeType,
        'status': status,
        'reason': 'Work did not match the agreed milestone description.',
        'desired_outcome': desiredOutcome,
        'priority': priority,
        'filed_at': filedAt,
        'resolved_at': resolvedAt,
        'closed_at': closedAt,
        'withdrawn_at': withdrawnAt,
        'metadata': metadata,
      };

  group('DisputeCaseDto.fromJson → DisputeMapper.caseToEntity', () {
    test('maps every snake_case column into the DisputeCase entity', () {
      final DisputeCaseDto dto = DisputeCaseDto.fromJson(caseJson());
      final DisputeCase entity = DisputeMapper.caseToEntity(dto);

      expect(entity.id, 'dispute-1');
      expect(entity.escrowId, 'escrow-1');
      expect(entity.filerEntityId, 'entity-filer');
      expect(entity.counterpartyEntityId, 'entity-counterparty');
      expect(entity.disputeType, 'milestone_disagreement');
      expect(entity.status, 'under_review');
      expect(entity.reason, 'Work did not match the agreed milestone description.');
      expect(entity.desiredOutcome, 'split');
      expect(entity.priority, 'high');
      expect(
        entity.filedAt,
        DateTime.parse('2026-01-01T00:00:00.000Z'),
      );
      expect(entity.resolvedAt, DateTime.parse('2026-01-02T00:00:00.000Z'));
      expect(entity.closedAt, isNull);
      expect(entity.withdrawnAt, isNull);
      expect(entity.isOpen, isFalse);
      expect(entity.acceptsEvidence, isTrue);
    });

    test('maps null timestamps to null instead of throwing', () {
      final DisputeCaseDto dto = DisputeCaseDto.fromJson(caseJson(
        resolvedAt: null,
        desiredOutcome: null,
      ));
      final DisputeCase entity = DisputeMapper.caseToEntity(dto);

      expect(entity.resolvedAt, isNull);
      expect(entity.desiredOutcome, isNull);
    });

    test('metadata jsonb passes through unchanged', () {
      final DisputeCaseDto dto = DisputeCaseDto.fromJson(caseJson(
        metadata: <String, dynamic>{'origin': 'escrow-detail', 'batch': 2},
      ));
      final DisputeCase entity = DisputeMapper.caseToEntity(dto);

      expect(entity.metadata, <String, dynamic>{
        'origin': 'escrow-detail',
        'batch': 2,
      });
    });

    test('defaults status to open and priority to medium when absent', () {
      final Map<String, dynamic> json = caseJson()..remove('priority');
      final DisputeCase entity =
          DisputeMapper.caseToEntity(DisputeCaseDto.fromJson(json));

      expect(entity.priority, 'medium');
      expect(entity.status, 'under_review');
    });
  });

  group('DisputeEvidenceDto.fromJson → DisputeMapper.evidenceToEntity', () {
    test('maps evidence columns and file_metadata', () {
      final DisputeEvidenceDto dto = DisputeEvidenceDto.fromJson(
        <String, dynamic>{
          'id': 'ev-1',
          'case_id': 'dispute-1',
          'submitted_by': 'entity-filer',
          'evidence_type': 'photo',
          'title': 'Damaged goods photo',
          'description': null,
          'file_url': 'entity-filer/dispute-1/abc.jpg',
          'file_metadata': <String, dynamic>{
            'mimeType': 'image/jpeg',
            'sizeBytes': 2048,
            'originalName': 'damage.jpg',
          },
          'created_at': '2026-01-02T00:00:00.000Z',
        },
      );
      final DisputeEvidence entity = DisputeMapper.evidenceToEntity(dto);

      expect(entity.id, 'ev-1');
      expect(entity.caseId, 'dispute-1');
      expect(entity.submittedBy, 'entity-filer');
      expect(entity.evidenceType, 'photo');
      expect(entity.title, 'Damaged goods photo');
      expect(entity.description, isNull);
      expect(entity.fileUrl, 'entity-filer/dispute-1/abc.jpg');
      expect(entity.fileMetadata['sizeBytes'], 2048);
      expect(entity.createdAt, DateTime.parse('2026-01-02T00:00:00.000Z'));
      expect(entity.hasAttachment, isTrue);
      expect(entity.isDescriptive, isFalse);
    });

    test('description-type evidence has no attachment and is descriptive', () {
      final DisputeEvidenceDto dto = DisputeEvidenceDto.fromJson(
        <String, dynamic>{
          'id': 'ev-2',
          'case_id': 'dispute-1',
          'submitted_by': 'entity-filer',
          'evidence_type': 'description',
          'title': 'Written account',
          'description': 'Full account of events.',
          'file_url': null,
          'file_metadata': <String, dynamic>{},
          'created_at': '2026-01-02T00:00:00.000Z',
        },
      );
      final DisputeEvidence entity = DisputeMapper.evidenceToEntity(dto);

      expect(entity.isDescriptive, isTrue);
      expect(entity.hasAttachment, isFalse);
    });

    test('missing file_metadata degrades to an empty map', () {
      final DisputeEvidenceDto dto = DisputeEvidenceDto.fromJson(
        <String, dynamic>{
          'id': 'ev-3',
          'case_id': 'dispute-1',
          'submitted_by': 'entity-filer',
          'evidence_type': 'document',
          'title': 'Delivery note',
          'file_url': 'entity-filer/dispute-1/note.pdf',
          'created_at': '2026-01-02T00:00:00.000Z',
        },
      );
      final DisputeEvidence entity = DisputeMapper.evidenceToEntity(dto);

      expect(entity.fileMetadata, isEmpty);
      expect(entity.hasAttachment, isTrue);
    });
  });

  group('DisputeResolutionDto.fromJson → DisputeMapper.resolutionToEntity', () {
    test('numeric amounts (JSON number/string) normalize to double', () {
      final DisputeResolutionDto dto = DisputeResolutionDto.fromJson(
        <String, dynamic>{
          'id': 'res-1',
          'case_id': 'dispute-1',
          'resolved_by': 'admin-1',
          'resolution_type': 'split',
          'reasoning': 'Evidence reviewed; the amount is split between the '
              'parties.',
          'payer_refund_amount': '25000.50',
          'payee_release_amount': 25000.50,
          'notes': null,
          'resolved_at': '2026-01-03T00:00:00.000Z',
          'created_at': '2026-01-03T00:00:00.000Z',
        },
      );
      final DisputeResolution entity = DisputeMapper.resolutionToEntity(dto);

      expect(entity.resolutionType, 'split');
      expect(entity.payerRefundAmount, closeTo(25000.50, 0.001));
      expect(entity.payeeReleaseAmount, closeTo(25000.50, 0.001));
      expect(entity.reasoning, contains('split'));
      expect(entity.resolvedAt, DateTime.parse('2026-01-03T00:00:00.000Z'));
    });

    test('missing numeric columns default to 0.0', () {
      final DisputeResolutionDto dto = DisputeResolutionDto.fromJson(
        <String, dynamic>{
          'id': 'res-2',
          'case_id': 'dispute-1',
          'resolution_type': 'dismissed',
          'reasoning': 'Not enough evidence was provided.',
          'resolved_at': '2026-01-03T00:00:00.000Z',
          'created_at': '2026-01-03T00:00:00.000Z',
        },
      );
      final DisputeResolution entity = DisputeMapper.resolutionToEntity(dto);

      expect(entity.payerRefundAmount, 0.0);
      expect(entity.payeeReleaseAmount, 0.0);
    });
  });

  group('Envelope mappers', () {
    test('caseDetailToEntity maps {case, evidence:[...], resolution} (FV-11)',
        () {
      final DisputeCaseDetailEnvelopeDto envelope =
          DisputeCaseDetailEnvelopeDto.fromJson(<String, dynamic>{
        'case': caseJson(),
        'evidence': <dynamic>[
          seedDisputeEvidenceDto(id: 'ev-1').toJsonHelper(),
        ],
        'resolution': <String, dynamic>{
          'id': 'res-1',
          'case_id': 'dispute-1',
          'resolution_type': 'release_to_payee',
          'reasoning': 'Released to the provider.',
          'payer_refund_amount': 0,
          'payee_release_amount': 50000,
          'resolved_at': '2026-01-03T00:00:00.000Z',
          'created_at': '2026-01-03T00:00:00.000Z',
        },
      });
      final DisputeCaseDetail detail =
          DisputeMapper.caseDetailToEntity(envelope);

      expect(detail.disputeCase.id, 'dispute-1');
      expect(detail.evidence, hasLength(1));
      expect(detail.evidence.single.id, 'ev-1');
      expect(detail.hasResolution, isTrue);
      expect(detail.resolution!.payeeReleaseAmount, 50000);
    });

    test('listEnvelopeToEntities maps the {disputes:[...]} envelope', () {
      final DisputeListEnvelopeDto envelope = DisputeListEnvelopeDto.fromJson(
        <String, dynamic>{
          'disputes': <dynamic>[
            caseJson(id: 'dispute-1', status: 'open'),
            caseJson(id: 'dispute-2', status: 'closed', closedAt: '2026-01-02T00:00:00.000Z'),
          ],
        },
      );
      final List<DisputeCase> entities =
          DisputeMapper.listEnvelopeToEntities(envelope);

      expect(entities, hasLength(2));
      expect(entities[0].isOpen, isTrue);
      expect(entities[1].status, 'closed');
    });

    test('empty evidence array maps to [] — never null (FV-11)', () {
      final DisputeCaseDetailEnvelopeDto envelope =
          DisputeCaseDetailEnvelopeDto.fromJson(<String, dynamic>{
        'case': caseJson(),
        'evidence': <dynamic>[],
        'resolution': null,
      });

      final DisputeCaseDetail detail =
          DisputeMapper.caseDetailToEntity(envelope);

      expect(detail.evidence, isEmpty);
      expect(detail.resolution, isNull);
      expect(detail.hasResolution, isFalse);
    });

    test('missing resolution key maps to null (FV-10)', () {
      final DisputeCaseDetailEnvelopeDto envelope =
          DisputeCaseDetailEnvelopeDto.fromJson(<String, dynamic>{
        'case': caseJson(),
        'evidence': <dynamic>[],
      });

      final DisputeCaseDetail detail =
          DisputeMapper.caseDetailToEntity(envelope);

      expect(detail.resolution, isNull);
    });

    test('missing evidence key degrades to an empty list', () {
      final DisputeCaseDetailEnvelopeDto envelope =
          DisputeCaseDetailEnvelopeDto.fromJson(<String, dynamic>{
        'case': caseJson(),
      });

      final DisputeCaseDetail detail =
          DisputeMapper.caseDetailToEntity(envelope);

      expect(detail.evidence, isEmpty);
    });
  });
}

extension on DisputeEvidenceDto {
  Map<String, dynamic> toJsonHelper() => <String, dynamic>{
        'id': id,
        'case_id': caseId,
        'submitted_by': submittedBy,
        'evidence_type': evidenceType,
        'title': title,
        'description': description,
        'file_url': fileUrl,
        'file_metadata': fileMetadata,
        'created_at': createdAt.toIso8601String(),
      };
}