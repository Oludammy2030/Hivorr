import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/mappers/verification_mapper.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/trade_verification_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/systems/verification/gate/trade_verification_gate.dart';

import '../../../support/fakes/fake_trade_verification.dart';

/// Transformation tests for the trade slice of the verification mapper
/// (EP-02-11 §5.2, TT-06).
void main() {
  group('TradeVerificationStatusDto', () {
    test('fromStatusDto extracts the trade array and identity flag', () {
      final VerificationStatusDto status = tradeStatusDto(
        identityVerified: true,
        statuses: <String, String>{'p1': 'approved', 'p2': 'pending'},
      );

      final TradeVerificationStatusDto trade =
          TradeVerificationStatusDto.fromStatusDto(status);

      expect(trade.identityVerified, isTrue);
      expect(
        trade.tradeVerifications.map((TradeVerificationDto e) => e.professionId),
        <String>['p1', 'p2'],
      );
    });

    test('defaults to an empty aggregate', () {
      const TradeVerificationStatusDto trade = TradeVerificationStatusDto();
      expect(trade.identityVerified, isFalse);
      expect(trade.tradeVerifications, isEmpty);
    });
  });

  group('TradeVerificationDto.fromJson', () {
    test('maps present profession_id and trade_verification_status', () {
      final TradeVerificationDto dto = TradeVerificationDto.fromJson(
        <String, dynamic>{
          'profession_id': 'p3',
          'trade_verification_status': 'approved',
        },
      );
      expect(dto.professionId, 'p3');
      expect(dto.status, 'approved');
    });

    test('falls back to empty id + unverified when keys are absent', () {
      final TradeVerificationDto dto =
          TradeVerificationDto.fromJson(<String, dynamic>{});
      expect(dto.professionId, '');
      expect(dto.status, 'unverified');
    });
  });

  group('VerificationMapper.tradeStatusToEntity', () {
    test('maps entries and the identity flag from the trade DTO', () {
      final TradeVerificationStatus entity =
          VerificationMapper.tradeStatusToEntity(
        TradeVerificationStatusDto(
          identityVerified: true,
          tradeVerifications: const <TradeVerificationDto>[
            TradeVerificationDto(professionId: 'p1', status: 'approved'),
            TradeVerificationDto(professionId: 'p2', status: 'pending'),
          ],
        ),
      );

      expect(entity.identityVerified, isTrue);
      expect(entity.tradeVerifications, hasLength(2));
      expect(entity.kindFor('p1'), TradeVerificationStatusKind.approved);
      expect(entity.kindFor('p2'), TradeVerificationStatusKind.pending);
      expect(TradeVerificationGate.canBid(entity, 'p1'), isTrue);
      expect(TradeVerificationGate.canBid(entity, 'p2'), isFalse);
    });

    test('derives statusKind across the server vocabulary', () {
      final TradeVerificationStatus entity =
          VerificationMapper.tradeStatusToEntity(
        TradeVerificationStatusDto(
          tradeVerifications: const <TradeVerificationDto>[
            TradeVerificationDto(professionId: 'a', status: 'approved'),
            TradeVerificationDto(professionId: 'i', status: 'in_review'),
            TradeVerificationDto(professionId: 'r', status: 'requires_resubmission'),
            TradeVerificationDto(professionId: 'u', status: 'mystery'),
          ],
        ),
      );

      expect(entity.kindFor('a'), TradeVerificationStatusKind.approved);
      expect(entity.kindFor('i'), TradeVerificationStatusKind.pending);
      expect(entity.kindFor('r'), TradeVerificationStatusKind.rejected);
      expect(entity.kindFor('u'), TradeVerificationStatusKind.unverified);
    });

    test('produces a fixed-size list (immutable copy)', () {
      final TradeVerificationStatus entity =
          VerificationMapper.tradeStatusToEntity(
        TradeVerificationStatusDto(
          tradeVerifications: const <TradeVerificationDto>[
            TradeVerificationDto(professionId: 'p1', status: 'approved'),
          ],
        ),
      );

      expect(
        () => entity.tradeVerifications.add(
          const TradeVerification(professionId: 'p2', status: 'pending'),
        ),
        throwsUnsupportedError,
      );
    });

    test('round-trips the fake aggregate fixture', () {
      final TradeVerificationStatus entity = VerificationMapper
          .tradeStatusToEntity(
        TradeVerificationStatusDto.fromStatusDto(
          tradeStatusDto(
            identityVerified: true,
            statuses: const <String, String>{'p1': 'approved'},
          ),
        ),
      );

      expect(entity.kindFor('p1'), TradeVerificationStatusKind.approved);
      expect(entity.identityVerified, isTrue);
    });
  });

  group('KycLimitsDto', () {
    test('coerces string numerics from the wire', () {
      final KycLimitsDto limits = KycLimitsDto.fromJson(<String, dynamic>{
        'daily': '1',
        'weekly': '2',
        'monthly': '3.5',
        'cashout': '4',
      });

      expect(limits.daily, 1);
      expect(limits.weekly, 2);
      expect(limits.monthly, 3.5);
      expect(limits.cashout, 4);
    });
  });
}