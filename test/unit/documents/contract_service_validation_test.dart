import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/documents/services/contract_service.dart';

void main() {
  group('ContractService.validateMilestoneTitle', () {
    test('accepts 1–255 chars after trim', () {
      expect(ContractService.validateMilestoneTitle('Work'), isTrue);
      expect(ContractService.validateMilestoneTitle('  Work  '), isTrue);
      expect(ContractService.validateMilestoneTitle(''), isFalse);
      expect(ContractService.validateMilestoneTitle('   '), isFalse);
      expect(
        ContractService.validateMilestoneTitle('a' * 256),
        isFalse,
      );
    });
  });

  group('ContractService.validateMilestoneDescription', () {
    test('accepts absent or ≤2000 chars', () {
      expect(ContractService.validateMilestoneDescription(null), isTrue);
      expect(ContractService.validateMilestoneDescription(''), isTrue);
      expect(
        ContractService.validateMilestoneDescription('a' * 2000),
        isTrue,
      );
      expect(
        ContractService.validateMilestoneDescription('a' * 2001),
        isFalse,
      );
    });
  });

  group('ContractService.validateTotal', () {
    test('requires greater than zero', () {
      expect(ContractService.validateTotal(30000), isTrue);
      expect(ContractService.validateTotal(0), isFalse);
      expect(ContractService.validateTotal(-1), isFalse);
      expect(ContractService.validateTotal(null), isFalse);
    });
  });

  group('ContractService.validateMilestoneSums', () {
    test('accepts exact sums within 0.01 tolerance', () {
      expect(
        ContractService.validateMilestoneSums(
          totalAmount: 30000,
          milestoneAmounts: [10000, 10000, 10000],
        ),
        isTrue,
      );
      expect(
        ContractService.validateMilestoneSums(
          totalAmount: 30000,
          milestoneAmounts: [10000, 10000, 9999.995],
        ),
        isTrue,
      );
    });

    test('rejects empty and mismatched sums', () {
      expect(
        ContractService.validateMilestoneSums(
          totalAmount: 30000,
          milestoneAmounts: [],
        ),
        isFalse,
      );
      expect(
        ContractService.validateMilestoneSums(
          totalAmount: 30000,
          milestoneAmounts: [10000, 10000],
        ),
        isFalse,
      );
    });
  });

  group('ContractService.validateCurrency', () {
    test('accepts active subset only', () {
      expect(ContractService.validateCurrency('NGN'), isTrue);
      expect(ContractService.validateCurrency('GHS'), isTrue);
      expect(ContractService.validateCurrency('USD'), isTrue);
      expect(ContractService.validateCurrency('GBP'), isTrue);
      expect(ContractService.validateCurrency('EUR'), isFalse);
      expect(ContractService.validateCurrency('ngn'), isFalse);
    });
  });

  group('ContractService.validateExpiry', () {
    test('accepts absent or future expiry', () {
      expect(ContractService.validateExpiry(null), isTrue);
      expect(
        ContractService.validateExpiry(
          DateTime.now().add(const Duration(days: 1)),
        ),
        isTrue,
      );
      expect(
        ContractService.validateExpiry(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        isFalse,
      );
    });
  });

  group('ContractService vocabularies', () {
    test('status vocabularies match frozen CHECKs', () {
      expect(
        ContractService.contractStatuses,
        containsAll(['offered', 'active', 'completed', 'disputed', 'closed']),
      );
      expect(
        ContractService.milestoneStatuses,
        containsAll(['pending', 'completed', 'verified', 'released']),
      );
      expect(
        ContractService.eventTypes,
        containsAll([
          'offered',
          'accepted',
          'milestone_completed',
          'milestone_verified',
          'revision_requested',
          'closed',
          'disputed',
        ]),
      );
      expect(
        ContractService.verifyActions,
        containsAll(['verified', 'revision_requested']),
      );
    });
  });
}
