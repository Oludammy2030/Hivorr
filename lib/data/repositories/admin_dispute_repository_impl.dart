// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/admin_dispute_remote_data_source.dart';
import 'package:hivorr/data/mappers/dispute_mapper.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/repositories/admin_dispute_repository.dart';

/// Default implementation of [AdminDisputeRepository] (R3 follow-up).
///
/// Read-only server-administration seam: fails fast on known-invalid filters
/// (status vocabulary, limit bounds, negative offset) and maps rows through
/// [DisputeMapper]. Never writes dispute tables and never references
/// `dispute_resolve` (AGENT.md Rule 4).
class AdminDisputeRepositoryImpl implements AdminDisputeRepository {
  AdminDisputeRepositoryImpl({required AdminDisputeRemoteDataSource remote})
    : _remote = remote;

  final AdminDisputeRemoteDataSource _remote;

  static const Set<String> _statuses = <String>{
    'open',
    'under_review',
    'resolved',
    'closed',
    'withdrawn',
  };

  @override
  Future<AdminDisputePage> listDisputes({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    if (status != null && !_statuses.contains(status)) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid status value.',
        code: 'PLT003',
      );
    }
    if (limit < 1 || limit > 100) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Limit must be between 1 and 100.',
        code: 'PLT003',
      );
    }
    if (offset < 0) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Offset must be zero or greater.',
        code: 'PLT003',
      );
    }
    final dto = await _remote.adminListDisputes(
      status: status,
      limit: limit,
      offset: offset,
    );
    return AdminDisputePage(
      items: dto.disputes.map(DisputeMapper.caseToEntity).toList(
        growable: false,
      ),
      totalCount: dto.totalCount,
    );
  }

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async {
    if (caseId.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'caseId is required.',
        code: 'PLT003',
      );
    }
    final dto = await _remote.adminGetCase(caseId);
    return DisputeMapper.serviceDetailToEntity(dto);
  }
}
