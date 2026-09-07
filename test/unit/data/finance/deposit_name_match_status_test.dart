import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

void main() {
  group('DepositNameMatchStatus', () {
    test('has exactly the four name-match states matching the schema',
        () {
      expect(DepositNameMatchStatus.values, hasLength(4));
      expect(DepositNameMatchStatus.values, containsAll(<DepositNameMatchStatus>[
        DepositNameMatchStatus.unverified,
        DepositNameMatchStatus.pending,
        DepositNameMatchStatus.matched,
        DepositNameMatchStatus.mismatched,
      ]));
    });

    test('fromPersisted maps each known value exactly', () {
      expect(
        DepositNameMatchStatus.fromPersisted('unverified'),
        DepositNameMatchStatus.unverified,
      );
      expect(
        DepositNameMatchStatus.fromPersisted('pending'),
        DepositNameMatchStatus.pending,
      );
      expect(
        DepositNameMatchStatus.fromPersisted('matched'),
        DepositNameMatchStatus.matched,
      );
      expect(
        DepositNameMatchStatus.fromPersisted('mismatched'),
        DepositNameMatchStatus.mismatched,
      );
      expect(
        DepositNameMatchStatus.fromPersisted('MATCHED'),
        DepositNameMatchStatus.matched,
      );
    });

    test('fromPersisted defaults unknown values to unverified', () {
      expect(
        DepositNameMatchStatus.fromPersisted('weird'),
        DepositNameMatchStatus.unverified,
      );
      expect(
        DepositNameMatchStatus.fromPersisted(''),
        DepositNameMatchStatus.unverified,
      );
    });

    test('display labels surface the four badge states', () {
      expect(DepositNameMatchStatus.unverified.displayLabel, 'Unverified');
      expect(DepositNameMatchStatus.pending.displayLabel, 'Pending');
      expect(DepositNameMatchStatus.matched.displayLabel, 'Verified');
      expect(DepositNameMatchStatus.mismatched.displayLabel, 'Failed');
    });
  });
}