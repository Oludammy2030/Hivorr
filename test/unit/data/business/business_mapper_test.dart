import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/mappers/business_mapper.dart';
import 'package:hivorr/data/models/business_dto.dart';

void main() {
  Map<String, dynamic> businessRow({
    String status = 'pending',
    Object? memberships,
  }) => <String, dynamic>{
    'id': 'biz-1',
    'trading_name': 'Amara Foods',
    'registered_legal_name': 'Amara Foods Ltd',
    'cac_number': 'CAC-001',
    'verification_status': status,
    'business_memberships': memberships,
  };

  Map<String, dynamic> membershipRow() => <String, dynamic>{
    'business_id': 'biz-1',
    'entity_id': 'u1',
    'role': 'representative',
    'is_authorized': false,
  };

  group('BusinessDto.fromJson', () {
    test('parses a row without membership', () {
      final BusinessDto dto = BusinessDto.fromJson(
        businessRow(memberships: null),
      );
      expect(dto.id, 'biz-1');
      expect(dto.tradingName, 'Amara Foods');
      expect(dto.registeredLegalName, 'Amara Foods Ltd');
      expect(dto.cacNumber, 'CAC-001');
      expect(dto.status, 'pending');
      expect(dto.membership, isNull);
    });

    test('parses an embedded membership map', () {
      final BusinessDto dto = BusinessDto.fromJson(
        businessRow(memberships: membershipRow()),
      );
      expect(dto.membership?.role, 'representative');
      expect(dto.membership?.isAuthorized, isFalse);
    });

    test('parses an embedded membership list', () {
      final BusinessDto dto = BusinessDto.fromJson(
        businessRow(
          memberships: <Map<String, dynamic>>[membershipRow()],
        ),
      );
      expect(dto.membership?.entityId, 'u1');
    });

    test('defaults unknown status to pending', () {
      final BusinessDto dto = BusinessDto.fromJson(<String, dynamic>{
        'id': 'biz-9',
      });
      expect(dto.status, 'pending');
      expect(dto.tradingName, isEmpty);
    });
  });

  group('BusinessMapper', () {
    test('blanks CAC to null and maps membership', () {
      final Business business = BusinessMapper.businessToEntity(
        BusinessDto.fromJson(<String, dynamic>{
          'id': 'biz-2',
          'trading_name': 'Dayo Delivers',
          'registered_legal_name': 'Dayo Delivers Ltd',
          'cac_number': '   ',
          'verification_status': 'approved',
          'business_memberships': <String, dynamic>{
            'business_id': 'biz-2',
            'entity_id': 'u1',
            'role': 'representative',
            'is_authorized': true,
          },
        }),
      );
      expect(business.cacNumber, isNull);
      expect(business.isVerified, isTrue);
      expect(business.membership?.isRepresentative, isTrue);
      expect(business.canAct, isTrue);
    });

    test('view hints stay display-only and fail closed', () {
      const Business pending = Business(
        id: 'biz-3',
        tradingName: 'Pending Co',
        registeredLegalName: 'Pending Co Ltd',
        status: 'pending',
      );
      expect(pending.isPending, isTrue);
      expect(pending.isVerified, isFalse);
      expect(pending.canAct, isFalse);

      const Business rejected = Business(
        id: 'biz-4',
        tradingName: 'Rejected Co',
        registeredLegalName: 'Rejected Co Ltd',
        status: 'rejected',
      );
      expect(rejected.isRejected, isTrue);
      expect(rejected.canAct, isFalse);
    });
  });
}
