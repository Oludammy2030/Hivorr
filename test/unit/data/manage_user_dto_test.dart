import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/models/manage_user_dto.dart';

void main() {
  group('ManageUserListItemDto (EP-02-11 canonical shape)', () {
    test('parses the canonical directory row', () {
      final ManageUserListItemDto item =
          ManageUserListItemDto.fromJson(<String, dynamic>{
        'id': '00000000-0000-4000-8000-000000000002',
        'display_name': 'Ada Lovelace',
        'legal_name': 'Ada B. Lovelace',
        'avatar_path': 'avatars/ada.png',
        'status': 'active',
        'roles': <String>['freelancer', 'contractor'],
        'kyc_tier': 'tier_2',
        'is_admin': false,
        'onboarding_completed': true,
        'created_at': '2026-01-02T03:04:05.000Z',
      });

      expect(item.id, '00000000-0000-4000-8000-000000000002');
      expect(item.displayName, 'Ada Lovelace');
      expect(item.legalName, 'Ada B. Lovelace');
      expect(item.avatarPath, 'avatars/ada.png');
      expect(item.status, 'active');
      expect(item.roles, <String>['freelancer', 'contractor']);
      expect(item.kycTier, 'tier_2');
      expect(item.isAdmin, isFalse);
      expect(item.onboardingCompleted, isTrue);
      expect(item.createdAt.year, 2026);
    });

    test('defaults safe values for absent nullable fields', () {
      final ManageUserListItemDto item =
          ManageUserListItemDto.fromJson(<String, dynamic>{
        'id': 'u1',
        'created_at': '2026-01-02T03:04:05.000Z',
      });

      expect(item.displayName, isEmpty);
      expect(item.status, 'active');
      expect(item.roles, isEmpty);
      expect(item.kycTier, isNull);
      expect(item.isAdmin, isFalse);
      expect(item.onboardingCompleted, isFalse);
    });
  });

  group('ManageUserListEnvelopeDto', () {
    test('parses users + total_count', () {
      final ManageUserListEnvelopeDto envelope =
          ManageUserListEnvelopeDto.fromJson(<String, dynamic>{
        'users': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'u1', 'created_at': '2026-01-02T03:04:05.000Z'},
        ],
        'total_count': 7,
      });

      expect(envelope.users, hasLength(1));
      expect(envelope.totalCount, 7);
    });

    test('defaults to an empty page', () {
      final ManageUserListEnvelopeDto envelope =
          ManageUserListEnvelopeDto.fromJson(<String, dynamic>{});
      expect(envelope.users, isEmpty);
      expect(envelope.totalCount, 0);
    });
  });

  group('ManageUserDetailDto (EP-02-11 canonical shape)', () {
    test('parses the full posture', () {
      final ManageUserDetailDto detail =
          ManageUserDetailDto.fromJson(<String, dynamic>{
        'entity': <String, dynamic>{
          'id': 'u1',
          'status': 'active',
          'capability': 'full_trading',
          'onboarding_completed_at': '2026-01-02T03:04:05.000Z',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        'profile': <String, dynamic>{
          'display_name': 'Ada Lovelace',
          'legal_name': 'Ada B. Lovelace',
          'bio': 'Analyst',
          'avatar_path': 'avatars/ada.png',
          'country_code': 'GB',
        },
        'roles': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'freelancer',
            'is_active': true,
            'activated_at': '2026-01-02T03:04:05.000Z',
          },
        ],
        'kyc': <String, dynamic>{
          'tier_code': 'tier_2',
          'status': 'verified',
          'assigned_at': '2026-01-02T03:04:05.000Z',
        },
        'is_admin': true,
        'summary': <String, dynamic>{
          'credential_count': 3,
          'approved_credentials': 2,
          'pending_submissions': 1,
          'total_submissions': 4,
        },
      });

      expect(detail.entity.id, 'u1');
      expect(detail.entity.status, 'active');
      expect(detail.entity.capability, 'full_trading');
      expect(detail.entity.onboardingCompletedAt, isNotNull);
      expect(detail.profile?.displayName, 'Ada Lovelace');
      expect(detail.profile?.countryCode, 'GB');
      expect(detail.roles, hasLength(1));
      expect(detail.roles.single.role, 'freelancer');
      expect(detail.roles.single.isActive, isTrue);
      expect(detail.kyc?.tierCode, 'tier_2');
      expect(detail.isAdmin, isTrue);
      expect(detail.summary.credentialCount, 3);
      expect(detail.summary.pendingSubmissions, 1);
    });

    test('handles missing profile/kyc rows as null', () {
      final ManageUserDetailDto detail =
          ManageUserDetailDto.fromJson(<String, dynamic>{
        'entity': <String, dynamic>{'id': 'u1', 'created_at': '2026-01-01T00:00:00.000Z'},
        'profile': null,
        'roles': <Object>[],
        'kyc': null,
        'is_admin': false,
        'summary': <String, dynamic>{},
      });

      expect(detail.profile, isNull);
      expect(detail.kyc, isNull);
      expect(detail.roles, isEmpty);
      expect(detail.summary.credentialCount, 0);
    });

    test('defaults is_admin/summary when omitted', () {
      final ManageUserDetailDto detail =
          ManageUserDetailDto.fromJson(<String, dynamic>{
        'entity': <String, dynamic>{
          'id': 'u1',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        'summary': <String, dynamic>{},
      });

      expect(detail.isAdmin, isFalse);
      expect(detail.entity.status, 'active');
    });
  });
}