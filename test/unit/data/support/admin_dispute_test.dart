import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/admin_dispute_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_admin_dispute_remote_data_source.dart';
import 'package:hivorr/data/models/dispute_admin_list_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/models/service_dispute_detail_envelope_dto.dart';
import 'package:hivorr/data/providers/admin_dispute_provider.dart';
import 'package:hivorr/data/repositories/admin_dispute_repository.dart';
import 'package:hivorr/data/repositories/admin_dispute_repository_impl.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';

class _RecordingAdminRemote implements AdminDisputeRemoteDataSource {
  int listCalls = 0;
  int getCalls = 0;
  String? lastStatus;
  int? lastLimit;
  int? lastOffset;
  String? lastCaseId;

  Map<String, dynamic> row({
    String id = 'dispute-1',
    String status = 'open',
  }) => <String, dynamic>{
    'id': id,
    'escrow_id': 'escrow-1',
    'contract_id': 'contract-1',
    'filer_entity_id': 'entity-filer',
    'counterparty_entity_id': 'entity-counterparty',
    'dispute_type': 'service_quality',
    'status': status,
    'reason': 'Work did not match the agreed milestone description.',
    'desired_outcome': 'release_to_payee',
    'priority': 'medium',
    'filed_at': '2026-02-01T00:00:00.000Z',
    'metadata': <String, dynamic>{},
  };

  Map<String, dynamic> contractJoin() => <String, dynamic>{
    'id': 'contract-1',
    'status': 'disputed',
    'escrow_id': 'escrow-1',
    'total_amount': 20000,
    'currency_code': 'NGN',
    'service_listing_id': 'listing-1',
    'listing_title': 'Fixture service offering',
  };

  @override
  Future<DisputeAdminListEnvelopeDto> adminListDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls++;
    lastStatus = status;
    lastLimit = limit;
    lastOffset = offset;
    // Two scripted rows on the first page, one fresh row per follow-up page.
    final List<Map<String, dynamic>> items = offset == 0
        ? <Map<String, dynamic>>[row()]
        : <Map<String, dynamic>>[row(id: 'dispute-2')];
    return DisputeAdminListEnvelopeDto.fromJson(<String, dynamic>{
      'disputes': items,
      'total_count': 3,
    });
  }

  @override
  Future<ServiceDisputeDetailEnvelopeDto> adminGetCase(String caseId) async {
    getCalls++;
    lastCaseId = caseId;
    return ServiceDisputeDetailEnvelopeDto.fromJson(<String, dynamic>{
      'case': row(id: caseId),
      'evidence': <dynamic>[],
      'resolution': null,
      'contract': contractJoin(),
    });
  }
}

void main() {
  SupabaseAdminDisputeRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ) => SupabaseAdminDisputeRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(rpcHandlers: rpcHandlers),
    exceptionMapper: const ApiExceptionMapper(),
  );

  Map<String, dynamic> ok(Object? data) => <String, dynamic>{
    'success': true,
    'code': 'PLT000',
    'message': 'ok',
    'data': data,
  };

  Map<String, dynamic> adminRow({
    String id = 'dispute-1',
    String status = 'open',
  }) => <String, dynamic>{
    'id': id,
    'escrow_id': 'escrow-1',
    'contract_id': 'contract-1',
    'filer_entity_id': 'entity-filer',
    'counterparty_entity_id': 'entity-counterparty',
    'dispute_type': 'service_quality',
    'status': status,
    'reason': 'Work did not match the agreed milestone description.',
    'desired_outcome': 'release_to_payee',
    'priority': 'medium',
    'filed_at': '2026-02-01T00:00:00.000Z',
    'metadata': <String, dynamic>{},
    'contract_status': 'disputed',
    'contract_escrow_id': 'escrow-1',
    'contract_total': 20000,
    'contract_currency': 'NGN',
    'listing_title': 'Fixture service offering',
    'escrow_status': 'disputed',
  };

  group('DisputeAdminListEnvelopeDto (R3)', () {
    test('maps disputes plus the server total', () {
      final dto = DisputeAdminListEnvelopeDto.fromJson(<String, dynamic>{
        'disputes': <dynamic>[adminRow(), adminRow(id: 'dispute-2')],
        'total_count': 2,
      });
      expect(dto.disputes, hasLength(2));
      expect(dto.totalCount, 2);
    });

    test('missing envelope degrades to an empty page', () {
      final dto = DisputeAdminListEnvelopeDto.fromJson(<String, dynamic>{});
      expect(dto.disputes, isEmpty);
      expect(dto.totalCount, 0);
    });
  });

  group('SupabaseAdminDisputeRemoteDataSource (R3)', () {
    test('adminListDisputes calls the admin list RPC with paging', () async {
      Map<String, dynamic>? seen;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_admin_list': (Map<String, dynamic> body) {
          seen = body;
          return ok(<String, dynamic>{
            'disputes': <dynamic>[adminRow()],
            'total_count': 1,
          });
        },
      });

      final dto = await source.adminListDisputes(status: 'open');

      expect(seen, containsPair('p_status', 'open'));
      expect(seen, containsPair('p_limit', 50));
      expect(seen, containsPair('p_offset', 0));
      expect(dto.disputes, hasLength(1));
      expect(dto.totalCount, 1);
    });

    test('adminGetCase maps the joined detail envelope', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_admin_get': (Map<String, dynamic> body) {
          expect(body, containsPair('p_case_id', 'dispute-1'));
          return ok(<String, dynamic>{
            'case': adminRow(),
            'evidence': <dynamic>[],
            'resolution': null,
            'contract': <String, dynamic>{
              'id': 'contract-1',
              'status': 'disputed',
              'escrow_id': 'escrow-1',
              'total_amount': 20000,
              'currency_code': 'NGN',
              'service_listing_id': 'listing-1',
              'listing_title': 'Fixture service offering',
            },
          });
        },
      });

      final dto = await source.adminGetCase('dispute-1');

      expect(dto.caseDto.id, 'dispute-1');
      expect(dto.contract!.id, 'contract-1');
    });

    test('PLT002 forbidden surfaces for non-admin callers', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_admin_list': (_) => <String, dynamic>{
          'success': false,
          'code': 'PLT002',
          'message': 'Platform admin access required.',
          'data': <String, dynamic>{},
        },
      });

      expect(
        () => source.adminListDisputes(),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.forbidden,
          ),
        ),
      );
    });
  });

  group('AdminDisputeRepositoryImpl (R3)', () {
    test('rejects an invalid status before the RPC', () async {
      final repo = AdminDisputeRepositoryImpl(
        remote: _RecordingAdminRemote(),
      );
      expect(
        () => repo.listDisputes(status: 'bogus'),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects out-of-range paging before the RPC', () async {
      final repo = AdminDisputeRepositoryImpl(
        remote: _RecordingAdminRemote(),
      );
      expect(() => repo.listDisputes(limit: 0), throwsA(isA<ApiException>()));
      expect(
        () => repo.listDisputes(limit: 101),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.listDisputes(offset: -1),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps the admin page with its total', () async {
      final remote = _RecordingAdminRemote();
      final repo = AdminDisputeRepositoryImpl(remote: remote);

      final AdminDisputePage page = await repo.listDisputes(status: 'open');

      expect(remote.listCalls, 1);
      expect(page.items, hasLength(1));
      expect(page.totalCount, 3);
      expect(page.hasMore, isTrue);
    });

    test('getCase rejects a blank id before the RPC', () async {
      final repo = AdminDisputeRepositoryImpl(
        remote: _RecordingAdminRemote(),
      );
      expect(() => repo.getCase('  '), throwsA(isA<ApiException>()));
    });

    test('getCase maps the joined detail', () async {
      final repo = AdminDisputeRepositoryImpl(
        remote: _RecordingAdminRemote(),
      );

      final DisputeCaseDetail detail = await repo.getCase('dispute-1');

      expect(detail.disputeCase.id, 'dispute-1');
      expect(detail.hasContractSummary, isTrue);
    });
  });

  group('AdminDisputeProvider (R3)', () {
    test('loadQueue populates rows plus the server total', () async {
      final provider = AdminDisputeProvider(
        repository: AdminDisputeRepositoryImpl(
          remote: _RecordingAdminRemote(),
        ),
      );

      await provider.loadQueue();

      expect(provider.loadState, AdminDisputeLoadState.loaded);
      expect(provider.queue, hasLength(1));
      expect(provider.totalCount, 3);
      expect(provider.hasMore, isTrue);
      provider.dispose();
    });

    test('loadMore appends the next page', () async {
      final provider = AdminDisputeProvider(
        repository: AdminDisputeRepositoryImpl(
          remote: _RecordingAdminRemote(),
        ),
      );

      await provider.loadQueue();
      await provider.loadMore();

      expect(provider.queue, hasLength(2));
      provider.dispose();
    });

    test('select loads the joined detail', () async {
      final provider = AdminDisputeProvider(
        repository: AdminDisputeRepositoryImpl(
          remote: _RecordingAdminRemote(),
        ),
      );

      await provider.select('dispute-1');

      expect(provider.selected?.id, 'dispute-1');
      expect(provider.contractSummary?.id, 'contract-1');
      provider.dispose();
    });
  });
}
