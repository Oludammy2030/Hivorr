import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

void main() {
  group('EntityCapability (switchable focus, no both)', () {
    test('exposes exactly hire and offer', () {
      expect(EntityCapability.values, <EntityCapability>[
        EntityCapability.hire,
        EntityCapability.offer,
      ]);
    });

    test('hire finishes immediately, offer requires the wizard', () {
      expect(EntityCapability.hire.requiresProfessionalWizard, isFalse);
      expect(EntityCapability.offer.requiresProfessionalWizard, isTrue);
    });

    test('fromName parses persisted values', () {
      expect(EntityCapability.fromName('hire'), EntityCapability.hire);
      expect(EntityCapability.fromName('offer'), EntityCapability.offer);
    });

    test('fromName maps unknown and retired values to hire', () {
      expect(EntityCapability.fromName(null), EntityCapability.hire);
      expect(EntityCapability.fromName(''), EntityCapability.hire);
      expect(EntityCapability.fromName('both'), EntityCapability.hire);
      expect(EntityCapability.fromName('wizard'), EntityCapability.hire);
    });
  });
}
