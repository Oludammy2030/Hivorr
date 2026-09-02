import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

/// Vocabulary + label tests for [TradeProofType] (EP-02-11 §5.2, TT-05).
void main() {
  group('enum surface', () {
    test('defines exactly the 5 allowed proof kinds', () {
      expect(
        TradeProofType.values,
        <TradeProofType>[
          TradeProofType.certificate,
          TradeProofType.license,
          TradeProofType.workSample,
          TradeProofType.portfolio,
          TradeProofType.other,
        ],
      );
    });

    test('exposes the stable trade-kind and submission-type constants', () {
      expect(TradeProofType.tradeKind, 'trade_proof');
      expect(TradeProofType.submissionType, 'trade_proof');
      expect(TradeProofType.certificate.kind, TradeProofType.tradeKind);
    });

    test('no proof kind collides with the identity-document type', () {
      for (final TradeProofType type in TradeProofType.values) {
        expect(type.kind, isNot('identity_document'));
      }
    });
  });

  group('labels', () {
    test('maps every kind to its display label', () {
      expect(TradeProofType.certificate.label, 'Certificate');
      expect(TradeProofType.license.label, 'License');
      expect(TradeProofType.workSample.label, 'Work Sample');
      expect(TradeProofType.portfolio.label, 'Portfolio');
      expect(TradeProofType.other.label, 'Other');
    });

    test('provides a short helper description per kind', () {
      for (final TradeProofType type in TradeProofType.values) {
        expect(type.helper, isNotEmpty);
        expect(type.helper, isNot(type.label));
      }
    });
  });

  group('fromTitle', () {
    test('resolves titles ignoring case and surrounding whitespace', () {
      expect(TradeProofType.fromTitle('  LICeNsE '), TradeProofType.license);
      expect(TradeProofType.fromTitle('work sample'), TradeProofType.workSample);
      expect(TradeProofType.fromTitle('Portfolio'), TradeProofType.portfolio);
    });

    test('returns null for an unrecognized title', () {
      expect(TradeProofType.fromTitle('diploma'), isNull);
      expect(TradeProofType.fromTitle(''), isNull);
      expect(TradeProofType.fromTitle('  '), isNull);
    });

    test('every label round-trips through fromTitle', () {
      for (final TradeProofType type in TradeProofType.values) {
        expect(TradeProofType.fromTitle(type.label), type, reason: type.name);
      }
    });
  });
}