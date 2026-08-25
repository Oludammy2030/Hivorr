// The Sentry `beforeSend` hook must read/rewrite the deprecated `extra` map and
// use `copyWith` to produce a sanitized event. These are the only supported SDK
// APIs for the PII-stripping hook (EP-01-14 §5.13, §12), so the deprecation
// warning is intentionally suppressed here.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sensitive request header names stripped by [sentryBeforeSend].
const Set<String> _sensitiveHeaderNames = <String>{'authorization', 'cookie'};

/// Sensitive extra keys stripped by [sentryBeforeSend].
const Set<String> _sensitiveExtraKeys = <String>{
  'password',
  'token',
  'secret',
  'apikey',
  'authorization',
  'cookie',
  'creditcard',
  'bankaccount',
  'pin',
  'otp',
  'ssn',
};

/// PII-stripping `beforeSend` hook for the Sentry SDK.
///
/// Strips `Authorization`/`Cookie` headers from the event request and drops
/// any sensitive extra keys before an event is transmitted. Exposed as a
/// top-level function so it can be unit-tested without initializing Sentry
/// (EP-01-14 §5.13, §12).
SentryEvent? sentryBeforeSend(SentryEvent event, Hint hint) {
  var modified = event;

  final request = event.request;
  if (request != null) {
    final headers = request.headers;
    if (headers.isNotEmpty) {
      final containsSensitive = headers.keys.any(
        (k) => _sensitiveHeaderNames.contains(k.toLowerCase()),
      );
      if (containsSensitive) {
        final cleanedRequest = request.copyWith(
          headers: <String, String>{
            for (final entry in headers.entries)
              if (!_sensitiveHeaderNames.contains(entry.key.toLowerCase()))
                entry.key: entry.value,
          },
        );
        modified = modified.copyWith(request: cleanedRequest);
      }
    }
  }

  final extra = event.extra;
  if (extra != null && extra.isNotEmpty) {
    final containsSensitive = extra.keys.any(
      (k) => _sensitiveExtraKeys.contains(k.toLowerCase()),
    );
    if (containsSensitive) {
      modified = modified.copyWith(
        extra: <String, dynamic>{
          for (final entry in extra.entries)
            if (!_sensitiveExtraKeys.contains(entry.key.toLowerCase()))
              entry.key: entry.value,
        },
      );
    }
  }

  // Last line of defense: if any sensitive request header or extra key survived
  // stripping (i.e. the event could not be fully sanitized), drop the event
  // rather than risk transmitting PII (EP-01-14 §5.13, §12).
  final remainingHeaders = modified.request?.headers;
  if (remainingHeaders != null &&
      remainingHeaders.keys.any(
        (k) => _sensitiveHeaderNames.contains(k.toLowerCase()),
      )) {
    return null;
  }
  final remainingExtra = modified.extra;
  if (remainingExtra != null &&
      remainingExtra.keys.any(
        (k) => _sensitiveExtraKeys.contains(k.toLowerCase()),
      )) {
    return null;
  }

  return modified;
}

/// Initializes the Sentry Flutter SDK in an environment-aware manner.
///
/// No-op (returns immediately) when [MonitoringConfig.isSentryActive] is
/// `false`, so the SDK never loads in Development or when unconfigured
/// (EP-01-14 §5.13). The [init] parameter is injectable for testing.
class SentryInitializer {
  SentryInitializer._();

  /// Initializes Sentry from [config].
  ///
  /// [init] defaults to [SentryFlutter.init] but can be overridden in tests
  /// to verify initialization without loading the real SDK.
  static Future<void> initialize(
    MonitoringConfig config, {
    Future<void> Function(FutureOr<void> Function(SentryFlutterOptions))? init,
  }) async {
    if (!config.isSentryActive) return;
    final initFn = init ?? SentryFlutter.init;
    await initFn((options) {
      options.dsn = config.sentryDsn;
      options.environment = config.environment;
      options.release = config.release;
      options.tracesSampleRate = config.traceSampleRate;
      // ignore: experimental_member_use
      options.profilesSampleRate = config.profileSampleRate;
      options.maxBreadcrumbs = config.maxBreadcrumbCount;
      options.diagnosticLevel = SentryLevel.warning;
      options.debug = false;
      options.beforeSend = sentryBeforeSend;
    });
  }
}
