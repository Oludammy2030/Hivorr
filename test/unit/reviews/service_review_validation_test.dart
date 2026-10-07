import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';

ServiceContract contract({String status = 'active'}) => ServiceContract(
  id: 'c1',
  serviceListingId: 'listing-1',
  clientEntityId: 'client-1',
  professionalEntityId: 'pro-1',
  status: status,
  totalAmount: 30000,
  currencyCode: 'NGN',
);

MyReviewStatus status({bool submitted = false}) => MyReviewStatus(
  contractId: 'c1',
  youHaveSubmitted: submitted,
  reviewCount: 0,
);

void main() {
  group('ServiceReviewService.validateRating', () {
    test('accepts 1-5 only', () {
      expect(ServiceReviewService.validateRating(1), isTrue);
      expect(ServiceReviewService.validateRating(5), isTrue);
      expect(ServiceReviewService.validateRating(0), isFalse);
      expect(ServiceReviewService.validateRating(6), isFalse);
      expect(ServiceReviewService.validateRating(null), isFalse);
    });
  });

  group('ServiceReviewService.validateComment', () {
    test('star-only is valid; otherwise 10-2000', () {
      expect(ServiceReviewService.validateComment(null), isTrue);
      expect(ServiceReviewService.validateComment(''), isTrue);
      expect(ServiceReviewService.validateComment('   '), isTrue);
      expect(
        ServiceReviewService.validateComment('a' * 9),
        isFalse,
      );
      expect(
        ServiceReviewService.validateComment('a' * 10),
        isTrue,
      );
      expect(
        ServiceReviewService.validateComment('a' * 2000),
        isTrue,
      );
      expect(
        ServiceReviewService.validateComment('a' * 2001),
        isFalse,
      );
    });
  });

  group('ServiceReviewService.validateContractId', () {
    test('requires non-blank', () {
      expect(ServiceReviewService.validateContractId('c1'), isTrue);
      expect(ServiceReviewService.validateContractId(''), isFalse);
      expect(ServiceReviewService.validateContractId('  '), isFalse);
      expect(ServiceReviewService.validateContractId(null), isFalse);
    });
  });

  group('ServiceReviewService.canReview', () {
    test('participant on reviewable contract without submission', () {
      expect(
        ServiceReviewService.canReview(
          contract: contract(status: 'active'),
          viewerEntityId: 'client-1',
          status: status(submitted: false),
        ),
        isTrue,
      );
      expect(
        ServiceReviewService.canReview(
          contract: contract(status: 'closed'),
          viewerEntityId: 'pro-1',
        ),
        isTrue,
      );
    });

    test('hides for non-participant, unreviewable, or submitted', () {
      expect(
        ServiceReviewService.canReview(
          contract: contract(status: 'active'),
          viewerEntityId: 'stranger',
        ),
        isFalse,
      );
      expect(
        ServiceReviewService.canReview(
          contract: contract(status: 'offered'),
          viewerEntityId: 'client-1',
        ),
        isFalse,
      );
      expect(
        ServiceReviewService.canReview(
          contract: contract(status: 'active'),
          viewerEntityId: 'client-1',
          status: status(submitted: true),
        ),
        isFalse,
      );
      expect(
        ServiceReviewService.canReview(
          contract: null,
          viewerEntityId: 'client-1',
        ),
        isFalse,
      );
    });
  });

  group('ReviewAggregate.shareFor', () {
    test('zero when empty; fraction otherwise', () {
      const ReviewAggregate empty = ReviewAggregate(
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
        avgRating: 0,
        reviewCount: 0,
        distribution: <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.shareFor(5), 0);
      const ReviewAggregate agg = ReviewAggregate(
        professionalEntityId: 'pro-1',
        professionId: 'profession-1',
        avgRating: 4.5,
        reviewCount: 2,
        distribution: <int, int>{1: 0, 2: 0, 3: 0, 4: 1, 5: 1},
      );
      expect(agg.isNotEmpty, isTrue);
      expect(agg.shareFor(5), 0.5);
    });
  });
}
