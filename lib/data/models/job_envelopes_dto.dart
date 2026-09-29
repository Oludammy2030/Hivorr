import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';

/// Envelope for the `job_list` / `job_list_mine` paginated reads (EP-04-01).
///
/// `data` shape: `{items: Job[], has_more: bool, next_cursor: uuid|null}`.
class JobListEnvelopeDto {
  const JobListEnvelopeDto({
    required this.jobs,
    required this.hasMore,
    this.nextCursor,
  });

  factory JobListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    final List<JobDto> jobs = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(JobDto.fromJson)
              .toList(growable: false)
        : const <JobDto>[];
    return JobListEnvelopeDto(
      jobs: jobs,
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<JobDto> jobs;
  final bool hasMore;
  final String? nextCursor;
}

/// Envelope for the `job_get` read (EP-04-01).
///
/// `data` shape: `{job, applications[], my_application|null, events[]}`.
/// `events` are passthrough row maps (rendered by the timeline UI).
class JobDetailEnvelopeDto {
  const JobDetailEnvelopeDto({
    required this.job,
    required this.applications,
    this.myApplication,
    this.events = const <Map<String, dynamic>>[],
  });

  factory JobDetailEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? jobRaw = json['job'];
    final Object? appsRaw = json['applications'];
    final Object? mineRaw = json['my_application'];
    final Object? eventsRaw = json['events'];
    return JobDetailEnvelopeDto(
      job: JobDto.fromJson(
        jobRaw is Map<String, dynamic> ? jobRaw : const <String, dynamic>{},
      ),
      applications: appsRaw is List
          ? appsRaw
                .whereType<Map<String, dynamic>>()
                .map(JobApplicationDto.fromJson)
                .toList(growable: false)
          : const <JobApplicationDto>[],
      myApplication: mineRaw is Map<String, dynamic>
          ? JobApplicationDto.fromJson(mineRaw)
          : null,
      events: eventsRaw is List
          ? eventsRaw
                .whereType<Map<String, dynamic>>()
                .map(Map<String, dynamic>.from)
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
    );
  }

  final JobDto job;
  final List<JobApplicationDto> applications;
  final JobApplicationDto? myApplication;
  final List<Map<String, dynamic>> events;
}

/// Envelope for `application_list_for_job` / `application_list_mine`
/// (EP-04-01).
///
/// `data` shape: `{items: JobApplication[], has_more, next_cursor}`.
class ApplicationListEnvelopeDto {
  const ApplicationListEnvelopeDto({
    required this.applications,
    required this.hasMore,
    this.nextCursor,
  });

  factory ApplicationListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    return ApplicationListEnvelopeDto(
      applications: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(JobApplicationDto.fromJson)
                .toList(growable: false)
          : const <JobApplicationDto>[],
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<JobApplicationDto> applications;
  final bool hasMore;
  final String? nextCursor;
}
