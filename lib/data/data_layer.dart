import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/storage/supabase_storage_service.dart';
import 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/data/repositories/verification_repository_impl.dart';

export 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
export 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
export 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
export 'package:hivorr/data/datasources/remote/entity_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_verification_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/verification_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/verification_remote_data_source.dart';
export 'package:hivorr/data/entities/entity.dart';
export 'package:hivorr/data/entities/entity_profile.dart';
export 'package:hivorr/data/entities/entity_role.dart';
export 'package:hivorr/data/entities/industry.dart';
export 'package:hivorr/data/entities/kyc_level.dart';
export 'package:hivorr/data/entities/profession.dart';
export 'package:hivorr/data/entities/verification_status.dart';
export 'package:hivorr/data/entities/verification_submission.dart';
export 'package:hivorr/data/mappers/entity_mapper.dart';
export 'package:hivorr/data/mappers/entity_profile_mapper.dart';
export 'package:hivorr/data/mappers/entity_role_mapper.dart';
export 'package:hivorr/data/mappers/industry_mapper.dart';
export 'package:hivorr/data/mappers/profession_mapper.dart';
export 'package:hivorr/data/mappers/verification_mapper.dart';
export 'package:hivorr/data/models/entity_dto.dart';
export 'package:hivorr/data/models/entity_profile_dto.dart';
export 'package:hivorr/data/models/entity_role_dto.dart';
export 'package:hivorr/data/models/industry_dto.dart';
export 'package:hivorr/data/models/kyc_level_dto.dart';
export 'package:hivorr/data/models/profession_dto.dart';
export 'package:hivorr/data/models/verification_status_dto.dart';
export 'package:hivorr/data/models/verification_submission_dto.dart';
export 'package:hivorr/data/providers/entity_provider.dart';
export 'package:hivorr/data/providers/submit_state.dart';
export 'package:hivorr/data/providers/taxonomy_provider.dart';
export 'package:hivorr/data/providers/verification_provider.dart';
export 'package:hivorr/data/repositories/entity_repository.dart';
export 'package:hivorr/data/repositories/entity_repository_impl.dart';
export 'package:hivorr/data/repositories/taxonomy_repository.dart';
export 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';
export 'package:hivorr/data/repositories/verification_repository.dart';
export 'package:hivorr/data/repositories/verification_repository_impl.dart';

/// Wires the Unified Data Access Layer for the active environment.
///
/// Consumes the [ApiLayer] produced by [ApiInitializer.initializeApi]
/// (EP-01-07) and returns a fully constructed [EntityProvider] ready for
/// EP-01-15 to place in the widget tree. `main.dart`/bootstrap is not
/// modified here (EP-01-08 §5.8).
EntityProvider registerDataLayer(ApiLayer apiLayer) {
  final remote = SupabaseEntityRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final local = InMemoryEntityLocalDataSource();
  final repository = EntityRepositoryImpl(remote: remote, local: local);
  return EntityProvider(repository: repository);
}

/// Wires the taxonomy (industry/profession) data slice for EP-02-07.
///
/// Builds the [TaxonomyRepository] (cache-first) and returns a ready
/// [TaxonomyProvider]. The repository's local datasource degrades gracefully
/// to in-memory storage until the app initializes the shared [CacheManager].
/// Exposed for the bootstrap to register in the widget tree's MultiProvider
/// (EP-02-07 plan §17 criterion 21).
///
/// Returns both the repository and provider so callers can provide the
/// repository as a `Provider<TaxonomyRepository>` alongside the
/// `ChangeNotifierProvider<TaxonomyProvider>`.
({TaxonomyRepository repository, TaxonomyProvider provider})
    registerTaxonomyLayer(ApiLayer apiLayer) {
  final remote = SupabaseTaxonomyRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final local = CacheManagerTaxonomyLocalDataSource();
  final repository = TaxonomyRepositoryImpl(remote: remote, local: local);
  return (repository: repository, provider: TaxonomyProvider(repository: repository));
}

/// Wires the identity-verification data slice for EP-02-10.
///
/// Builds the [SupabaseStorageService] (object store) and
/// [VerificationRepository] over the [ApiLayer] and returns a ready
/// [VerificationProvider]. Exposed for the bootstrap to register in the
/// widget tree's MultiProvider (mirrors `registerTaxonomyLayer`).
///
/// The storage service uses the injected API-layer [Dio] for progress-aware
/// uploads to the private `credential-documents` bucket (server-authoritative).
({VerificationRepository repository, VerificationProvider provider})
    registerVerificationLayer(ApiLayer apiLayer) {
  final remote = SupabaseVerificationRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final storage = SupabaseStorageService(
    storageClient: apiLayer.supabaseClient.storage,
    dio: apiLayer.dio,
    tokenProvider: apiLayer.tokenProvider,
  );
  final repository = VerificationRepositoryImpl(
    remote: remote,
    storage: storage,
    supabase: apiLayer.supabaseClient,
  );
  return (
    repository: repository,
    provider: VerificationProvider(repo: repository),
  );
}
