import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/datasources/remote/scheduling_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_scheduling_remote_data_source.dart';
import 'package:hivorr/data/providers/scheduling_provider.dart';
import 'package:hivorr/data/repositories/scheduling_repository.dart';
import 'package:hivorr/data/repositories/scheduling_repository_impl.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';

/// Wires the scheduling (availability + appointments) layer for EP-03-14.
///
/// Builds the [SupabaseSchedulingRemoteDataSource] (the five scheduling RPCs
/// plus participant RLS-`SELECT` reads per plan §7.1 Option B), the
/// [SchedulingRepositoryImpl], a ready [SchedulingProvider], and the
/// [SchedulingService] facade. Mirrors `registerDocumentsLayer`: the client
/// never writes scheduling tables — all state changes flow through the RPCs.
///
/// The record shape is frozen by the plan seam contract:
/// `({dataSource, repository, provider, service})`.
({
  SchedulingRemoteDataSource dataSource,
  SchedulingRepository repository,
  SchedulingProvider provider,
  SchedulingService service,
})
registerSchedulingLayer({
  required ApiLayer apiLayer,
  SchedulingRemoteDataSource? dataSource,
  HivorrLogger? logger,
  PerformanceTracer? tracer,
}) {
  final SchedulingRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseSchedulingRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final SchedulingRepository repository = SchedulingRepositoryImpl(
    remote: resolvedDataSource,
  );
  final SchedulingService service = SchedulingService(
    repository: repository,
    logger: logger,
    tracer: tracer,
  );
  final SchedulingProvider provider = SchedulingProvider(
    service: service,
    logger: logger,
  );
  return (
    dataSource: resolvedDataSource,
    repository: repository,
    provider: provider,
    service: service,
  );
}
