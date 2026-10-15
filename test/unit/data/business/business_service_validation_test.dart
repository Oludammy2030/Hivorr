import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/business/services/business_service.dart';

void main() {
  group('BusinessService validators mirror server CHECKs', () {
    test('validateTradingName enforces 1-120', () {
      expect(BusinessService.validateTradingName(''), isFalse);
      expect(BusinessService.validateTradingName('   '), isFalse);
      expect(BusinessService.validateTradingName('Amara Foods'), isTrue);
      expect(
        BusinessService.validateTradingName(
          List<String>.filled(121, 'x').join(),
        ),
        isFalse,
      );
    });

    test('validateLegalName enforces 1-255', () {
      expect(BusinessService.validateLegalName(''), isFalse);
      expect(BusinessService.validateLegalName('Amara Foods Ltd'), isTrue);
      expect(
        BusinessService.validateLegalName(
          List<String>.filled(256, 'x').join(),
        ),
        isFalse,
      );
    });

    test('validateCacNumber allows absent, enforces 1-64', () {
      expect(BusinessService.validateCacNumber(null), isTrue);
      expect(BusinessService.validateCacNumber(''), isFalse);
      expect(BusinessService.validateCacNumber('CAC-001'), isTrue);
      expect(
        BusinessService.validateCacNumber(
          List<String>.filled(65, 'x').join(),
        ),
        isFalse,
      );
    });

    test('validateDocumentTitle enforces 1-255', () {
      expect(BusinessService.validateDocumentTitle(''), isFalse);
      expect(BusinessService.validateDocumentTitle('CAC certificate'), isTrue);
    });
  });
}
