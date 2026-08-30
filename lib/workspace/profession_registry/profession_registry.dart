/// Public surface of the client-side profession registry (EP-02-07).
///
/// Re-exports the read-only [TaxonomyEngine] and the reusable registry widgets
/// so consumers (onboarding EP-02-18, profile EP-02-19) can import a single
/// barrel rather than individual paths. Consumes the shared [TaxonomyProvider]
/// wired by the app bootstrap, keeping callers free of datasource plumbing.
library;

export 'taxonomy_engine.dart';
export 'widgets/industry_picker.dart';
export 'widgets/profession_picker.dart';
export 'widgets/profession_registry_browser.dart';
export 'widgets/taxonomy_search_field.dart';
