import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';

/// Abstract contract for taxonomy data operations.
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not the Supabase
/// implementation (EP-01-08 §5.6 vendor-lock-in mitigation). This task is
/// read-only: no write surface is exposed; the service-role write RPCs stay
/// off this contract (EP-02-07 plan §3).
abstract class TaxonomyRepository {
  /// Returns industries in `sort_order ASC`, preferring cache then remote.
  Future<List<Industry>> getIndustries();

  /// Returns professions in `sort_order ASC`, optionally scoped to [industryId].
  /// A `null` [industryId] returns all professions. Cache-first, remote
  /// fallback.
  Future<List<Profession>> getProfessions({String? industryId});

  /// Evicts all `taxonomy:`-prefixed cache entries.
  void invalidateTaxonomy();
}
