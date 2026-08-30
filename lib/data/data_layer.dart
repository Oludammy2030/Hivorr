import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/entity_repository_impl.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

export 'package:hivorr/data/datasources/local/entity_local_data_source.dart';
export 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
export 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
export 'package:hivorr/data/datasources/remote/entity_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_entity_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_envelope_parser.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
export 'package:hivorr/data/entities/entity.dart';
export 'package:hivorr/data/entities/entity_profile.dart';
export 'package:hivorr/data/entities/entity_role.dart';
export 'package:hivorr/data/entities/industry.dart';
export 'package:hivorr/data/entities/profession.dart';
export 'package:hivorr/data/mappers/entity_mapper.dart';
export 'package:hivorr/data/mappers/entity_profile_mapper.dart';
export 'package:hivorr/data/mappers/entity_role_mapper.dart';
export 'package:hivorr/data/mappers/industry_mapper.dart';
export 'package:hivorr/data/mappers/profession_mapper.dart';
export 'package:hivorr/data/models/entity_dto.dart';
export 'package:hivorr/data/models/entity_profile_dto.dart';
export 'package:hivorr/data/models/entity_role_dto.dart';
export 'package:hivorr/data/models/industry_dto.dart';
export 'package:hivorr/data/models/profession_dto.dart';
export 'package:hivorr/data/providers/entity_provider.dart';
export 'package:hivorr/data/providers/taxonomy_provider.dart';
export 'package:hivorr/data/repositories/entity_repository.dart';
export 'package:hivorr/data/repositories/entity_repository_impl.dart';
export 'package:hivorr/data/repositories/taxonomy_repository.dart';
export 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

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
