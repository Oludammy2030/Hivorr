import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Immutable offline sync engine configuration for the Hivorr client.
///
/// Carries only non-secret, deployment-sourced sync parameters: the maximum
/// queue depth, retry policy, backoff parameters, and drain batch size. All
/// values are sourced exclusively from [EnvironmentConfig] (EP-01-03);
/// nothing here is a hardcoded secret.
///
/// When not supplied via environment variables, safe defaults apply so the
/// sync engine remains operational out-of-the-box (EP-01-12 §5.10).
class SyncConfig {
  const SyncConfig({
    required this.maxQueueDepth,
    required this.defaultMaxRetries,
    required this.baseDelay,
    required this.maxDelay,
    required this.jitterMax,
    required this.defaultPriority,
    required this.drainBatchSize,
  });

  /// Maximum number of pending actions before the queue rejects new ones.
  final int maxQueueDepth;

  /// Default per-action retry ceiling before dead-lettering.
  final int defaultMaxRetries;

  /// Base delay for exponential backoff.
  final Duration baseDelay;

  /// Maximum delay for exponential backoff (ceiling).
  final Duration maxDelay;

  /// Maximum random jitter added to each backoff delay.
  final Duration jitterMax;

  /// Default priority assigned to sync actions (lower = higher priority).
  final int defaultPriority;

  /// Maximum number of actions processed per drain cycle.
  final int drainBatchSize;

  /// Builds [SyncConfig] from an [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults so the loader stays fail-closed
  /// on the core Supabase/schema contract while sync remains opt-in.
  static SyncConfig fromSource(EnvironmentValueSource source) {
    return SyncConfig(
      maxQueueDepth: _parseInt(
        source,
        AppConstants.envSyncMaxQueueDepth,
        AppConstants.defaultSyncMaxQueueDepth,
      ),
      defaultMaxRetries: _parseInt(
        source,
        AppConstants.envSyncMaxRetries,
        AppConstants.defaultSyncMaxRetries,
      ),
      baseDelay: Duration(
        milliseconds: _parseInt(
          source,
          AppConstants.envSyncBaseDelayMs,
          AppConstants.defaultSyncBaseDelayMs,
        ),
      ),
      maxDelay: Duration(
        milliseconds: _parseInt(
          source,
          AppConstants.envSyncMaxDelayMs,
          AppConstants.defaultSyncMaxDelayMs,
        ),
      ),
      jitterMax: Duration(
        milliseconds: _parseInt(
          source,
          AppConstants.envSyncJitterMaxMs,
          AppConstants.defaultSyncJitterMaxMs,
        ),
      ),
      defaultPriority: _parseInt(
        source,
        AppConstants.envSyncDefaultPriority,
        AppConstants.defaultSyncDefaultPriority,
      ),
      drainBatchSize: _parseInt(
        source,
        AppConstants.envSyncDrainBatchSize,
        AppConstants.defaultSyncDrainBatchSize,
      ),
    );
  }

  /// Integer parse with a safe fallback; malformed → throws.
  static int _parseInt(
    EnvironmentValueSource source,
    String key,
    int fallback,
  ) {
    final String? raw = source.read(key);
    if (raw == null) {
      return fallback;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Sync configuration value must be an integer.',
      );
    }
    return parsed;
  }

  @override
  String toString() {
    return 'SyncConfig('
        'maxQueueDepth: $maxQueueDepth, '
        'defaultMaxRetries: $defaultMaxRetries, '
        'baseDelay: ${baseDelay.inMilliseconds}ms, '
        'maxDelay: ${maxDelay.inMilliseconds}ms, '
        'jitterMax: ${jitterMax.inMilliseconds}ms, '
        'defaultPriority: $defaultPriority, '
        'drainBatchSize: $drainBatchSize)';
  }
}
