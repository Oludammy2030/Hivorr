import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/models/escrow_status.dart';

void main() {
  group('escrowStatuses', () {
    test('is the 7-state vocabulary matching the frozen check constraint', () {
      expect(
        escrowStatuses.map((EscrowStatus s) => s.code),
        orderedEquals(<String>[
          'created',
          'funded',
          'partially_released',
          'released',
          'refunded',
          'cancelled',
          'disputed',
        ]),
      );
    });

    test('maps each state to its DoD display tone (§14.2)', () {
      final byCode = <String, EscrowStatusTone>{
        for (final EscrowStatus s in escrowStatuses) s.code: s.tone,
      };

      expect(byCode['created'], EscrowStatusTone.warning);
      expect(byCode['funded'], EscrowStatusTone.primary);
      expect(byCode['partially_released'], EscrowStatusTone.primary);
      expect(byCode['released'], EscrowStatusTone.success);
      expect(byCode['refunded'], EscrowStatusTone.neutral);
      expect(byCode['cancelled'], EscrowStatusTone.neutral);
      expect(byCode['disputed'], EscrowStatusTone.danger);
    });

    test('forCode resolves known codes and rejects unknown ones', () {
      final released = EscrowStatus.forCode('released');
      expect(released, isNotNull);
      expect(released!.label, 'Released to provider');
      expect(EscrowStatus.forCode('exploded'), isNull);
    });
  });

  group('milestoneStatuses', () {
    test('is the 3-state vocabulary matching the frozen check constraint', () {
      expect(
        milestoneStatuses.map((MilestoneStatus s) => s.code),
        orderedEquals(<String>['pending', 'completed', 'released']),
      );
    });

    test('maps each state to its DoD display tone (§14.2)', () {
      final byCode = <String, EscrowStatusTone>{
        for (final MilestoneStatus s in milestoneStatuses) s.code: s.tone,
      };

      expect(byCode['pending'], EscrowStatusTone.neutral);
      expect(byCode['completed'], EscrowStatusTone.primary);
      expect(byCode['released'], EscrowStatusTone.success);
    });

    test('forCode resolves known codes and rejects unknown ones', () {
      expect(MilestoneStatus.forCode('completed')?.label,
          'Completed — awaiting release');
      expect(MilestoneStatus.forCode('bogus'), isNull);
    });
  });
}