// Run: flutter test test/integration/marketplace/trade_gate_block_integration_test.dart
//
// EP-03-20 VP2 — Unverified pro is blocked from publishing/bidding (PLT005).
// Composes the REAL ServiceListingService with FakeServiceListingRepository
// for the PLT005 surface, plus the pure [TradeVerificationGate] bid-lock for
// the fail-closed contrast (AGENT.md Rule 2). The client never writes gate
// columns (asserted by marketplace_ranking_override_scan / trust scans).

import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/verification/gate/trade_verification_gate.dart';

import '../../support/fakes/fake_service_listing.dart';

void main() {
  group('EP-03-20 VP2 — trade verification gate blocks unverified', () {
    late FakeServiceListingRepository repo;
    late ServiceListingService service;

    setUp(() {
      repo = FakeServiceListingRepository();
      service = ServiceListingService(repository: repo);
    });

    test('DoD-VP2a: unverified publish is refused with PLT005', () async {
      // Arrange: the server refuses the publish for an unverified pro.
      repo.publishError = const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Trade verification required to publish.',
        code: 'PLT005',
      );

      // Act & Assert: the typed conflict surfaces (never a silent success).
      final Object? error = await service
          .publishListing('listing-1')
          .then<Object?>((_) => null)
          .catchError((Object e) => e);
      expect(error, isA<ApiException>());
      final ApiException api = error! as ApiException;
      expect(api.code, 'PLT005');
      expect(api.kind, ApiExceptionKind.conflict);
    });

    test('DoD-VP2b: verified pro publish succeeds (contrast)', () async {
      // Arrange: a verified pro's publish is accepted by the server.
      final MyServiceListing seed = FakeServiceListingRepository.listing(
        id: 'listing-1',
        status: 'draft',
      );
      repo = FakeServiceListingRepository(seed: <MyServiceListing>[seed]);
      service = ServiceListingService(repository: repo);

      // Act: publish succeeds for the verified pro.
      final MyServiceListing published = await service.publishListing(
        'listing-1',
      );

      // Assert: status flips to published — the gate unlocked.
      expect(published.status, 'published');
    });

    test('DoD-VP2c: TradeVerificationGate is fail-closed (approved-only)', () {
      // Arrange: an aggregate with one approved + one pending profession.
      const TradeVerificationStatus status = TradeVerificationStatus(
        tradeVerifications: <TradeVerification>[
          TradeVerification(professionId: 'prof-approved', status: 'approved'),
          TradeVerification(professionId: 'prof-pending', status: 'pending'),
          TradeVerification(professionId: 'prof-rejected', status: 'rejected'),
        ],
      );

      // Assert: only `approved` unlocks the bid-lock.
      expect(TradeVerificationGate.canBid(status, 'prof-approved'), isTrue);
      expect(TradeVerificationGate.canBid(status, 'prof-pending'), isFalse);
      expect(TradeVerificationGate.canBid(status, 'prof-rejected'), isFalse);
      // An absent/unknown profession resolves unverified → locked (fail-closed).
      expect(TradeVerificationGate.canBid(status, 'prof-absent'), isFalse);
      // An empty aggregate locks every profession.
      expect(
        TradeVerificationGate.canBid(
          const TradeVerificationStatus(),
          'prof-approved',
        ),
        isFalse,
      );
    });
  });
}
