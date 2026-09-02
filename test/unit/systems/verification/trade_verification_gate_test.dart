import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/systems/verification/gate/trade_verification_gate.dart';

import '../../../support/fakes/fake_trade_verification.dart';

void main() {
  group('TradeVerificationGate.canBid', () {
    test('allows bidding only when the profession is approved', () {
      final TradeVerificationStatus approved = tradeStatusEntity(
        statuses: <String, String>{'p1': 'approved'},
      );

      expect(TradeVerificationGate.canBid(approved, 'p1'), isTrue);
    });

    test('locks bidding while unverified', () {
      final TradeVerificationStatus unverified = tradeStatusEntity(
        statuses: <String, String>{'p1': 'unverified'},
      );

      expect(TradeVerificationGate.canBid(unverified, 'p1'), isFalse);
    });

    test('locks bidding while pending review', () {
      final TradeVerificationStatus pending = tradeStatusEntity(
        statuses: <String, String>{'p1': 'pending'},
      );

      expect(TradeVerificationGate.canBid(pending, 'p1'), isFalse);
    });

    test('locks bidding when rejected (derived)', () {
      final TradeVerificationStatus rejected = tradeStatusEntity(
        statuses: <String, String>{'p1': 'rejected'},
      );

      expect(TradeVerificationGate.canBid(rejected, 'p1'), isFalse);
    });

    test('fails closed for an unknown/absent profession', () {
      final TradeVerificationStatus status = tradeStatusEntity(
        statuses: <String, String>{'p1': 'approved'},
      );

      expect(TradeVerificationGate.canBid(status, 'unknown'), isFalse);
    });

    test('is per-profession (does not release other professions)', () {
      final TradeVerificationStatus status = tradeStatusEntity(
        statuses: <String, String>{'p1': 'approved', 'p2': 'pending'},
      );

      expect(TradeVerificationGate.canBid(status, 'p1'), isTrue);
      expect(TradeVerificationGate.canBid(status, 'p2'), isFalse);
    });
  });

  group('TradeVerificationStatusKind mapping', () {
    test('fromServer maps the server column vocabulary', () {
      expect(TradeVerificationStatusKind.fromServer('approved'),
          TradeVerificationStatusKind.approved);
      expect(TradeVerificationStatusKind.fromServer('pending'),
          TradeVerificationStatusKind.pending);
      expect(TradeVerificationStatusKind.fromServer('unverified'),
          TradeVerificationStatusKind.unverified);
      expect(TradeVerificationStatusKind.fromServer('rejected'),
          TradeVerificationStatusKind.rejected);
    });

    test('unknown values default to unverified', () {
      expect(TradeVerificationStatusKind.fromServer(null),
          TradeVerificationStatusKind.unverified);
      expect(TradeVerificationStatusKind.fromServer(''),
          TradeVerificationStatusKind.unverified);
      expect(TradeVerificationStatusKind.fromServer('weird'),
          TradeVerificationStatusKind.unverified);
    });

    test('only approved is terminal + bid-locked', () {
      expect(TradeVerificationStatusKind.approved.canBid, isTrue);
      expect(TradeVerificationStatusKind.pending.canBid, isFalse);
      expect(TradeVerificationStatusKind.unverified.canBid, isFalse);
      expect(TradeVerificationStatusKind.rejected.canBid, isFalse);

      expect(TradeVerificationStatusKind.approved.isTerminal, isTrue);
      expect(TradeVerificationStatusKind.rejected.isTerminal, isTrue);
      expect(TradeVerificationStatusKind.pending.isTerminal, isFalse);
      expect(TradeVerificationStatusKind.unverified.isTerminal, isFalse);
    });
  });
}
