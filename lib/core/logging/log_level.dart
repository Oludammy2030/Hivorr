/// Structured log severity levels.
///
/// Numeric [severity] enables threshold comparisons so the [LogRouter] can
/// discard entries below an environment-specific minimum level (EP-01-14 §5.3).
enum LogLevel {
  debug(0),
  info(1),
  warning(2),
  error(3),
  fatal(4);

  const LogLevel(this.severity);

  /// Numeric severity used for threshold comparison.
  final int severity;

  /// Whether this level meets (is at or above) the [threshold].
  bool meetsThreshold(LogLevel threshold) => severity >= threshold.severity;

  /// Parses a level name (case-insensitive); unknown names default to [debug].
  static LogLevel parse(String name) {
    final lower = name.toLowerCase();
    for (final level in LogLevel.values) {
      if (level.name == lower) return level;
    }
    return LogLevel.debug;
  }
}
