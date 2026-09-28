import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:hivorr/data/datasources/remote/service_listing_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_service_listing_remote_data_source.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/data/repositories/service_listing_repository.dart';
import 'package:hivorr/data/repositories/service_listing_repository_impl.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';

/// Wires the service listing owner-management layer for EP-03-08.
///
/// Builds the [SupabaseServiceListingRemoteDataSource] (the six owner RPCs
/// plus the `service_favorite_toggle` read-through), the
/// [ServiceListingRepositoryImpl], a ready [ServiceListingProvider], and the
/// [ServiceListingService] facade over a [SupabaseStorageService] (for
/// `service-listing-media` uploads). Mirrors `registerPortfolioLayer`: the
/// storage service defaults to the API-layer client and is overridable for
/// tests.
///
/// The record shape is frozen by the plan seam contract:
/// `({dataSource, repository, provider, service})`.
({
  ServiceListingRemoteDataSource dataSource,
  ServiceListingRepository repository,
  ServiceListingProvider provider,
  ServiceListingService service,
})
registerMarketplaceLayer({
  required ApiLayer apiLayer,
  ServiceListingRemoteDataSource? dataSource,
  StorageService? storage,
  HivorrLogger? logger,
  PerformanceTracer? tracer,
}) {
  final ServiceListingRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseServiceListingRemoteDataSource(
        dio: apiLayer.dio,
        supabase: apiLayer.supabaseClient,
        exceptionMapper: apiLayer.exceptionMapper,
      );
  final StorageService resolvedStorage =
      storage ??
      SupabaseStorageService(
        storageClient: apiLayer.supabaseClient.storage,
        dio: apiLayer.dio,
        tokenProvider: apiLayer.tokenProvider,
      );
  final ServiceListingRepository repository = ServiceListingRepositoryImpl(
    remote: resolvedDataSource,
  );
  final ServiceListingService service = ServiceListingService(
    repository: repository,
    supabase: apiLayer.supabaseClient,
    storage: resolvedStorage,
    logger: logger,
    tracer: tracer,
  );
  final ServiceListingProvider provider = ServiceListingProvider(
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
