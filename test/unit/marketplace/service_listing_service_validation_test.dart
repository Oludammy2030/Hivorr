import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

void main() {
  group('ServiceListingService.validateTitle', () {
    test('accepts 10–120 chars after trim', () {
      expect(ServiceListingService.validateTitle('1234567890'), isTrue);
      expect(
        ServiceListingService.validateTitle('  Certified plumbing repair  '),
        isTrue,
      );
      expect(ServiceListingService.validateTitle('x' * 120), isTrue);
    });

    test('rejects short, empty, and overlong', () {
      expect(ServiceListingService.validateTitle('Short'), isFalse);
      expect(ServiceListingService.validateTitle('   '), isFalse);
      expect(ServiceListingService.validateTitle('x' * 121), isFalse);
    });
  });

  group('ServiceListingService.validateDescription', () {
    test('accepts 50–5000 chars after trim', () {
      expect(ServiceListingService.validateDescription('x' * 50), isTrue);
      expect(ServiceListingService.validateDescription('x' * 5000), isTrue);
    });

    test('rejects short and overlong', () {
      expect(ServiceListingService.validateDescription('Too short'), isFalse);
      expect(ServiceListingService.validateDescription('x' * 5001), isFalse);
    });
  });

  group('ServiceListingService.validatePrices', () {
    test('requires min for fixed/hourly/per_milestone', () {
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'fixed',
          priceMin: null,
          priceMax: null,
        ),
        isFalse,
      );
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'fixed',
          priceMin: 1000,
          priceMax: null,
        ),
        isTrue,
      );
    });

    test('allows missing min for custom', () {
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'custom',
          priceMin: null,
          priceMax: null,
        ),
        isTrue,
      );
    });

    test('rejects negative and inverted range', () {
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'fixed',
          priceMin: -1,
          priceMax: null,
        ),
        isFalse,
      );
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'fixed',
          priceMin: 5000,
          priceMax: 1000,
        ),
        isFalse,
      );
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'fixed',
          priceMin: 1000,
          priceMax: 5000,
        ),
        isTrue,
      );
    });

    test('rejects max without min', () {
      expect(
        ServiceListingService.validatePrices(
          pricingType: 'fixed',
          priceMin: null,
          priceMax: 5000,
        ),
        isFalse,
      );
    });
  });

  group('ServiceListingService vocabularies', () {
    test('pricing and currency mirrors', () {
      expect(
        ServiceListingService.validatePricingType('fixed'),
        isTrue,
      );
      expect(
        ServiceListingService.validatePricingType('per_hour'),
        isFalse,
      );
      expect(ServiceListingService.validateCurrency('NGN'), isTrue);
      expect(ServiceListingService.validateCurrency('XYZ'), isFalse);
    });
  });
}
