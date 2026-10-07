import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/repositories/service_review_repository.dart';
import 'package:hivorr/data/repositories/service_review_repository_impl.dart';

import '../../support/fakes/fake_service_review.dart';

void main() {
  ServiceReviewRepository repository({
    FakeServiceReviewRemoteDataSource? remote,
  }) => ServiceReviewRepositoryImpl(
    remote: remote ?? FakeServiceReviewRemoteDataSource(),
  );

  group('ServiceReviewRepositoryImpl.submitReview fail-fast PLT003', () {
    test('rejects blank contract id', () async {
      await expectLater(
        repository().submitReview(contractId: '  ', rating: 5),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects out-of-range rating', () async {
      await expectLater(
        repository().submitReview(contractId: 'c1', rating: 0),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
      await expectLater(
        repository().submitReview(contractId: 'c1', rating: 6),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects short comment', () async {
      await expectLater(
        repository().submitReview(
          contractId: 'c1',
          rating: 5,
          comment: 'Too short',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });

    test('rejects bad limit on listing read', () async {
      await expectLater(
        repository().getForListing(
          listingId: 'listing-1',
          professionalEntityId: 'pro-1',
          professionId: 'profession-1',
          limit: 0,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT003'),
        ),
      );
    });
  });

  group('ServiceReviewRepositoryImpl blind flow', () {
    test('solo submit stays unrevealed; both submit reveals', () async {
      final FakeServiceReviewRemoteDataSource remote =
          FakeServiceReviewRemoteDataSource();
      final ServiceReviewRepository repo = repository(remote: remote);

      final ServiceReview first = await repo.submitReview(
        contractId: 'c1',
        rating: 5,
      );
      expect(first.isRevealed, isFalse);

      MyReviewStatus mine = await repo.getMyStatus('c1');
      expect(mine.youHaveSubmitted, isTrue);
      expect(mine.revealedReviews, isEmpty);

      remote.viewerId = 'pro-1';
      await repo.submitReview(contractId: 'c1', rating: 4);

      remote.viewerId = 'client-1';
      mine = await repo.getMyStatus('c1');
      expect(mine.revealedReviews.length, 2);
    });

    test('duplicate submit yields PLT005', () async {
      final ServiceReviewRepository repo = repository();
      await repo.submitReview(contractId: 'c1', rating: 5);
      await expectLater(
        repo.submitReview(contractId: 'c1', rating: 4),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PLT005'),
        ),
      );
    });

    test('foreign and unknown share PLT004 (no oracle)', () async {
      final ServiceReviewRepository repo = repository();
      Future<String?> codeFor(String id) async {
        try {
          await repo.getMyStatus(id);
          return null;
        } on ApiException catch (e) {
          return e.code;
        }
      }

      expect(await codeFor('foreign'), 'PLT004');
      expect(await codeFor('missing'), 'PLT004');
    });

    test('listing pagination has no overlap; unknown cursor is empty', () async {
      final FakeServiceReviewRemoteDataSource remote =
          FakeServiceReviewRemoteDataSource();
      final ServiceReviewRepository repo = repository(remote: remote);
      remote.viewerId = 'client-1';
      await repo.submitReview(contractId: 'c1', rating: 5);
      remote.viewerId = 'pro-1';
      await repo.submitReview(contractId: 'c1', rating: 5);
      remote.viewerId = 'client-1';
      await repo.submitReview(contractId: 'c2', rating: 4);
      remote.viewerId = 'pro-1';
      await repo.submitReview(contractId: 'c2', rating: 4);

      final ListingReviewsPage page1 = await repo.getForListing(
        listingId: 'listing-1',
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
        limit: 3,
      );
      expect(page1.reviews.length, 3);
      expect(page1.hasMore, isTrue);
      expect(page1.nextCursor, isNotNull);

      final ListingReviewsPage page2 = await repo.getForListing(
        listingId: 'listing-1',
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
        limit: 3,
        cursor: page1.nextCursor,
      );
      final Set<String> ids1 = page1.reviews.map((e) => e.id).toSet();
      for (final ServiceReview r in page2.reviews) {
        expect(ids1.contains(r.id), isFalse);
      }

      final ListingReviewsPage exhausted = await repo.getForListing(
        listingId: 'listing-1',
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
        cursor: 'unknown-cursor',
      );
      expect(exhausted.reviews, isEmpty);
    });
  });
}
