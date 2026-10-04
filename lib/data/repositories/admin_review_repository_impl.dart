// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/data/datasources/remote/admin_review_remote_data_source.dart';
import 'package:hivorr/data/models/admin_review_dto.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';

/// Default implementation of [AdminReviewRepository].
///
/// Maps DTOs to domain entities and delegates transport to the injected
/// [AdminReviewRemoteDataSource]. Storage access is via the injected
/// [StorageService] for signed-URL creation (the server RLS policy grants
/// SELECT to platform admins only).
class AdminReviewRepositoryImpl implements AdminReviewRepository {
  AdminReviewRepositoryImpl({required AdminReviewRemoteDataSource remote})
    : _remote = remote;

  final AdminReviewRemoteDataSource _remote;

  @override
  Future<bool> checkAdmin() async {
    final AdminCheckResultDto result = await _remote.checkAdmin();
    return result.isPlatformAdmin;
  }

  @override
  Future<List<AdminReviewQueueEntry>> getReviewQueue({
    String? submissionType,
    int limit = 50,
    int offset = 0,
    String? search,
    String? professionId,
    String? sort,
  }) async {
    final List<AdminReviewQueueEntryDto> dtos = await _remote.getReviewQueue(
      submissionType: submissionType,
      limit: limit,
      offset: offset,
      search: search,
      professionId: professionId,
      sort: sort,
    );
    return dtos.map(_queueEntryToEntity).toList(growable: false);
  }

  @override
  Future<void> startReview(String submissionId) =>
      _remote.startReview(submissionId);

  @override
  Future<void> approveSubmission(String submissionId, {String notes = ''}) =>
      _remote.approveSubmission(submissionId, notes: notes);

  @override
  Future<void> rejectSubmission(
    String submissionId, {
    String notes = '',
    bool requiresResubmission = false,
  }) => _remote.rejectSubmission(
    submissionId,
    notes: notes,
    requiresResubmission: requiresResubmission,
  );

  @override
  Future<List<AdminReviewAuditEntry>> getAuditTrail(String submissionId) async {
    final List<AdminReviewAuditEntryDto> dtos = await _remote.getAuditTrail(
      submissionId,
    );
    return dtos.map(_auditEntryToEntity).toList(growable: false);
  }

  @override
  Future<AdminReviewMetrics> getReviewMetrics({
    int periodDays = 30,
    String? submissionType,
  }) async {
    final AdminReviewMetricsDto dto = await _remote.getReviewMetrics(
      periodDays: periodDays,
      submissionType: submissionType,
    );
    return AdminReviewMetrics(
      pendingTotal: dto.pendingTotal,
      inReviewTotal: dto.inReviewTotal,
      avgVerificationSeconds: dto.avgVerificationSeconds,
      approvedToday: dto.approvedToday,
      decidedTotal: dto.decidedTotal,
      rejectedTotal: dto.rejectedTotal,
      rejectionRate: dto.rejectionRate,
      periodDays: dto.periodDays,
    );
  }

  @override
  Future<AdminReviewProfile> getReviewProfile(String submissionId) async {
    final AdminReviewProfileDto dto = await _remote.getReviewProfile(
      submissionId,
    );
    return AdminReviewProfile(
      experiences: dto.experiences
          .map(
            (ReviewExperienceDto d) => ReviewExperience(
              id: d.id,
              title: d.title,
              organization: d.organization,
              startYear: d.startYear,
              startMonth: d.startMonth,
              endYear: d.endYear,
              endMonth: d.endMonth,
              isCurrent: d.isCurrent,
              description: d.description,
            ),
          )
          .toList(growable: false),
      educations: dto.educations
          .map(
            (ReviewEducationDto d) => ReviewEducation(
              id: d.id,
              school: d.school,
              degree: d.degree,
              fieldOfStudy: d.fieldOfStudy,
              graduationYear: d.graduationYear,
            ),
          )
          .toList(growable: false),
      skills: dto.skills
          .map(
            (ReviewSkillDto d) => ReviewSkill(
              id: d.id,
              name: d.name,
              yearsExperience: d.yearsExperience,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<String> createDocumentSignedUrl(
    String credentialId, {
    int expiresIn = 60,
  }) => _remote.createDocumentSignedUrl(credentialId, expiresIn: expiresIn);

  @override
  int? get lastTotalCount => _remote.lastTotalCount;

  AdminReviewQueueEntry _queueEntryToEntity(AdminReviewQueueEntryDto dto) {
    return AdminReviewQueueEntry(
      submissionId: dto.submissionId,
      entityId: dto.entityId,
      entityName: dto.entityName,
      credentialId: dto.credentialId,
      credentialType: dto.credentialType,
      credentialName: dto.credentialName,
      submissionType: dto.submissionType,
      status: dto.status,
      submittedAt: dto.submittedAt,
      entityAvatarPath: dto.entityAvatarPath,
      entityLegalName: dto.entityLegalName,
      documentPath: dto.documentPath,
      professionId: dto.professionId,
      professionName: dto.professionName,
      assignedReviewer: dto.assignedReviewer,
      decisionNotes: dto.decisionNotes,
    );
  }

  AdminReviewAuditEntry _auditEntryToEntity(AdminReviewAuditEntryDto dto) {
    return AdminReviewAuditEntry(
      id: dto.id,
      eventType: dto.eventType,
      subjectType: dto.subjectType,
      subjectId: dto.subjectId,
      fromState: dto.fromState,
      toState: dto.toState,
      actorId: dto.actorId,
      detailsJson: dto.detailsJson,
      createdAt: dto.createdAt,
    );
  }
}
