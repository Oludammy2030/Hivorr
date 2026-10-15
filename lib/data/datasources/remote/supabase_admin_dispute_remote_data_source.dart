// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/admin_dispute_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/dispute_envelope_parser.dart';
import 'package:hivorr/data/models/dispute_admin_list_envelope_dto.dart';
import 'package:hivorr/data/models/service_dispute_detail_envelope_dto.dart';

/// Supabase-backed implementation of [AdminDisputeRemoteDataSource] (R3).
///
/// Calls the admin-gated RPCs with the caller's user JWT; the server enforces
/// `is_platform_admin()` in the function body (PLT002 otherwise). Shares the
/// standard `{success, code, message, data}` envelope via
/// [DisputeEnvelopeParser] — no second envelope shape is invented.
class SupabaseAdminDisputeRemoteDataSource extends BaseApiService
    implements AdminDisputeRemoteDataSource {
  SupabaseAdminDisputeRemoteDataSource({
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
  Future<DisputeAdminListEnvelopeDto> adminListDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'service_dispute_admin_list',
          params: <String, dynamic>{
            'p_status': ?status,
            'p_limit': limit,
            'p_offset': offset,
          },
        );
    final Map<String, dynamic> data = DisputeEnvelopeParser.unwrap(response);
    return DisputeAdminListEnvelopeDto.fromJson(data);
  });

  @override
  Future<ServiceDisputeDetailEnvelopeDto> adminGetCase(String caseId) =>
      _guard(() async {
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'service_dispute_admin_get',
              params: <String, dynamic>{'p_case_id': caseId},
            );
        final Map<String, dynamic> data = DisputeEnvelopeParser.unwrap(
          response,
        );
        return ServiceDisputeDetailEnvelopeDto.fromJson(data);
      });
}
