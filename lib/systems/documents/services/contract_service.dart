// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_paths.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/mappers/contract_mapper.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin facade over [ServiceContractRepository] consumed by
/// [ServiceContractProvider] and the contract screens (EP-03-10 §8 D6).
///
/// Exposes the contract/milestone/event/currency vocabularies (compile-time
/// const, mirroring the frozen CHECK constraints) plus the fail-fast
/// validators [validateMilestoneTitle]/[validateMilestoneDescription]/
/// [validateTotal]/[validateMilestoneSums]/[validateCurrency]/[validateExpiry],
/// and delegates data operations to the repository. Adds PII-safe structured
/// [HivorrLogger] output (contract id suffix, status deltas — never milestone
/// titles, descriptions, or evidence paths in full) and
/// `contracts.*` [PerformanceTracer] spans.
///
/// Evidence orchestration follows the storage-before-RPC pattern (copied from
/// `ServiceListingService.uploadMedia`): `validate →
/// upload(service-listing-media) → complete_milestone(path)`. Orphan bytes are
/// removed when the RPC step fails. This service never funds, releases, or
/// refunds escrow — that belongs to the EP-03-11 orchestrator.
class ContractService {
  ContractService({
    required ServiceContractRepository repository,
    SupabaseClient? supabase,
    StorageService? storage,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _repository = repository,
       _supabase = supabase,
       _storage = storage,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final ServiceContractRepository _repository;

  /// Supabase client for evidence-row reads. Nullable so contract widget tests
  /// can run without a networked auth client; [uploadEvidence] fails closed
  /// with `PLT999`/`PLT001` when absent.
  final SupabaseClient? _supabase;
  final StorageService? _storage;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints) ────────────────────

  /// Contract status vocabulary (`service_contracts_status_allowed`).
  static const List<String> contractStatuses = <String>[
    'draft',
    'offered',
    'active',
    'completed',
    'disputed',
    'closed',
    'cancelled',
  ];

  /// Milestone status vocabulary (`contract_milestones_status_allowed`).
  static const List<String> milestoneStatuses = <String>[
    'pending',
    'completed',
    'verified',
    'released',
  ];

  /// Contract event vocabulary (`contract_events_event_type_allowed`).
  static const List<String> eventTypes = <String>[
    'offered',
    'accepted',
    'cancelled',
    'milestone_completed',
    'milestone_verified',
    'revision_requested',
    'closed',
    'disputed',
  ];

  /// Active currency subset (`financial_supported_currencies`).
  static const List<String> currencies = <String>[
    'NGN',
    'GHS',
    'USD',
    'GBP',
  ];

  /// Verify actions accepted by `service_contract_verify_milestone`.
  static const List<String> verifyActions = <String>[
    'verified',
    'revision_requested',
  ];

  // ─── Fail-fast validators (mirror CHECKs; server stays authoritative) ──

  /// `true` when [title] is 1–255 chars after trim.
  static bool validateMilestoneTitle(String title) {
    final int length = title.trim().length;
    return length >= 1 && length <= 255;
  }

  /// `true` when [description] is absent or ≤2000 chars after trim.
  static bool validateMilestoneDescription(String? description) {
    if (description == null || description.trim().isEmpty) return true;
    return description.trim().length <= 2000;
  }

  /// `true` when [totalAmount] is greater than zero.
  static bool validateTotal(double? totalAmount) =>
      totalAmount != null && totalAmount > 0;

  /// `true` when [milestoneAmounts] is non-empty and sums to [totalAmount]
  /// within the `0.01` server tolerance (mirrors `EscrowService`
  /// fail-fast semantics).
  static bool validateMilestoneSums({
    required double totalAmount,
    required List<double> milestoneAmounts,
  }) {
    if (milestoneAmounts.isEmpty) return false;
    final double sum = milestoneAmounts.fold(
      0.0,
      (double acc, double amount) => acc + amount,
    );
    return (sum - totalAmount).abs() <= 0.01;
  }

  /// `true` when [currencyCode] is in the active subset.
  static bool validateCurrency(String currencyCode) =>
      currencies.contains(currencyCode);

  /// `true` when [expiry] is absent or in the future.
  static bool validateExpiry(DateTime? expiry) {
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  // ─── Data operations (delegate to repository, traced + logged) ─────────

  Future<ServiceContractPage> listMine({
    String? status,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('contracts.list', () async {
    final page = await _repository.listMine(
      status: status,
      limit: limit,
      cursor: cursor,
    );
    _logger?.info('Contract list fetched', <String, Object?>{
      'statusFilter': status,
      'contractCount': page.items.length,
      'hasMore': page.hasMore,
    });
    return page;
  });

  Future<ServiceContract> getContract(String contractId) =>
      _tracedAndLogged('contracts.get', () async {
        final contract = await _repository.getContract(contractId);
        _logger?.info('Contract detail fetched', <String, Object?>{
          'contractId': _redactor.redact(contract.id),
          'status': contract.status,
          'milestoneCount': contract.milestones.length,
        });
        return contract;
      });

  Future<ServiceContract> offerContract({
    required String serviceListingId,
    required double totalAmount,
    String currencyCode = 'NGN',
    required List<ContractMilestoneInput> milestones,
    DateTime? offerExpiresAt,
  }) => _tracedAndLogged('contracts.offer', () async {
    _logger?.info('Creating contract offer', <String, Object?>{
      'currencyCode': currencyCode,
      'totalAmount': totalAmount,
      'milestoneCount': milestones.length,
    });
    final contract = await _repository.offerContract(
      serviceListingId: serviceListingId,
      totalAmount: totalAmount,
      currencyCode: currencyCode,
      milestones: milestones,
      offerExpiresAt: offerExpiresAt,
    );
    _logger?.info('Contract offered', <String, Object?>{
      'contractId': _redactor.redact(contract.id),
      'status': contract.status,
    });
    return contract;
  });

  Future<ServiceContract> acceptContract(String contractId) =>
      _tracedAndLogged('contracts.accept', () async {
        final contract = await _repository.acceptContract(contractId);
        _logger?.info('Contract accepted', <String, Object?>{
          'contractId': _redactor.redact(contract.id),
          'status': contract.status,
        });
        return contract;
      });

  Future<ServiceContract> cancelContract(
    String contractId, {
    String? reason,
  }) => _tracedAndLogged('contracts.cancel', () async {
    final contract = await _repository.cancelContract(
      contractId,
      reason: reason,
    );
    _logger?.info('Contract cancelled', <String, Object?>{
      'contractId': _redactor.redact(contract.id),
      'status': contract.status,
    });
    return contract;
  });

  Future<ServiceContract> completeMilestone({
    required String contractId,
    required String milestoneId,
    String? evidencePath,
  }) => _tracedAndLogged('contracts.milestone.complete', () async {
    final contract = await _repository.completeMilestone(
      contractId: contractId,
      milestoneId: milestoneId,
      evidencePath: evidencePath,
    );
    _logger?.info('Contract milestone completed', <String, Object?>{
      'contractId': _redactor.redact(contractId),
      'milestoneId': _redactor.redact(milestoneId),
      'status': contract.status,
    });
    return contract;
  });

  Future<ServiceContract> verifyMilestone({
    required String contractId,
    required String milestoneId,
    String action = 'verified',
  }) => _tracedAndLogged('contracts.milestone.verify', () async {
    final contract = await _repository.verifyMilestone(
      contractId: contractId,
      milestoneId: milestoneId,
      action: action,
    );
    _logger?.info('Contract milestone verified', <String, Object?>{
      'contractId': _redactor.redact(contractId),
      'milestoneId': _redactor.redact(milestoneId),
      'action': action,
    });
    return contract;
  });

  Future<ServiceContract> closeContract(String contractId) =>
      _tracedAndLogged('contracts.close', () async {
        final contract = await _repository.closeContract(contractId);
        _logger?.info('Contract closed', <String, Object?>{
          'contractId': _redactor.redact(contract.id),
          'status': contract.status,
        });
        return contract;
      });

  /// Uploads evidence bytes to `service-listing-media` under the
  /// professional-owner prefix, then marks the milestone `completed` with the
  /// uploaded path (storage-before-RPC).
  ///
  /// Returns the re-read [ServiceContract]. Removes the uploaded bytes when
  /// the RPC step fails so no orphan objects accumulate.
  Future<ServiceContract> completeMilestoneWithEvidence({
    required String contractId,
    required String milestoneId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final StorageService? storage = _storage;
    final SupabaseClient? supabase = _supabase;
    if (storage == null || supabase == null) {
      throw const ApiException(
        kind: ApiExceptionKind.server,
        message: 'Evidence upload is unavailable.',
        code: 'PLT999',
      );
    }
    final String? entityId = supabase.auth.currentUser?.id;
    if (entityId == null || entityId.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.auth,
        message: 'Authentication required.',
        code: 'PLT001',
      );
    }
    storage.validateForBucket(
      bucket: StorageBuckets.serviceListingMedia,
      mimeType: mimeType,
      byteLength: bytes.lengthInBytes,
    );
    final String storagePath = StoragePaths.listingMedia(
      entityId: entityId,
      listingId: contractId,
      fileName: fileName,
    );
    final String storageKey = await storage.upload(
      bucket: StorageBuckets.serviceListingMedia,
      path: storagePath,
      bytes: bytes,
      mimeType: mimeType,
      fileName: fileName,
      onProgress: onProgress,
    );
    try {
      return await completeMilestone(
        contractId: contractId,
        milestoneId: milestoneId,
        evidencePath: storageKey,
      );
    } catch (_) {
      try {
        await storage.remove(
          bucket: StorageBuckets.serviceListingMedia,
          paths: <String>[storageKey],
        );
      } on Object {
        // Best-effort orphan cleanup; the original error propagates.
      }
      rethrow;
    }
  }

  /// Resolves a public URL for an evidence path, or `null` when storage
  /// is unavailable (callers render a type placeholder instead).
  String? evidencePublicUrl(String storagePath) {
    final StorageService? storage = _storage;
    if (storage == null) return null;
    try {
      return storage.getPublicUrl(
        bucket: StorageBuckets.serviceListingMedia,
        path: storagePath,
      );
    } on Object {
      return null;
    }
  }

  /// Wraps [action] in a `contracts.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'contracts');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}
