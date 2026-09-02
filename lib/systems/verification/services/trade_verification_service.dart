// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin orchestration facade over the trade-verification data layer
/// (EP-02-11 §5.4).
///
/// Consumed by [TradeVerificationProvider] and future onboarding. Adds
/// PII-safe [HivorrLogger] output (entity id suffix, proof type, byte length,
/// MIME, profession id — never the full `document_path` or bytes) and a
/// `trade.proof.submit.duration` [PerformanceTracer] span.
class TradeVerificationService {
  /// Creates the facade bound to [repo].
  TradeVerificationService({
    required TradeVerificationRepository repo,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repo = repo,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final TradeVerificationRepository _repo;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// All supported trade-proof types (extensible: adding a value is just a
  /// label + `kind` mapping, no schema change).
  List<TradeProofType> get supportedTradeProofTypes => TradeProofType.values;

  /// Submits a trade proof, tracing + logging the operation.
  ///
  /// Delegates to the repository; [onProgress] streams upload progress through.
  Future<VerificationSubmission> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final span = _tracer?.startTransaction('trade.proof.submit', 'verification');
    _logger?.info('Trade proof submission started', <String, Object?>{
      'tradeType': type.name,
      'byteLength': bytes.length,
      'mimeType': mimeType,
      'professionId': _redactor.redact(professionId),
    });
    try {
      final VerificationSubmission submission = await _repo.submitTradeProof(
        type: type,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      );
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      _logger?.info('Trade proof submission completed', <String, Object?>{
        'tradeType': type.name,
        'submissionId': submission.id,
        'entityId': _redactor.redact(submission.entityId),
      });
      return submission;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Trade proof submission failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'tradeType': type.name},
      );
      rethrow;
    }
  }

  /// Fetches the trade-verification aggregate.
  Future<TradeVerificationStatus> getStatus() => _repo.getStatus();
}
