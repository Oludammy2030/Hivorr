import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/mappers/review_mapper.dart';
import 'package:hivorr/data/models/service_review_dto.dart';

Map<String, dynamic> row({
  String id = 'r1',
  int rating = 5,
  bool revealed = false,
}) => <String, dynamic>{
  'id': id,
  'contract_id': 'c1',
  'service_listing_id': 'listing-1',
  'reviewer_entity_id': 'client-1',
  'reviewee_entity_id': 'pro-1',
  'profession_id': 'profession-1',
  'rating': rating,
  'comment': 'Excellent delivery and communication',
  'is_revealed': revealed,
  'revealed_at': revealed ? '2026-09-26T12:00:00.000Z' : null,
  'created_at': '2026-09-26T10:00:00.000Z',
};

void main() {
  group('ReviewMapper.reviewToEntity', () {
    test('maps fields verbatim including blindness', () {
      final ServiceReview entity = ReviewMapper.reviewToEntity(
        ServiceReviewDto.fromJson(row()),
      );
      expect(entity.id, 'r1');
      expect(entity.rating, 5);
      expect(entity.hasComment, isTrue);
      expect(entity.isRevealed, isFalse);
      expect(entity.revealedAt, isNull);
    });

    test('star-only maps null comment', () {
      final Map<String, dynamic> json = row()..['comment'] = null;
      final ServiceReview entity = ReviewMapper.reviewToEntity(
        ServiceReviewDto.fromJson(json),
      );
      expect(entity.hasComment, isFalse);
    });
  });

  group('ReviewMapper.myStatusEnvelopeToEntity', () {
    test('preserves server order and submitted flag', () {
      final dto = MyReviewStatusEnvelopeDto.fromJson(<String, dynamic>{
        'you_have_submitted': true,
        'your_review': row(id: 'r1'),
        'revealed_reviews': <Map<String, dynamic>>[],
        'review_count': 0,
      });
      final MyReviewStatus status = ReviewMapper.myStatusEnvelopeToEntity(
        dto,
        'c1',
      );
      expect(status.contractId, 'c1');
      expect(status.youHaveSubmitted, isTrue);
      expect(status.yourReview?.id, 'r1');
      expect(status.isRevealed, isFalse);
    });

    test('revealed rows map verbatim', () {
      final dto = MyReviewStatusEnvelopeDto.fromJson(<String, dynamic>{
        'you_have_submitted': true,
        'your_review': row(id: 'r1', revealed: true),
        'revealed_reviews': <Map<String, dynamic>>[
          row(id: 'r1', revealed: true),
          row(id: 'r2', rating: 4, revealed: true),
        ],
        'review_count': 2,
      });
      final MyReviewStatus status = ReviewMapper.myStatusEnvelopeToEntity(
        dto,
        'c1',
      );
      expect(status.revealedReviews.map((e) => e.id), ['r1', 'r2']);
      expect(status.isRevealed, isTrue);
    });
  });

  group('ReviewMapper.listingEnvelopeToPage', () {
    test('null aggregate when empty; header otherwise', () {
      final empty = ListingReviewsEnvelopeDto.fromJson(<String, dynamic>{
        'reviews': <Map<String, dynamic>>[],
        'avg_rating': 0,
        'review_count': 0,
        'distribution': <String, int>{
          '1': 0,
          '2': 0,
          '3': 0,
          '4': 0,
          '5': 0,
        },
        'has_more': false,
        'next_cursor': null,
      });
      final ListingReviewsPage emptyPage = ReviewMapper.listingEnvelopeToPage(
        empty,
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
      );
      expect(emptyPage.isEmpty, isTrue);
      expect(emptyPage.aggregate, isNull);

      final full = ListingReviewsEnvelopeDto.fromJson(<String, dynamic>{
        'reviews': <Map<String, dynamic>>[
          row(id: 'r1', revealed: true),
        ],
        'avg_rating': 5,
        'review_count': 1,
        'distribution': <String, int>{
          '1': 0,
          '2': 0,
          '3': 0,
          '4': 0,
          '5': 1,
        },
        'has_more': false,
        'next_cursor': null,
      });
      final ListingReviewsPage page = ReviewMapper.listingEnvelopeToPage(
        full,
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
      );
      expect(page.isNotEmpty, isTrue);
      expect(page.aggregate?.avgRating, 5);
      expect(page.aggregate?.distribution[5], 1);
    });
  });
}
