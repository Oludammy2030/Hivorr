import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/jobs_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/jobs_remote_data_source.dart';
import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/models/job_envelopes_dto.dart';

/// Supabase-backed implementation of [JobsRemoteDataSource] (EP-04-01).
///
/// Wraps the **sixteen client-callable** jobs RPCs via `supabase.rpc(...)`
/// and unwraps the standard `{success, code, message, data}` envelope with
/// [JobsEnvelopeParser]. Optional parameters use Dart's pattern-matching
/// `{'key': ?value}` omission so nulls never reach the server as explicit
/// nulls (mirrors `SupabaseDisputeRemoteDataSource`).
class SupabaseJobsRemoteDataSource extends BaseApiService
    implements JobsRemoteDataSource {
  SupabaseJobsRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<JobDto> createJob({
    required String title,
    required String description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String currencyCode = 'NGN',
    String? location,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_create',
          params: <String, dynamic>{
            'p_title': title,
            'p_description': description,
            'p_profession_id': ?professionId,
            'p_industry_id': ?industryId,
            'p_budget_min': ?budgetMin,
            'p_budget_max': ?budgetMax,
            'p_currency_code': currencyCode,
            'p_location': ?location,
          },
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDto> updateJob({
    required String jobId,
    String? title,
    String? description,
    String? professionId,
    String? industryId,
    double? budgetMin,
    double? budgetMax,
    String? currencyCode,
    String? location,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_update',
          params: <String, dynamic>{
            'p_job_id': jobId,
            'p_title': ?title,
            'p_description': ?description,
            'p_profession_id': ?professionId,
            'p_industry_id': ?industryId,
            'p_budget_min': ?budgetMin,
            'p_budget_max': ?budgetMax,
            'p_currency_code': ?currencyCode,
            'p_location': ?location,
          },
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDto> publishJob(String jobId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_publish',
          params: <String, dynamic>{'p_job_id': jobId},
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDto> pauseJob(String jobId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_pause',
          params: <String, dynamic>{'p_job_id': jobId},
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDto> resumeJob(String jobId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_resume',
          params: <String, dynamic>{'p_job_id': jobId},
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDto> cancelJob(String jobId, {String? reason}) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_cancel',
          params: <String, dynamic>{'p_job_id': jobId, 'p_reason': ?reason},
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDto> completeJob(String jobId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_complete',
          params: <String, dynamic>{'p_job_id': jobId},
        );
    return JobDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobDetailEnvelopeDto> getJob(String jobId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_get',
          params: <String, dynamic>{'p_job_id': jobId},
        );
    return JobDetailEnvelopeDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobListEnvelopeDto> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_list',
          params: <String, dynamic>{
            'p_profession_id': ?professionId,
            'p_search': ?search,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return JobListEnvelopeDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobListEnvelopeDto> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'job_list_mine',
          params: <String, dynamic>{
            'p_role': role,
            'p_status': ?status,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return JobListEnvelopeDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobApplicationDto> submitApplication({
    required String jobId,
    required String coverNote,
    double? quotedAmount,
    String currencyCode = 'NGN',
    int? durationDays,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'application_submit',
          params: <String, dynamic>{
            'p_job_id': jobId,
            'p_cover_note': coverNote,
            'p_quoted_amount': ?quotedAmount,
            'p_currency_code': currencyCode,
            'p_duration_days': ?durationDays,
          },
        );
    return JobApplicationDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobApplicationDto> withdrawApplication(String applicationId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'application_withdraw',
              params: <String, dynamic>{'p_application_id': applicationId},
            );
        return JobApplicationDto.fromJson(JobsEnvelopeParser.unwrap(response));
      });

  @override
  Future<JobApplicationDto> shortlistApplication(String applicationId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'application_shortlist',
              params: <String, dynamic>{'p_application_id': applicationId},
            );
        return JobApplicationDto.fromJson(JobsEnvelopeParser.unwrap(response));
      });

  @override
  Future<JobApplicationDto> rejectApplication(String applicationId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'application_reject',
              params: <String, dynamic>{'p_application_id': applicationId},
            );
        return JobApplicationDto.fromJson(JobsEnvelopeParser.unwrap(response));
      });

  @override
  Future<ApplicationListEnvelopeDto> listApplicationsForJob(
    String jobId, {
    String? status,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'application_list_for_job',
          params: <String, dynamic>{
            'p_job_id': jobId,
            'p_status': ?status,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return ApplicationListEnvelopeDto.fromJson(
      JobsEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<ApplicationListEnvelopeDto> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'application_list_mine',
          params: <String, dynamic>{
            'p_status': ?status,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return ApplicationListEnvelopeDto.fromJson(
      JobsEnvelopeParser.unwrap(response),
    );
  });
}
