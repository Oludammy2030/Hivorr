import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/datasources/remote/service_review_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_service_review_remote_data_source.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/data/repositories/service_review_repository.dart';
import 'package:hivorr/data/repositories/service_review_repository_impl.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';

/// Wires the double-blind review layer for EP-03-12.
///
/// Builds the [SupabaseServiceReviewRemoteDataSource] (the three
/// client-callable review RPCs), the [ServiceReviewRepositoryImpl], the
/// [ServiceReviewService] facade, and a ready [ServiceReviewProvider].
/// Mirrors `registerDocumentsLayer`: the datasource is overridable for tests.
///
/// The record shape follows the plan seam contract:
/// `({dataSource, repository, provider, service})`.
({
  ServiceReviewRemoteDataSource dataSource,
  ServiceReviewRepository repository,
  ServiceReviewProvider provider,
  ServiceReviewService service,
})
registerReviewsLayer({
  required ApiLayer apiLayer,
  ServiceReviewRemoteDataSource? dataSource,
  HivorrLogger? logger,
  PerformanceTracer? tracer,
}) {
  final ServiceReviewRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseServiceReviewRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final ServiceReviewRepository repository = ServiceReviewRepositoryImpl(
    remote: resolvedDataSource,
  );
  final ServiceReviewService service = ServiceReviewService(
    repository: repository,
    logger: logger,
    tracer: tracer,
  );
  final ServiceReviewProvider provider = ServiceReviewProvider(
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
