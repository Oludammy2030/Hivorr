import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/systems/identity/services/identity_resolver.dart';

Business verifiedBusiness({bool authorized = true}) => Business(
  id: 'biz-1',
  tradingName: 'Amara Foods',
  registeredLegalName: 'Amara Foods Ltd',
  cacNumber: 'CAC-001',
  status: 'approved',
  membership: BusinessMembership(
    businessId: 'biz-1',
    entityId: 'u1',
    role: 'representative',
    isAuthorized: authorized,
  ),
);

void main() {
  group('IdentityResolver.professionalFace', () {
    test('prefers the approved professional name', () {
      final ResolvedIdentity resolved = IdentityResolver.professionalFace(
        approvedProfessionalName: 'Adaeze Fixes It',
        fallbackDisplayName: 'Adaeze Okafor',
      );
      expect(resolved.name, 'Adaeze Fixes It');
      expect(resolved.kind, IdentityKind.professionalApproved);
    });

    test('falls back to the derived name when unapproved', () {
      for (final String? missing in <String?>[null, '', '   ']) {
        final ResolvedIdentity resolved = IdentityResolver.professionalFace(
          approvedProfessionalName: missing,
          fallbackDisplayName: 'Adaeze Okafor',
        );
        expect(resolved.name, 'Adaeze Okafor');
        expect(resolved.kind, IdentityKind.derived);
      }
    });

    test('trims the approved name', () {
      final ResolvedIdentity resolved = IdentityResolver.professionalFace(
        approvedProfessionalName: '  Adaeze Fixes It  ',
        fallbackDisplayName: 'Adaeze Okafor',
      );
      expect(resolved.name, 'Adaeze Fixes It');
    });
  });

  group('IdentityResolver.clientFace', () {
    test('shows the verified business when authorized', () {
      final ResolvedIdentity resolved = IdentityResolver.clientFace(
        business: verifiedBusiness(),
        individualName: 'David Musa',
      );
      expect(resolved.name, 'Amara Foods');
      expect(resolved.kind, IdentityKind.businessVerified);
    });

    test('pending business never displays (falls back to individual)', () {
      const Business pending = Business(
        id: 'biz-2',
        tradingName: 'Pending Co',
        registeredLegalName: 'Pending Co Ltd',
        status: 'pending',
        membership: BusinessMembership(
          businessId: 'biz-2',
          entityId: 'u1',
          role: 'representative',
          isAuthorized: false,
        ),
      );
      final ResolvedIdentity resolved = IdentityResolver.clientFace(
        business: pending,
        individualName: 'David Musa',
      );
      expect(resolved.name, 'David Musa');
      expect(resolved.kind, IdentityKind.derived);
    });

    test('unauthorized membership never displays the business', () {
      final ResolvedIdentity resolved = IdentityResolver.clientFace(
        business: verifiedBusiness(authorized: false),
        individualName: 'David Musa',
      );
      expect(resolved.name, 'David Musa');
    });

    test('marks KYC-backed individual names', () {
      final ResolvedIdentity resolved = IdentityResolver.clientFace(
        individualName: 'David Musa',
        individualVerified: true,
      );
      expect(resolved.kind, IdentityKind.individualVerified);
    });
  });

  group('IdentityResolver.forEngagement (Amara ↔ David)', () {
    test('client sees professional face, professional sees client face', () {
      final ({ResolvedIdentity self, ResolvedIdentity other}) asClient =
          IdentityResolver.forEngagement(
            viewerIsClient: true,
            approvedProfessionalName: 'Adaeze Fixes It',
            professionalFallback: 'Adaeze Okafor',
            clientIndividualName: 'David Musa',
          );
      expect(asClient.self.name, 'David Musa');
      expect(asClient.other.name, 'Adaeze Fixes It');
      expect(asClient.other.kind, IdentityKind.professionalApproved);

      final ({ResolvedIdentity self, ResolvedIdentity other}) asProfessional =
          IdentityResolver.forEngagement(
            viewerIsClient: false,
            approvedProfessionalName: 'Adaeze Fixes It',
            professionalFallback: 'Adaeze Okafor',
            clientBusiness: verifiedBusiness(),
            clientIndividualName: 'David Musa',
          );
      expect(asProfessional.self.name, 'Adaeze Fixes It');
      expect(asProfessional.other.name, 'Amara Foods');
      expect(asProfessional.other.kind, IdentityKind.businessVerified);
    });

    test('role reversal needs no account changes', () {
      final ({ResolvedIdentity self, ResolvedIdentity other}) reversed =
          IdentityResolver.forEngagement(
            viewerIsClient: true,
            approvedProfessionalName: 'David the Painter',
            professionalFallback: 'David Musa',
            clientIndividualName: 'Amara Diallo',
          );
      expect(reversed.self.name, 'Amara Diallo');
      expect(reversed.other.name, 'David the Painter');
    });
  });
}
