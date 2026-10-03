import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_listing.dart';

void main() {
  group('ServiceSearchFilters → p_filters (EP-03-09)', () {
    test('empty filters serialize to an empty object', () {
      const ServiceSearchFilters filters = ServiceSearchFilters();
      expect(filters.isEmpty, isTrue);
      expect(filters.toJson(), isEmpty);
    });

    test('profession + industry compose their uuid keys', () {
      const ServiceSearchFilters filters = ServiceSearchFilters(
        professionId: 'prof-9',
        industryId: 'ind-1',
      );
      expect(filters.isEmpty, isFalse);
      expect(
        filters.toJson(),
        <String, dynamic>{
          'profession_id': 'prof-9',
          'industry_id': 'ind-1',
        },
      );
    });

    test('price range + currency compose numeric and code keys', () {
      const ServiceSearchFilters filters = ServiceSearchFilters(
        priceMin: 1000,
        priceMax: 5000,
        currencyCode: 'NGN',
      );
      expect(
        filters.toJson(),
        <String, dynamic>{
          'price_min': 1000,
          'price_max': 5000,
          'currency_code': 'NGN',
        },
      );
    });

    test('rating floor composes the rating key', () {
      const ServiceSearchFilters filters = ServiceSearchFilters(
        ratingMin: 4.5,
      );
      expect(filters.toJson(), <String, dynamic>{'rating_min': 4.5});
    });

    test('verified-only uses the canonical is_trade_verified_only key', () {
      const ServiceSearchFilters filters = ServiceSearchFilters(
        isTradeVerifiedOnly: true,
      );
      expect(
        filters.toJson(),
        <String, dynamic>{'is_trade_verified_only': true},
      );
    });

    test('availability date serializes as ISO8601', () {
      final ServiceSearchFilters filters = ServiceSearchFilters(
        availabilityDate: DateTime.utc(2026, 10, 4, 9),
      );
      expect(
        filters.toJson(),
        <String, dynamic>{
          'availability_date': '2026-10-04T09:00:00.000Z',
        },
      );
    });

    test('cursor round-trips score + id', () {
      const ServiceListingCursor cursor = ServiceListingCursor(
        score: 0.812345,
        id: 'listing-1',
      );
      final ServiceListingCursor revived = ServiceListingCursor.fromJson(
        cursor.toJson(),
      );
      expect(revived.score, 0.812345);
      expect(revived.id, 'listing-1');
    });
  });
}
