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
  }) =>
      VerificationSubmissionDto(
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
      final VerificationSubmission entity = VerificationMapper.submissionToEntity(
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
        final VerificationSubmission entity = VerificationMapper.submissionToEntity(
          submissionDto(status: raw),
          documentType: DocumentType.nationalId,
        );
        expect(entity.status, expected, reason: 'for $raw');
      });
    });

    test('copies reviewedAt and truncates over-long decision notes', () {
      final String notes = 'x' * 6000;
      final VerificationSubmission entity = VerificationMapper.submissionToEntity(
        submissionDto(
          status: 'rejected',
          reviewedAt: reviewed,
          decisionNotes: notes,
        ),
        documentType: DocumentType.driversLicense,
      );

      expect(entity.reviewedAt, reviewed);
      expect(entity.decisionNotes!.length, VerificationMapper.maxDecisionNotesLength);
      expect(entity.decisionNotes!.startsWith('x' * 100), isTrue);
    });

    test('keeps short decision notes verbatim', () {
      final VerificationSubmission entity = VerificationMapper.submissionToEntity(
        submissionDto(status: 'rejected', decisionNotes: 'ID illegible'),
        documentType: DocumentType.votersCard,
      );
      expect(entity.decisionNotes, 'ID illegible');
    });
  });

  group('VerificationMapper KYC/limits', () {
    test('kycToEntity maps tier, status and limits', () {
      final KycLevelDto dto = KycLevelDto(
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
        KycLimitsDto(daily: 10, weekly: 20, monthly: 30, cashout: 40),
      );
      expect(limits.daily, 10);
      expect(limits.weekly, 20);
      expect(limits.monthly, 30);
      expect(limits.cashout, 40);
    });
  });

  group('VerificationMapper status aggregate', () {
    test('statusToEntity maps the full aggregate incl. trade verifications',
        () {
      final VerificationStatusDto dto = VerificationStatusDto(
        entityId: 'u1',
        kyc: KycLevelDto(
          tierCode: 'tier_1',
          status: 'active',
          limits: KycLimitsDto(daily: 1, weekly: 2, monthly: 3, cashout: 4),
        ),
        identityVerified: true,
        tradeVerifications: const <TradeVerificationDto>[
          TradeVerificationDto(professionId: 'p1', status: 'verified'),
        ],
        pendingSubmissions: 0,
        totalSubmissions: 2,
      );

      final VerificationStatus entity =
          VerificationMapper.statusToEntity(dto);

      expect(entity.entityId, 'u1');
      expect(entity.identityVerified, isTrue);
      expect(entity.kycLevel.tierCode, 'tier_1');
      expect(entity.tradeVerifications.single.professionId, 'p1');
      expect(entity.tradeVerifications.single.status, 'verified');
      expect(entity.pendingSubmissions, 0);
      expect(entity.totalSubmissions, 2);
    });

    test('tradeToEntity maps profession + status', () {
      final TradeVerification trade = VerificationMapper.tradeToEntity(
        const TradeVerificationDto(professionId: 'p9', status: 'unverified'),
      );
      expect(trade.professionId, 'p9');
      expect(trade.status, 'unverified');
    });
  });
}
