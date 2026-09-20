// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/manage_user_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/models/manage_user_dto.dart';

/// Supabase-backed implementation of [ManageUserRemoteDataSource] (EP-02-11
/// §5.2).
///
/// Accesses Supabase only through the injected [BaseApiService] accessors.
/// Admin authorization is enforced server-side by `is_platform_admin()`;
/// the client never caches or trusts the admin flag beyond the current session.
class SupabaseManageUserRemoteDataSource extends BaseApiService
    implements ManageUserRemoteDataSource {
  SupabaseManageUserRemoteDataSource({
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
  Future<ManageUserListEnvelopeDto> listUsers({
    String? search,
    String? status,
    int offset = 0,
    int limit = 20,
  }) => _guard(() async {
    final Map<String, dynamic> params = <String, dynamic>{
      'p_offset': offset,
      'p_limit': limit,
    };
    if (search != null && search.isNotEmpty) {
      params['p_search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      params['p_status'] = status;
    }
    final Map<String, dynamic> envelope = await supabase
        .rpc<Map<String, dynamic>>('manage_user_list', params: params);
    final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
      envelope,
    );
    return ManageUserListEnvelopeDto.fromJson(data);
  });

  @override
  Future<ManageUserDetailDto> getUser(String userId) => _guard(() async {
    final Map<String, dynamic> envelope = await supabase
        .rpc<Map<String, dynamic>>(
          'manage_user_get',
          params: <String, dynamic>{'p_user_id': userId},
        );
    final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
      envelope,
    );
    final Object? user = data['user'];
    if (user is! Map) {
      throw const FormatException('Malformed manage_user_get payload.');
    }
    return ManageUserDetailDto.fromJson(Map<String, dynamic>.from(user));
  });

  @override
  Future<void> setUserStatus(String userId, String status) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'manage_user_set_status',
          params: <String, dynamic>{'p_user_id': userId, 'p_status': status},
        );
    VerificationEnvelopeParser.unwrap(response);
  });

  @override
  Future<void> resetOnboarding(String userId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'manage_user_reset_onboarding',
          params: <String, dynamic>{'p_user_id': userId},
        );
    VerificationEnvelopeParser.unwrap(response);
  });
}
