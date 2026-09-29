import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/jobs_envelope_parser.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/mappers/hire_mapper.dart';
import 'package:hivorr/data/mappers/job_mapper.dart';
import 'package:hivorr/data/models/hire_dto.dart';
import 'package:hivorr/data/models/hire_envelopes_dto.dart';
import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/models/job_envelopes_dto.dart';
import 'package:hivorr/data/models/job_quotation_dto.dart';

void main() {
  group('JobsEnvelopeParser', () {
    test('unwraps the data object on PLT000', () {
      final Map<String, dynamic> data = JobsEnvelopeParser.unwrap(
        <String, dynamic>{
          'success': true,
          'code': 'PLT000',
          'message': 'Jobs retrieved.',
          'data': <String, dynamic>{'items': <dynamic>[], 'has_more': false},
        },
      );
      expect(data['has_more'], isFalse);
    });

    test('maps PLT codes to ApiException kinds', () {
      const Map<String, ApiExceptionKind> cases = <String, ApiExceptionKind>{
        'PLT001': ApiExceptionKind.auth,
        'PLT002': ApiExceptionKind.forbidden,
        'PLT003': ApiExceptionKind.validation,
        'PLT004': ApiExceptionKind.notFound,
        'PLT005': ApiExceptionKind.conflict,
        'PLT999': ApiExceptionKind.server,
      };
      for (final MapEntry<String, ApiExceptionKind> entry in cases.entries) {
        expect(
          () => JobsEnvelopeParser.unwrap(<String, dynamic>{
            'success': false,
            'code': entry.key,
            'message': 'Nope.',
            'data': null,
          }),
          throwsA(
            isA<ApiException>()
                .having((ApiException e) => e.kind, 'kind', entry.value)
                .having((ApiException e) => e.code, 'code', entry.key),
          ),
        );
      }
    });

    test('malformed envelope throws server', () {
      expect(
        () => JobsEnvelopeParser.unwrap(<String, dynamic>{
          'success': true,
          'code': 'PLT000',
          'message': 'ok',
          'data': <dynamic>[],
        }),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.server,
          ),
        ),
      );
    });
  });

  group('Job DTO + mapper', () {
    Map<String, dynamic> jobJson() => <String, dynamic>{
      'id': 'job-1',
      'client_entity_id': 'client-1',
      'profession_id': null,
      'industry_id': null,
      'title': 'Fix my sink',
      'description': 'Kitchen sink blocked.',
      'budget_min': 5000,
      'budget_max': 15000.5,
      'currency_code': 'NGN',
      'location': 'Lagos',
      'status': 'open',
      'applications_count': 3,
      'awarded_application_id': null,
      'posted_at': '2026-09-01T10:00:00Z',
      'created_at': '2026-09-01T09:00:00Z',
      'updated_at': '2026-09-01T09:00:00Z',
    };

    test('parses numerics and dates, maps to entity', () {
      final Job job = JobMapper.jobToEntity(JobDto.fromJson(jobJson()));
      expect(job.id, 'job-1');
      expect(job.budgetMin, 5000.0);
      expect(job.budgetMax, 15000.5);
      expect(job.applicationsCount, 3);
      expect(job.isOpen, isTrue);
      expect(job.isEditable, isTrue);
      expect(job.postedAt?.year, 2026);
    });

    test('entity status helpers', () {
      Job jobWith(String status) => Job(
        id: 'j',
        clientEntityId: 'c',
        title: 't',
        description: 'd',
        currencyCode: 'NGN',
        status: status,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(jobWith('draft').isEditable, isTrue);
      expect(jobWith('awarded').isAwarded, isTrue);
      expect(jobWith('completed').isTerminal, isTrue);
      expect(jobWith('open').isOpen, isTrue);
    });

    test('application DTO maps with denormalized job fields', () {
      final JobApplication app = JobMapper.applicationToEntity(
        JobApplicationDto.fromJson(<String, dynamic>{
          'id': 'app-1',
          'job_id': 'job-1',
          'professional_entity_id': 'pro-1',
          'client_entity_id': 'client-1',
          'cover_note': 'I can do this work well.',
          'quoted_amount': '12000',
          'currency_code': 'NGN',
          'duration_days': 3,
          'status': 'shortlisted',
          'submitted_at': '2026-09-02T10:00:00Z',
          'created_at': '2026-09-02T10:00:00Z',
          'updated_at': '2026-09-02T10:00:00Z',
          'job_title': 'Fix my sink',
          'job_status': 'open',
        }),
      );
      expect(app.quotedAmount, 12000.0);
      expect(app.durationDays, 3);
      expect(app.isActive, isTrue);
      expect(app.isWithdrawable, isTrue);
      expect(app.jobTitle, 'Fix my sink');
    });

    test('job list envelope degrades missing items to empty', () {
      final JobListEnvelopeDto envelope = JobListEnvelopeDto.fromJson(
        <String, dynamic>{'has_more': false},
      );
      expect(envelope.jobs, isEmpty);
      expect(envelope.hasMore, isFalse);
    });

    test('job detail envelope maps applications + events', () {
      final JobDetailEnvelopeDto envelope = JobDetailEnvelopeDto.fromJson(
        <String, dynamic>{
          'job': jobJson(),
          'applications': <dynamic>[],
          'my_application': null,
          'events': <dynamic>[
            <String, dynamic>{'event_type': 'published'},
          ],
        },
      );
      expect(envelope.job.id, 'job-1');
      expect(envelope.applications, isEmpty);
      expect(envelope.myApplication, isNull);
      expect(envelope.events.single['event_type'], 'published');
    });
  });

  group('Hire DTO + mapper', () {
    test('quotation maps revision + live state', () {
      final JobQuotation quote = HireMapper.quotationToEntity(
        JobQuotationDto.fromJson(<String, dynamic>{
          'id': 'q-1',
          'application_id': 'app-1',
          'proposed_by': 'pro-1',
          'proposed_amount': 36000,
          'currency_code': 'NGN',
          'revision_number': 2,
          'status': 'proposed',
          'created_at': '2026-09-03T10:00:00Z',
          'updated_at': '2026-09-03T10:00:00Z',
        }),
      );
      expect(quote.proposedAmount, 36000.0);
      expect(quote.revisionNumber, 2);
      expect(quote.isLive, isTrue);
      expect(quote.isHirable, isTrue);
    });

    test('hire live status prefers the contract-derived value', () {
      final Hire hire = HireMapper.hireToEntity(
        HireDto.fromJson(<String, dynamic>{
          'id': 'h-1',
          'job_id': 'job-1',
          'application_id': 'app-1',
          'client_entity_id': 'client-1',
          'professional_entity_id': 'pro-1',
          'contract_id': 'c-1',
          'status': 'pending',
          'hired_at': '2026-09-04T10:00:00Z',
          'effective_status': 'active',
          'job_title': 'Fix my sink',
        }),
      );
      expect(hire.liveStatus, 'active');
      expect(hire.isActive, isTrue);
      expect(hire.jobTitle, 'Fix my sink');
    });

    test('hire accept envelope carries the contract id', () {
      final HireAcceptEnvelopeDto envelope = HireAcceptEnvelopeDto.fromJson(
        <String, dynamic>{
          'hire': <String, dynamic>{
            'id': 'h-1',
            'job_id': 'job-1',
            'application_id': 'app-1',
            'client_entity_id': 'client-1',
            'professional_entity_id': 'pro-1',
            'contract_id': 'c-1',
            'status': 'pending',
            'hired_at': '2026-09-04T10:00:00Z',
          },
          'contract_id': 'c-1',
        },
      );
      expect(envelope.contractId, 'c-1');
      expect(envelope.hire.id, 'h-1');
    });
  });
}
