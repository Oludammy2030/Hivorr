// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin orchestration facade over the verification data layer (EP-02-10 §5.4).
///
/// Consumed by [VerificationProvider] and future EP-02-18 onboarding. Adds
/// PII-safe [HivorrLogger] output (entity id suffix, document type, byte
/// length, MIME — never the full `document_path` or bytes) and a
/// `verification.submit.duration` [PerformanceTracer] span.
class IdentityVerificationService {
  /// Creates the facade bound to [repo].
  IdentityVerificationService({
    required VerificationRepository repo,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repo = repo,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final VerificationRepository _repo;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// All supported document types (extensible: adding a value is just a label).
  List<DocumentType> get supportedDocumentTypes => DocumentType.values;

  /// Submits an identity document, tracing + logging the operation.
  ///
  /// Delegates to the repository; [onProgress] streams upload progress through.
  Future<VerificationSubmission> submitIdentityDocument({
    required DocumentType documentType,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final span = _tracer?.startTransaction(
      'verification.submit',
      'verification',
    );
    _logger?.info('Identity document submission started', <String, Object?>{
      'documentType': documentType.name,
      'byteLength': bytes.length,
      'mimeType': mimeType,
    });
    try {
      final VerificationSubmission submission = await _repo.submitIdentityDocument(
        documentType: documentType,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      );
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      _logger?.info('Identity document submission completed', <String, Object?>{
        'documentType': documentType.name,
        'submissionId': submission.id,
        'entityId': _redactor.redact(submission.entityId),
      });
      return submission;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'Identity document submission failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'documentType': documentType.name},
      );
      rethrow;
    }
  }

  /// Fetches the full verification aggregate.
  Future<VerificationStatus> getStatus() => _repo.getStatus();
}
