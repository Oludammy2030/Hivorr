# TASK IMPLEMENTATION PLAN: EP-01-14

## Monitoring, Logging & Telemetry Infrastructure

| Field | Value |
|---|---|
| Task ID | EP-01-14 |
| Task Name | Monitoring, Logging & Telemetry Infrastructure |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-02 (Dependency Integration & Package Configuration — completed; `sentry_flutter: 9.27.0` already in `pubspec.yaml`). EP-01-03 (Multi-Environment Configuration System — completed; provides `EnvironmentConfig`, `FeatureFlags`, `AppConstants`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource` extension points). Consumed downstream by EP-01-07 (API layer `ApiLogSink` upgrade), EP-01-09 (auth event breadcrumbs), EP-01-12 (sync engine event logging), EP-01-13 (network event breadcrumbs), EP-01-15 (bootstrap wiring), EP-01-19 (test infrastructure), EP-01-20 (phase integration validation — Sentry capture verification). |
| Priority | High |
| Planning Reasoning | High (approved EP-01 matrix) |
| Coding Reasoning | High (approved EP-01 matrix) |

---

## 1. Task Objective

Implement the client-side monitoring, logging, and telemetry infrastructure in the ARCHITECTURE.md-mandated directories `lib/core/logging/` and `lib/core/monitoring/`:

- **Structured Logger** — a multi-level logging service (`debug`, `info`, `warning`, `error`, `fatal`) with environment-aware verbosity, automatic PII redaction, structured context fields, and named logger scoping per subsystem.
- **Log Router** — a routing layer that dispatches log entries to environment-appropriate sinks: `DeveloperLogSink` (dart:developer) in Development, `SentryLogSink` in Staging/Production, with configurable minimum level thresholds per environment.
- **PII Redactor** — a stateless utility that strips or masks personally identifiable information (email, phone, auth tokens, bank account numbers, names in structured fields) from log messages and context before any sink receives them.
- **Sentry Initialization** — environment-aware `SentryFlutter.init()` configuration with DSN sourced from `EnvironmentConfig`, environment tag, release version, sample rate configuration, and PII-stripping `beforeSend` hook.
- **Crash & Error Capture** — a `MonitoringService` wrapping Sentry's `captureException`, `captureMessage`, and `addBreadcrumb` with structured context enrichment.
- **Performance Tracing** — Sentry performance transaction helpers for tracing API calls, navigation events, and critical user journeys, gated by `FeatureFlags.enableAnalyticsTracking`.
- **API Log Sink Upgrade** — a `SentryApiLogSink` implementation of EP-01-07's existing `ApiLogSink` abstract interface that routes API logs through the structured logger, enabling the existing `LoggingInterceptor` to emit to Sentry in production without modifying EP-01-07 interceptor code.
- **Monitoring Configuration** — a `MonitoringConfig` class sourced from `EnvironmentConfig` (Sentry DSN, sample rates, environment-specific log levels, PII redaction toggle).
- **Unit tests** proving log level filtering, PII redaction, environment-aware routing, Sentry configuration, crash capture delegation, performance tracing, and API log sink compatibility.

Deliverables:
- A `HivorrLogger` structured logging service with multi-level, named-scope, PII-redacted logging.
- A `LogRouter` dispatching to environment-appropriate sinks.
- A `PiiRedactor` stateless utility for log content sanitization.
- A `MonitoringService` wrapping Sentry crash capture, breadcrumbs, and performance tracing.
- A `SentryApiLogSink` implementing EP-01-07's `ApiLogSink` for production API logging.
- A `MonitoringConfig` class sourced from `EnvironmentConfig`.
- EP-01-03 additive config extensions (`AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`).
- Unit tests for all components.
- `flutter analyze` (strict lints) + `flutter test` must pass.

**Dependency note:** EP-01-14 depends on EP-01-02 (Sentry package) and EP-01-03 (environment config) per the approved matrix. EP-01-07 (API layer) provides the `ApiLogSink` abstract interface that EP-01-14 implements. This task does not modify EP-01-07, EP-01-09, EP-01-12, or EP-01-13 files — it provides interfaces and implementations that downstream tasks wire in.

---

## 2. Business Problem Being Solved

Without a monitoring, logging, and telemetry layer:

- **Zero production visibility.** Crashes, errors, and exceptions occurring on user devices go undetected until users report them. For a Nigeria-market platform where users may not have reliable channels to report bugs, this means silent failures accumulate and erode trust.
- **No structured debugging capability.** Without structured logging with context fields, debugging production issues requires reproducing them locally — an expensive and often impossible task for device-specific or connectivity-related issues.
- **PII leakage risk in logs.** Ad-hoc logging (`print`, `developer.log`) without PII redaction risks exposing user emails, phone numbers, auth tokens, and financial data in Sentry dashboards, crash reports, and log aggregators — violating data protection requirements and Nigerian NDPR compliance.
- **No performance telemetry.** Without Sentry performance tracing, there is no visibility into API latency, screen load times, or slow transactions — preventing data-driven optimization of the user experience on low-end devices and slow networks common in the target market.
- **EP-01-07's `ApiLogSink` has only a developer sink.** The existing `LoggingInterceptor` routes to `DeveloperLogSink` (dart:developer), which is invisible in production. API errors, timeouts, and failures in staging/production are completely unobserved.
- **EP-01-20 phase validation requires Sentry capture.** The phase completion criteria explicitly states: "Sentry captures errors + metrics — Monitoring verification." Without EP-01-14, EP-01 cannot be marked complete.
- **No breadcrumb trail.** When a crash occurs, there is no contextual breadcrumb history showing what the user was doing, what API calls preceded the crash, or what network/sync state the app was in — making root cause analysis extremely difficult.

This is the **observability backbone** — it turns the client from a silent, opaque presentation layer into a monitored, debuggable, performance-measured system that enables rapid issue detection and resolution across all three environments.

---

## 3. Scope

### In Scope

- `lib/core/logging/` module: `log_level.dart`, `log_entry.dart`, `pii_redactor.dart`, `log_sink.dart`, `developer_log_sink.dart`, `sentry_log_sink.dart`, `log_router.dart`, `hivorr_logger.dart`, `logging.dart` barrel + `initializeLogging()`.
- `lib/core/monitoring/` module: `monitoring_config.dart`, `monitoring_service.dart`, `sentry_initializer.dart`, `performance_tracer.dart`, `monitoring.dart` barrel + `initializeMonitoring()` + `MonitoringLayer` aggregate.
- **Log level enum** (`LogLevel`) — `debug`, `info`, `warning`, `error`, `fatal` with numeric severity for filtering.
- **Log entry model** (`LogEntry`) — immutable structured record: level, message, logger name, timestamp, context map, error, stack trace.
- **PII redactor** (`PiiRedactor`) — stateless utility detecting and masking email addresses, phone numbers, auth tokens (Bearer/JWT), bank account numbers, and configurable field names from log content.
- **Structured logger** (`HivorrLogger`) — named-scope logger with level-gated methods, automatic PII redaction on message and context values, context field enrichment.
- **Log sink abstraction** (`LogSink`) — abstract interface for log entry dispatch; `DeveloperLogSink` (dart:developer, Development) and `SentryLogSink` (Sentry breadcrumbs + events, Staging/Production).
- **Log router** (`LogRouter`) — dispatches `LogEntry` to the configured sink(s) based on environment and minimum level threshold.
- **Monitoring configuration** (`MonitoringConfig`) — Sentry DSN, environment tag, release version, trace sample rate, profile sample rate, enable flag, minimum log level per environment.
- **Monitoring service** (`MonitoringService`) — wraps Sentry `captureException`, `captureMessage`, `addBreadcrumb`, user context setting (entity ID only, no PII), tag management.
- **Sentry initializer** (`SentryInitializer`) — environment-aware `SentryFlutter.init()` configuration with `beforeSend` PII-stripping hook, environment tag, release, sample rates.
- **Performance tracer** (`PerformanceTracer`) — helpers for starting/finishing Sentry transactions and spans for API calls, navigation, and custom operations.
- **Sentry API log sink** (`SentryApiLogSink`) — implements EP-01-07's `ApiLogSink` abstract, routes through `HivorrLogger` with `'hivorr.api'` scope.
- **EP-01-03 config extensions**: additive changes to `AppConstants` (monitoring env variable names + defaults), `EnvironmentConfig` (`monitoringConfig` field), `EnvironmentLoader` (`MonitoringConfig.fromSource` wiring), `CompileTimeEnvironmentValueSource` (monitoring variables).
- Unit tests (`test/unit/core/logging/` and `test/unit/core/monitoring/`): log level filtering, PII redaction, log routing, Sentry configuration, crash capture, performance tracing, API log sink compatibility, config sourcing.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Modifying EP-01-07 files (`lib/core/api/`) — the `SentryApiLogSink` implements the existing `ApiLogSink` interface without changing it. EP-01-15 bootstrap wires it in.
- Modifying EP-01-09 files (`lib/core/authentication/`) — auth event breadcrumbs are emitted by EP-01-09 consuming the `MonitoringService`; this task provides the service only.
- Modifying EP-01-12 files (`lib/core/sync/`) — sync event logging is added by EP-01-12 or EP-01-15 consuming the `HivorrLogger`; this task provides the logger only.
- Modifying EP-01-13 files (`lib/core/network/`) — network event breadcrumbs are emitted by EP-01-13 or EP-01-15 consuming the `MonitoringService`; this task provides the service only.
- Modifying `main.dart` or app bootstrap — EP-01-15 wires `initializeLogging()` and `initializeMonitoring()` at startup.
- Server-side error aggregation or alerting rules (Supabase/Sentry dashboard configuration) — operational concern, not code.
- Custom Sentry dashboards, alert rules, or Slack/email notification configuration — operational concern.
- Real-time log streaming to external systems (ELK, Datadog, etc.) — Sentry is the approved monitoring tool per the technology stack.
- UI widgets (error boundary screens, debug overlays, log viewers) — EP-01-15/16+.
- Auth framework, token handling — EP-01-09.
- Security infrastructure (encryption, SSL pinning) — EP-01-10.
- Supabase migrations, RPC, RLS — EP-01-05/06.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification logic is permitted. This layer **observes, logs, and reports errors and performance metrics**; it does not authorize, compute, or decide outcomes. It must never store secrets or tokens beyond transient Sentry SDK configuration. The monitoring layer operates purely as an unprivileged client-side observability layer — all server-side enforcement (RLS, RPC validation) remains authoritative (AGENT.md Rule 4). Log content must never contain secrets, tokens, or raw PII. The PII redactor is a defense-in-depth measure; the primary control is that callers should never pass PII to the logger in the first place.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Reuse existing `sentry_flutter` package | EP-01-02 already added it to `pubspec.yaml` |
| No modification of EP-01-07/09/12/13 files | Implement existing interfaces; downstream wiring by EP-01-15 |
| Feature-gated via `FeatureFlags` | EP-01-03 (`enableVerboseLogging`, `enableAnalyticsTracking`) |
| No business logic in client | AGENT.md Rules 1, 4 |
| PII never reaches Sentry | Defense-in-depth: `PiiRedactor` + `beforeSend` hook |
| Environment-aware verbosity | Development = verbose; Staging = info+; Production = warning+ |

### 5.2 Proposed Structure

```text
lib/core/logging/
├── log_level.dart                  # enum: debug, info, warning, error, fatal
├── log_entry.dart                  # immutable structured log record
├── pii_redactor.dart               # stateless PII detection + masking utility
├── log_sink.dart                   # abstract LogSink interface
├── developer_log_sink.dart         # dart:developer sink (Development env)
├── sentry_log_sink.dart            # Sentry breadcrumb + event sink (Staging/Prod)
├── log_router.dart                 # environment-aware sink dispatcher
├── hivorr_logger.dart              # named-scope structured logger
└── logging.dart                    # barrel + initializeLogging() + LoggingLayer aggregate

lib/core/monitoring/
├── monitoring_config.dart          # Sentry DSN, sample rates, env tag, enable flag
├── monitoring_service.dart         # crash capture, breadcrumbs, user context, tags
├── sentry_initializer.dart         # SentryFlutter.init() with PII-stripping beforeSend
├── performance_tracer.dart         # Sentry transaction + span helpers
└── monitoring.dart                 # barrel + initializeMonitoring() + MonitoringLayer aggregate
```

### 5.3 Log Level (`log_level.dart`)

```dart
enum LogLevel {
  debug(0),
  info(1),
  warning(2),
  error(3),
  fatal(4);

  final int severity;
  const LogLevel(this.severity);

  bool meetsThreshold(LogLevel threshold) => severity >= threshold.severity;
}
```

### 5.4 Log Entry (`log_entry.dart`)

| Field | Type | Purpose |
|---|---|---|
| `level` | `LogLevel` | Severity level |
| `message` | `String` | Log message (PII-redacted before construction) |
| `loggerName` | `String` | Named scope (e.g., `'hivorr.api'`, `'hivorr.sync'`, `'hivorr.auth'`) |
| `timestamp` | `DateTime` | When the entry was created |
| `context` | `Map<String, Object?>` | Structured context fields (PII-redacted) |
| `error` | `Object?` | Optional error/exception object |
| `stackTrace` | `StackTrace?` | Optional stack trace |

Immutable. Constructed by `HivorrLogger` after PII redaction. Sinks receive only redacted entries.

### 5.5 PII Redactor (`pii_redactor.dart`)

Stateless utility class with configurable pattern set:

| Method | Input | Output | Purpose |
|---|---|---|---|
| `redact(String text)` | raw text | redacted text | Apply all regex patterns |
| `redactContext(Map<String, Object?>)` | context map | redacted map | Redact values + sensitive key names |
| `redactEmail(String)` | text | text with emails masked | `user@example.com` → `***@***.***` |
| `redactPhone(String)` | text | text with phones masked | `+234 801 234 5678` → `***-****-****` |
| `redactToken(String)` | text | text with tokens masked | `Bearer eyJ...` → `Bearer ***` |
| `redactAccountNumber(String)` | text | text with account numbers masked | 10-digit sequences → `***` |

Default regex patterns:

| Pattern | Regex | Replacement |
|---|---|---|
| Email | `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}` | `***@***.***` |
| Phone (Nigerian) | `\+?234[\s-]?\d{3}[\s-]?\d{4}[\s-]?\d{4}` | `***-****-****` |
| Phone (generic) | `\+?\d{10,15}` | `***` |
| Bearer token | `Bearer\s+\S+` | `Bearer ***` |
| JWT | `eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` | `***` |
| Account number | `\b\d{10}\b` | `***` |

Sensitive context key names (values always replaced with `'[REDACTED]'`):
- `password`, `token`, `secret`, `apiKey`, `authorization`, `cookie`, `creditCard`, `bankAccount`, `pin`, `otp`, `ssn`

The redactor is configurable — additional patterns and sensitive key names can be added via constructor parameters. Default patterns cover the most common PII types for the Nigeria market.

### 5.6 Log Sink Abstraction (`log_sink.dart`)

```dart
abstract class LogSink {
  void write(LogEntry entry);
  void dispose();
}
```

### 5.7 Developer Log Sink (`developer_log_sink.dart`)

Wraps `dart:developer` `developer.log()`:

- Maps `LogLevel` to `developer.log()` `level` parameter.
- Uses `entry.loggerName` as the `name` parameter.
- Formats: `'[${entry.level.name.toUpperCase()}] ${entry.message}'` with optional context dump.
- Never uses `print()` (AGENT.md/analysis_options strict lint).

This sink already exists conceptually in EP-01-07's `DeveloperLogSink` (`lib/core/api/logging/developer_log_sink.dart`). EP-01-14 creates a **generalized** version in `lib/core/logging/` that is not API-specific. EP-01-15 bootstrap can then replace the API-specific `DeveloperLogSink` with the generalized one, or both can coexist.

### 5.8 Sentry Log Sink (`sentry_log_sink.dart`)

Routes log entries to Sentry:

| `LogLevel` | Sentry Action |
|---|---|
| `debug` | `Sentry.addBreadcrumb()` with `level: SentryLevel.debug` |
| `info` | `Sentry.addBreadcrumb()` with `level: SentryLevel.info` |
| `warning` | `Sentry.addBreadcrumb()` with `level: SentryLevel.warning` |
| `error` | `Sentry.captureException()` if `error` present, else `Sentry.captureMessage()` with `level: SentryLevel.error` |
| `fatal` | `Sentry.captureException()` if `error` present, else `Sentry.captureMessage()` with `level: SentryLevel.fatal` |

All entries also add a breadcrumb (so error/fatal events have a breadcrumb trail). Context map is passed as breadcrumb `data` or Sentry event `extras`.

### 5.9 Log Router (`log_router.dart`)

| Property | Type | Purpose |
|---|---|---|
| `sinks` | `List<LogSink>` | Active sinks for the current environment |
| `minimumLevel` | `LogLevel` | Minimum level threshold; entries below are discarded |

`write(LogEntry)`: iterates sinks, calls `sink.write(entry)` if `entry.level.meetsThreshold(minimumLevel)`.

Environment-based default configuration:

| Environment | Sinks | Minimum Level |
|---|---|---|
| Development | `[DeveloperLogSink]` | `debug` (or `debug` if `enableVerboseLogging` flag is on) |
| Staging | `[SentryLogSink]` | `info` |
| Production | `[SentryLogSink]` | `warning` |

The router supports multiple sinks simultaneously (e.g., Development could run both `DeveloperLogSink` and `SentryLogSink` for local Sentry testing).

### 5.10 Structured Logger (`hivorr_logger.dart`)

Named-scope logger factory:

```dart
class HivorrLogger {
  HivorrLogger(this._name, this._router, this._redactor);

  final String _name;
  final LogRouter _router;
  final PiiRedactor _redactor;

  void debug(String message, [Map<String, Object?>? context]) => _log(LogLevel.debug, message, context: context);
  void info(String message, [Map<String, Object?>? context]) => _log(LogLevel.info, message, context: context);
  void warning(String message, [Map<String, Object?>? context]) => _log(LogLevel.warning, message, context: context);
  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) => _log(LogLevel.error, message, error: error, stackTrace: stackTrace, context: context);
  void fatal(String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) => _log(LogLevel.fatal, message, error: error, stackTrace: stackTrace, context: context);

  void _log(LogLevel level, String message, {Object? error, StackTrace? stackTrace, Map<String, Object?>? context}) {
    final redactedMessage = _redactor.redact(message);
    final redactedContext = context != null ? _redactor.redactContext(context) : null;
    _router.write(LogEntry(
      level: level,
      message: redactedMessage,
      loggerName: _name,
      timestamp: DateTime.now(),
      context: redactedContext ?? const {},
      error: error,
      stackTrace: stackTrace,
    ));
  }
}
```

Factory: `LoggerFactory` creates named loggers:

```dart
class LoggerFactory {
  LoggerFactory(this._router, this._redactor);
  HivorrLogger named(String name) => HivorrLogger(name, _router, _redactor);
}
```

Subsystem loggers are obtained via `loggerFactory.named('hivorr.sync')`, `loggerFactory.named('hivorr.api')`, etc.

### 5.11 Monitoring Configuration (`monitoring_config.dart`)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `sentryDsn` | `String` | `''` (empty = Sentry disabled) | Sentry project DSN |
| `environment` | `String` | `'development'` | Sentry environment tag |
| `release` | `String` | `'unknown'` | Sentry release tag (app version) |
| `traceSampleRate` | `double` | `0.0` | Performance trace sample rate (0.0–1.0) |
| `profileSampleRate` | `double` | `0.0` | Profiling sample rate (0.0–1.0) |
| `enableSentry` | `bool` | `false` | Master enable for Sentry SDK |
| `minimumLogLevel` | `String` | `'debug'` | Minimum log level name |
| `enablePiiRedaction` | `bool` | `true` | Master enable for PII redaction |
| `maxBreadcrumbCount` | `int` | `100` | Maximum breadcrumbs retained |

Sourced from `EnvironmentConfig` via compile-time defines (`HIVORR_MONITORING_*`). If `sentryDsn` is empty or `enableSentry` is `false`, Sentry SDK is not initialized and the `SentryLogSink` is excluded from the router.

### 5.12 Monitoring Service (`monitoring_service.dart`)

Wraps Sentry SDK operations with PII-safe abstractions:

| Method | Purpose |
|---|---|
| `captureException(Object error, {StackTrace?, Map<String, Object?>? context})` | Report an exception to Sentry with structured context |
| `captureMessage(String message, {LogLevel?, Map<String, Object?>? context})` | Report a message to Sentry |
| `addBreadcrumb(String category, String message, {Map<String, Object?>? data})` | Add a breadcrumb (PII-redacted) |
| `setUserContext(String? entityId)` | Set Sentry user context (entity ID only, no PII) |
| `clearUserContext()` | Clear Sentry user context on logout |
| `setTag(String key, String value)` | Set a Sentry tag |
| `isEnabled` | `bool` — whether Sentry is active |

All methods are no-ops when `MonitoringConfig.enableSentry` is `false` (safe to call regardless of environment).

### 5.13 Sentry Initializer (`sentry_initializer.dart`)

`SentryInitializer.initialize(MonitoringConfig config)`:

1. Guard: if `!config.enableSentry` or `config.sentryDsn.isEmpty`, return immediately (no-op).
2. Call `SentryFlutter.init()` with:
   - `dsn: config.sentryDsn`
   - `environment: config.environment`
   - `release: config.release`
   - `tracesSampleRate: config.traceSampleRate`
   - `profilesSampleRate: config.profileSampleRate`
   - `maxBreadcrumbs: config.maxBreadcrumbCount`
   - `beforeSend: (SentryEvent event, {Hint? hint})` — PII-stripping hook:
     - Strip `event.request?.headers` of `Authorization`, `Cookie` keys.
     - Strip `event.extra` values matching sensitive key names.
     - Return `event` (modified) or `null` to drop.
   - `diagnosticLevel: SentryLevel.warning` (Sentry SDK internal logging).
   - `debug: false` (never enable Sentry debug in production).

### 5.14 Performance Tracer (`performance_tracer.dart`)

Helpers for Sentry performance monitoring, gated by `FeatureFlags.enableAnalyticsTracking`:

| Method | Purpose |
|---|---|
| `startTransaction(String name, String operation)` | Start a Sentry transaction; returns `ISentrySpan?` (null if disabled) |
| `startChildSpan(ISentrySpan parent, String description, String operation)` | Create a child span under a parent transaction |
| `finishSpan(ISentrySpan? span, {SentrySpanStatus? status})` | Finish a span with status |
| `isEnabled` | `bool` — whether tracing is active |

All methods are no-ops when `enableAnalyticsTracking` is `false` or `MonitoringConfig.enableSentry` is `false`.

### 5.15 Sentry API Log Sink (`sentry_log_sink.dart` in `lib/core/logging/`)

Implements EP-01-07's existing `ApiLogSink` abstract interface:

```dart
class SentryApiLogSink implements ApiLogSink {
  SentryApiLogSink(this._logger);

  final HivorrLogger _logger;

  @override
  void log(String level, String message) {
    switch (level) {
      case 'debug': _logger.debug(message);
      case 'info': _logger.info(message);
      case 'warning': _logger.warning(message);
      case 'error': _logger.error(message);
      case 'fatal': _logger.fatal(message);
      default: _logger.info(message);
    }
  }
}
```

EP-01-15 bootstrap replaces the EP-01-07 `DeveloperLogSink('hivorr.api')` with `SentryApiLogSink(loggerFactory.named('hivorr.api'))` in the `LoggingInterceptor` constructor — without modifying any EP-01-07 file.

### 5.16 Initialization Wiring

**`initializeLogging(MonitoringConfig config)`:**
1. Constructs `PiiRedactor` (with default patterns; `config.enablePiiRedaction` toggle).
2. Determines `LogLevel` threshold from `config.minimumLogLevel`.
3. Constructs sinks based on environment + `config.enableSentry`:
   - Development: `[DeveloperLogSink()]`
   - Staging/Production with Sentry enabled: `[SentryLogSink()]`
   - Fallback: `[DeveloperLogSink()]`
4. Constructs `LogRouter(sinks, minimumLevel)`.
5. Constructs `LoggerFactory(router, redactor)`.
6. Returns `LoggingLayer`.

**`initializeMonitoring(MonitoringConfig config, FeatureFlags flags)`:**
1. Calls `SentryInitializer.initialize(config)`.
2. Constructs `MonitoringService(config)`.
3. Constructs `PerformanceTracer(config, flags)`.
4. Returns `MonitoringLayer`.

**`LoggingLayer` aggregate:**

| Field | Type | Purpose |
|---|---|---|
| `loggerFactory` | `LoggerFactory` | Named logger creation |
| `router` | `LogRouter` | Active log routing |
| `redactor` | `PiiRedactor` | PII redaction utility |
| `config` | `MonitoringConfig` | Active logging configuration |

**`MonitoringLayer` aggregate:**

| Field | Type | Purpose |
|---|---|---|
| `service` | `MonitoringService` | Crash capture, breadcrumbs, user context |
| `tracer` | `PerformanceTracer` | Performance transaction helpers |
| `config` | `MonitoringConfig` | Active monitoring configuration |

`lib/app/` (EP-01-15) calls `initializeLogging()` and `initializeMonitoring()` at bootstrap — **this task does not modify `main.dart` or bootstrap**; it exports the initializers only.

### 5.17 EP-01-03 Configuration Extensions (additive)

Following the established pattern from EP-01-10, EP-01-11, EP-01-12, EP-01-13:

**`AppConstants` additions:**
- `envMonitoringSentryDsn` = `'HIVORR_MONITORING_SENTRY_DSN'`
- `envMonitoringEnvironment` = `'HIVORR_MONITORING_ENVIRONMENT'`
- `envMonitoringRelease` = `'HIVORR_MONITORING_RELEASE'`
- `envMonitoringTraceSampleRate` = `'HIVORR_MONITORING_TRACE_SAMPLE_RATE'`
- `envMonitoringProfileSampleRate` = `'HIVORR_MONITORING_PROFILE_SAMPLE_RATE'`
- `envMonitoringEnableSentry` = `'HIVORR_MONITORING_ENABLE_SENTRY'`
- `envMonitoringMinLogLevel` = `'HIVORR_MONITORING_MIN_LOG_LEVEL'`
- `envMonitoringEnablePiiRedaction` = `'HIVORR_MONITORING_ENABLE_PII_REDACTION'`
- `envMonitoringMaxBreadcrumbs` = `'HIVORR_MONITORING_MAX_BREADCRUMBS'`
- Corresponding `default*` constants for each.

**`EnvironmentConfig` addition:**
- `monitoringConfig` field (`MonitoringConfig`).

**`EnvironmentLoader` addition:**
- `MonitoringConfig.fromSource(source)` wiring (step 10 in load sequence).

**`CompileTimeEnvironmentValueSource` addition:**
- Monitoring variable mappings in the `switch` expression.

### 5.18 Extensibility Hooks

- `LogSink` abstract → future phases can add sinks (file sink, remote log shipping, debug overlay sink).
- `HivorrLogger` → every subsystem (API, sync, network, auth) obtains a named logger for structured, PII-redacted logging.
- `MonitoringService` → EP-01-09 auth events, EP-01-12 sync events, EP-01-13 network events emit breadcrumbs.
- `PerformanceTracer` → EP-02+ features trace critical user journeys (checkout, search, onboarding).
- `SentryApiLogSink` → EP-01-15 bootstrap wires into EP-01-07's `LoggingInterceptor` without modifying EP-01-07.
- `PiiRedactor` → extensible pattern set for future PII types.
- `MonitoringConfig` → environment-specific tuning without code changes.
- `logging.dart` / `monitoring.dart` barrels → EP-01-15 bootstrap.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Source of monitoring config values, feature gates |
| `sentry_flutter` | `pubspec.yaml` (EP-01-02) | Sentry SDK for crash reporting + performance (already integrated at `9.27.0`) |
| `ApiLogSink` | `lib/core/api/logging/` (EP-01-07) | Abstract API log contract (already exists; EP-01-14 implements it) |
| `HivorrLogger` | `lib/core/logging/` | Named-scope structured logger with PII redaction |
| `LoggerFactory` | `lib/core/logging/` | Named logger creation |
| `LogRouter` | `lib/core/logging/` | Environment-aware sink dispatcher |
| `PiiRedactor` | `lib/core/logging/` | PII detection + masking utility |
| `DeveloperLogSink` | `lib/core/logging/` | dart:developer sink for Development |
| `SentryLogSink` | `lib/core/logging/` | Sentry breadcrumb + event sink for Staging/Prod |
| `MonitoringService` | `lib/core/monitoring/` | Crash capture, breadcrumbs, user context |
| `SentryInitializer` | `lib/core/monitoring/` | Sentry SDK initialization with PII-stripping |
| `PerformanceTracer` | `lib/core/monitoring/` | Transaction + span helpers |
| `MonitoringConfig` | `lib/core/monitoring/` | Configuration sourced from `EnvironmentConfig` |
| EP-01-03 config extensions | `lib/config/` | Additive `AppConstants`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource` |
| Test suites | `test/unit/core/logging/`, `test/unit/core/monitoring/` | Logger, redactor, router, sink, service, tracer, config tests |

**No new dependencies required.** `sentry_flutter: 9.27.0` is already in `pubspec.yaml` (added by EP-01-02). All logging/monitoring code uses `sentry_flutter` and `dart:developer` only.

---

## 7. Data Requirements

- **Log entries** are transient structured records (level, message, logger name, timestamp, context, error, stack trace). They contain no business logic, no domain entities.
- `LogEntry` is an in-memory value object — never persisted to local storage. Sentry SDK handles its own event transport and buffering.
- **Breadcrumbs** are managed by the Sentry SDK in-memory (bounded by `maxBreadcrumbCount`). They contain only redacted category, message, and data.
- **PII redaction** ensures no email, phone, token, or account number reaches any sink. The redactor is defense-in-depth; callers should never pass PII to the logger.
- **User context** in Sentry is limited to entity ID (UUID) only — no name, email, phone, or address.
- No tokens, secrets, or credentials are stored or transmitted by this layer beyond the Sentry DSN (which is a public, client-safe ingestion endpoint).
- No business, financial, or domain data is created by this task.

---

## 8. Database Considerations

**Not applicable** to Supabase/PostgreSQL. This task defines **client-local** observability only. All server-side schema, RPC, and RLS remain owned by EP-01-05/06. No migrations; no persistent storage. Sentry SDK manages its own offline event buffering internally.

---

## 9. API Requirements

- **No new network endpoints/RPCs.** The monitoring layer observes and reports; it does not make API calls to the Hivorr backend.
- Sentry SDK communicates with Sentry's ingestion endpoint (`sentry.io` or self-hosted) using the DSN. This is an external service, not a Hivorr API.
- The `SentryApiLogSink` implements EP-01-07's `ApiLogSink` — the existing `LoggingInterceptor` continues to function unchanged. EP-01-15 bootstrap swaps the sink implementation.
- No interceptor modifications to EP-01-07.
- Performance tracing can wrap API calls via `PerformanceTracer.startTransaction()` / `startChildSpan()`, but this task does not instrument any API calls — EP-02+ features add instrumentation.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing. The `MonitoringService` and `HivorrLogger` are exported for EP-01-15/16+ to build error boundary UI, debug overlays, or user-facing error reporting. `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `initializeLogging(config)` yields a fully wired `LoggingLayer` with environment-appropriate sinks.
- One-call `initializeMonitoring(config, flags)` yields a fully wired `MonitoringLayer` with Sentry initialized.
- `LoggerFactory.named('hivorr.sync')` gives every subsystem a clean, scoped logger.
- PII redaction is automatic — developers cannot accidentally log PII (it is stripped before reaching any sink).
- `MonitoringService.addBreadcrumb()` gives subsystems a simple API for contextual event trails.
- `PerformanceTracer` gives EP-02+ features a clean API for tracing critical user journeys.
- Feature gates (`enableVerboseLogging`, `enableAnalyticsTracking`) allow toggling without code changes.
- Sentry disabled gracefully when DSN is empty or `enableSentry` is `false` — all methods become no-ops.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| PII in log messages | `PiiRedactor` applied to all messages and context before any sink receives them. Defense-in-depth: `beforeSend` hook strips remaining PII from Sentry events. |
| PII in Sentry breadcrumbs | `MonitoringService.addBreadcrumb()` redacts `data` map through `PiiRedactor` before passing to Sentry SDK. |
| Auth tokens in API logs | `SentryApiLogSink` routes through `HivorrLogger` which applies PII redaction. EP-01-07's `LoggingInterceptor` already never logs Authorization headers or bodies. |
| Sentry DSN exposure | DSN is a public, client-safe ingestion endpoint (designed for client SDKs). Not a secret. Sourced from `EnvironmentConfig` — no hardcoded values. |
| User context PII | `MonitoringService.setUserContext()` accepts entity ID (UUID) only. No name, email, phone, or address fields. |
| `beforeSend` hook bypass | Hook strips `Authorization`/`Cookie` headers from `event.request.headers` and sensitive keys from `event.extra`. Returns `null` to drop events that cannot be sanitized. |
| Hardcoded config values | All monitoring parameters sourced exclusively from `EnvironmentConfig`; no `String.fromEnvironment`, no literals. |
| Business logic in client | Layer observes and reports only; no role/verification/pricing decisions (AGENT.md Rule 4). |
| Log injection attacks | Log messages are treated as opaque strings by sinks. No log message is ever evaluated as code or used in SQL queries. |
| Sensitive key name leakage | `PiiRedactor.redactContext()` replaces values for known sensitive key names (`password`, `token`, `secret`, `apiKey`, `authorization`, etc.) with `'[REDACTED]'`. |

---

## 13. Performance Considerations

- **Level-gated filtering:** `LogRouter` discards entries below the minimum threshold before any sink processes them. In Production (`warning` minimum), `debug` and `info` entries are discarded with zero sink overhead.
- **Lazy Sentry init:** Sentry SDK is not initialized when `enableSentry` is `false` or DSN is empty. No SDK overhead in Development when disabled.
- **Breadcrumb bounded:** Sentry SDK retains at most `maxBreadcrumbCount` (default 100) breadcrumbs in memory. FIFO eviction prevents unbounded growth.
- **PII redaction cost:** Regex matching on log messages is O(n) per pattern per message. With 6 default patterns, the cost is negligible for typical log message lengths (< 500 chars). Redaction is synchronous and non-blocking.
- **No synchronous I/O in sinks:** `DeveloperLogSink` writes to `dart:developer` (synchronous, fast). `SentryLogSink` calls Sentry SDK methods which buffer internally and transport asynchronously.
- **Performance tracing gated:** `PerformanceTracer` is a no-op when `enableAnalyticsTracking` is `false`. When enabled, Sentry SDK manages transaction lifecycle with minimal overhead.
- **No new dependencies:** reuses `sentry_flutter` already in `pubspec.yaml`. Zero impact on the 15–20 MB installer target.
- **Memory:** `LogRouter` holds a list of sinks (1–2). `LoggerFactory` holds references to router and redactor (shared). `MonitoringService` holds config reference. Sentry SDK manages its own memory (bounded breadcrumbs, event queue).
- **Sampling:** `traceSampleRate` and `profileSampleRate` allow tuning Sentry overhead in production (e.g., 10% trace sampling for high-traffic environments).

---

## 14. Testing Strategy

### 14.1 Unit — Log Level
- `LogLevel.debug.severity` = 0, `LogLevel.fatal.severity` = 4.
- `meetsThreshold()`: `debug.meetsThreshold(debug)` = `true`; `debug.meetsThreshold(warning)` = `false`; `fatal.meetsThreshold(debug)` = `true`.
- `LogLevel.values` has exactly 5 entries.

### 14.2 Unit — Log Entry
- Construction with all fields.
- Immutability: context map cannot be modified after construction (defensive copy or `Map.unmodifiable`).
- `LogEntry` with null `error` and `stackTrace`.

### 14.3 Unit — PII Redactor
- **Email redaction:** `'Contact user@example.com for details'` → `'Contact ***@***.*** for details'`.
- **Phone redaction (Nigerian):** `'Call +234 801 234 5678'` → `'Call ***-****-****'`.
- **Phone redaction (generic):** `'Number: 1234567890'` → `'Number: ***'`.
- **Bearer token redaction:** `'Auth: Bearer eyJhbGciOi...'` → `'Auth: Bearer ***'`.
- **JWT redaction:** `'Token: eyJhbGciOi.eyJzdWIi.signed'` → `'Token: ***'`.
- **Account number redaction:** `'Account: 1234567890'` → `'Account: ***'`.
- **Context redaction:** `{'email': 'user@test.com', 'action': 'login'}` → `{'email': '[REDACTED]', 'action': 'login'}`.
- **Sensitive key names:** `password`, `token`, `secret`, `apiKey`, `authorization`, `cookie`, `creditCard`, `bankAccount`, `pin`, `otp`, `ssn` → values replaced with `'[REDACTED]'`.
- **No false positives:** `'Order #12345 placed'` → unchanged (5-digit number, not 10-digit account).
- **Empty/null input:** handled gracefully.
- **Multiple PII in one message:** all instances redacted.
- **Redaction disabled:** when `enablePiiRedaction` is `false`, text passes through unchanged.

### 14.4 Unit — Developer Log Sink
- `write(LogEntry)` calls `developer.log()` with correct level, name, and message.
- Does not use `print()`.

### 14.5 Unit — Sentry Log Sink
- `debug`/`info`/`warning` entries → `Sentry.addBreadcrumb()` called with correct level.
- `error` entry with `error` object → `Sentry.captureException()` called.
- `error` entry without `error` object → `Sentry.captureMessage()` called.
- `fatal` entry → `Sentry.captureException()` or `captureMessage()` with `SentryLevel.fatal`.
- Context map passed as breadcrumb `data` or event `extras`.

### 14.6 Unit — Log Router
- Entry below minimum level → no sink receives it.
- Entry at minimum level → all sinks receive it.
- Entry above minimum level → all sinks receive it.
- Multiple sinks → all receive the entry.
- Empty sinks list → no crash, entry discarded.

### 14.7 Unit — HivorrLogger
- `debug()` creates `LogEntry` with `LogLevel.debug`.
- `error()` creates `LogEntry` with `LogLevel.error`, error object, and stack trace.
- Message is PII-redacted before `LogEntry` construction.
- Context map is PII-redacted before `LogEntry` construction.
- Logger name is set correctly.

### 14.8 Unit — Logger Factory
- `named('hivorr.sync')` returns a `HivorrLogger` with `_name = 'hivorr.sync'`.
- Multiple calls with the same name return independent loggers (not cached singletons — stateless).

### 14.9 Unit — Monitoring Configuration
- `MonitoringConfig.fromSource()` with all values present → correct parsing.
- `MonitoringConfig.fromSource()` with no values → defaults applied.
- `sentryDsn` empty → Sentry disabled.
- `enableSentry` false → Sentry disabled.
- `traceSampleRate` clamped to 0.0–1.0.
- `minimumLogLevel` parsed from string to `LogLevel`.

### 14.10 Unit — Monitoring Service
- `captureException()` delegates to `Sentry.captureException()` when enabled.
- `captureException()` is no-op when disabled.
- `addBreadcrumb()` redacts data through `PiiRedactor` before passing to Sentry.
- `setUserContext('entity-uuid')` sets Sentry user with `id: 'entity-uuid'` and no other fields.
- `clearUserContext()` calls `Sentry.configureScope` to clear user.

### 14.11 Unit — Sentry Initializer
- `initialize()` with `enableSentry: false` → `SentryFlutter.init()` not called.
- `initialize()` with empty DSN → `SentryFlutter.init()` not called.
- `beforeSend` hook strips `Authorization` header from event request.
- `beforeSend` hook strips `Cookie` header from event request.
- `beforeSend` hook redacts sensitive keys from event extras.

### 14.12 Unit — Performance Tracer
- `startTransaction()` returns `ISentrySpan` when enabled.
- `startTransaction()` returns `null` when disabled.
- `finishSpan()` with null span → no-op (no crash).
- `isEnabled` reflects `enableAnalyticsTracking` flag AND `enableSentry`.

### 14.13 Unit — Sentry API Log Sink
- `log('debug', 'message')` → calls `_logger.debug('message')`.
- `log('error', 'message')` → calls `_logger.error('message')`.
- Unknown level → defaults to `info`.
- Implements `ApiLogSink` interface (type check passes).

### 14.14 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new tests pass.
- Available platform smoke build (no native changes required).

### 14.15 Scope Validation
- Diff review: only `lib/core/logging/` + `lib/core/monitoring/` + `test/unit/core/logging/` + `test/unit/core/monitoring/` + EP-01-03 additive config extensions (`AppConstants`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`). No modifications to EP-01-07, EP-01-09, EP-01-12, or EP-01-13 files. No bootstrap/UI/DB/auth/security implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-02, EP-01-03, and EP-01-07 deliverables; confirm `lib/core/logging/` and `lib/core/monitoring/` contain only `.gitkeep`.
2. Confirm `sentry_flutter: 9.27.0` is in `pubspec.yaml`.
3. Confirm EP-01-07's `ApiLogSink` abstract interface in `lib/core/api/logging/api_log_sink.dart`.
4. Implement EP-01-03 additive config extensions: `AppConstants` (9 monitoring variable names + defaults), `MonitoringConfig` class, `EnvironmentConfig` (`monitoringConfig` field), `EnvironmentLoader` (MonitoringConfig.fromSource wiring, step 10), `CompileTimeEnvironmentValueSource` (monitoring variables).
5. Implement `lib/core/logging/log_level.dart` — `LogLevel` enum with severity and `meetsThreshold()`.
6. Implement `lib/core/logging/log_entry.dart` — immutable `LogEntry` model.
7. Implement `lib/core/logging/pii_redactor.dart` — `PiiRedactor` with default regex patterns and sensitive key names.
8. Implement `lib/core/logging/log_sink.dart` — abstract `LogSink` interface.
9. Implement `lib/core/logging/developer_log_sink.dart` — `DeveloperLogSink` using `dart:developer`.
10. Implement `lib/core/logging/sentry_log_sink.dart` — `SentryLogSink` routing to Sentry breadcrumbs and events.
11. Implement `lib/core/logging/log_router.dart` — `LogRouter` with level filtering and multi-sink dispatch.
12. Implement `lib/core/logging/hivorr_logger.dart` — `HivorrLogger` + `LoggerFactory` with PII-redacted logging.
13. Implement `lib/core/logging/logging.dart` — barrel + `initializeLogging()` + `LoggingLayer` aggregate.
14. Implement `lib/core/monitoring/monitoring_config.dart` — `MonitoringConfig` class (if not already done in step 4).
15. Implement `lib/core/monitoring/sentry_initializer.dart` — `SentryInitializer` with `beforeSend` PII-stripping hook.
16. Implement `lib/core/monitoring/monitoring_service.dart` — `MonitoringService` wrapping Sentry operations.
17. Implement `lib/core/monitoring/performance_tracer.dart` — `PerformanceTracer` with transaction/span helpers.
18. Implement `lib/core/monitoring/monitoring.dart` — barrel + `initializeMonitoring()` + `MonitoringLayer` aggregate.
19. Implement `SentryApiLogSink` in `lib/core/logging/` — EP-01-07 `ApiLogSink` implementation.
20. Add `test/unit/core/logging/` unit tests (log level, log entry, PII redactor, sinks, router, logger, factory, API log sink).
21. Add `test/unit/core/monitoring/` unit tests (config, service, initializer, tracer).
22. Run `flutter analyze` and `flutter test`.
23. Available platform smoke builds.
24. Review final diff for strict EP-01-14 scope containment and phase-document integrity.
25. **Stop at the approval gate** — do not implement EP-01-15 bootstrap, EP-01-16 UI, or downstream tasks.

---

## 16. Expected Outcome

- A fully functional **structured logging layer** in `lib/core/logging/` providing multi-level, named-scope, PII-redacted logging with environment-aware sink routing.
- A fully functional **monitoring layer** in `lib/core/monitoring/` providing Sentry crash capture, breadcrumbs, user context, and performance tracing.
- `PiiRedactor` ensures no email, phone, token, or account number reaches any log sink — defense-in-depth with `beforeSend` hook.
- `HivorrLogger` + `LoggerFactory` give every subsystem a clean, scoped logger for structured observability.
- `MonitoringService` gives subsystems a simple API for crash reporting and breadcrumb trails.
- `PerformanceTracer` gives EP-02+ features a clean API for tracing critical user journeys.
- `SentryApiLogSink` implements EP-01-07's `ApiLogSink` — enabling production API logging without modifying EP-01-07.
- `MonitoringConfig` sourced from `EnvironmentConfig` — environment-tunable without code changes.
- Sentry gracefully disabled when DSN is empty or `enableSentry` is `false` — all methods become no-ops.
- Unit tests proving log level filtering, PII redaction, environment routing, Sentry configuration, crash capture, performance tracing, and API log sink compatibility — all without a live backend.
- EP-01-20 phase validation criterion "Sentry captures errors + metrics" is achievable once EP-01-15 wires the bootstrap.

---

## 17. Definition of Done (DoD)

**Structure & Code — Logging**
- [ ] `lib/core/logging/` contains the §5.2 structure; all files implemented and importing correctly.
- [ ] `LogLevel` enum defines `debug`, `info`, `warning`, `error`, `fatal` with numeric severity and `meetsThreshold()`.
- [ ] `LogEntry` is immutable with `level`, `message`, `loggerName`, `timestamp`, `context`, `error`, `stackTrace`.
- [ ] `PiiRedactor` detects and masks email, phone (Nigerian + generic), Bearer tokens, JWTs, and 10-digit account numbers. Redacts sensitive context key names (`password`, `token`, `secret`, `apiKey`, `authorization`, `cookie`, `creditCard`, `bankAccount`, `pin`, `otp`, `ssn`).
- [ ] `LogSink` abstract interface defines `write(LogEntry)` and `dispose()`.
- [ ] `DeveloperLogSink` uses `dart:developer` `developer.log()` — never `print()`.
- [ ] `SentryLogSink` routes `debug`/`info`/`warning` to breadcrumbs, `error`/`fatal` to `captureException`/`captureMessage`.
- [ ] `LogRouter` dispatches to configured sinks with minimum level filtering.
- [ ] `HivorrLogger` applies PII redaction to message and context before `LogEntry` construction. Provides `debug`, `info`, `warning`, `error`, `fatal` methods.
- [ ] `LoggerFactory` creates named loggers via `named(String name)`.
- [ ] `logging.dart` barrel exports public API; `initializeLogging()` wired for EP-01-15; `LoggingLayer` aggregate.

**Structure & Code — Monitoring**
- [ ] `lib/core/monitoring/` contains the §5.2 structure; all files implemented and importing correctly.
- [ ] `MonitoringConfig` sourced from `EnvironmentConfig`; fields: `sentryDsn`, `environment`, `release`, `traceSampleRate`, `profileSampleRate`, `enableSentry`, `minimumLogLevel`, `enablePiiRedaction`, `maxBreadcrumbCount`. No `String.fromEnvironment`, no hardcoded values.
- [ ] `SentryInitializer` calls `SentryFlutter.init()` with correct config; `beforeSend` hook strips `Authorization`/`Cookie` headers and sensitive extra keys. No-op when disabled.
- [ ] `MonitoringService` wraps `captureException`, `captureMessage`, `addBreadcrumb`, `setUserContext`, `clearUserContext`, `setTag`. All methods are no-ops when disabled.
- [ ] `MonitoringService.setUserContext()` accepts entity ID only — no PII fields.
- [ ] `MonitoringService.addBreadcrumb()` redacts data through `PiiRedactor`.
- [ ] `PerformanceTracer` provides `startTransaction`, `startChildSpan`, `finishSpan`. No-op when `enableAnalyticsTracking` is `false` or Sentry disabled.
- [ ] `monitoring.dart` barrel exports public API; `initializeMonitoring()` wired for EP-01-15; `MonitoringLayer` aggregate.

**Cross-Cutting**
- [ ] `SentryApiLogSink` implements EP-01-07's `ApiLogSink` interface; routes through `HivorrLogger`. Type-compatible without EP-01-07 modifications.
- [ ] EP-01-03 additive config extensions: `AppConstants` (9 monitoring variable names + defaults), `EnvironmentConfig` (`monitoringConfig` field), `EnvironmentLoader` (MonitoringConfig.fromSource, step 10), `CompileTimeEnvironmentValueSource` (monitoring variables).
- [ ] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/DB/auth/security/network/sync code included.
- [ ] No modifications to EP-01-07, EP-01-09, EP-01-12, or EP-01-13 files.
- [ ] No new dependencies added to `pubspec.yaml` (reuses `sentry_flutter` from EP-01-02).
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (log level, log entry, PII redactor, sinks, router, logger, factory, API log sink, config, service, initializer, tracer unit tests).
- [ ] Available platform smoke builds pass.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-14 changes (+ EP-01-03 additive config extensions).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** Medium-high — designing a correct structured logger with PII redaction, environment-aware sink routing, and Sentry integration requires careful reasoning about log level semantics, regex pattern correctness, sink lifecycle, and `beforeSend` hook safety. The Sentry initialization configuration (sample rates, environment tags, `beforeSend` PII stripping) requires understanding of the Sentry SDK API. However, the patterns are well-established and the implementation is largely wiring and delegation.
- **Business impact:** High — this is the observability backbone. Every subsystem depends on it for debugging and monitoring. EP-01-20 phase completion explicitly requires "Sentry captures errors + metrics." Incorrect implementation means silent production failures, undetected crashes, and PII leakage in Sentry dashboards.
- **Security risk:** High — PII redaction is a critical defense-in-depth control. Incorrect regex patterns or missed sensitive key names could leak user emails, phone numbers, auth tokens, or bank account numbers to Sentry. The `beforeSend` hook is the last line of defense. `setUserContext` must be strictly limited to entity ID.
- **Performance sensitivity:** Medium — level-gated filtering prevents unnecessary sink processing. Bounded breadcrumbs prevent memory growth. PII redaction regex cost is negligible for typical log message lengths. Performance tracing is gated and sampled.
- **Data complexity:** Low — `LogEntry` is a simple structured record (7 fields). `MonitoringConfig` is a flat configuration class. No relational data, no persistence, no schema design.
- **Integration complexity:** High — must integrate correctly with three completed subsystems (`sentry_flutter` via EP-01-02, `EnvironmentConfig` via EP-01-03's established pattern, `ApiLogSink` via EP-01-07's existing interface). The EP-01-03 config extension pattern must be followed precisely (9 new variable names, EnvironmentConfig field, EnvironmentLoader step 10, CompileTimeEnvironmentValueSource mapping). The `SentryApiLogSink` must be type-compatible with EP-01-07's `ApiLogSink` without modifying EP-01-07 files.

High reasoning matches the approved EP-01 matrix (EP-01-14 = High) and the security-sensitive, integration-heavy nature of the task — the complexity lies in correct PII redaction, Sentry SDK configuration safety, and precise config pattern adherence rather than algorithmic depth.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

No approval-required decisions are flagged — this task introduces no new dependencies (reuses `sentry_flutter` from EP-01-02), no architectural tradeoffs, and no scope ambiguities. The plan follows established patterns from EP-01-10, EP-01-11, EP-01-12, and EP-01-13.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-14-Monitoring-Logging-Telemetry-Infrastructure.md`. Implementation will begin only after a separate implementation approval. No production code is written during planning.
