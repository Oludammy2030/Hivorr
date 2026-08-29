import 'package:sentry_flutter/sentry_flutter.dart';

/// Shared Sentry test harness.
///
/// Initializes the real Sentry SDK exactly once with a fake DSN and a no-op
/// transport, recording every outgoing event through `beforeSend`. This lets
/// the Sentry-dependent unit tests verify delegation to the SDK without any
/// network access.
final List<SentryEvent> recordedSentryEvents = <SentryEvent>[];

bool _sentryInitialized = false;

const String _fakeDsn = 'https://username@o123456.ingest.sentry.io/1';

/// No-network transport that simply drops envelopes.
class _RecordingTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => SentryId.newId();
}

/// Ensures Sentry is initialized (once) and resets state for a fresh test.
Future<void> setUpSentryRecording() async {
  if (!_sentryInitialized) {
    _sentryInitialized = true;
    await Sentry.init((options) {
      options.dsn = _fakeDsn;
      options.transport = _RecordingTransport();
      options.beforeSend = (SentryEvent event, Hint hint) {
        recordedSentryEvents.add(event);
        return event;
      };
    });
  } else {
    recordedSentryEvents.clear();
    await Sentry.configureScope((scope) => scope.clear());
  }
}

/// Resets recorded events and the active scope between tests.
Future<void> resetSentryScope() async {
  recordedSentryEvents.clear();
  await Sentry.configureScope((scope) => scope.clear());
}

/// Recording harness around the real Sentry SDK for unit tests.
///
/// Captures both events (`beforeSend`) and breadcrumbs (`beforeBreadcrumb`).
class SentryRecordingHarness {
  final List<SentryEvent> capturedEvents = <SentryEvent>[];
  final List<Breadcrumb> capturedBreadcrumbs = <Breadcrumb>[];

  bool _initialized = false;

  /// Initializes Sentry once (idempotent across tests) and resets captures.
  Future<void> setUp() async {
    if (!_initialized) {
      _initialized = true;
      await Sentry.init((options) {
        options.dsn = _fakeDsn;
        options.transport = _RecordingTransport();
        options.beforeSend = (SentryEvent event, Hint hint) {
          capturedEvents.add(event);
          return event;
        };
        options.beforeBreadcrumb = (Breadcrumb? breadcrumb, Hint hint) {
          if (breadcrumb != null) {
            capturedBreadcrumbs.add(breadcrumb);
          }
          return breadcrumb;
        };
      });
    } else {
      await reset();
    }
  }

  /// Clears both [capturedEvents] and [capturedBreadcrumbs] and the scope.
  Future<void> reset() async {
    capturedEvents.clear();
    capturedBreadcrumbs.clear();
    await Sentry.configureScope((scope) => scope.clear());
  }

  /// The most recently captured event, or `null` if none.
  SentryEvent? get lastEvent =>
      capturedEvents.isEmpty ? null : capturedEvents.last;

  /// The most recently captured breadcrumb, or `null` if none.
  Breadcrumb? get lastBreadcrumb =>
      capturedBreadcrumbs.isEmpty ? null : capturedBreadcrumbs.last;
}
