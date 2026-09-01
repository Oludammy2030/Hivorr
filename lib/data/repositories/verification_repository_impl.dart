// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/datasources/remote/verification_remote_data_source.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/mappers/verification_mapper.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Default implementation of [VerificationRepository].
///
/// Implements the server-authoritative identity flow (EP-02-10 §5.3):
/// validate → private `credential-documents` upload → `entity_credentials`
/// insert → `verification_submit` queue. Storage is injected so `lib/data/`
/// stays persistence-agnostic; the entity id is resolved from the injected
/// Supabase session (`auth.uid()`), never trusted from callers.
class VerificationRepositoryImpl implements VerificationRepository {
  /// Creates the repository from its datasource, storage, and client deps.
  VerificationRepositoryImpl({
    required VerificationRemoteDataSource remote,
    required StorageService storage,
    required SupabaseClient supabase,
    Uuid? uuid,
  })  : _remote = remote,
        _storage = storage,
        _supabase = supabase,
        _uuid = uuid ?? const Uuid();

  final VerificationRemoteDataSource _remote;
  final StorageService _storage;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  @override
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final String entityId = _requireEntityId();

    // 1. Validate first — before any network call (PLT003 fail-fast).
    _storage.validateForBucket(
      bucket: StorageBuckets.credentialDocuments,
      mimeType: mimeType,
      byteLength: bytes.length,
    );

    // 2. Reserve a submission id for the path helper.
    final String submissionId = _uuid.v4();
    final String storagePath = StoragePaths.credentialDocument(
      entityId: entityId,
      submissionId: submissionId,
      fileName: fileName,
    );

    // 3. Upload to the private bucket.
    final String storageKey = await _storage.upload(
      bucket: StorageBuckets.credentialDocuments,
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
      onProgress: onProgress,
      upsert: false,
    );

    // 4. Create the trust-evidence credential row (server-scoped insert).
    final Map<String, dynamic> credential =
        await _insertCredential(
          entityId: entityId,
          title: documentType.label,
          documentPath: storageKey,
        );

    // 5. Queue the submission via the server RPC.
    final VerificationSubmissionDto dto = await _remote.submit(
      credentialId: credential['id'] as String,
      submissionType: DocumentType.submissionType,
    );

    // 6. Return the mapped domain submission.
    return VerificationMapper.submissionToEntity(
      dto,
      documentType: documentType,
    );
  }

  Future<Map<String, dynamic>> _insertCredential({
    required String entityId,
    required String title,
    required String documentPath,
  }) async {
    final List<Map<String, dynamic>> rows = await _supabase
        .from('entity_credentials')
        .insert(<String, dynamic>{
          'entity_id': entityId,
          'kind': DocumentType.identityKind,
          'title': title,
          'document_path': documentPath,
          'profession_id': null,
        })
        .select()
        .limit(1);
    if (rows.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Credential row could not be created.',
        code: 'PLT999',
      );
    }
    return rows.first;
  }

  @override
  Future<VerificationStatus> getStatus() async {
    final dto = await _remote.getStatus();
    return VerificationMapper.statusToEntity(dto);
  }

  @override
  Future<KycLevel> getKycLevel() async {
    final dto = await _remote.getKycLevel();
    return VerificationMapper.kycToEntity(dto);
  }

  @override
  Future<KycLevel> getLimits() async {
    final dto = await _remote.getLimits();
    return VerificationMapper.kycToEntity(dto);
  }

  String _requireEntityId() {
    final String? entityId = _supabase.auth.currentUser?.id;
    if (entityId == null || entityId.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Authentication required to submit identity documents.',
        code: 'PLT001',
      );
    }
    return entityId;
  }
}
