import 'package:hivorr/config/feature_flags/feature_flags.dart';

import 'package:hivorr/core/monitoring/monitoring_config.dart';
import 'package:hivorr/core/monitoring/monitoring_service.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/monitoring/sentry_initializer.dart';

export 'package:hivorr/core/monitoring/monitoring_config.dart';
export 'package:hivorr/core/monitoring/monitoring_service.dart';
export 'package:hivorr/core/monitoring/performance_tracer.dart';
export 'package:hivorr/core/monitoring/sentry_initializer.dart';

/// Aggregate of the wired monitoring layer, returned by [initializeMonitoring].
class MonitoringLayer {
  const MonitoringLayer({
    required this.service,
    required this.tracer,
    required this.config,
  });

  /// Crash capture, breadcrumbs, and user context.
  final MonitoringService service;

  /// Performance transaction/span helpers.
  final PerformanceTracer tracer;

  /// Active monitoring configuration.
  final MonitoringConfig config;
}

/// Constructs the monitoring layer from [MonitoringConfig] and [FeatureFlags].
///
/// Initializes Sentry, then wires the [MonitoringService] and
/// [PerformanceTracer]. EP-01-15 bootstrap calls this at startup (EP-01-14
/// §5.16).
Future<MonitoringLayer> initializeMonitoring(
  MonitoringConfig config,
  FeatureFlags flags,
) async {
  await SentryInitializer.initialize(config);
  final service = MonitoringService(config);
  final tracer = PerformanceTracer(config, flags);
  return MonitoringLayer(service: service, tracer: tracer, config: config);
}
