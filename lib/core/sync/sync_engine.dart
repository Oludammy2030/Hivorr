import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/sync/action_queue.dart';
import 'package:hivorr/core/sync/conflict_detector.dart';
import 'package:hivorr/core/sync/connectivity_provider.dart';
import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';
import 'package:hivorr/core/sync/sync_config.dart';
import 'package:hivorr/core/sync/sync_exception.dart';
import 'package:hivorr/core/sync/sync_status.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';

/// Internal classification of a replay failure.
enum _ErrorClassification {
  /// Server returned 409 Conflict → flag as conflicted.
  conflict,

  /// Transient failure (network, timeout, 5xx, 401 after refresh) → retry.
  transient,

  /// Client error (4xx except 401/409) → dead-letter, no retry.
  deadLetter,
}

/// Orchestrator that drains the action queue and replays mutations through
/// the EP-01-07 API layer (Dio with full interceptor chain).
///
/// The engine replays actions sequentially (one at a time per D2) to preserve
/// ordering and avoid race conditions. On transient failures, it retries with
/// exponential backoff + jitter. On 409 responses, it flags conflicts without
/// resolving them (server is authority). On client errors (4xx except 401/409),
/// it dead-letters without retry (EP-01-12 §5.5).
///
/// Auth (401) is handled by the API layer's `RetryInterceptor` (token refresh
/// + single retry) before reaching this engine. If the refresh still fails,
/// the action is treated as transient.
class SyncEngine {
  SyncEngine({
    required this._enabled,
    required this._config,
    required this._queue,
    required this._dio,
    required this._connectivityProvider,
    required this._conflictDetector,
    required this._statusProvider,
  }) {
    // Wire connectivity-triggered drain.
    _connectivitySubscription = _connectivityProvider.onConnectivityChanged
        .listen(
          (ConnectivityStatus status) async {
            if (!_enabled) return;
            if (status == ConnectivityStatus.online) {
              _statusProvider.setStatus(SyncStatus.syncing);
              await drain();
            } else {
              _statusProvider.setStatus(SyncStatus.offline);
            }
          },
          onError: (Object error) {
            _statusProvider.setError(
              SyncException('Connectivity stream error: $error'),
            );
          },
        );
  }

  final bool _enabled;
  final SyncConfig _config;
  final ActionQueue _queue;
  final Dio _dio;
  final ConnectivityProvider _connectivityProvider;
  final ConflictDetector _conflictDetector;
  final SyncStatusProvider _statusProvider;

  late final StreamSubscription<ConnectivityStatus> _connectivitySubscription;

  final math.Random _random = math.Random();

  /// Enqueues [action] for later replay. Throws [SyncException] if the
  /// feature gate is disabled or the queue is at capacity.
  Future<SyncAction> enqueue(SyncAction action) async {
    if (!_enabled) {
      throw const SyncException('Offline sync disabled.');
    }
    final SyncAction queued = await _queue.enqueue(action);
    await _updateCounts();
    return queued;
  }

  /// Drains the queue: loads pending/failed actions, sorts by priority +
  /// creation time, and replays each sequentially through the API layer.
  ///
  /// Processes at most [SyncConfig.drainBatchSize] actions per cycle. When
  /// the queue is empty, sets status to [SyncStatus.idle].
  Future<void> drain() async {
    if (!_enabled) return;

    _statusProvider.setStatus(SyncStatus.syncing);
    _statusProvider.clearError();

    try {
      final List<SyncAction> actions = await _queue.peek();
      final int batchLimit = _config.drainBatchSize;
      final List<SyncAction> batch = actions.length > batchLimit
          ? actions.sublist(0, batchLimit)
          : actions;

      for (final SyncAction action in batch) {
        await _replayAction(action);
      }

      await _updateCounts();

      final int pending = await _queue.pendingCount;
      if (pending == 0) {
        _statusProvider.setStatus(SyncStatus.idle);
      }
    } on SyncException catch (e) {
      _statusProvider.setError(e);
    }
  }

  /// Replays a single action, retrying on transient failures with exponential
  /// backoff + jitter. Dead-letters on max retries or client errors.
  Future<void> _replayAction(SyncAction action) async {
    SyncAction current = action;

    while (true) {
      final SyncAction inFlight = current.copyWith(
        status: SyncActionStatus.inFlight,
        lastAttemptAt: DateTime.now(),
      );
      await _queue.update(inFlight);

      try {
        await _dio.request<void>(
          inFlight.endpoint,
          data: inFlight.payload,
          options: Options(method: inFlight.method, headers: inFlight.headers),
        );

        // Success (2xx): dequeue.
        await _queue.dequeue(inFlight.id);
        return;
      } on DioException catch (e) {
        final _ErrorClassification classification = _classifyError(e);

        switch (classification) {
          case _ErrorClassification.conflict:
            final SyncAction conflicted = _conflictDetector.detect(
              inFlight,
              _extractResponseData(e),
            );
            await _queue.update(conflicted);
            await _updateCounts();
            return;

          case _ErrorClassification.deadLetter:
            final SyncAction deadLettered = inFlight.copyWith(
              status: SyncActionStatus.deadLettered,
              errorMessage: _safeErrorMessage(e),
            );
            await _queue.update(deadLettered);
            await _updateCounts();
            return;

          case _ErrorClassification.transient:
            final int newRetryCount = inFlight.retryCount + 1;

            if (newRetryCount >= inFlight.maxRetries) {
              final SyncAction deadLettered = inFlight.copyWith(
                status: SyncActionStatus.deadLettered,
                retryCount: newRetryCount,
                errorMessage: 'Max retries exhausted: ${_safeErrorMessage(e)}',
              );
              await _queue.update(deadLettered);
              await _updateCounts();
              return;
            }

            // Apply exponential backoff + jitter, then retry.
            final Duration delay = _calculateBackoff(newRetryCount);
            await Future<void>.delayed(delay);

            current = inFlight.copyWith(
              retryCount: newRetryCount,
              errorMessage: _safeErrorMessage(e),
            );
          // Loop back to retry.
        }
      }
    }
  }

  /// Classifies a [DioException] into conflict, transient, or dead-letter.
  ///
  /// Checks for an [ApiException] embedded in `e.error` (set by the API
  /// layer's `ErrorInterceptor`) first. Falls back to the raw HTTP status
  /// code or DioException type.
  static _ErrorClassification _classifyError(DioException e) {
    // 1. Check for embedded ApiException (from ErrorInterceptor).
    final Object? embedded = e.error;
    if (embedded is ApiException) {
      return _classifyApiException(embedded);
    }

    // 2. Check raw HTTP status code.
    final int? statusCode = e.response?.statusCode;
    if (statusCode != null) {
      return _classifyStatusCode(statusCode);
    }

    // 3. No response — network error or timeout. Treat as transient.
    return _ErrorClassification.transient;
  }

  /// Classifies based on [ApiExceptionKind].
  static _ErrorClassification _classifyApiException(ApiException e) {
    switch (e.kind) {
      case ApiExceptionKind.conflict:
        return _ErrorClassification.conflict;
      case ApiExceptionKind.network:
      case ApiExceptionKind.timeout:
      case ApiExceptionKind.server:
      case ApiExceptionKind.auth:
      case ApiExceptionKind.unknown:
        return _ErrorClassification.transient;
      case ApiExceptionKind.forbidden:
      case ApiExceptionKind.validation:
      case ApiExceptionKind.notFound:
        return _ErrorClassification.deadLetter;
    }
  }

  /// Classifies based on HTTP status code.
  static _ErrorClassification _classifyStatusCode(int statusCode) {
    if (statusCode == 409) {
      return _ErrorClassification.conflict;
    }
    if (statusCode == 401) {
      // RetryInterceptor already attempted token refresh; still failing
      // means the session is invalid. Treat as transient — the action
      // remains queued and will retry on the next drain.
      return _ErrorClassification.transient;
    }
    if (statusCode >= 500) {
      return _ErrorClassification.transient;
    }
    if (statusCode >= 400) {
      return _ErrorClassification.deadLetter;
    }
    return _ErrorClassification.transient;
  }

  /// Extracts response data from a [DioException], if available.
  static Map<String, dynamic>? _extractResponseData(DioException e) {
    final dynamic data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  /// Returns a safe, non-sensitive error message for storage in the action.
  static String _safeErrorMessage(DioException e) {
    final int? statusCode = e.response?.statusCode;
    if (statusCode != null) {
      return 'HTTP $statusCode';
    }
    return e.type.name;
  }

  /// Calculates the exponential backoff delay with jitter:
  ///
  /// `delay = min(baseDelay * 2^retryCount + random(0, jitterMax), maxDelay)`
  Duration _calculateBackoff(int retryCount) {
    final int baseMs = _config.baseDelay.inMilliseconds;
    final int maxMs = _config.maxDelay.inMilliseconds;
    final int jitterMs = _config.jitterMax.inMilliseconds;

    final int exponential = baseMs * (1 << retryCount);
    final int jitter = _random.nextInt(jitterMs + 1);
    final int delay = math.min(exponential + jitter, maxMs);

    return Duration(milliseconds: delay);
  }

  /// Updates pending and dead-letter counts in the status provider.
  Future<void> _updateCounts() async {
    final int pending = await _queue.pendingCount;
    final int deadLetters = await _queue.deadLetterCount;
    _statusProvider.setPendingCount(pending);
    _statusProvider.setDeadLetterCount(deadLetters);
  }

  /// Releases all resources (stream subscriptions, platform handles).
  void dispose() {
    unawaited(_connectivitySubscription.cancel());
    _connectivityProvider.dispose();
    _statusProvider.dispose();
  }
}
