import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:hivorr/data/repositories/service_contract_repository_impl.dart';

import '../../support/fakes/fake_service_contract.dart';

void main() {
  ServiceContractRepository repository({
    List<Map<String, dynamic>>? seed,
  }) => ServiceContractRepositoryImpl(
    remote: FakeServiceContractRemoteDataSource(seed: seed),
  );

  ContractMilestoneInput milestone({
    required int number,
    String title = 'Work package',
    double amount = 10000,
  }) => ContractMilestoneInput(
    milestoneNumber: number,
    title: title,
    amount: amount,
  );

  group('ServiceContractRepositoryImpl.offerContract fail-fast PLT003', () {
    test('rejects empty milestones', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 30000,
          milestones: [],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects empty milestone title', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 10000,
          milestones: [milestone(number: 1, title: '  ')],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects long description', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 10000,
          milestones: [
            ContractMilestoneInput(
              milestoneNumber: 1,
              title: 'Work package',
              description: 'a' * 2001,
              amount: 10000,
            ),
          ],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects zero milestone amount', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 0,
          milestones: [milestone(number: 1, amount: 0)],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects sum != total', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 30000,
          milestones: [
            milestone(number: 1, amount: 10000),
            milestone(number: 2, amount: 10000),
          ],
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'PLT003')
              .having(
                (e) => e.message,
                'message',
                contains('sum to total'),
              ),
        ),
      );
    });

    test('rejects bad currency and past expiry', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 10000,
          currencyCode: 'EUR',
          milestones: [milestone(number: 1)],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 10000,
          milestones: [milestone(number: 1)],
          offerExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects duplicate and non-contiguous numbering with PLT005', () async {
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 20000,
          milestones: [
            milestone(number: 1),
            milestone(number: 1),
          ],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT005'),
        ),
      );
      await expectLater(
        repository().offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 20000,
          milestones: [
            milestone(number: 1),
            milestone(number: 3, amount: 10000),
          ],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT005'),
        ),
      );
    });
  });

  group('ServiceContractRepositoryImpl read/write seam', () {
    test('offer re-reads authoritative row via get', () async {
      final repo = repository();
      final ServiceContract created = await repo.offerContract(
        serviceListingId: 'listing-1',
        totalAmount: 30000,
        milestones: [
          milestone(number: 1, title: 'Inspection visit'),
          milestone(number: 2, title: 'Repair works'),
          milestone(number: 3, title: 'Testing and handover'),
        ],
      );
      expect(created.status, 'offered');
      expect(created.milestones, hasLength(3));
      expect(created.events, isNotEmpty);
    });

    test('listMine validates status and limit', () async {
      final repo = repository(
        seed: [contractDetailRow(id: 'c1', status: 'offered')],
      );
      await expectLater(
        repo.listMine(status: 'bogus'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      await expectLater(
        repo.listMine(limit: 0),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      final page = await repo.listMine(status: 'offered');
      expect(page.items, hasLength(1));
      expect(page.hasMore, isFalse);
    });

    test('verifyMilestone rejects unknown action', () async {
      final repo = repository(
        seed: [contractDetailRow(id: 'c1')],
      );
      await expectLater(
        repo.verifyMilestone(
          contractId: 'c1',
          milestoneId: 'm1',
          action: 'bogus',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });
  });
}
