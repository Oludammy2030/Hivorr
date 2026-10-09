import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/repositories/service_listing_repository_impl.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

import '../../support/fakes/fake_service_listing.dart';

void main() {
  group('ServiceListingService.validateProofSelection', () {
    test('accepts one to eight distinct ids', () {
      expect(ServiceListingService.validateProofSelection(['a']), isTrue);
      expect(
        ServiceListingService.validateProofSelection(
          ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
        ),
        isTrue,
      );
    });

    test('rejects empty, oversize, blank, and duplicate selections', () {
      expect(ServiceListingService.validateProofSelection([]), isFalse);
      expect(
        ServiceListingService.validateProofSelection(
          ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
        ),
        isFalse,
      );
      expect(ServiceListingService.validateProofSelection(['a', '']), isFalse);
      expect(
        ServiceListingService.validateProofSelection(['a', 'a']),
        isFalse,
      );
    });
  });

  group('ServiceListingService proof delegation', () {
    test('linkProofs delegates and returns the authoritative set', () async {
      final repo = FakeServiceListingRepository();
      final service = ServiceListingService(repository: repo);

      final proofs = await service.linkProofs(
        listingId: 'd1',
        portfolioItemIds: ['p1', 'p2'],
      );

      expect(repo.proofLinkCalls, 1);
      expect(proofs.map((p) => p.item.id), ['p1', 'p2']);
      expect(proofs.map((p) => p.linkSortOrder), [1, 2]);
    });

    test('unlinkProof delegates and returns the remaining set', () async {
      final repo = FakeServiceListingRepository(
        proofs: {
          'd1': [
            FakeServiceListingRepository.proof(id: 'p1', linkSortOrder: 1),
            FakeServiceListingRepository.proof(id: 'p2', linkSortOrder: 2),
          ],
        },
      );
      final service = ServiceListingService(repository: repo);

      final proofs = await service.unlinkProof(
        listingId: 'd1',
        portfolioItemId: 'p1',
      );

      expect(repo.proofUnlinkCalls, 1);
      expect(proofs.map((p) => p.item.id), ['p2']);
    });

    test('fetchProofs delegates to the repository', () async {
      final repo = FakeServiceListingRepository(
        proofs: {
          'd1': [FakeServiceListingRepository.proof(id: 'p1')],
        },
      );
      final service = ServiceListingService(repository: repo);

      final proofs = await service.fetchProofs('d1');

      expect(proofs.map((p) => p.item.id), ['p1']);
    });

    test('propagates server errors with codes intact', () async {
      final repo = FakeServiceListingRepository()
        ..proofError = const ApiException(
          kind: ApiExceptionKind.forbidden,
          message: 'You can only link your own portfolio items.',
          code: 'PLT001',
        );
      final service = ServiceListingService(repository: repo);

      await expectLater(
        service.linkProofs(listingId: 'd1', portfolioItemIds: ['p1']),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT001'),
        ),
      );
    });
  });

  group('ServiceListingRepositoryImpl proof fail-fast', () {
    test('rejects empty selection without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = ServiceListingRepositoryImpl(remote: remote);

      await expectLater(
        repo.linkPortfolioItems(listingId: 'd1', portfolioItemIds: []),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.linkProofCalls, 0);
    });

    test('rejects oversize selection without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = ServiceListingRepositoryImpl(remote: remote);

      await expectLater(
        repo.linkPortfolioItems(
          listingId: 'd1',
          portfolioItemIds: ['1', '2', '3', '4', '5', '6', '7', '8', '9'],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.linkProofCalls, 0);
    });

    test('rejects duplicates without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = ServiceListingRepositoryImpl(remote: remote);

      await expectLater(
        repo.linkPortfolioItems(
          listingId: 'd1',
          portfolioItemIds: ['p1', 'p1'],
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.linkProofCalls, 0);
    });

    test('rejects blank listing id without RPC', () async {
      final remote = FakeServiceListingRemoteDataSource();
      final repo = ServiceListingRepositoryImpl(remote: remote);

      await expectLater(
        repo.listPortfolioProofs('  '),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      expect(remote.listProofCalls, 0);
    });

    test('link re-reads the authoritative set in order', () async {
      final remote = FakeServiceListingRemoteDataSource(
        proofSeed: {
          'd1': [
            FakeServiceListingRemoteDataSource.proofRow(
              id: 'p1',
              linkSortOrder: 1,
            ),
            FakeServiceListingRemoteDataSource.proofRow(
              id: 'p2',
              linkSortOrder: 2,
            ),
          ],
        },
      );
      final repo = ServiceListingRepositoryImpl(remote: remote);

      final proofs = await repo.linkPortfolioItems(
        listingId: 'd1',
        portfolioItemIds: ['p2', 'p1'],
      );

      expect(remote.linkProofCalls, 1);
      expect(remote.listProofCalls, 1);
      expect(proofs.map((p) => p.item.id), ['p2', 'p1']);
      expect(proofs.map((p) => p.linkSortOrder), [1, 2]);
    });

    test('unlink re-reads the remaining set', () async {
      final remote = FakeServiceListingRemoteDataSource(
        proofSeed: {
          'd1': [
            FakeServiceListingRemoteDataSource.proofRow(
              id: 'p1',
              linkSortOrder: 1,
            ),
            FakeServiceListingRemoteDataSource.proofRow(
              id: 'p2',
              linkSortOrder: 2,
            ),
          ],
        },
      );
      final repo = ServiceListingRepositoryImpl(remote: remote);

      final proofs = await repo.unlinkPortfolioItem(
        listingId: 'd1',
        portfolioItemId: 'p1',
      );

      expect(remote.unlinkProofCalls, 1);
      expect(proofs.map((p) => p.item.id), ['p2']);
    });
  });
}
