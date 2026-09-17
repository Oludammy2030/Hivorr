import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/onboarding_remote_data_source.dart';
import 'package:hivorr/data/models/onboarding_status_dto.dart';

/// Supabase-backed implementation of [OnboardingRemoteDataSource].
///
/// Accesses Supabase only through the injected [BaseApiService] accessors.
/// Reads and writes go through the EP twins `entity_onboarding_status_get` /
/// `entity_onboarding_status_update` (migration 20260915090001); the direct
/// PostgREST PATCH of `capability` / `onboarding_completed_at` is blocked by
/// the `entities_guard_onboarding_state` trigger, so every mutation flows
/// through the validating RPC.
class SupabaseOnboardingRemoteDataSource extends BaseApiService
    implements OnboardingRemoteDataSource {
  /// Creates the datasource from the single EP-01-07 API channel.
  SupabaseOnboardingRemoteDataSource({
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
  Future<OnboardingStatusDto> getStatus() => _guard(() async {
        final Map<String, dynamic> envelope = await supabase
            .rpc<Map<String, dynamic>>('entity_onboarding_status_get');
        return OnboardingStatusDto.fromJson(_unwrap(envelope));
      });

  @override
  Future<OnboardingStatusDto> updateStatus({
    String? capability,
    bool? completed,
  }) =>
      _guard(() async {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_capability': ?capability,
          'p_completed': ?completed,
        };
        final Map<String, dynamic> envelope = await supabase
            .rpc<Map<String, dynamic>>(
              'entity_onboarding_status_update',
              params: params,
            );
        return OnboardingStatusDto.fromJson(_unwrap(envelope));
      });

  /// Extracts the `data` object from the canonical `{success, code, message,
  /// data}` RPC envelope.
  ///
  /// `PLT000` → success; any other code raises a typed [ApiException] reusing
  /// the server-provided `message` so step-validation guidance (e.g. "Complete
  /// your profile before finishing onboarding.") survives the transport. The
  /// kind mapping mirrors [ApiExceptionMapper]'s `PLT###` contract.
  static Map<String, dynamic> _unwrap(Map<String, dynamic> envelope) {
    final Object? code = envelope['code'];
    if (code != 'PLT000') {
      throw ApiException(
        kind: _kindFor(code?.toString()),
        message:
            (envelope['message'] as String?) ?? 'Onboarding request failed.',
        code: code?.toString(),
      );
    }
    final Object? data = envelope['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(
      kind: ApiExceptionKind.server,
      message: 'Malformed onboarding envelope: data is not an object.',
    );
  }

  static ApiExceptionKind _kindFor(String? code) => switch (code) {
        'PLT001' => ApiExceptionKind.auth,
        'PLT002' => ApiExceptionKind.forbidden,
        'PLT003' => ApiExceptionKind.validation,
        'PLT004' => ApiExceptionKind.notFound,
        'PLT005' => ApiExceptionKind.conflict,
        _ => ApiExceptionKind.server,
      };
}