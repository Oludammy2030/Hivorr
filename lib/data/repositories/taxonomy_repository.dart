import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';

/// Abstract contract for taxonomy (industry/profession) data operations.
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not a Supabase
/// implementation. This abstraction is the vendor-lock-in mitigation required
/// by ARCHITECTURE.md and EP-01-08 §5.6.
abstract class TaxonomyRepository {
  /// Returns all industries, preferring cache then remote.
  ///
  /// When [includeInactive] is `false` (default), inactive industries are
  /// filtered out client-side.
  Future<List<Industry>> getIndustries({bool includeInactive = false});

  /// Returns professions for [industryId], preferring cache then remote.
  ///
  /// When [industryId] is `null`, all professions are returned. When
  /// [includeInactive] is `false` (default), inactive professions are filtered
  /// out client-side.
  Future<List<Profession>> getProfessions({
    String? industryId,
    bool includeInactive = false,
  });

  /// Clears the taxonomy local cache, forcing a refetch on next read.
  Future<void> invalidate();
}
