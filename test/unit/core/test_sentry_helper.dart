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
