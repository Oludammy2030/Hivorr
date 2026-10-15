import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/data/datasources/remote/supabase_dispute_remote_data_source.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/mappers/dispute_mapper.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/service_dispute_contract_summary_dto.dart';
import 'package:hivorr/data/models/service_dispute_detail_envelope_dto.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/repositories/dispute_repository_impl.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:hivorr/systems/support/services/service_dispute_notifier.dart';

import '../../../support/factories/mock_supabase_client_factory.dart';
import '../../../support/fakes/fake_service_contract.dart';
import '../../../support/fakes/support/fake_dispute_remote_data_source.dart';
import '../../../support/fakes/support/fake_dispute_repository.dart';

void main() {
  SupabaseDisputeRemoteDataSource build(
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
  ) => SupabaseDisputeRemoteDataSource(
    dio: Dio(),
    supabase: MockSupabaseClientFactory.create(rpcHandlers: rpcHandlers),
    exceptionMapper: const ApiExceptionMapper(),
  );

  Map<String, dynamic> ok(Object data) => <String, dynamic>{
    'success': true,
    'code': 'PLT000',
    'message': 'ok',
    'data': data,
  };

  Map<String, dynamic> fail(String code, String message) =>
      <String, dynamic>{
        'success': false,
        'code': code,
        'message': message,
        'data': <String, dynamic>{},
      };

  Map<String, dynamic> serviceCaseData({
    String id = 'dispute-service-1',
    String? escrowId,
    String? contractId = 'contract-1',
    String status = 'open',
  }) => <String, dynamic>{
    'id': id,
    'escrow_id': escrowId,
    'contract_id': contractId,
    'filer_entity_id': 'entity-filer',
    'counterparty_entity_id': 'entity-counterparty',
    'dispute_type': 'milestone_disagreement',
    'status': status,
    'reason': 'The milestone was marked complete without delivering scope.',
    'desired_outcome': 'refund_to_payer',
    'priority': 'high',
    'filed_at': '2026-02-01T00:00:00.000Z',
    'metadata': <String, dynamic>{'pre_dispute_status': 'active'},
  };

  Map<String, dynamic> contractJoin() => <String, dynamic>{
    'id': 'contract-1',
    'status': 'disputed',
    'escrow_id': 'escrow-9',
    'total_amount': 20000,
    'currency_code': 'NGN',
    'service_listing_id': 'listing-1',
    'listing_title': 'Fixture service offering',
  };

  group('DisputeCaseDto contract linkage (EP-03-17)', () {
    test('parses a nullable contract_id', () {
      final DisputeCaseDto dto = DisputeCaseDto.fromJson(
        serviceCaseData(),
      );
      expect(dto.contractId, 'contract-1');
      expect(dto.escrowId, '');
    });

    test('missing contract_id degrades to null (legacy rows)', () {
      final Map<String, dynamic> data = serviceCaseData()..remove('contract_id');
      final DisputeCaseDto dto = DisputeCaseDto.fromJson(data);
      expect(dto.contractId, isNull);
    });
  });

  group('DisputeMapper contract linkage (EP-03-17)', () {
    test('maps contract_id through to the entity', () {
      final DisputeCase entity = DisputeMapper.caseToEntity(
        DisputeCaseDto.fromJson(serviceCaseData()),
      );
      expect(entity.contractId, 'contract-1');
      expect(entity.hasContract, isTrue);
      expect(entity.hasEscrow, isFalse);
    });

    test('blank contract_id normalizes to null', () {
      final DisputeCase entity = DisputeMapper.caseToEntity(
        DisputeCaseDto.fromJson(serviceCaseData(contractId: '  ')),
      );
      expect(entity.contractId, isNull);
      expect(entity.hasContract, isFalse);
    });

    test('serviceDetailToEntity carries the contract summary', () {
      final ServiceDisputeDetailEnvelopeDto dto =
          ServiceDisputeDetailEnvelopeDto.fromJson(<String, dynamic>{
            'case': serviceCaseData(),
            'evidence': <dynamic>[],
            'resolution': null,
            'contract': contractJoin(),
          });
      final DisputeCaseDetail detail = DisputeMapper.serviceDetailToEntity(dto);
      expect(detail.hasContractSummary, isTrue);
      expect(detail.contractSummary!.id, 'contract-1');
      expect(detail.contractSummary!.isDisputed, isTrue);
      expect(detail.contractSummary!.isFunded, isTrue);
      expect(detail.contractSummary!.totalAmount, 20000);
    });

    test('serviceDetailToEntity tolerates a missing contract join', () {
      final ServiceDisputeDetailEnvelopeDto dto =
          ServiceDisputeDetailEnvelopeDto.fromJson(<String, dynamic>{
            'case': serviceCaseData(contractId: null),
            'evidence': <dynamic>[],
          });
      final DisputeCaseDetail detail = DisputeMapper.serviceDetailToEntity(dto);
      expect(detail.hasContractSummary, isFalse);
      expect(detail.disputeCase.hasContract, isFalse);
    });

    test('contract summary normalizes blank escrow to unfunded', () {
      const ServiceDisputeContractSummaryDto dto =
          ServiceDisputeContractSummaryDto(
            id: 'contract-2',
            status: 'disputed',
            escrowId: '  ',
            totalAmount: 5000,
            currencyCode: 'NGN',
            serviceListingId: 'listing-2',
          );
      final entity = dto.toEntity();
      expect(entity.escrowId, isNull);
      expect(entity.isFunded, isFalse);
    });
  });

  group('SupabaseDisputeRemoteDataSource service RPCs (EP-03-17)', () {
    test('fileServiceDispute calls service_dispute_file with p_contract_id',
        () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_file': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(serviceCaseData());
        },
      });

      final dto = await source.fileServiceDispute(
        contractId: 'contract-1',
        disputeType: 'milestone_disagreement',
        reason: 'The milestone was marked complete without delivering scope.',
        priority: 'high',
      );

      expect(seenParams, containsPair('p_contract_id', 'contract-1'));
      expect(
        seenParams,
        containsPair('p_dispute_type', 'milestone_disagreement'),
      );
      expect(dto.contractId, 'contract-1');
    });

    test('getServiceCase calls service_dispute_get and maps the join',
        () async {
      String? seenFn;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_get': (Map<String, dynamic> body) {
          seenFn = 'service_dispute_get';
          expect(body, containsPair('p_case_id', 'dispute-service-1'));
          return ok(<String, dynamic>{
            'case': serviceCaseData(),
            'evidence': <dynamic>[],
            'resolution': null,
            'contract': contractJoin(),
          });
        },
      });

      final dto = await source.getServiceCase('dispute-service-1');

      expect(seenFn, 'service_dispute_get');
      expect(dto.contract!.id, 'contract-1');
    });

    test('listDisputesForContract passes p_contract_id and p_status',
        () async {
      Map<String, dynamic>? seenParams;
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_list_for_contract': (Map<String, dynamic> body) {
          seenParams = body;
          return ok(<String, dynamic>{
            'disputes': <dynamic>[serviceCaseData()],
          });
        },
      });

      final dto = await source.listDisputesForContract(
        'contract-1',
        status: 'open',
      );

      expect(seenParams, containsPair('p_contract_id', 'contract-1'));
      expect(seenParams, containsPair('p_status', 'open'));
      expect(dto.disputes, hasLength(1));
    });

    test('service file maps PLT005 conflict to ApiExceptionKind.conflict',
        () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_file': (_) =>
            fail('PLT005', 'An active dispute already exists.'),
      });

      expect(
        () => source.fileServiceDispute(
          contractId: 'contract-1',
          disputeType: 'fraud',
          reason: 'A sufficiently long dispute reason for testing.',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.conflict,
          ),
        ),
      );
    });

    test('service get maps PLT004 to ApiExceptionKind.notFound', () async {
      final source = build(<String, Object? Function(Map<String, dynamic>)>{
        'service_dispute_get': (_) => fail('PLT004', 'Not found.'),
      });

      expect(
        () => source.getServiceCase('missing'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.kind,
            'kind',
            ApiExceptionKind.notFound,
          ),
        ),
      );
    });

    test('never exposes a dispute_resolve path', () {
      final source = build(null);
      expect(source, isA<SupabaseDisputeRemoteDataSource>());
      // Compile-time proof: the interface declares no resolve method, so any
      // dynamic resolve call fails. The static grep lens
      // (`dispute_resolve` absent from lib/) is the CI gate.
    });
  });

  group('DisputeRepositoryImpl service methods (EP-03-17)', () {
    test('fileServiceDispute rejects an empty contractId before the RPC',
        () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = DisputeRepositoryImpl(remote: remote);

      expect(
        () => repo.fileServiceDispute(
          contractId: '  ',
          disputeType: 'fraud',
          reason: 'A sufficiently long dispute reason for testing.',
        ),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT003',
          ),
        ),
      );
      expect(remote.fileServiceCallCount, 0);
    });

    test('fileServiceDispute rejects a short reason before the RPC', () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = DisputeRepositoryImpl(remote: remote);

      expect(
        () => repo.fileServiceDispute(
          contractId: 'contract-1',
          disputeType: 'fraud',
          reason: 'short',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(remote.fileServiceCallCount, 0);
    });

    test('fileServiceDispute re-reads the authoritative service case',
        () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = DisputeRepositoryImpl(remote: remote);
      remote.setDetail(
        seedDisputeDetailDto(
          caseDto: seedDisputeCaseDto(
            id: 'dispute-filed-1',
            escrowId: '',
            contractId: 'contract-1',
          ),
        ),
      );

      final DisputeCaseDetail detail = await repo.fileServiceDispute(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );

      expect(remote.fileServiceCallCount, 1);
      expect(remote.lastContractId, 'contract-1');
      expect(remote.getServiceCaseCallCount, 1);
      expect(detail.disputeCase.id, 'dispute-filed-1');
      expect(detail.disputeCase.contractId, 'contract-1');
    });

    test('listDisputesForContract rejects an invalid status before the RPC',
        () async {
      final remote = FakeDisputeRemoteDataSource();
      final repo = DisputeRepositoryImpl(remote: remote);

      expect(
        () => repo.listDisputesForContract('contract-1', status: 'bogus'),
        throwsA(isA<ApiException>()),
      );
      expect(remote.listForContractCallCount, 0);
    });

    test('listDisputesForContract maps the filtered rows', () async {
      final seeded = FakeDisputeRemoteDataSource();
      seeded.setList([
        seedDisputeCaseDto(
          id: 'd1',
          escrowId: '',
          contractId: 'contract-1',
          status: 'open',
        ),
        seedDisputeCaseDto(
          id: 'd2',
          escrowId: '',
          contractId: 'contract-2',
          status: 'open',
        ),
      ]);
      final seededRepo = DisputeRepositoryImpl(remote: seeded);

      final result = await seededRepo.listDisputesForContract('contract-1');

      expect(seeded.listForContractCallCount, 1);
      expect(seeded.lastContractId, 'contract-1');
      expect(result, hasLength(1));
      expect(result.single.id, 'd1');
    });
  });

  group('StoragePaths.serviceDisputeEvidence (EP-03-17)', () {
    test('builds an owner-prefixed dispute path', () {
      final String path = StoragePaths.serviceDisputeEvidence(
        entityId: 'entity-1',
        caseId: 'case-1',
        fileName: 'Evidence Photo.PNG',
      );
      expect(path.startsWith('entity-1/dispute/case-1/'), isTrue);
      expect(path.endsWith('.png'), isTrue);
    });

    test('rejects an empty case id', () {
      expect(
        () => StoragePaths.serviceDisputeEvidence(
          entityId: 'entity-1',
          caseId: '',
          fileName: 'a.png',
        ),
        throwsA(isA<Object>()),
      );
    });
  });

  group('DisputeProvider service methods (EP-03-17)', () {
    DisputeProvider buildProvider({FakeDisputeRepository? repo}) =>
        DisputeProvider(
          service: DisputeService(repository: repo ?? FakeDisputeRepository()),
        );

    test('fileForContract selects the filed case with its summary', () async {
      final repo = FakeDisputeRepository();
      final provider = buildProvider(repo: repo);

      final filed = await provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );

      expect(repo.fileServiceCallCount, 1);
      expect(repo.lastContractId, 'contract-1');
      expect(filed.contractId, 'contract-1');
      expect(provider.selected?.id, filed.id);
      expect(provider.isLoaded, isFalse);
      provider.dispose();
    });

    test('select loads the service read with contract summary', () async {
      final repo = FakeDisputeRepository();
      repo.setDetail(
        seedDisputeDetailEntity(
          id: 'dispute-9',
          status: 'open',
          contractId: 'contract-9',
        ),
      );
      final provider = buildProvider(repo: repo);
      await provider.select('dispute-9');

      expect(repo.getServiceCaseCallCount, 1);
      expect(provider.selected?.contractId, 'contract-9');
      expect(provider.loadState, DisputeLoadState.loaded);
      provider.dispose();
    });

    test('listForContract delegates without polluting the list scope',
        () async {
      final repo = FakeDisputeRepository(
        cases: <DisputeCase>[
          seedDisputeCaseEntity(
            id: 'd1',
            escrowId: '',
            contractId: 'contract-1',
          ),
          seedDisputeCaseEntity(id: 'd2', contractId: 'contract-2'),
        ],
      );
      final provider = buildProvider(repo: repo);

      final result = await provider.listForContract('contract-1');

      expect(repo.listForContractCallCount, 1);
      expect(result, hasLength(1));
      expect(provider.disputes, isEmpty);
      provider.dispose();
    });
  });

  group('DisputeProvider counterparty fan-out (EP-03-17 R2)', () {

    test('fileForContract notifies the counterparty once filed', () async {
      final notifier = _RecordingNotifier();
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
        counterpartyNotifier: notifier,
      );

      final filed = await provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifier.calls, hasLength(1));
      expect(notifier.calls.single.caseId, filed.id);
      expect(notifier.calls.single.event, 'filed');
      provider.dispose();
    });

    test('withdraw notifies the counterparty', () async {
      final notifier = _RecordingNotifier();
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
        counterpartyNotifier: notifier,
      );

      await provider.withdraw('dispute-1');
      await Future<void>.delayed(Duration.zero);

      expect(notifier.calls, hasLength(1));
      expect(notifier.calls.single.event, 'withdrawn');
      provider.dispose();
    });

    test('notifier failure never fails the dispute write', () async {
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
        counterpartyNotifier: _ThrowingNotifier(),
      );

      final filed = await provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(filed.contractId, 'contract-1');
      expect(provider.selected?.id, filed.id);
      provider.dispose();
    });

    test('absent notifier changes nothing', () async {
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
      );

      final filed = await provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );

      expect(filed.contractId, 'contract-1');
      provider.dispose();
    });

    test('fileForContract refreshes the linked engagement when wired',
        () async {
      final contracts = ServiceContractProvider(
        service: ContractService(
          repository: FakeServiceContractRepository(
            seed: [
              FakeServiceContractRepository.contract(
                id: 'contract-1',
                status: 'disputed',
              ),
            ],
          ),
        ),
      );
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
        contractProvider: contracts,
      );

      final filed = await provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(filed.contractId, 'contract-1');
      expect(contracts.selected?.id, 'contract-1');
      provider.dispose();
      contracts.dispose();
    });

    test('contract refresh failure never fails the dispute write', () async {
      final contracts = ServiceContractProvider(
        service: ContractService(
          repository: FakeServiceContractRepository(seed: const []),
        ),
      );
      final provider = DisputeProvider(
        service: DisputeService(repository: FakeDisputeRepository()),
        contractProvider: contracts,
      );

      final filed = await provider.fileForContract(
        contractId: 'contract-1',
        disputeType: 'service_quality',
        reason: 'The delivered work does not match the milestone scope.',
      );
      await Future<void>.delayed(Duration.zero);

      expect(filed.contractId, 'contract-1');
      expect(provider.selected?.id, filed.id);
      provider.dispose();
      contracts.dispose();
    });

    test('newly observed resolution notifies resolved', () async {
      final repo = FakeDisputeRepository();
      repo.setDetail(seedDisputeDetailEntity(id: 'dispute-r'));
      final notifier = _RecordingNotifier();
      final provider = DisputeProvider(
        service: DisputeService(repository: repo),
        counterpartyNotifier: notifier,
      );

      await provider.select('dispute-r');
      expect(notifier.calls, isEmpty);

      repo.setDetail(
        seedDisputeDetailEntity(
          id: 'dispute-r',
          resolution: seedDisputeResolutionEntity(),
        ),
      );
      await provider.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.calls, hasLength(1));
      expect(notifier.calls.single.event, 'resolved');
      provider.dispose();
    });

    test('first load of an already-resolved case does not notify', () async {
      final repo = FakeDisputeRepository();
      repo.setDetail(
        seedDisputeDetailEntity(
          id: 'dispute-r',
          resolution: seedDisputeResolutionEntity(),
        ),
      );
      final notifier = _RecordingNotifier();
      final provider = DisputeProvider(
        service: DisputeService(repository: repo),
        counterpartyNotifier: notifier,
      );

      await provider.select('dispute-r');
      await Future<void>.delayed(Duration.zero);

      expect(provider.resolution, isNotNull);
      expect(notifier.calls, isEmpty);
      provider.dispose();
    });
  });
}

class _NotifyCall {
  _NotifyCall(this.caseId, this.event);

  final String caseId;
  final String event;
}

class _RecordingNotifier implements ServiceDisputeNotifier {
  final List<_NotifyCall> calls = <_NotifyCall>[];

  @override
  Future<void> notifyCounterparty({
    required String caseId,
    required String event,
  }) async {
    calls.add(_NotifyCall(caseId, event));
  }
}

class _ThrowingNotifier implements ServiceDisputeNotifier {
  @override
  Future<void> notifyCounterparty({
    required String caseId,
    required String event,
  }) =>
      throw StateError('functions unavailable');
}
