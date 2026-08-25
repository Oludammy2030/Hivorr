import 'package:hivorr/core/api/logging/api_log_sink.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';

/// [ApiLogSink] implementation that routes API logs through the structured
/// [HivorrLogger] under the `'hivorr.api'` scope.
///
/// This lets EP-01-07's existing [LoggingInterceptor] emit to Sentry in
/// production without modifying any EP-01-07 code (EP-01-14 §5.15).
class SentryApiLogSink implements ApiLogSink {
  SentryApiLogSink(this._logger);

  final HivorrLogger _logger;

  @override
  void log(String level, String message) {
    switch (level) {
      case 'debug':
        _logger.debug(message);
      case 'info':
        _logger.info(message);
      case 'warning':
        _logger.warning(message);
      case 'error':
        _logger.error(message);
      case 'fatal':
        _logger.fatal(message);
      default:
        _logger.info(message);
    }
  }
}
