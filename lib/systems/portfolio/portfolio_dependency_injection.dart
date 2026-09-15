import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/core/storage/storage_service.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:hivorr/data/datasources/remote/portfolio_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_portfolio_remote_data_source.dart';
import 'package:hivorr/data/providers/portfolio_provider.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/data/repositories/portfolio_repository_impl.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';

/// Wires the portfolio public-profile layer for EP-02-19.
///
/// Builds the [SupabasePortfolioRemoteDataSource] (the sole read is the
/// `portfolio_public_profile_get` SECURITY DEFINER RPC), the
/// [PortfolioRepositoryImpl], a ready [PortfolioProvider], and the
/// [ProfessionalProfileService] facade over a [SupabaseStorageService]
/// (for public avatar/portfolio URL resolution). Mirrors
/// `registerOnboardingLayer`: the storage service defaults to the API-layer
/// client and is overridable for tests (DoD FV-20, TV-18).
///
/// The record shape is frozen by the DoD seam contract:
/// `({dataSource, repository, provider, service})`.
({PortfolioRemoteDataSource dataSource, PortfolioRepository repository, PortfolioProvider provider, ProfessionalProfileService service})
registerPortfolioLayer({
  required ApiLayer apiLayer,
  PortfolioRemoteDataSource? dataSource,
  StorageService? storage,
  String seoBaseUrl = '',
  HivorrLogger? logger,
  PerformanceTracer? tracer,
}) {
  final PortfolioRemoteDataSource resolvedDataSource =
      dataSource ??
      SupabasePortfolioRemoteDataSource(
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
  final PortfolioRepository repository =
      PortfolioRepositoryImpl(remote: resolvedDataSource);
  final PortfolioProvider provider = PortfolioProvider(repository: repository);
  final ProfessionalProfileService service = ProfessionalProfileService(
    provider: provider,
    storage: resolvedStorage,
    seoBaseUrl: seoBaseUrl,
    logger: logger,
    tracer: tracer,
  );
  return (
    dataSource: resolvedDataSource,
    repository: repository,
    provider: provider,
    service: service,
  );
}