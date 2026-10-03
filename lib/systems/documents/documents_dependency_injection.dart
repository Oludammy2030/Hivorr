import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:hivorr/data/datasources/remote/service_contract_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_service_contract_remote_data_source.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:hivorr/data/repositories/service_contract_repository_impl.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';

/// Wires the service contract engagement layer for EP-03-10.
///
/// Builds the [SupabaseServiceContractRemoteDataSource] (the eight contract
/// RPCs), the [ServiceContractRepositoryImpl], a ready
/// [ServiceContractProvider], and the [ContractService] facade over a
/// [SupabaseStorageService] (for `service-listing-media` milestone evidence).
/// Mirrors `registerMarketplaceLayer`: the storage service defaults to the
/// API-layer client and is overridable for tests.
///
/// The record shape is frozen by the plan seam contract:
/// `({dataSource, repository, provider, service})`.
({
  ServiceContractRemoteDataSource dataSource,
  ServiceContractRepository repository,
  ServiceContractProvider provider,
  ContractService service,
})
registerDocumentsLayer({
  required ApiLayer apiLayer,
  ServiceContractRemoteDataSource? dataSource,
  StorageService? storage,
  HivorrLogger? logger,
  PerformanceTracer? tracer,
}) {
  final ServiceContractRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabaseServiceContractRemoteDataSource(
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
  final ServiceContractRepository repository = ServiceContractRepositoryImpl(
    remote: resolvedDataSource,
  );
  final ContractService service = ContractService(
    repository: repository,
    supabase: apiLayer.supabaseClient,
    storage: resolvedStorage,
    logger: logger,
    tracer: tracer,
  );
  final ServiceContractProvider provider = ServiceContractProvider(
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
