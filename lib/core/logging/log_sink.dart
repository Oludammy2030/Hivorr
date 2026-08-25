import 'package:hivorr/core/logging/log_entry.dart';

/// Abstract sink that receives [LogEntry] records for dispatch.
///
/// Implementations route entries to a concrete backend (developer log, Sentry,
/// file, etc.). EP-01-14 provides [DeveloperLogSink] and [SentryLogSink]
/// (EP-01-14 §5.6).
abstract class LogSink {
  /// Dispatches a single [LogEntry].
  void write(LogEntry entry);

  /// Releases any backend resources held by the sink.
  void dispose();
}
