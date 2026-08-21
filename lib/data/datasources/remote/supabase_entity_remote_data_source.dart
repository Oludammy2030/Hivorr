import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/entity_remote_data_source.dart';
import 'package:hivorr/data/models/entity_profile_dto.dart';
import 'package:hivorr/data/models/entity_role_dto.dart';

/// Supabase-backed implementation of [EntityRemoteDataSource].
///
/// Accesses Supabase **only** through the injected [BaseApiService] accessors
/// (never constructs clients). All reads are self-scoped by RLS; all writes go
/// through EP-01-06 RPCs. Any transport/PostgREST/`PLT*` failure is normalized
/// to an [ApiException] before crossing the repository boundary
/// (EP-01-08 §5.4, §12).
class SupabaseEntityRemoteDataSource extends BaseApiService
    implements EntityRemoteDataSource {
  /// Creates the datasource from the single EP-01-07 API channel.
  SupabaseEntityRemoteDataSource({
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
  Future<EntityProfileDto?> getProfile(String entityId) => _guard(() async {
        final Map<String, dynamic>? row = await supabase
            .from('entity_profiles')
            .select()
            .eq('entity_id', entityId)
            .maybeSingle();
        if (row == null) {
          return null;
        }
        return EntityProfileDto.fromJson(row);
      });

  @override
  Future<EntityProfileDto> updateProfile({
    required String entityId,
    required String legalName,
    required String displayName,
    String? bio,
  }) =>
      _guard(() async {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_legal_name': legalName,
          'p_display_name': displayName,
          'p_bio': bio,
        };
        await supabase.rpc<void>('entity_profile_update', params: params);
        final Map<String, dynamic>? row = await supabase
            .from('entity_profiles')
            .select()
            .eq('entity_id', entityId)
            .maybeSingle();
        if (row == null) {
          throw const ApiException(
            kind: ApiExceptionKind.notFound,
            message: 'Profile not found.',
            code: 'PLT004',
          );
        }
        return EntityProfileDto.fromJson(row);
      });

  @override
  Future<void> activateRole({
    required String entityId,
    required String role,
  }) =>
      _guard(() async {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_role': role,
        };
        await supabase.rpc<void>('entity_roles_activate', params: params);
      });

  @override
  Future<List<EntityRoleDto>> getRoles(String entityId) => _guard(() async {
        final List<Map<String, dynamic>> rows = await supabase
            .from('entity_roles')
            .select()
            .eq('entity_id', entityId);
        return rows.map(EntityRoleDto.fromJson).toList();
      });
}
