import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/hires_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/jobs_envelope_parser.dart';
import 'package:hivorr/data/models/hire_dto.dart';
import 'package:hivorr/data/models/hire_envelopes_dto.dart';
import 'package:hivorr/data/models/job_quotation_dto.dart';

/// Supabase-backed implementation of [HiresRemoteDataSource] (EP-04-02).
///
/// Wraps the **eight client-callable** hiring RPCs via `supabase.rpc(...)`
/// and unwraps the standard `{success, code, message, data}` envelope with
/// [JobsEnvelopeParser] (shared envelope contract with the jobs RPCs).
class SupabaseHiresRemoteDataSource extends BaseApiService
    implements HiresRemoteDataSource {
  SupabaseHiresRemoteDataSource({
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
  Future<JobQuotationDto> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'quotation_propose',
          params: <String, dynamic>{
            'p_application_id': applicationId,
            'p_amount': amount,
            'p_currency_code': currencyCode,
            'p_duration_days': ?durationDays,
            'p_message': ?message,
          },
        );
    return JobQuotationDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<JobQuotationDto> withdrawQuotation(String quotationId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'quotation_withdraw',
              params: <String, dynamic>{'p_quotation_id': quotationId},
            );
        return JobQuotationDto.fromJson(JobsEnvelopeParser.unwrap(response));
      });

  @override
  Future<JobQuotationDto> acceptQuotation(String quotationId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'quotation_accept',
              params: <String, dynamic>{'p_quotation_id': quotationId},
            );
        return JobQuotationDto.fromJson(JobsEnvelopeParser.unwrap(response));
      });

  @override
  Future<HireAcceptEnvelopeDto> acceptHire(
    String applicationId, {
    String? quotationId,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'hire_accept',
          params: <String, dynamic>{
            'p_application_id': applicationId,
            'p_quotation_id': ?quotationId,
          },
        );
    return HireAcceptEnvelopeDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<HireDetailEnvelopeDto> getHire(String hireId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'hire_get',
          params: <String, dynamic>{'p_hire_id': hireId},
        );
    return HireDetailEnvelopeDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<HireListEnvelopeDto> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'hire_list_mine',
          params: <String, dynamic>{
            'p_role': ?role,
            'p_status': ?status,
            'p_limit': limit,
            'p_cursor': ?cursor,
          },
        );
    return HireListEnvelopeDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });

  @override
  Future<HireDto> cancelHire(String hireId, {String? reason}) => _guard(
    () async {
      final Map<String, dynamic> response = await supabase
          .rpc<Map<String, dynamic>>(
            'hire_cancel',
            params: <String, dynamic>{'p_hire_id': hireId, 'p_reason': ?reason},
          );
      return HireDto.fromJson(JobsEnvelopeParser.unwrap(response));
    },
  );

  @override
  Future<HireDto> completeHire(String hireId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'hire_complete',
          params: <String, dynamic>{'p_hire_id': hireId},
        );
    return HireDto.fromJson(JobsEnvelopeParser.unwrap(response));
  });
}
