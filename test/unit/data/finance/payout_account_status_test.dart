import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/models/payout_account_status.dart';

void main() {
  group('PayoutAccountStatus', () {
    test('has exactly the three lifecycle states matching the schema',
        () {
      expect(PayoutAccountStatus.values, hasLength(3));
      expect(PayoutAccountStatus.values, containsAll(<PayoutAccountStatus>[
        PayoutAccountStatus.pending,
        PayoutAccountStatus.active,
        PayoutAccountStatus.deactivated,
      ]));
    });

    test('fromPersisted maps active and deactivated exactly', () {
      expect(
        PayoutAccountStatus.fromPersisted('active'),
        PayoutAccountStatus.active,
      );
      expect(
        PayoutAccountStatus.fromPersisted('ACTIVE'),
        PayoutAccountStatus.active,
      );
      expect(
        PayoutAccountStatus.fromPersisted('deactivated'),
        PayoutAccountStatus.deactivated,
      );
    });

    test('fromPersisted defaults unknown values to pending (conservative)',
        () {
      expect(
        PayoutAccountStatus.fromPersisted('verified'),
        PayoutAccountStatus.pending,
      );
      expect(
        PayoutAccountStatus.fromPersisted(''),
        PayoutAccountStatus.pending,
      );
      expect(
        PayoutAccountStatus.fromPersisted('anything'),
        PayoutAccountStatus.pending,
      );
    });

    test('display labels are user-facing', () {
      expect(PayoutAccountStatus.pending.displayLabel, 'Pending');
      expect(PayoutAccountStatus.active.displayLabel, 'Active');
      expect(PayoutAccountStatus.deactivated.displayLabel, 'Deactivated');
    });
  });
}