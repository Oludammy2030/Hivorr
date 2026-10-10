import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/models/job_envelopes_dto.dart';

/// Transformations between the jobs transport DTOs and the pure-Dart domain
/// entities (EP-04-01).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
abstract final class JobMapper {
  /// Maps a `jobs` DTO into a domain [Job].
  static Job jobToEntity(JobDto dto) => Job(
    id: dto.id,
    clientEntityId: dto.clientEntityId,
    professionId: dto.professionId,
    industryId: dto.industryId,
    title: dto.title,
    description: dto.description,
    budgetMin: dto.budgetMin,
    budgetMax: dto.budgetMax,
    currencyCode: dto.currencyCode,
    location: dto.location,
    status: dto.status,
    applicationsCount: dto.applicationsCount,
    awardedApplicationId: dto.awardedApplicationId,
    postedAt: dto.postedAt,
    awardedAt: dto.awardedAt,
    completedAt: dto.completedAt,
    cancelledAt: dto.cancelledAt,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
  );

  /// Maps a `job_applications` DTO into a domain [JobApplication].
  static JobApplication applicationToEntity(JobApplicationDto dto) =>
      JobApplication(
        id: dto.id,
        jobId: dto.jobId,
        professionalEntityId: dto.professionalEntityId,
        clientEntityId: dto.clientEntityId,
        coverNote: dto.coverNote,
        quotedAmount: dto.quotedAmount,
        currencyCode: dto.currencyCode,
        durationDays: dto.durationDays,
        status: dto.status,
        submittedAt: dto.submittedAt,
        decidedAt: dto.decidedAt,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
        jobTitle: dto.jobTitle,
        jobStatus: dto.jobStatus,
        applicantDisplayName: dto.applicantDisplayName,
        applicantAvatarPath: dto.applicantAvatarPath,
        applicantProfessionName: dto.applicantProfessionName,
        applicantProfessionSlug: dto.applicantProfessionSlug,
      );

  /// Maps a `job_list` / `job_list_mine` envelope into domain [Job]s.
  static List<Job> listEnvelopeToEntities(JobListEnvelopeDto dto) =>
      dto.jobs.map(jobToEntity).toList(growable: false);

  /// Maps an application list envelope into domain [JobApplication]s.
  static List<JobApplication> applicationListToEntities(
    ApplicationListEnvelopeDto dto,
  ) => dto.applications.map(applicationToEntity).toList(growable: false);
}
