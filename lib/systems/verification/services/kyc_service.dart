// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/repositories/kyc_repository.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;

/// Thin orchestration facade over the KYC data layer (EP-02-12 §5.4).
///
/// Consumed by [KycProvider] and future EP-02-18 onboarding + EP-02-16 payout
/// guard. Adds PII-safe [HivorrLogger] output (entity id suffix, tier code,
/// provider name, limit values — never `legal_name`, raw NIN/BVN) and
/// `kyc.*.duration` [PerformanceTracer] spans.
class KycService {
  /// Creates the facade bound to [repo].
  KycService({
    required KycRepository repo,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  })  : _repo = repo,
        _logger = logger,
        _tracer = tracer,
        _redactor = redactor ?? PiiRedactor();

  final KycRepository _repo;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  /// All supported tiers with display labels + limit previews.
  List<KycTier> get supportedTiers => KycTier.values;

  /// Fetches the current KYC level.
  Future<KycLevel> getKycLevel() => _tracel('kyc.level.get', _repo.getKycLevel);

  /// Fetches the current tier limits.
  Future<KycLimits> getLimits() => _tracel('kyc.limits.get', _repo.getLimits);

  /// Fetches the full verification aggregate.
  Future<VerificationStatus> getStatus() => _repo.getStatus();

  /// Requests a tier upgrade via the provider seam, logging + tracing.
  Future<KycLevel> requestUpgrade({
    required KycTier targetTier,
    Map<String, dynamic>? payload,
  }) async {
    final span = _tracer?.startTransaction('kyc.upgrade.request', 'kyc');
    _logger?.info('KYC upgrade requested', <String, Object?>{
      'targetTier': targetTier.code,
    });
    try {
      final KycLevel next = await _repo.requestUpgrade(
        targetTier: targetTier,
        payload: payload,
      );
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      _logger?.info('KYC upgrade resolved', <String, Object?>{
        'targetTier': targetTier.code,
        'resultTier': next.tierCode,
        'entityId': _redactor.redact(next.tierCode),
      });
      return next;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        'KYC upgrade failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'targetTier': targetTier.code},
      );
      rethrow;
    }
  }

  Future<T> _tracel<T>(String name, Future<T> Function() action) async {
    final span = _tracer?.startTransaction(name, 'kyc');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
