// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/datasources/remote/business_remote_data_source.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/mappers/business_mapper.dart';
import 'package:hivorr/data/models/business_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/data/repositories/business_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Default implementation of [BusinessRepository] (identity Phase 2a).
///
/// Business CRUD flows through the member-scoped RLS seam; CAC evidence
/// follows the verification pipeline (validate → private `credential-documents`
/// upload → `entity_credentials_submit` with business link → queued
/// `business_verification` submission). The entity id resolves from the
/// injected session, never from callers.
class BusinessRepositoryImpl implements BusinessRepository {
  BusinessRepositoryImpl({
    required BusinessRemoteDataSource remote,
    required StorageService storage,
    required SupabaseClient supabase,
    Uuid? uuid,
  }) : _remote = remote,
       _storage = storage,
       _supabase = supabase,
       _uuid = uuid ?? const Uuid();

  final BusinessRemoteDataSource _remote;
  final StorageService _storage;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  static const int maxTradingNameLength = 120;
  static const int maxLegalNameLength = 255;
  static const int maxCacLength = 64;

  void _requireTradingName(String value) {
    if (value.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Business name cannot be empty.',
        code: 'PLT003',
      );
    }
    if (value.trim().length > maxTradingNameLength) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Business name must be 120 characters or fewer.',
        code: 'PLT003',
      );
    }
  }

  void _requireLegalName(String value) {
    if (value.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Registered legal name cannot be empty.',
        code: 'PLT003',
      );
    }
    if (value.trim().length > maxLegalNameLength) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Registered legal name must be 255 characters or fewer.',
        code: 'PLT003',
      );
    }
  }

  void _requireCac(String? value) {
    if (value == null) return;
    if (value.trim().isEmpty || value.trim().length > maxCacLength) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'CAC number must be 1 to 64 characters.',
        code: 'PLT003',
      );
    }
  }

  @override
  Future<List<Business>> myBusinesses({required String entityId}) async {
    final List<BusinessDto> dtos = await _remote.listMine(entityId: entityId);
    return dtos.map(BusinessMapper.businessToEntity).toList(growable: false);
  }

  @override
  Future<Business> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  }) async {
    _requireTradingName(tradingName);
    _requireLegalName(registeredLegalName);
    _requireCac(cacNumber);
    final BusinessDto dto = await _remote.createBusiness(
      tradingName: tradingName.trim(),
      registeredLegalName: registeredLegalName.trim(),
      cacNumber: cacNumber?.trim().isEmpty ?? true
          ? null
          : cacNumber!.trim(),
    );
    return BusinessMapper.businessToEntity(dto);
  }

  @override
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  }) async {
    if (businessId.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Business id is required.',
        code: 'PLT003',
      );
    }
    await _remote.joinBusiness(businessId: businessId, entityId: entityId);
  }

  @override
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  }) async {
    if (businessId.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Business id is required.',
        code: 'PLT003',
      );
    }
    await _remote.leaveBusiness(businessId: businessId, entityId: entityId);
  }

  @override
  Future<VerificationSubmission> submitDocument({
    required String businessId,
    required String title,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final String entityId = _requireEntityId();
    if (businessId.trim().isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Business id is required.',
        code: 'PLT003',
      );
    }
    if (title.trim().isEmpty || title.trim().length > 255) {
      throw const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Document title must be 1 to 255 characters.',
        code: 'PLT003',
      );
    }

    // 1. Validate first — before any network call (PLT003 fail-fast).
    _storage.validateForBucket(
      bucket: StorageBuckets.credentialDocuments,
      mimeType: mimeType,
      byteLength: bytes.length,
    );

    // 2. Upload to the private bucket.
    final String submissionId = _uuid.v4();
    final String storagePath = StoragePaths.credentialDocument(
      entityId: entityId,
      submissionId: submissionId,
      fileName: fileName,
    );
    final String storageKey = await _storage.upload(
      bucket: StorageBuckets.credentialDocuments,
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
      onProgress: onProgress,
      upsert: false,
    );

    // 3. Create the business-linked credential row (membership-checked RPC).
    final Map<String, dynamic> credential = await _remote.submitCredential(
      businessId: businessId,
      title: title.trim(),
      documentPath: storageKey,
    );

    // 4. Queue into the business_verification lane.
    final VerificationSubmissionDto dto = await _remote.queueSubmission(
      credentialId: credential['id'] as String,
    );
    // Neutral carrier: the server row carries no DocumentType (business lane
    // has its own document kinds); mirrors the trade-proof mapping precedent.
    return VerificationSubmission(
      id: dto.id,
      entityId: dto.entityId,
      credentialId: dto.credentialId,
      documentType: DocumentType.nationalId,
      status: VerificationStatusKind.fromServer(dto.status),
      submittedAt: dto.submittedAt,
      reviewedAt: dto.reviewedAt,
      decisionNotes: dto.decisionNotes,
    );
  }

  String _requireEntityId() {
    final String? entityId = _supabase.auth.currentUser?.id;
    if (entityId == null || entityId.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Authentication required to manage businesses.',
        code: 'PLT001',
      );
    }
    return entityId;
  }
}
