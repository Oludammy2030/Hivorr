import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/business_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/models/business_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';

/// Supabase-backed implementation of [BusinessRemoteDataSource]
/// (identity audit Phase 2a).
///
/// Businesses and memberships are RLS-CRUD rows (member-scoped policies +
/// admin policies; `anon` 0) — no dedicated RPC. Evidence flows through the
/// extended `entity_credentials_submit` (business_document kind) and the
/// generic `verification_submit`, unwrapped with [VerificationEnvelopeParser].
/// This class never writes verification state directly.
class SupabaseBusinessRemoteDataSource extends BaseApiService
    implements BusinessRemoteDataSource {
  SupabaseBusinessRemoteDataSource({
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
  Future<List<BusinessDto>> listMine({required String entityId}) =>
      _guard(() async {
        // Membership-first read: the roster join keeps the caller's role +
        // authorization on each row; RLS narrows to member businesses.
        final List<dynamic> rows = await supabase
            .from('business_memberships')
            .select('*, businesses(*)')
            .eq('entity_id', entityId);
        final List<BusinessDto> out = <BusinessDto>[];
        for (final Object? row in rows) {
          if (row is! Map<String, dynamic>) continue;
          final BusinessMembershipDto membership =
              BusinessMembershipDto.fromJson(row);
          final BusinessDto? business = membership.business;
          if (business == null || business.id.isEmpty) continue;
          out.add(
            BusinessDto(
              id: business.id,
              tradingName: business.tradingName,
              registeredLegalName: business.registeredLegalName,
              cacNumber: business.cacNumber,
              status: business.status,
              membership: membership,
            ),
          );
        }
        return out;
      });

  @override
  Future<BusinessDto> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  }) => _guard(() async {
    final Map<String, dynamic>? row = await supabase
        .from('businesses')
        .insert(<String, dynamic>{
          'trading_name': tradingName,
          'registered_legal_name': registeredLegalName,
          'cac_number': ?cacNumber,
        })
        .select()
        .maybeSingle();
    if (row == null) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Business could not be created.',
        code: 'PLT999',
      );
    }
    return BusinessDto.fromJson(row);
  });

  @override
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  }) => _guard(() async {
    await supabase.from('business_memberships').insert(<String, dynamic>{
      'business_id': businessId,
      'entity_id': entityId,
      'role': 'representative',
    });
  });

  @override
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  }) => _guard(() async {
    await supabase
        .from('business_memberships')
        .delete()
        .eq('business_id', businessId)
        .eq('entity_id', entityId);
  });

  @override
  Future<Map<String, dynamic>> submitCredential({
    required String businessId,
    required String title,
    required String documentPath,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'entity_credentials_submit',
          params: <String, dynamic>{
            'p_kind': 'business_document',
            'p_title': title,
            'p_document_path': documentPath,
            'p_business_id': businessId,
          },
        );
    return VerificationEnvelopeParser.unwrap(response);
  });

  @override
  Future<VerificationSubmissionDto> queueSubmission({
    required String credentialId,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'verification_submit',
          params: <String, dynamic>{
            'p_credential_id': credentialId,
            'p_submission_type': 'business_verification',
          },
        );
    return VerificationSubmissionDto.fromJson(
      VerificationEnvelopeParser.unwrap(response),
    );
  });
}
