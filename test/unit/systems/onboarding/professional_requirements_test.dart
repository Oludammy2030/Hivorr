import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/systems/onboarding/models/professional_requirements.dart';

List<ProfessionalRequirement> resolve({
  bool isOfferFocus = true,
  int boundProfessions = 1,
  bool identityVerified = true,
  bool identitySubmitted = true,
  bool tradeApproved = true,
  bool tradeSubmitted = true,
}) => resolveProfessionalRequirements(
  isOfferFocus: isOfferFocus,
  boundProfessions: boundProfessions,
  identityVerified: identityVerified,
  identitySubmitted: identitySubmitted,
  tradeApproved: tradeApproved,
  tradeSubmitted: tradeSubmitted,
  activitiesRoute: RoutePaths.activities,
  industryRoute: RoutePaths.onboardingIndustry,
  identityRoute: RoutePaths.onboardingIdentity,
  tradeRoute: RoutePaths.onboardingTradeProof,
);

ProfessionalRequirement byKey(List<ProfessionalRequirement> items, String key) =>
    items.firstWhere((ProfessionalRequirement item) => item.key == key);

void main() {
  group('resolveProfessionalRequirements', () {
    test('complete professional resolves all done', () {
      final List<ProfessionalRequirement> items = resolve();
      expect(items, hasLength(4));
      expect(ProfessionalRequirement.allDone(items), isTrue);
      for (final ProfessionalRequirement item in items) {
        expect(item.state, ProfessionalRequirementState.done);
        expect(item.destination, isNull);
      }
    });

    test('fresh account routes every item to its fix', () {
      final List<ProfessionalRequirement> items = resolve(
        isOfferFocus: false,
        boundProfessions: 0,
        identityVerified: false,
        identitySubmitted: false,
        tradeApproved: false,
        tradeSubmitted: false,
      );
      expect(ProfessionalRequirement.allDone(items), isFalse);
      expect(byKey(items, 'focus').destination, RoutePaths.activities);
      expect(byKey(items, 'profession').destination, RoutePaths.onboardingIndustry);
      expect(byKey(items, 'identity').destination, RoutePaths.onboardingIdentity);
      expect(byKey(items, 'trade').destination, RoutePaths.onboardingTradeProof);
      for (final ProfessionalRequirement item in items) {
        expect(item.state, ProfessionalRequirementState.action);
      }
    });

    test('submitted-but-unapproved reads as awaiting without destination', () {
      final List<ProfessionalRequirement> items = resolve(
        identityVerified: false,
        identitySubmitted: true,
        tradeApproved: false,
        tradeSubmitted: true,
      );
      expect(ProfessionalRequirement.allDone(items), isFalse);
      expect(
        byKey(items, 'identity').state,
        ProfessionalRequirementState.awaiting,
      );
      expect(byKey(items, 'identity').destination, isNull);
      expect(
        byKey(items, 'trade').state,
        ProfessionalRequirementState.awaiting,
      );
      expect(byKey(items, 'trade').destination, isNull);
    });

    test('verified identity counts as done even with pending trade', () {
      final List<ProfessionalRequirement> items = resolve(
        tradeApproved: false,
        tradeSubmitted: true,
      );
      expect(byKey(items, 'identity').state, ProfessionalRequirementState.done);
      expect(byKey(items, 'trade').state, ProfessionalRequirementState.awaiting);
    });

    test('empty list never counts as done', () {
      expect(
        ProfessionalRequirement.allDone(<ProfessionalRequirement>[]),
        isFalse,
      );
    });
  });
}
