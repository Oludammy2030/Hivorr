import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/mappers/verification_mapper.dart';
import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

void main() {
  final DateTime submitted = DateTime.fromMillisecondsSinceEpoch(1000);
  final DateTime reviewed = DateTime.fromMillisecondsSinceEpoch(5000);

  VerificationSubmissionDto submissionDto({
    String status = 'pending',
    DateTime? reviewedAt,
    String? decisionNotes,
  }) => VerificationSubmissionDto(
    id: 'sub-1',
    entityId: 'u1',
    credentialId: 'cred-1',
    submissionType: 'identity_document',
    status: status,
    submittedAt: submitted,
    reviewedAt: reviewedAt,
    decisionNotes: decisionNotes,
  );

  group('VerificationMapper.submissionToEntity', () {
    test('maps fields and injects the caller-supplied document type', () {
      final VerificationSubmission entity =
          VerificationMapper.submissionToEntity(
            submissionDto(),
            documentType: DocumentType.passport,
          );

      expect(entity.id, 'sub-1');
      expect(entity.entityId, 'u1');
      expect(entity.credentialId, 'cred-1');
      expect(entity.documentType, DocumentType.passport);
      expect(entity.status, VerificationStatusKind.pending);
      expect(entity.submittedAt, submitted);
    });

    test('maps every server status string to the enum', () {
      final map = <String, VerificationStatusKind>{
        'pending': VerificationStatusKind.pending,
        'in_review': VerificationStatusKind.inReview,
        'approved': VerificationStatusKind.approved,
        'rejected': VerificationStatusKind.rejected,
        'requires_resubmission': VerificationStatusKind.requiresResubmission,
      };
      map.forEach((String raw, VerificationStatusKind expected) {
        final VerificationSubmission entity =
            VerificationMapper.submissionToEntity(
              submissionDto(status: raw),
              documentType: DocumentType.nationalId,
            );
        expect(entity.status, expected, reason: 'for $raw');
      });
    });

    test('copies reviewedAt and truncates over-long decision notes', () {
      final String notes = 'x' * 6000;
      final VerificationSubmission entity =
          VerificationMapper.submissionToEntity(
            submissionDto(
              status: 'rejected',
              reviewedAt: reviewed,
              decisionNotes: notes,
            ),
            documentType: DocumentType.driversLicense,
          );

      expect(entity.reviewedAt, reviewed);
      expect(
        entity.decisionNotes!.length,
        VerificationMapper.maxDecisionNotesLength,
      );
      expect(entity.decisionNotes!.startsWith('x' * 100), isTrue);
    });

    test('keeps short decision notes verbatim', () {
      final VerificationSubmission entity =
          VerificationMapper.submissionToEntity(
            submissionDto(status: 'rejected', decisionNotes: 'ID illegible'),
            documentType: DocumentType.votersCard,
          );
      expect(entity.decisionNotes, 'ID illegible');
    });
  });

  group('VerificationMapper KYC/limits', () {
    test('kycToEntity maps tier, status and limits', () {
      const KycLevelDto dto = KycLevelDto(
        tierCode: 'tier_1',
        status: 'active',
        limits: KycLimitsDto(daily: 1, weekly: 2, monthly: 3, cashout: 4),
      );

      final KycLevel entity = VerificationMapper.kycToEntity(dto);

      expect(entity.tierCode, 'tier_1');
      expect(entity.status, 'active');
      expect(entity.limits.daily, 1);
      expect(entity.limits.weekly, 2);
      expect(entity.limits.monthly, 3);
      expect(entity.limits.cashout, 4);
    });

    test('limitsToEntity copies each numeric limit', () {
      final KycLimits limits = VerificationMapper.limitsToEntity(
        const KycLimitsDto(daily: 10, weekly: 20, monthly: 30, cashout: 40),
      );
      expect(limits.daily, 10);
      expect(limits.weekly, 20);
      expect(limits.monthly, 30);
      expect(limits.cashout, 40);
    });
  });

  group('VerificationMapper status aggregate', () {
    test(
      'statusToEntity maps the full aggregate incl. trade verifications',
      () {
        const VerificationStatusDto dto = VerificationStatusDto(
          entityId: 'u1',
          kyc: KycLevelDto(
            tierCode: 'tier_1',
            status: 'active',
            limits: KycLimitsDto(daily: 1, weekly: 2, monthly: 3, cashout: 4),
          ),
          identityVerified: true,
          tradeVerifications: <TradeVerificationDto>[
            TradeVerificationDto(professionId: 'p1', status: 'verified'),
          ],
          pendingSubmissions: 0,
          totalSubmissions: 2,
        );

        final VerificationStatus entity = VerificationMapper.statusToEntity(
          dto,
        );

        expect(entity.entityId, 'u1');
        expect(entity.identityVerified, isTrue);
        expect(entity.kycLevel.tierCode, 'tier_1');
        expect(entity.tradeVerifications.single.professionId, 'p1');
        expect(entity.tradeVerifications.single.status, 'verified');
        expect(entity.pendingSubmissions, 0);
        expect(entity.totalSubmissions, 2);
      },
    );

    test('statusToEntity maps latest per-lane submissions', () {
      final VerificationStatusDto dto = VerificationStatusDto(
        entityId: 'u1',
        kyc: const KycLevelDto(
          tierCode: 'tier_0',
          status: 'pending',
          limits: KycLimitsDto(daily: 0, weekly: 0, monthly: 0, cashout: 0),
        ),
        identityVerified: false,
        latestSubmissions: <VerificationSubmissionSummaryDto>[
          VerificationSubmissionSummaryDto(
            submissionType: 'identity_document',
            status: 'rejected',
            submittedAt: submitted,
            reviewedAt: reviewed,
          ),
          VerificationSubmissionSummaryDto(
            submissionType: 'trade_proof',
            professionId: 'p1',
            status: 'in_review',
            submittedAt: submitted,
          ),
        ],
        hasLatestSubmissionData: true,
        pendingSubmissions: 1,
        totalSubmissions: 2,
      );

      final VerificationStatus entity = VerificationMapper.statusToEntity(dto);

      expect(entity.hasLatestSubmissionData, isTrue);
      expect(
        entity.latestIdentitySubmission!.status,
        VerificationStatusKind.rejected,
      );
      expect(
        entity.latestTradeSubmissionFor('p1')!.status,
        VerificationStatusKind.inReview,
      );
      expect(entity.latestTradeSubmissionFor('other'), isNull);
    });

    test('status DTO parses latest submission projection', () {
      final VerificationStatusDto dto = VerificationStatusDto.fromJson(
        <String, dynamic>{
          'entity_id': 'u1',
          'kyc': <String, dynamic>{
            'tier_code': 'tier_0',
            'status': 'pending',
            'limits': <String, dynamic>{
              'daily': 0,
              'weekly': 0,
              'monthly': 0,
              'cashout': 0,
            },
          },
          'identity_verified': false,
          'trade_verifications': <dynamic>[],
          'latest_submissions': <dynamic>[
            <String, dynamic>{
              'submission_type': 'trade_proof',
              'profession_id': 'p1',
              'status': 'requires_resubmission',
              'submitted_at': '2026-10-01T10:00:00Z',
              'reviewed_at': '2026-10-02T10:00:00Z',
            },
          ],
          'pending_submissions': 0,
          'total_submissions': 1,
        },
      );

      expect(dto.hasLatestSubmissionData, isTrue);
      expect(dto.latestSubmissions.single.status, 'requires_resubmission');
      expect(dto.latestSubmissions.single.professionId, 'p1');
      expect(dto.latestSubmissions.single.reviewedAt, isNotNull);
    });

    test('status DTO parses business lanes, notes and eligibility', () {
      final VerificationStatusDto dto = VerificationStatusDto.fromJson(
        <String, dynamic>{
          'entity_id': 'u1',
          'kyc': <String, dynamic>{
            'tier_code': 'tier_1',
            'status': 'active',
            'limits': <String, dynamic>{
              'daily': 50000,
              'weekly': 200000,
              'monthly': 800000,
              'cashout': 100000,
            },
          },
          'identity_verified': true,
          'trade_verifications': <dynamic>[],
          'latest_submissions': <dynamic>[],
          'businesses': <dynamic>[
            <String, dynamic>{
              'business_id': 'biz-1',
              'trading_name': 'Amara Foods',
              'registered_legal_name': 'Amara Foods Ltd',
              'cac_number': 'CAC-001',
              'verification_status': 'rejected',
              'role': 'representative',
              'is_authorized': false,
              'latest_submission': <String, dynamic>{
                'status': 'rejected',
                'submitted_at': '2026-10-01T10:00:00Z',
                'reviewed_at': '2026-10-02T10:00:00Z',
                'decision_notes': 'Registry mismatch',
              },
            },
          ],
          'eligibility': <String, dynamic>{
            'identity_verified': true,
            'professional_eligibility': <dynamic>[],
            'business_eligibility': <dynamic>[
              <String, dynamic>{
                'business_id': 'biz-1',
                'approved': false,
                'authorized': false,
                'can_hire': false,
                'can_manage': true,
              },
            ],
          },
          'pending_submissions': 0,
          'total_submissions': 2,
        },
      );

      final VerificationStatus entity = VerificationMapper.statusToEntity(dto);

      expect(entity.businesses, hasLength(1));
      final BusinessVerificationEntry business = entity.businesses.single;
      expect(business.businessId, 'biz-1');
      expect(business.tradingName, 'Amara Foods');
      expect(business.verificationStatus, 'rejected');
      expect(business.isAuthorized, isFalse);
      expect(
        business.latestSubmission!.status,
        VerificationStatusKind.rejected,
      );
      expect(business.latestSubmission!.decisionNotes, 'Registry mismatch');
      expect(entity.eligibility['identity_verified'], isTrue);
    });

    test('old aggregate without latest_submissions fails open', () {
      final VerificationStatusDto dto = VerificationStatusDto.fromJson(
        <String, dynamic>{
          'entity_id': 'u1',
          'kyc': <String, dynamic>{
            'tier_code': 'tier_0',
            'status': 'pending',
            'limits': <String, dynamic>{
              'daily': 0,
              'weekly': 0,
              'monthly': 0,
              'cashout': 0,
            },
          },
          'identity_verified': false,
          'pending_submissions': 1,
          'total_submissions': 1,
        },
      );

      expect(dto.hasLatestSubmissionData, isFalse);
      expect(dto.latestSubmissions, isEmpty);
      expect(dto.businesses, isEmpty);
      expect(dto.eligibility, isEmpty);
    });

    test('tradeToEntity maps profession + status', () {
      final TradeVerification trade = VerificationMapper.tradeToEntity(
        const TradeVerificationDto(professionId: 'p9', status: 'unverified'),
      );
      expect(trade.professionId, 'p9');
      expect(trade.status, 'unverified');
      expect(trade.professionalDisplayName, isNull);
    });

    test('tradeToEntity carries the professional display name', () {
      final TradeVerification trade = VerificationMapper.tradeToEntity(
        const TradeVerificationDto(
          professionId: 'p9',
          status: 'approved',
          professionalDisplayName: 'Adaeze Fixes It',
        ),
      );
      expect(trade.professionalDisplayName, 'Adaeze Fixes It');
    });

    test('trade DTO trims blank professional names to null', () {
      const TradeVerificationDto dto = TradeVerificationDto(
        professionId: 'p9',
        status: 'pending',
      );
      expect(dto.professionalDisplayName, isNull);
      final TradeVerificationDto blank =
          TradeVerificationDto.fromJson(<String, dynamic>{
            'profession_id': 'p9',
            'trade_verification_status': 'pending',
            'professional_display_name': '   ',
          });
      expect(blank.professionalDisplayName, isNull);
    });
  });
}
