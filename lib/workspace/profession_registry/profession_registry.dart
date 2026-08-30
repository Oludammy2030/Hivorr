/// Public barrel for the client-side Taxonomy Engine & Profession Registry
/// (EP-02-07).
///
/// Consumers (EP-02-18 onboarding, EP-02-19 profile, EP-02-11 verification)
/// import just this file to obtain the embeddable [TaxonomyProvider],
/// [ProfessionRegistryWidget], domain entities, and the engine service.
library;

import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
import 'package:hivorr/data/datasources/remote/supabase_taxonomy_remote_data_source.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

import 'profession_registry_service.dart';
import 'widgets/profession_registry_widget.dart';

export 'package:hivorr/data/datasources/local/taxonomy_local_data_source.dart';
export 'package:hivorr/data/datasources/remote/taxonomy_remote_data_source.dart';
export 'package:hivorr/data/entities/industry.dart';
export 'package:hivorr/data/entities/profession.dart';
export 'package:hivorr/data/mappers/industry_mapper.dart';
export 'package:hivorr/data/mappers/profession_mapper.dart';
export 'package:hivorr/data/models/industry_dto.dart';
export 'package:hivorr/data/models/profession_dto.dart';
export 'package:hivorr/data/providers/taxonomy_provider.dart';
export 'package:hivorr/data/repositories/taxonomy_repository.dart';
export 'package:hivorr/data/repositories/taxonomy_repository_impl.dart';

export 'profession_registry_service.dart';
export 'widgets/industry_picker.dart';
export 'widgets/profession_list.dart';
export 'widgets/profession_registry_widget.dart';

/// Wires the taxonomy vertical slice for the active environment.
///
/// Consumes the [ApiLayer] produced by [ApiInitializer.initializeApi]
/// (EP-01-07) and returns a fully constructed [TaxonomyProvider] ready for the
/// widget tree, plus an optional engine. `main.dart`/bootstrap is not modified
/// here (EP-02-07 plan §5.7) — this hook is exposed for a future consumer to
/// call.
(TaxonomyProvider, ProfessionRegistryService) registerTaxonomyLayer(
  ApiLayer apiLayer,
) {
  final remote = SupabaseTaxonomyRemoteDataSource(
    dio: apiLayer.dio,
    supabase: apiLayer.supabaseClient,
    exceptionMapper: apiLayer.exceptionMapper,
  );
  final local = InMemoryTaxonomyLocalDataSource();
  final repository = TaxonomyRepositoryImpl(remote: remote, local: local);
  final provider = TaxonomyProvider(repository: repository);
  final service = ProfessionRegistryService(repository: repository);
  return (provider, service);
}
