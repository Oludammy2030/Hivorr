// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/data/datasources/remote/admin_review_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
import 'package:hivorr/data/models/admin_review_dto.dart';

/// Supabase-backed implementation of [AdminReviewRemoteDataSource] (EP-02-11
/// §5.2).
///
/// Accesses Supabase only through the injected [BaseApiService] accessors.
/// Admin authorization is enforced server-side by `is_platform_admin()`;
/// the client never caches or trusts the admin flag beyond the current session.
class SupabaseAdminReviewRemoteDataSource extends BaseApiService
    implements AdminReviewRemoteDataSource {
  SupabaseAdminReviewRemoteDataSource({
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

  int? _lastTotalCount;

  @override
  int? get lastTotalCount => _lastTotalCount;

  @override
  Future<AdminCheckResultDto> checkAdmin() => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>('platform_admin_check');
    final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
      response,
    );
    return AdminCheckResultDto.fromJson(data);
  });

  @override
  Future<List<AdminReviewQueueEntryDto>> getReviewQueue({
    String? submissionType,
    int limit = 50,
    int offset = 0,
    String? search,
    String? professionId,
    String? sort,
  }) => _guard(() async {
    final Map<String, dynamic> params = <String, dynamic>{
      'p_limit': limit,
      'p_offset': offset,
    };
    if (submissionType != null && submissionType.isNotEmpty) {
      params['p_submission_type'] = submissionType;
    }
    if (search != null && search.trim().isNotEmpty) {
      params['p_search'] = search.trim();
    }
    if (professionId != null && professionId.isNotEmpty) {
      params['p_profession_id'] = professionId;
    }
    if (sort != null && sort.isNotEmpty) {
      params['p_sort'] = sort;
    }
    final Map<String, dynamic> envelope = await supabase
        .rpc<Map<String, dynamic>>(
          'verification_review_queue_get',
          params: params,
        );
    final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
      envelope,
    );
    _lastTotalCount = _parseTotalCount(data['total_count']);
    final Object? items = data['submissions'];
    if (items is List) {
      return items
          .cast<Map<String, dynamic>>()
          .map(AdminReviewQueueEntryDto.fromJson)
          .toList(growable: false);
    }
    return const <AdminReviewQueueEntryDto>[];
  });

  @override
  Future<AdminReviewMetricsDto> getReviewMetrics({
    int periodDays = 30,
    String? submissionType,
  }) => _guard(() async {
    final Map<String, dynamic> params = <String, dynamic>{
      'p_days': periodDays,
    };
    if (submissionType != null && submissionType.isNotEmpty) {
      params['p_submission_type'] = submissionType;
    }
    final Map<String, dynamic> envelope = await supabase
        .rpc<Map<String, dynamic>>(
          'verification_review_metrics_get',
          params: params,
        );
    final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
      envelope,
    );
    return AdminReviewMetricsDto.fromJson(data);
  });

  @override
  Future<AdminReviewProfileDto> getReviewProfile(String submissionId) =>
      _guard(() async {
        final Map<String, dynamic> envelope = await supabase
            .rpc<Map<String, dynamic>>(
              'verification_review_profile_get',
              params: <String, dynamic>{'p_submission_id': submissionId},
            );
        final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
          envelope,
        );
        return AdminReviewProfileDto.fromJson(data);
      });

  @override
  Future<void> startReview(String submissionId) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'verification_review_start',
          params: <String, dynamic>{'p_submission_id': submissionId},
        );
    VerificationEnvelopeParser.unwrap(response);
  });

  @override
  Future<void> approveSubmission(String submissionId, {String notes = ''}) =>
      _guard(() async {
        final Map<String, dynamic> params = <String, dynamic>{
          'p_submission_id': submissionId,
          'p_notes': notes,
        };
        final Map<String, dynamic> response = await supabase
            .rpc<Map<String, dynamic>>(
              'verification_review_approve',
              params: params,
            );
        VerificationEnvelopeParser.unwrap(response);
      });

  @override
  Future<void> rejectSubmission(
    String submissionId, {
    String notes = '',
    bool requiresResubmission = false,
  }) => _guard(() async {
    final Map<String, dynamic> params = <String, dynamic>{
      'p_submission_id': submissionId,
      'p_notes': notes,
      'p_requires_resubmission': requiresResubmission,
    };
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'verification_review_reject',
          params: params,
        );
    VerificationEnvelopeParser.unwrap(response);
  });

  @override
  Future<List<AdminReviewAuditEntryDto>> getAuditTrail(String submissionId) =>
      _guard(() async {
        final Map<String, dynamic> envelope = await supabase
            .rpc<Map<String, dynamic>>(
              'verification_review_audit_get',
              params: <String, dynamic>{'p_submission_id': submissionId},
            );
        final Map<String, dynamic> data = VerificationEnvelopeParser.unwrap(
          envelope,
        );
        final Object? items = data['audit_entries'];
        if (items is List) {
          return items
              .cast<Map<String, dynamic>>()
              .map(AdminReviewAuditEntryDto.fromJson)
              .toList(growable: false);
        }
        return const <AdminReviewAuditEntryDto>[];
      });

  @override
  Future<String> createDocumentSignedUrl(
    String credentialId, {
    int expiresIn = 60,
  }) => _guard(() async {
    final List<Map<String, dynamic>> rows = await supabase
        .from('entity_credentials')
        .select('document_path')
        .eq('id', credentialId)
        .limit(1);
    if (rows.isEmpty) {
      throw Exception('Credential not found.');
    }
    final String? documentPath = rows.first['document_path'] as String?;
    if (documentPath == null || documentPath.isEmpty) {
      throw Exception('Credential has no attached document.');
    }
    final String signedUrl = await supabase.storage
        .from(StorageBuckets.credentialDocuments)
        .createSignedUrl(documentPath, expiresIn);
    return signedUrl;
  });

  static int? _parseTotalCount(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
