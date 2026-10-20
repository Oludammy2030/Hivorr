// Run: flutter test test/integration/marketplace/contract_lifecycle_integration_test.dart
//
// EP-03-20 VP5 — Contract lifecycle entry: offer → accept (→ escrow linkage
// is VP6). Composes the REAL ContractService with FakeServiceContractRepository
// (entity seam). Negatives: malformed milestone sum is caught by the client
// fail-fast validator (PLT003 guard); stranger/unknown contract reads surface
// the server PLT004 oracle. Self-offer PLT005 is server-enforced only (no
// client oracle — recorded in the verification report).

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';

import '../../support/fakes/fake_service_contract.dart';

void main() {
  group('EP-03-20 VP5 — contract offer→accept lifecycle', () {
    late FakeServiceContractRepository repo;
    late ContractService service;

    setUp(() {
      repo = FakeServiceContractRepository();
      service = ContractService(repository: repo);
    });

    test(
      'DoD-VP5a: offer creates a contract with the submitted milestones',
      () async {
        // Act: offer a two-milestone contract whose amounts sum to the total.
        final ServiceContract offered = await service.offerContract(
          serviceListingId: 'listing-1',
          totalAmount: 15000,
          currencyCode: 'NGN',
          milestones: const <ContractMilestoneInput>[
            ContractMilestoneInput(
              milestoneNumber: 1,
              title: 'Phase 1',
              amount: 5000,
            ),
            ContractMilestoneInput(
              milestoneNumber: 2,
              title: 'Phase 2',
              amount: 10000,
            ),
          ],
        );

        // Assert: the offer recorded the structure verbatim and started
        // `offered` (amounts/positions pass through without client mutation).
        expect(offered.id, isNotEmpty);
        expect(offered.status, 'offered');
        expect(offered.milestones.length, 2);
        expect(offered.milestones.first.title, 'Phase 1');
        expect(offered.milestones.first.amount, 5000);
        expect(offered.milestones.last.title, 'Phase 2');
        expect(offered.milestones.last.amount, 10000);
        expect(offered.totalAmount, 15000);
        expect(repo.offerCalls, 1);
      },
    );

    test('DoD-VP5b: accept transitions offered → active', () async {
      // Arrange: seed an offered contract.
      final ServiceContract seed = FakeServiceContractRepository.contract(
        id: 'c1',
        status: 'offered',
      );
      repo = FakeServiceContractRepository(seed: <ServiceContract>[seed]);
      service = ContractService(repository: repo);

      // Act: the counterparty accepts.
      final ServiceContract accepted = await service.acceptContract('c1');

      // Assert: the contract is now active.
      expect(accepted.status, 'active');
      expect(repo.acceptCalls, 1);
    });

    test(
      'DoD-VP5c: malformed milestone sum is caught by the fail-fast guard',
      () {
        // A sum that does not match the total is a PLT003-class server error;
        // the client validator refuses it before any network call.
        expect(
          ContractService.validateMilestoneSums(
            totalAmount: 30000,
            milestoneAmounts: const <double>[10000, 5000],
          ),
          isFalse,
        );
        // An empty milestone list is never valid.
        expect(
          ContractService.validateMilestoneSums(
            totalAmount: 30000,
            milestoneAmounts: const <double>[],
          ),
          isFalse,
        );
        // A correct sum passes (within the 0.01 server tolerance).
        expect(
          ContractService.validateMilestoneSums(
            totalAmount: 30000,
            milestoneAmounts: const <double>[10000, 10000, 10000],
          ),
          isTrue,
        );
      },
    );

    test('DoD-VP5d: stranger/unknown contract read surfaces PLT004', () async {
      // Arrange: the server returns the not-found oracle for a foreign id.
      repo = FakeServiceContractRepository()
        ..getContractError = const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Contract not found.',
          code: 'PLT004',
        );
      service = ContractService(repository: repo);

      // Act & Assert: the typed PLT004 propagates (no oracle leak).
      await expectLater(
        service.getContract('c1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            'PLT004',
          ),
        ),
      );
    });

    test(
      'DoD-VP5e: listMine status filter round-trips to the repository',
      () async {
        // Arrange: one active + one offered contract.
        repo = FakeServiceContractRepository(
          seed: <ServiceContract>[
            FakeServiceContractRepository.contract(id: 'c1', status: 'active'),
            FakeServiceContractRepository.contract(id: 'c2', status: 'offered'),
          ],
        );
        service = ContractService(repository: repo);

        // Act: list only active contracts.
        final ServiceContractPage page = await service.listMine(
          status: 'active',
        );

        // Assert: the filter reached the repo and only active rows returned.
        expect(repo.lastStatus, 'active');
        expect(page.items.length, 1);
        expect(page.items.first.status, 'active');
      },
    );
  });
}
