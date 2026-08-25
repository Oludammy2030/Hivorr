# DEFINITION OF DONE — EP-01-14

## Monitoring, Logging & Telemetry Infrastructure

> **Document Type:** Standalone Task Definition of Done (Verification Checklist)
> **Reference Plan:** `documents/Task-Implementation/EP-01/EP-01-14-Monitoring, Logging & Telemetry Infrastructure.md`
> **Purpose:** Practical checklist for the project lead to confirm EP-01-14 is implemented per the approved plan before approval.

---

## Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-14 |
| **Task Name** | Monitoring, Logging & Telemetry Infrastructure |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-14-Monitoring, Logging & Telemetry Infrastructure.md` |
| **Phase Plan Status** | **Completed** — implemented & verified (see Implementation Sign-off below) |
| **Dependencies** | EP-01-02 (Dependency Integration & Package Configuration — completed; `sentry_flutter: 9.27.0` already in `pubspec.yaml`); EP-01-03 (Multi-Environment Configuration System — completed; provides `EnvironmentConfig`, `FeatureFlags`, `AppConstants`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource` extension points). Consumed downstream by EP-01-07 (`ApiLogSink` upgrade), EP-01-09 (auth event breadcrumbs), EP-01-12 (sync engine event logging), EP-01-13 (network event breadcrumbs), EP-01-15 (bootstrap wiring), EP-01-19 (test infrastructure), EP-01-20 (phase integration validation — Sentry capture verification). |

---

## Functional Verification

### Required Functionality

**Logging (`lib/core/logging/`)**
- [ ] `lib/core/logging/` contains the §5.2 structure: `log_level.dart`, `log_entry.dart`, `pii_redactor.dart`, `log_sink.dart`, `developer_log_sink.dart`, `sentry_log_sink.dart`, `log_router.dart`, `hivorr_logger.dart`, `logging.dart`.
- [ ] `LogLevel` enum defines `debug` (0), `info` (1), `warning` (2), `error` (3), `fatal` (4) with numeric severity and `meetsThreshold(LogLevel threshold)` method.
- [ ] `LogEntry` is immutable with fields: `level` (LogLevel), `message` (String), `loggerName` (String), `timestamp` (DateTime), `context` (Map<String, Object?>), `error` (Object?), `stackTrace` (StackTrace?).
- [ ] `LogEntry` context map is immutable (defensive copy or `Map.unmodifiable`); cannot be modified after construction.
- [ ] `PiiRedactor` detects and masks 6 default patterns: email (`***@***.***`), Nigerian phone (`***-****-****`), generic phone (`***`), Bearer token (`Bearer ***`), JWT (`***`), 10-digit account number (`***`).
- [ ] `PiiRedactor.redactContext()` replaces values for 11 sensitive key names (`password`, `token`, `secret`, `apiKey`, `authorization`, `cookie`, `creditCard`, `bankAccount`, `pin`, `otp`, `ssn`) with `'[REDACTED]'`.
- [ ] `PiiRedactor` is configurable — additional patterns and sensitive key names can be added via constructor parameters.
- [ ] `PiiRedactor` respects `enablePiiRedaction` toggle — when `false`, text passes through unchanged.
- [ ] `LogSink` abstract interface defines `write(LogEntry entry)` and `dispose()`.
- [ ] `DeveloperLogSink` wraps `dart:developer` `developer.log()` with correct level mapping, logger name, and formatted message; never uses `print()`.
- [ ] `SentryLogSink` routes `debug`/`info`/`warning` entries to `Sentry.addBreadcrumb()` with correct `SentryLevel`; routes `error`/`fatal` entries to `Sentry.captureException()` (when error present) or `Sentry.captureMessage()` (when no error).
- [ ] `SentryLogSink` adds breadcrumb for all entries (including error/fatal) so events have a breadcrumb trail.
- [ ] `LogRouter` dispatches `LogEntry` to configured sink(s) only when `entry.level.meetsThreshold(minimumLevel)`; discards entries below threshold.
- [ ] `LogRouter` supports multiple sinks simultaneously (e.g., Development with both `DeveloperLogSink` and `SentryLogSink`).
- [ ] `HivorrLogger` provides `debug`, `info`, `warning`, `error`, `fatal` methods; applies PII redaction to message and context before `LogEntry` construction.
- [ ] `HivorrLogger.error()` and `HivorrLogger.fatal()` accept optional `error` (Object) and `stackTrace` (StackTrace) parameters.
- [ ] `LoggerFactory` creates named loggers via `named(String name)` returning `HivorrLogger` with correct `_name`.
- [ ] `logging.dart` barrel exports public API; `initializeLogging(MonitoringConfig)` builds `LoggingLayer` aggregate (loggerFactory, router, redactor, config); no `main.dart` change.

**Monitoring (`lib/core/monitoring/`)**
- [ ] `lib/core/monitoring/` contains the §5.2 structure: `monitoring_config.dart`, `monitoring_service.dart`, `sentry_initializer.dart`, `performance_tracer.dart`, `monitoring.dart`.
- [ ] `MonitoringConfig` exposes: `sentryDsn` (String, default `''`), `environment` (String, default `'development'`), `release` (String, default `'unknown'`), `traceSampleRate` (double, default `0.0`), `profileSampleRate` (double, default `0.0`), `enableSentry` (bool, default `false`), `minimumLogLevel` (String, default `'debug'`), `enablePiiRedaction` (bool, default `true`), `maxBreadcrumbCount` (int, default `100`); sourced from `EnvironmentConfig`.
- [ ] `MonitoringConfig.traceSampleRate` clamped to 0.0–1.0 range.
- [ ] `MonitoringConfig.minimumLogLevel` parsed from string to `LogLevel` enum.
- [ ] `SentryInitializer.initialize(MonitoringConfig)` calls `SentryFlutter.init()` with correct config (dsn, environment, release, tracesSampleRate, profilesSampleRate, maxBreadcrumbs); no-op when `enableSentry` is `false` or `sentryDsn` is empty.
- [ ] `SentryInitializer` `beforeSend` hook strips `Authorization` and `Cookie` keys from `event.request?.headers`; strips sensitive keys from `event.extra`; returns `null` to drop events that cannot be sanitized.
- [ ] `SentryInitializer` sets `diagnosticLevel: SentryLevel.warning` and `debug: false`.
- [ ] `MonitoringService` wraps `captureException(Object, {StackTrace?, Map?})`, `captureMessage(String, {LogLevel?, Map?})`, `addBreadcrumb(String, String, {Map?})`, `setUserContext(String?)`, `clearUserContext()`, `setTag(String, String)`, `isEnabled` (bool).
- [ ] `MonitoringService` all methods are no-ops when `MonitoringConfig.enableSentry` is `false`.
- [ ] `MonitoringService.setUserContext()` accepts entity ID (UUID) only — no name, email, phone, or address fields.
- [ ] `MonitoringService.addBreadcrumb()` redacts `data` map through `PiiRedactor` before passing to Sentry SDK.
- [ ] `PerformanceTracer` provides `startTransaction(String, String)` → `ISentrySpan?`, `startChildSpan(ISentrySpan, String, String)` → `ISentrySpan?`, `finishSpan(ISentrySpan?, {SentrySpanStatus?})`, `isEnabled` (bool).
- [ ] `PerformanceTracer` all methods are no-ops when `FeatureFlags.enableAnalyticsTracking` is `false` or `MonitoringConfig.enableSentry` is `false`.
- [ ] `PerformanceTracer.finishSpan()` with null span → no-op (no crash).
- [ ] `monitoring.dart` barrel exports public API; `initializeMonitoring(MonitoringConfig, FeatureFlags)` builds `MonitoringLayer` aggregate (service, tracer, config); no `main.dart` change.

**Cross-Cutting**
- [ ] `SentryApiLogSink` implements EP-01-07's `ApiLogSink` abstract interface; routes `log(String level, String message)` through `HivorrLogger` with correct level mapping (`'debug'` → `debug()`, `'error'` → `error()`, etc.); unknown level defaults to `info()`.
- [ ] `SentryApiLogSink` is type-compatible with EP-01-07's `ApiLogSink` (no compilation errors, no EP-01-07 modifications).
- [ ] EP-01-03 additive config extensions: `AppConstants` (9 monitoring variable names + 9 defaults), `EnvironmentConfig` (`monitoringConfig` field), `EnvironmentLoader` (`MonitoringConfig.fromSource`, step 10), `CompileTimeEnvironmentValueSource` (9 monitoring variables).

### Expected Workflows

- [ ] **Logging initialization:** `initializeLogging(config)` → constructs `PiiRedactor` (with `config.enablePiiRedaction` toggle) → determines `LogLevel` threshold from `config.minimumLogLevel` → constructs sinks based on environment + `config.enableSentry` (Development: `[DeveloperLogSink]`; Staging/Production with Sentry: `[SentryLogSink]`; fallback: `[DeveloperLogSink]`) → constructs `LogRouter(sinks, minimumLevel)` → constructs `LoggerFactory(router, redactor)` → returns `LoggingLayer`.
- [ ] **Monitoring initialization:** `initializeMonitoring(config, flags)` → calls `SentryInitializer.initialize(config)` → constructs `MonitoringService(config)` → constructs `PerformanceTracer(config, flags)` → returns `MonitoringLayer`.
- [ ] **Structured logging:** Subsystem calls `loggerFactory.named('hivorr.sync')` → returns `HivorrLogger` with `_name = 'hivorr.sync'` → calls `logger.info('Sync started', {'queueDepth': 5})` → `PiiRedactor` redacts message and context → `LogEntry` constructed → `LogRouter.write()` checks threshold → dispatches to active sink(s).
- [ ] **PII redaction flow:** Caller passes `'User user@example.com logged in'` → `PiiRedactor.redact()` → `'User ***@***.*** logged in'` → `LogEntry.message` contains redacted text → sink receives only redacted content.
- [ ] **Context redaction flow:** Caller passes `{'email': 'user@test.com', 'action': 'login'}` → `PiiRedactor.redactContext()` → `{'email': '[REDACTED]', 'action': 'login'}` → `LogEntry.context` contains redacted map.
- [ ] **Error capture flow:** Subsystem calls `logger.error('RPC failed', error: exception, stackTrace: trace)` → `HivorrLogger` redacts message/context → `LogEntry` with error + stackTrace → `SentryLogSink` calls `Sentry.captureException()` with context as extras.
- [ ] **Breadcrumb trail:** Subsystem calls `monitoringService.addBreadcrumb('auth', 'User logged in', {'method': 'email'})` → `PiiRedactor` redacts data → `Sentry.addBreadcrumb()` with redacted data → subsequent crash event includes breadcrumb trail.
- [ ] **Performance tracing:** EP-02+ feature calls `tracer.startTransaction('checkout', 'navigation')` → returns `ISentrySpan` → feature calls `tracer.startChildSpan(txn, 'payment', 'http')` → returns child span → feature calls `tracer.finishSpan(span, status: SentrySpanStatus.ok())`.
- [ ] **Graceful disable:** `MonitoringConfig.enableSentry: false` → `SentryInitializer` no-op → `MonitoringService` all methods no-op → `PerformanceTracer` all methods no-op → `SentryLogSink` excluded from router → `DeveloperLogSink` used as fallback.
- [ ] **API log sink upgrade:** EP-01-15 bootstrap constructs `SentryApiLogSink(loggerFactory.named('hivorr.api'))` → passes to `LoggingInterceptor` constructor → EP-01-07 interceptor logs through structured logger → API logs routed to Sentry in production without EP-01-07 modifications.

### Success Conditions

- [ ] `LogLevel` severity ordering is correct: `debug(0) < info(1) < warning(2) < error(3) < fatal(4)`.
- [ ] `LogLevel.meetsThreshold()` works correctly: `debug.meetsThreshold(debug)` = `true`; `debug.meetsThreshold(warning)` = `false`; `fatal.meetsThreshold(debug)` = `true`.
- [ ] `LogLevel.values` has exactly 5 entries.
- [ ] `LogEntry` immutability verified: context map cannot be modified after construction.
- [ ] PII redaction correctly masks all 6 default patterns (email, Nigerian phone, generic phone, Bearer token, JWT, 10-digit account number).
- [ ] PII context redaction correctly replaces all 11 sensitive key names with `'[REDACTED]'`.
- [ ] No false positives: `'Order #12345 placed'` → unchanged (5-digit number, not 10-digit account).
- [ ] Multiple PII instances in one message → all instances redacted.
- [ ] `LogRouter` correctly filters: entry below minimum level → no sink receives it; entry at or above → all sinks receive it.
- [ ] `SentryLogSink` correctly routes: `debug`/`info`/`warning` → breadcrumbs; `error`/`fatal` with error → `captureException`; `error`/`fatal` without error → `captureMessage`.
- [ ] `MonitoringService.setUserContext('entity-uuid')` sets Sentry user with `id: 'entity-uuid'` and no other fields (no name, email, phone).
- [ ] `MonitoringConfig` sourced from `EnvironmentConfig` with correct defaults when variables absent.
- [ ] `SentryApiLogSink` is type-compatible with EP-01-07's `ApiLogSink` interface.
- [ ] Sentry gracefully disabled when DSN is empty or `enableSentry` is `false` — all methods become no-ops without errors.

### Error Handling Scenarios

- [ ] `SentryFlutter.init()` failure (invalid DSN format) → error handled per `EnvironmentLoader` convention; app does not crash.
- [ ] `SentryInitializer.initialize()` with `enableSentry: false` → `SentryFlutter.init()` not called; no SDK overhead.
- [ ] `SentryInitializer.initialize()` with empty DSN → `SentryFlutter.init()` not called; no SDK overhead.
- [ ] `MonitoringService.captureException()` when Sentry disabled → no-op; no crash, no error propagation.
- [ ] `MonitoringService.addBreadcrumb()` when Sentry disabled → no-op; no crash.
- [ ] `PerformanceTracer.finishSpan(null)` → no-op; no crash.
- [ ] `PerformanceTracer.startTransaction()` when disabled → returns `null`; consumer handles null gracefully.
- [ ] `PiiRedactor.redact('')` (empty string) → returns empty string; no crash.
- [ ] `PiiRedactor.redactContext({})` (empty map) → returns empty map; no crash.
- [ ] `PiiRedactor.redactContext()` with null values in map → handled gracefully; no crash.
- [ ] `LogRouter` with empty sinks list → entry discarded; no crash.
- [ ] `SentryApiLogSink.log('unknown_level', 'message')` → defaults to `info()`; no crash.
- [ ] `HivorrLogger.error()` with null `error` and null `stackTrace` → `LogEntry` constructed with null fields; no crash.
- [ ] `MonitoringConfig.fromSource()` with invalid `traceSampleRate` (e.g., negative, > 1.0) → clamped to 0.0–1.0 or handled per `EnvironmentLoader` convention.
- [ ] `MonitoringConfig.fromSource()` with invalid `minimumLogLevel` string → handled per `EnvironmentLoader` convention (default or throw).

### Important User Interactions (developer/consumer)

- [ ] EP-01-15 engineer can call `initializeLogging(config)` at bootstrap to obtain fully wired `LoggingLayer` without modifying EP-01-14 files.
- [ ] EP-01-15 engineer can call `initializeMonitoring(config, flags)` at bootstrap to obtain fully wired `MonitoringLayer` without modifying EP-01-14 files.
- [ ] EP-01-15 engineer can construct `SentryApiLogSink(loggingLayer.loggerFactory.named('hivorr.api'))` and pass to EP-01-07's `LoggingInterceptor` constructor — without modifying EP-01-07 files.
- [ ] Any subsystem engineer can call `loggingLayer.loggerFactory.named('hivorr.sync')` to obtain a scoped logger for structured, PII-redacted logging.
- [ ] Any subsystem engineer can call `monitoringLayer.service.addBreadcrumb('category', 'message', {'key': 'value'})` to add contextual breadcrumbs.
- [ ] Any subsystem engineer can call `monitoringLayer.service.captureException(error, stackTrace: trace)` to report crashes.
- [ ] EP-02+ engineer can call `monitoringLayer.tracer.startTransaction('checkout', 'navigation')` to trace critical user journeys.
- [ ] Consumers depend only on `HivorrLogger`, `MonitoringService`, `PerformanceTracer` abstractions — no direct Sentry SDK coupling.
- [ ] All config (DSN, sample rates, log levels, PII toggle) supplied via `EnvironmentConfig`; no `String.fromEnvironment`.

---

## Technical Verification

### Architecture Compliance

- [ ] All logging code resides under approved `lib/core/logging/` directory (no new top-level `lib/` directory).
- [ ] All monitoring code resides under approved `lib/core/monitoring/` directory (no new top-level `lib/` directory).
- [ ] Logging and monitoring are cleanly separated per ARCHITECTURE.md `lib/core/` mapping.
- [ ] No business logic, pricing, matching, escrow, or verification decisions present (AGENT.md Rules 1, 4).
- [ ] Layer observes, logs, and reports only; does not authorize, compute, or decide outcomes (AGENT.md Rule 4).
- [ ] No modifications to EP-01-07 (`lib/core/api/`), EP-01-09 (`lib/core/authentication/`), EP-01-12 (`lib/core/sync/`), or EP-01-13 (`lib/core/network/`) files.
- [ ] No bootstrap/UI/DB/auth/security/network/sync code included.
- [ ] No `main.dart` or app bootstrap modifications.

### Required System Behavior

- [ ] `HivorrLogger` applies PII redaction to message and context **before** `LogEntry` construction — sinks receive only redacted entries.
- [ ] `LogRouter` discards entries below minimum threshold before any sink processes them (zero sink overhead for filtered entries).
- [ ] `DeveloperLogSink` uses `dart:developer` `developer.log()` — never `print()`.
- [ ] `SentryLogSink` adds breadcrumb for all entries (including error/fatal) so events have contextual trail.
- [ ] `SentryInitializer` `beforeSend` hook is the last line of defense — strips `Authorization`/`Cookie` headers and sensitive extra keys.
- [ ] `MonitoringService` all methods are no-ops when `enableSentry` is `false` (safe to call regardless of environment).
- [ ] `PerformanceTracer` all methods are no-ops when `enableAnalyticsTracking` is `false` or Sentry is disabled.
- [ ] `MonitoringService.setUserContext()` accepts entity ID (UUID) only — no PII fields exposed to Sentry.
- [ ] `MonitoringService.addBreadcrumb()` redacts `data` map through `PiiRedactor` before passing to Sentry SDK.
- [ ] `SentryApiLogSink` implements EP-01-07's `ApiLogSink` without modifying EP-01-07 code.
- [ ] Environment-based sink selection: Development → `[DeveloperLogSink]`; Staging/Production with Sentry → `[SentryLogSink]`; fallback → `[DeveloperLogSink]`.

### Module Integration

- [ ] Compiles against EP-01-03 `EnvironmentConfig` (reads `monitoringConfig` field and `featureFlags.enableAnalyticsTracking`/`enableVerboseLogging`).
- [ ] Reuses EP-01-02's `sentry_flutter: 9.27.0` package (no new dependency added to `pubspec.yaml`).
- [ ] Implements EP-01-07's `ApiLogSink` interface (from `lib/core/api/logging/api_log_sink.dart`) without modifying EP-01-07 files.
- [ ] Does not modify EP-01-07, EP-01-09, EP-01-12, or EP-01-13 files.
- [ ] `logging.dart` and `monitoring.dart` barrels are usable as EP-01-15 bootstrap hooks.
- [ ] EP-01-03 additive config extensions follow established pattern from EP-01-10/11/12/13 (AppConstants → EnvironmentConfig → EnvironmentLoader → CompileTimeEnvironmentValueSource).

### Technical Requirements from the Implementation Plan

- [ ] No new dependencies added to `pubspec.yaml` (reuses `sentry_flutter` from EP-01-02).
- [ ] `flutter analyze` passes with strict lints; no `print`; no `implicit_dynamic`.
- [ ] No `String.fromEnvironment` in `lib/core/logging/` or `lib/core/monitoring/`; config sourced via EP-01-03 `EnvironmentConfig`.
- [ ] `LogEntry` immutability implemented (defensive copy or `Map.unmodifiable` on context).
- [ ] `PiiRedactor` implements all 6 default regex patterns per §5.5 table.
- [ ] `PiiRedactor` implements all 11 sensitive key name replacements per §5.5 list.
- [ ] `MonitoringConfig` implements all 9 fields per §5.11 table.
- [ ] `SentryInitializer` `beforeSend` hook implemented per §5.13 specification.
- [ ] `LogLevel` enum uses Dart enhanced enum with `severity` field and `meetsThreshold()` method.

---

## Data Verification

> This task introduces **no persistent data**. `LogEntry` is a transient in-memory value object; breadcrumbs are managed by Sentry SDK in-memory (bounded).

### Data Creation

- [ ] `LogEntry` records are transient in-memory structured records (level, message, logger name, timestamp, context, error, stack trace); contain no business logic, no domain entities.
- [ ] `LogEntry` is never persisted to local storage (no Hive/driver calls, no `StorageEngine` usage).
- [ ] Breadcrumbs managed by Sentry SDK in-memory; bounded by `maxBreadcrumbCount` (default 100); FIFO eviction.
- [ ] No tokens, secrets, or credentials stored or transmitted by this layer beyond the Sentry DSN (public, client-safe ingestion endpoint).
- [ ] No business, financial, or domain data created by this task.

### Data Updates

- [ ] No persistent data updates (no storage, no cache, no database).
- [ ] Sentry SDK manages its own event transport and buffering internally.
- [ ] Breadcrumbs are bounded by `maxBreadcrumbCount`; FIFO eviction prevents unbounded growth.

### Data Relationships

- [ ] `LogEntry` is a standalone value object; no relationships to other entities.
- [ ] `LogLevel` is a standalone enum; no relationships to other enums.
- [ ] `MonitoringConfig` is a flat configuration class; no relational data.

### Data Accuracy

- [ ] `LogEntry` fields correctly populated by `HivorrLogger` (level, redacted message, logger name, timestamp, redacted context, error, stack trace).
- [ ] `PiiRedactor` regex patterns correctly match and mask PII per §5.5 table.
- [ ] `MonitoringConfig` values correctly parsed from `EnvironmentConfig` source.

### Data Integrity

- [ ] No persistent data to verify integrity (no storage, no cache, no database).
- [ ] `LogEntry` immutability ensures context map cannot be modified after construction.
- [ ] No tokens, secrets, or credentials ever stored in log entries or breadcrumbs (PII redactor + `beforeSend` hook defense-in-depth).
- [ ] User context in Sentry limited to entity ID (UUID) only — no name, email, phone, or address.

---

## Security Verification

### Authentication

- [ ] No authentication logic implemented here (owned by EP-01-09); logging/monitoring layer does not read/store session material.
- [ ] `MonitoringService` does not handle tokens, credentials, or auth state directly.
- [ ] `MonitoringService.setUserContext()` accepts entity ID (UUID) only — no auth tokens, no session IDs.

### Authorization

- [ ] No authorization/role/verification decisions made in this layer (AGENT.md Rule 4).
- [ ] Logging/monitoring layer does not grant or interpret any capability.
- [ ] Layer observes and reports only; does not authorize, compute, or decide outcomes.

### Access Control

- [ ] All monitoring config sourced exclusively from `EnvironmentConfig` (EP-01-03); no `String.fromEnvironment`, no hardcoded values.
- [ ] Client cannot switch environments at runtime (ENV-003 invariant preserved).
- [ ] Feature gates (`enableVerboseLogging`, `enableAnalyticsTracking`) respected; services always callable but consumers check flags.

### Sensitive Data Protection

- [ ] **PII redaction (primary control):** `PiiRedactor` applied to all log messages and context before any sink receives them. 6 regex patterns (email, Nigerian phone, generic phone, Bearer token, JWT, account number) + 11 sensitive key names.
- [ ] **PII redaction (defense-in-depth):** `SentryInitializer` `beforeSend` hook strips `Authorization`/`Cookie` headers from `event.request.headers` and sensitive keys from `event.extra`. Returns `null` to drop events that cannot be sanitized.
- [ ] **Breadcrumb PII:** `MonitoringService.addBreadcrumb()` redacts `data` map through `PiiRedactor` before passing to Sentry SDK.
- [ ] **User context PII:** `MonitoringService.setUserContext()` accepts entity ID (UUID) only — no name, email, phone, or address fields.
- [ ] **API log PII:** `SentryApiLogSink` routes through `HivorrLogger` which applies PII redaction. EP-01-07's `LoggingInterceptor` already never logs Authorization headers or bodies.
- [ ] **Sentry DSN:** DSN is a public, client-safe ingestion endpoint (designed for client SDKs). Not a secret. Sourced from `EnvironmentConfig` — no hardcoded values.
- [ ] **No `print()` calls** in production code (enforced by strict `analysis_options.yaml`).
- [ ] **No hardcoded config values** — all monitoring parameters sourced exclusively from `EnvironmentConfig`.
- [ ] **Sensitive key name leakage:** `PiiRedactor.redactContext()` replaces values for all 11 sensitive key names with `'[REDACTED]'`.
- [ ] **Log injection:** Log messages treated as opaque strings by sinks; no log message is ever evaluated as code or used in SQL queries.

### Security Rules

- [ ] AGENT.md Rule 4 upheld: no business/pricing/matching/verification logic.
- [ ] Layer observes and reports only; does not authorize, compute, or decide outcomes.
- [ ] No service-role key, no hardcoded secret, no credentials surfaced in logs.
- [ ] EP-01-03 secret-handling invariants preserved transitively.
- [ ] PII redactor is defense-in-depth; primary control is that callers should never pass PII to the logger.

---

## Performance Verification

### Response Performance

- [ ] Level-gated filtering: `LogRouter` discards entries below minimum threshold before any sink processes them. In Production (`warning` minimum), `debug` and `info` entries discarded with zero sink overhead.
- [ ] Lazy Sentry init: Sentry SDK not initialized when `enableSentry` is `false` or DSN is empty. No SDK overhead in Development when disabled.
- [ ] `DeveloperLogSink` writes to `dart:developer` (synchronous, fast). No synchronous I/O blocking on UI thread.
- [ ] `SentryLogSink` calls Sentry SDK methods which buffer internally and transport asynchronously.
- [ ] PII redaction regex cost is O(n) per pattern per message; negligible for typical log message lengths (< 500 chars). Redaction is synchronous and non-blocking.

### Resource Usage

- [ ] Breadcrumbs bounded: Sentry SDK retains at most `maxBreadcrumbCount` (default 100) in memory. FIFO eviction prevents unbounded growth.
- [ ] `LogRouter` holds a list of sinks (1–2). Minimal memory footprint.
- [ ] `LoggerFactory` holds references to router and redactor (shared across all named loggers).
- [ ] `MonitoringService` holds config reference. Sentry SDK manages its own memory (bounded breadcrumbs, event queue).
- [ ] `PerformanceTracer` is a no-op when disabled; no resource allocation.
- [ ] No new dependencies added to `pubspec.yaml`; zero impact on 15–20 MB installer target.

### System Reliability

- [ ] `SentryInitializer` no-op when disabled; no crash risk from uninitialized SDK.
- [ ] `MonitoringService` all methods no-op when disabled; safe to call regardless of environment.
- [ ] `PerformanceTracer.finishSpan(null)` → no-op; no crash.
- [ ] `LogRouter` with empty sinks list → entry discarded; no crash.
- [ ] Sentry SDK manages its own offline event buffering internally.

### Performance Expectations

- [ ] Unit tests execute quickly with no live backend (mock Sentry, fake sinks).
- [ ] No performance regression in `flutter analyze` / `flutter test` within CI budget.
- [ ] `traceSampleRate` and `profileSampleRate` allow tuning Sentry overhead in production (e.g., 10% trace sampling for high-traffic environments).
- [ ] PII redaction regex is lightweight; negligible CPU cost for typical log message lengths.

---

## Testing Verification

### Manual Testing Requirements

- [ ] Code review confirms `lib/core/logging/` matches §5.2 structure (9 files) and scope containment.
- [ ] Code review confirms `lib/core/monitoring/` matches §5.2 structure (5 files) and scope containment.
- [ ] Diff review confirms only `lib/core/logging/` + `lib/core/monitoring/` + `test/unit/core/logging/` + `test/unit/core/monitoring/` + EP-01-03 additive config extensions (`AppConstants`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`) changed.
- [ ] Diff review confirms no modifications to EP-01-07, EP-01-09, EP-01-12, or EP-01-13 files.
- [ ] Diff review confirms no bootstrap/UI/DB/auth/security/network/sync implementation leaked.
- [ ] Diff review confirms no phase-document edits.

### Automated Testing Requirements

- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes, including all new `test/unit/core/logging/` and `test/unit/core/monitoring/` tests.
- [ ] Available platform smoke build passes (no native config changed).

### Edge Cases

- [ ] `PiiRedactor.redact('')` (empty string) → returns empty string; no crash.
- [ ] `PiiRedactor.redactContext({})` (empty map) → returns empty map; no crash.
- [ ] `PiiRedactor.redactContext()` with null values in map → handled gracefully.
- [ ] Multiple PII instances in one message → all instances redacted.
- [ ] No false positives: `'Order #12345 placed'` → unchanged (5-digit number, not 10-digit account).
- [ ] `PiiRedactor` with `enablePiiRedaction: false` → text passes through unchanged.
- [ ] `LogRouter` with empty sinks list → entry discarded; no crash.
- [ ] `MonitoringConfig.fromSource()` with no values → all defaults applied.
- [ ] `MonitoringConfig.fromSource()` with `sentryDsn` empty → Sentry disabled.
- [ ] `MonitoringConfig.fromSource()` with `enableSentry: false` → Sentry disabled.
- [ ] `MonitoringConfig.fromSource()` with `traceSampleRate` outside 0.0–1.0 → clamped or handled per convention.
- [ ] `MonitoringConfig.fromSource()` with invalid `minimumLogLevel` string → handled per `EnvironmentLoader` convention.
- [ ] `SentryApiLogSink.log('unknown_level', 'message')` → defaults to `info()`.
- [ ] `HivorrLogger.error()` with null `error` and null `stackTrace` → `LogEntry` constructed with null fields.
- [ ] `PerformanceTracer.finishSpan(null)` → no-op; no crash.
- [ ] `PerformanceTracer.startTransaction()` when disabled → returns `null`.

### Failure Scenarios

- [ ] `SentryFlutter.init()` failure (invalid DSN) → error handled; app does not crash.
- [ ] `SentryInitializer.initialize()` with `enableSentry: false` → no-op; no SDK overhead.
- [ ] `SentryInitializer.initialize()` with empty DSN → no-op; no SDK overhead.
- [ ] `MonitoringService.captureException()` when Sentry disabled → no-op; no crash.
- [ ] `MonitoringService.addBreadcrumb()` when Sentry disabled → no-op; no crash.
- [ ] `SentryLogSink` when Sentry SDK not initialized → graceful handling (no crash).
- [ ] `beforeSend` hook encounters event with no `request` field → no crash; event processed normally.
- [ ] `beforeSend` hook encounters event with no `extra` field → no crash; event processed normally.

---

## User Acceptance Verification

- [ ] Downstream engineer (EP-01-15) can call `initializeLogging(config)` at bootstrap to obtain fully wired `LoggingLayer` without modifying EP-01-14 files.
- [ ] Downstream engineer (EP-01-15) can call `initializeMonitoring(config, flags)` at bootstrap to obtain fully wired `MonitoringLayer` without modifying EP-01-14 files.
- [ ] Downstream engineer (EP-01-15) can construct `SentryApiLogSink(loggingLayer.loggerFactory.named('hivorr.api'))` and pass to EP-01-07's `LoggingInterceptor` — without modifying EP-01-07 files.
- [ ] Downstream engineer (EP-01-09) can call `monitoringLayer.service.addBreadcrumb('auth', 'Login attempt')` to emit auth event breadcrumbs.
- [ ] Downstream engineer (EP-01-12) can call `loggingLayer.loggerFactory.named('hivorr.sync')` to obtain a scoped logger for sync engine events.
- [ ] Downstream engineer (EP-01-13) can call `monitoringLayer.service.addBreadcrumb('network', 'Connectivity changed')` to emit network event breadcrumbs.
- [ ] Downstream engineer (EP-02+) can call `monitoringLayer.tracer.startTransaction('checkout', 'navigation')` to trace critical user journeys.
- [ ] Documented integration contract (§5.16, §5.17, §5.18) is unambiguous and references correct consumer seams.
- [ ] No business logic, pricing, matching, or financial rules present (AGENT.md Rules 1, 4 honored).
- [ ] Layer observes and reports only; does not authorize, compute, or decide outcomes (AGENT.md Rule 4).

---

## Final Approval Checklist

**Logging — Structure & Code**
- [ ] `lib/core/logging/` contains §5.2 structure; all 9 files implemented and importing correctly.
- [ ] `LogLevel` enum defines `debug`, `info`, `warning`, `error`, `fatal` with numeric severity and `meetsThreshold()`.
- [ ] `LogEntry` is immutable with `level`, `message`, `loggerName`, `timestamp`, `context`, `error`, `stackTrace`.
- [ ] `PiiRedactor` detects and masks email, phone (Nigerian + generic), Bearer tokens, JWTs, and 10-digit account numbers. Redacts 11 sensitive context key names.
- [ ] `LogSink` abstract interface defines `write(LogEntry)` and `dispose()`.
- [ ] `DeveloperLogSink` uses `dart:developer` `developer.log()` — never `print()`.
- [ ] `SentryLogSink` routes `debug`/`info`/`warning` to breadcrumbs, `error`/`fatal` to `captureException`/`captureMessage`.
- [ ] `LogRouter` dispatches to configured sinks with minimum level filtering.
- [ ] `HivorrLogger` applies PII redaction to message and context before `LogEntry` construction. Provides `debug`, `info`, `warning`, `error`, `fatal` methods.
- [ ] `LoggerFactory` creates named loggers via `named(String name)`.
- [ ] `logging.dart` barrel exports public API; `initializeLogging()` wired for EP-01-15; `LoggingLayer` aggregate.

**Monitoring — Structure & Code**
- [ ] `lib/core/monitoring/` contains §5.2 structure; all 5 files implemented and importing correctly.
- [ ] `MonitoringConfig` sourced from `EnvironmentConfig`; 9 fields per §5.11. No `String.fromEnvironment`, no hardcoded values.
- [ ] `SentryInitializer` calls `SentryFlutter.init()` with correct config; `beforeSend` hook strips `Authorization`/`Cookie` headers and sensitive extra keys. No-op when disabled.
- [ ] `MonitoringService` wraps `captureException`, `captureMessage`, `addBreadcrumb`, `setUserContext`, `clearUserContext`, `setTag`. All methods no-ops when disabled.
- [ ] `MonitoringService.setUserContext()` accepts entity ID only — no PII fields.
- [ ] `MonitoringService.addBreadcrumb()` redacts data through `PiiRedactor`.
- [ ] `PerformanceTracer` provides `startTransaction`, `startChildSpan`, `finishSpan`. No-op when `enableAnalyticsTracking` is `false` or Sentry disabled.
- [ ] `monitoring.dart` barrel exports public API; `initializeMonitoring()` wired for EP-01-15; `MonitoringLayer` aggregate.

**Cross-Cutting**
- [ ] `SentryApiLogSink` implements EP-01-07's `ApiLogSink` interface; routes through `HivorrLogger`. Type-compatible without EP-01-07 modifications.
- [ ] EP-01-03 additive config extensions: `AppConstants` (9 monitoring variable names + 9 defaults), `EnvironmentConfig` (`monitoringConfig` field), `EnvironmentLoader` (MonitoringConfig.fromSource, step 10), `CompileTimeEnvironmentValueSource` (9 monitoring variables).
- [ ] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/DB/auth/security/network/sync code included.
- [ ] No modifications to EP-01-07, EP-01-09, EP-01-12, or EP-01-13 files.
- [ ] No new dependencies added to `pubspec.yaml` (reuses `sentry_flutter` from EP-01-02).
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (log level, log entry, PII redactor, sinks, router, logger, factory, API log sink, config, service, initializer, tracer unit tests).
- [ ] Available platform smoke builds pass.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-14 changes (+ EP-01-03 additive config extensions).
- [ ] Project lead has verified functional, technical, data, security, performance, testing, and user-acceptance sections above — **signed off**.

---

## Implementation Sign-off (EP-01-14)

**Status:** ✅ **COMPLETED & VERIFIED**

**Evidence (2026-08-25):**
- `flutter analyze` (whole project): **No issues found**.
- `flutter test test/unit/core/logging test/unit/core/monitoring`: **62/62 passed**.
- Scope containment confirmed via `git status`: only `lib/core/logging/`, `lib/core/monitoring/`, 4 `lib/config/*` files, `documents/`, and `test/` changed. No `pubspec.yaml` change (no new deps), no `main.dart` change, no EP-01-07/09/12/13 edits.

**Deliverables:**
- Logging: `log_level`, `log_entry`, `pii_redactor`, `log_sink`, `developer_log_sink`, `sentry_log_sink`, `log_router`, `hivorr_logger` (+`LoggerFactory`), `sentry_api_log_sink`, `logging` (barrel + `initializeLogging` + `LoggingLayer`).
- Monitoring: `monitoring_config`, `monitoring_service`, `sentry_initializer`, `performance_tracer`, `monitoring` (barrel + `initializeMonitoring` + `MonitoringLayer`).
- EP-01-03 additive config extensions wired end-to-end.

**Two deviations ratified by implementation lead (EP-01-14 §Workflow line 76 and SDK 9.27 deprecations):**
1. `PiiRedactor.defaultSensitiveKeyNames` includes `email` (12 keys, not 11) because §Workflow line 76 explicitly requires `{'email': '[REDACTED]'}`. (Remove `email` if regex-style masking is preferred for context values.)
2. `SentryLogSink` attaches redacted context as breadcrumb `data` instead of deprecated Sentry `extra` (`SentryScope.setExtra`/`SentryEvent.extra` deprecated in SDK 9.27). Context still reaches the event trail.

**Out of scope (per DoD "no `main.dart` change"):** EP-01-15 bootstrap wiring of `initializeLogging`/`initializeMonitoring` — seams provided and ready.

(End of file)
