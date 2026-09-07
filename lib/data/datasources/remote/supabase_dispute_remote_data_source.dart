import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/dispute_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/dispute_remote_data_source.dart';
import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';

/// Supabase-backed implementation of [DisputeRemoteDataSource] (EP-02-17 §5.3).
///
/// Wraps the **five client-callable** dispute RPCs via `supabase.rpc(...)`
/// and unwraps the standard `{success, code, message, data}` envelope with
/// [DisputeEnvelopeParser]. `dispute_withdraw` is SECURITY DEFINER server-side
/// but is called exactly like the other entity RPCs (`p_case_id`) — filer
/// scoping is enforced inside the function body.
///
/// This class **never** calls `dispute_resolve` (server-granted only,
/// `20260829120005:874`) — it is absent from the entire client contract.
class SupabaseDisputeRemoteDataSource extends BaseApiService
    implements DisputeRemoteDataSource {
  SupabaseDisputeRemoteDataSource({
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
  Future<DisputeListEnvelopeDto> listDisputes({String? status}) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'dispute_list',
          params: <String, dynamic>{
            'p_status': ?status,
          },
        );
        final Map<String, dynamic> data =
            DisputeEnvelopeParser.unwrap(response);
        return DisputeListEnvelopeDto.fromJson(data);
      });

  @override
  Future<DisputeCaseDetailEnvelopeDto> getCase(String caseId) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'dispute_get',
          params: <String, dynamic>{'p_case_id': caseId},
        );
        final Map<String, dynamic> data =
            DisputeEnvelopeParser.unwrap(response);
        return DisputeCaseDetailEnvelopeDto.fromJson(data);
      });

  @override
  Future<DisputeCaseDto> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'dispute_file',
          params: <String, dynamic>{
            'p_escrow_id': escrowId,
            'p_dispute_type': disputeType,
            'p_reason': reason,
            'p_desired_outcome': ?desiredOutcome,
            'p_priority': priority,
          },
        );
        final Map<String, dynamic> data =
            DisputeEnvelopeParser.unwrap(response);
        return DisputeCaseDto.fromJson(data);
      });

  @override
  Future<DisputeEvidenceDto> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  }) =>
      _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'dispute_submit_evidence',
          params: <String, dynamic>{
            'p_case_id': caseId,
            'p_evidence_type': evidenceType,
            'p_title': title,
            'p_description': ?description,
            'p_file_url': ?fileUrl,
            'p_file_metadata': fileMetadata,
          },
        );
        final Map<String, dynamic> data =
            DisputeEnvelopeParser.unwrap(response);
        return DisputeEvidenceDto.fromJson(data);
      });

  @override
  Future<DisputeCaseDto> withdrawDispute(String caseId) => _guard(() async {
        final Map<String, dynamic> response =
            await supabase.rpc<Map<String, dynamic>>(
          'dispute_withdraw',
          params: <String, dynamic>{'p_case_id': caseId},
        );
        final Map<String, dynamic> data =
            DisputeEnvelopeParser.unwrap(response);
        return DisputeCaseDto.fromJson(data);
      });
}
