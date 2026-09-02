// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/datasources/remote/trade_verification_remote_data_source.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/mappers/verification_mapper.dart';
import 'package:hivorr/data/models/trade_verification_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Default implementation of [TradeVerificationRepository] (EP-02-11 §5.3).
///
/// Implements the server-authoritative trade-proof flow: validate → private
/// `credential-documents` upload → `entity_credentials` insert (with
/// `profession_id` binding) → `verification_submit('trade_proof')` queue.
/// Storage is injected so `lib/data/` stays persistence-agnostic; the entity id
/// is resolved from the injected Supabase session (`auth.uid()`), never trusted
/// from callers.
class TradeVerificationRepositoryImpl implements TradeVerificationRepository {
  /// Creates the repository from its datasource, storage, and client deps.
  ///
  /// [resolveProfessionName] resolves a display name for a bound profession to
  /// build the credential title; it defaults to `null` (falls back to the proof
  /// type label). [uuid] is injectable for deterministic tests.
  TradeVerificationRepositoryImpl({
    required TradeVerificationRemoteDataSource remote,
    required StorageService storage,
    required SupabaseClient supabase,
    TradeProfessionNameResolver? resolveProfessionName,
    Uuid? uuid,
  })  : _remote = remote,
        _storage = storage,
        _supabase = supabase,
        _resolveProfessionName = resolveProfessionName,
        _uuid = uuid ?? const Uuid();

  final TradeVerificationRemoteDataSource _remote;
  final StorageService _storage;
  final SupabaseClient _supabase;
  final TradeProfessionNameResolver? _resolveProfessionName;
  final Uuid _uuid;

  @override
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
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

    // 4. Create the trust-evidence credential row bound to the profession.
    final String title = await _buildTitle(professionId, type);
    final Map<String, dynamic> credential = await _insertCredential(
      entityId: entityId,
      title: title,
      documentPath: storageKey,
      professionId: professionId,
    );

    // 5. Queue the submission via the server RPC.
    final VerificationSubmissionDto dto = await _remote.submit(
      credentialId: credential['id'] as String,
      submissionType: TradeProofType.submissionType,
    );

    // 6. Return the mapped domain submission. Trade proofs carry the coarse
    // `submission_type = trade_proof`; the identity [DocumentType] on the
    // shared submission row is a neutral carrier the mapper requires.
    return VerificationMapper.submissionToEntity(
      dto,
      documentType: DocumentType.nationalId,
    );
  }

  Future<String> _buildTitle(String professionId, TradeProofType type) async {
    final String? professionName = _resolveProfessionName == null
        ? null
        : await _resolveProfessionName(professionId);
    if (professionName == null || professionName.isEmpty) {
      return type.label;
    }
    return '$professionName — ${type.label}';
  }

  Future<Map<String, dynamic>> _insertCredential({
    required String entityId,
    required String title,
    required String documentPath,
    required String professionId,
  }) async {
    final List<Map<String, dynamic>> rows = await _supabase
        .from('entity_credentials')
        .insert(<String, dynamic>{
          'entity_id': entityId,
          'kind': TradeProofType.tradeKind,
          'title': title,
          'document_path': documentPath,
          'profession_id': professionId,
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
  Future<TradeVerificationStatus> getStatus() async {
    final dto = await _remote.getStatus();
    return VerificationMapper.tradeStatusToEntity(
      TradeVerificationStatusDto.fromStatusDto(dto),
    );
  }

  String _requireEntityId() {
    final String? entityId = _supabase.auth.currentUser?.id;
    if (entityId == null || entityId.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Authentication required to submit trade proofs.',
        code: 'PLT001',
      );
    }
    return entityId;
  }
}
