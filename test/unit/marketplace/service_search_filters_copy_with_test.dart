import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/service_listing.dart';

void main() {
  group('ServiceSearchFilters.copyWith', () {
    test('omitted fields keep their values', () {
      const ServiceSearchFilters filters = ServiceSearchFilters(
        industryId: 'ind-1',
        professionId: 'prof-9',
        priceMin: 1000,
        currencyCode: 'NGN',
        ratingMin: 4.0,
      );

      final ServiceSearchFilters updated = filters.copyWith(priceMax: 5000);

      expect(updated.industryId, 'ind-1');
      expect(updated.professionId, 'prof-9');
      expect(updated.priceMin, 1000);
      expect(updated.priceMax, 5000);
      expect(updated.currencyCode, 'NGN');
      expect(updated.ratingMin, 4.0);
    });

    test('explicit null clears that dimension only', () {
      const ServiceSearchFilters filters = ServiceSearchFilters(
        industryId: 'ind-1',
        professionId: 'prof-9',
        priceMin: 1000,
        priceMax: 5000,
      );

      final ServiceSearchFilters updated = filters.copyWith(
        industryId: null,
        professionId: null,
      );

      expect(updated.industryId, isNull);
      expect(updated.professionId, isNull);
      expect(updated.priceMin, 1000);
      expect(updated.priceMax, 5000);
      expect(
        updated.toJson(),
        <String, dynamic>{'price_min': 1000, 'price_max': 5000},
      );
    });

    test('empty copy stays empty', () {
      const ServiceSearchFilters filters = ServiceSearchFilters();

      expect(filters.copyWith().isEmpty, isTrue);
      expect(filters.copyWith().toJson(), isEmpty);
    });
  });
}
