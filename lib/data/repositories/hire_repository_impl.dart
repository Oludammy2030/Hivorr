// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/hires_remote_data_source.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/mappers/hire_mapper.dart';
import 'package:hivorr/data/mappers/job_mapper.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';

/// Default implementation of [HireRepository].
///
/// Implements the server-authoritative hiring flow (EP-04-02): writes via the
/// client-callable quotation/hire RPCs, reads via `hire_get`/`hire_list_mine`
/// mapped through [HireMapper] (and [JobMapper] for the joined job payload).
/// Known CHECK constraints are pre-validated client-side so a preventable
/// `PLT003` never round-trips. This implementation never writes hiring tables
/// directly (AGENT.md Rule 4).
class HireRepositoryImpl implements HireRepository {
  HireRepositoryImpl({required HiresRemoteDataSource remote})
    : _remote = remote;

  final HiresRemoteDataSource _remote;

  // Validation mirrors of the frozen CHECK constraints
  // (`20260928090002_quotations_hires_schema.sql:66-81,105-113`).
  static const Set<String> _hireStatuses = <String>{
    'pending',
    'active',
    'completed',
    'cancelled',
    'disputed',
  };
  static const Set<String> _hireRoles = <String>{'client', 'professional'};

  @override
  Future<JobQuotation> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  }) async {
    _requireNonEmpty(applicationId, 'applicationId');
    if (amount <= 0) _fail('Quotation amount must be greater than zero.');
    _requireCurrency(currencyCode);
    if (durationDays != null && durationDays < 1) {
      _fail('Duration must be at least 1 day.');
    }
    if (message != null && message.length > 2000) {
      _fail('Quotation message must be at most 2000 characters.');
    }
    return HireMapper.quotationToEntity(
      await _remote.proposeQuotation(
        applicationId: applicationId,
        amount: amount,
        currencyCode: currencyCode,
        durationDays: durationDays,
        message: message?.trim().isEmpty ?? true ? null : message?.trim(),
      ),
    );
  }

  @override
  Future<JobQuotation> withdrawQuotation(String quotationId) async {
    _requireNonEmpty(quotationId, 'quotationId');
    return HireMapper.quotationToEntity(
      await _remote.withdrawQuotation(quotationId),
    );
  }

  @override
  Future<JobQuotation> acceptQuotation(String quotationId) async {
    _requireNonEmpty(quotationId, 'quotationId');
    return HireMapper.quotationToEntity(
      await _remote.acceptQuotation(quotationId),
    );
  }

  @override
  Future<HireAcceptResult> acceptHire(
    String applicationId, {
    String? quotationId,
  }) async {
    _requireNonEmpty(applicationId, 'applicationId');
    final envelope = await _remote.acceptHire(
      applicationId,
      quotationId: quotationId,
    );
    return HireAcceptResult(
      hire: HireMapper.hireToEntity(envelope.hire),
      contractId: envelope.contractId,
    );
  }

  @override
  Future<HireDetail> getHire(String hireId) async {
    _requireNonEmpty(hireId, 'hireId');
    final dto = await _remote.getHire(hireId);
    final Map<String, dynamic>? contract = dto.contract;
    return HireDetail(
      hire: HireMapper.hireToEntity(
        dto.hire,
      ).copyWithEffective(dto.effectiveStatus),
      effectiveStatus: dto.effectiveStatus,
      jobId: dto.job.id,
      jobTitle: dto.job.title,
      applicationId: dto.application.id,
      quotation: dto.quotation == null
          ? null
          : HireMapper.quotationToEntity(dto.quotation!),
      contractId: contract?['id'] as String?,
      contractStatus: contract?['status'] as String?,
    );
  }

  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    if (role != null) _requireInVocabulary(role, _hireRoles, 'role');
    if (status != null) _requireInVocabulary(status, _hireStatuses, 'status');
    _requireLimit(limit);
    final dto = await _remote.listMyHires(
      role: role,
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return HirePage(
      hires: HireMapper.listEnvelopeToEntities(dto),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  @override
  Future<Hire> cancelHire(String hireId, {String? reason}) async {
    _requireNonEmpty(hireId, 'hireId');
    return HireMapper.hireToEntity(
      await _remote.cancelHire(hireId, reason: reason),
    );
  }

  @override
  Future<Hire> completeHire(String hireId) async {
    _requireNonEmpty(hireId, 'hireId');
    return HireMapper.hireToEntity(await _remote.completeHire(hireId));
  }

  void _requireCurrency(String currency) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency.trim().toUpperCase())) {
      _fail('Invalid currency code.');
    }
  }

  void _requireLimit(int limit) {
    if (limit < 1 || limit > 100) {
      _fail('Limit must be between 1 and 100.');
    }
  }

  static void _fail(String message) {
    throw ApiException(
      kind: ApiExceptionKind.validation,
      message: message,
      code: 'PLT003',
    );
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      _fail('$field is required.');
    }
  }

  static void _requireInVocabulary(
    String value,
    Set<String> vocabulary,
    String field,
  ) {
    if (!vocabulary.contains(value)) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid $field value: $value.',
        code: 'PLT003',
      );
    }
  }
}
