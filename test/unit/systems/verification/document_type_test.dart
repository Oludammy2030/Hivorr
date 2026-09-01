import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/verification/models/document_type.dart';

void main() {
  group('DocumentType vocabulary', () {
    test('exposes the full 5-value identity vocabulary', () {
      expect(DocumentType.values, hasLength(5));
      expect(
        DocumentType.values.map((DocumentType t) => t.name),
        containsAll(<String>[
          'nationalId',
          'passport',
          'driversLicense',
          'votersCard',
          'ninSlip',
        ]),
      );
    });

    test('every value maps to the stable identity document kind', () {
      for (final DocumentType type in DocumentType.values) {
        expect(type.kind, 'identity_document');
        expect(type.kind, DocumentType.identityKind);
        expect(DocumentType.submissionType, 'identity_document');
      }
    });

    test('provides a human-readable, Nigeria-hinted label per value', () {
      expect(DocumentType.nationalId.label, 'National ID (NIN)');
      expect(DocumentType.driversLicense.label, "Driver's License (FRSC)");
      expect(DocumentType.votersCard.label, "Voter's Card (INEC)");
      expect(DocumentType.ninSlip.label, 'NIN Slip');
      expect(DocumentType.passport.label, 'Passport');
    });

    test('provides a short helper hint per value', () {
      for (final DocumentType type in DocumentType.values) {
        expect(type.helper, isNotEmpty);
      }
      expect(
        DocumentType.nationalId.helper,
        contains('National Identity'),
      );
    });

    test('fromTitle resolves case-insensitively', () {
      expect(
        DocumentType.fromTitle('national id (nin)'),
        DocumentType.nationalId,
      );
      expect(
        DocumentType.fromTitle("Driver's License (FRSC)"),
        DocumentType.driversLicense,
      );
    });

    test('fromTitle returns null for an unknown title', () {
      expect(DocumentType.fromTitle('Cereal Card'), isNull);
    });

    test('every submission represents an identity document (AGENT.md)', () {
      // Sanity: no other submission type leaks from the identity vocabulary.
      expect(DocumentType.submissionType, DocumentType.identityKind);
      for (final DocumentType type in DocumentType.values) {
        expect(type.kind, DocumentType.submissionType);
      }
    });
  });
}
