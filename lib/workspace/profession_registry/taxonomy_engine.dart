import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// Thin, pure-Dart service over [TaxonomyRepository] providing hierarchical
/// taxonomy browsing and client-side search/filter (EP-02-07 plan §5.6).
///
/// The engine is **agnostic** to the concrete industry/profession set — it
/// discovers entries via the repository (RPC), so new industries appear
/// automatically as data inserts (extensibility principle, plan §5.6). No
/// hardcoded slugs, no business logic, no network code.
class TaxonomyEngine {
  /// Creates the engine bound to [repository].
  TaxonomyEngine({required this.repository});

  /// The repository backing this engine.
  final TaxonomyRepository repository;

  /// Maximum accepted search-query length (plan §5.6, §12).
  static const int maxSearchQueryLength = 100;

  /// Returns industries ordered by `sortOrder`, optionally active-only.
  Future<List<Industry>> browseIndustries({bool activeOnly = true}) async {
    final List<Industry> all = await repository.getIndustries(
      includeInactive: !activeOnly,
    );
    all.sort(_bySortOrder);
    return all;
  }

  /// Returns professions scoped to [industryId], optionally active-only.
  ///
  /// Results are ordered by `sortOrder` (then name) regardless of server order
  /// so the engine stays deterministic for future callers.
  Future<List<Profession>> browseProfessions(
    String industryId, {
    bool activeOnly = true,
  }) async {
    final List<Profession> all = await repository.getProfessions(
      industryId: industryId,
      includeInactive: !activeOnly,
    );
    all.sort(_byProfessionOrder);
    return all;
  }

  /// Case-insensitive substring search over `name/slug/description`.
  ///
  /// An empty/blank query returns [scope] unfiltered. The query is sanitized
  /// ([trim], capped at [maxSearchQueryLength]) and never reaches SQL — all
  /// matching is in-memory `String.contains`.
  List<Profession> search(String query, List<Profession> scope) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return scope;
    }
    final String needle = trimmed
        .substring(0, trimmed.length > maxSearchQueryLength
            ? maxSearchQueryLength
            : trimmed.length)
        .toLowerCase();
    return scope
        .where((Profession p) {
          final String haystack =
              '${p.name} ${p.slug} ${p.description ?? ''}'.toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  /// Reverse-lookup: returns the owning industry for [professionId], or `null`
  /// when the profession is not found in the browsed set.
  ///
  /// Uses the hierarchical relationship only — loads industries first, then
  /// the professions of the matching industry, so `industryForProfession` stays
  /// consistent with browse.
  Future<Industry?> industryForProfession(String professionId) async {
    final List<Industry> industries = await repository.getIndustries();
    for (final Industry industry in industries) {
      final List<Profession> professions =
          await repository.getProfessions(industryId: industry.id);
      for (final Profession profession in professions) {
        if (profession.id == professionId) {
          return industry;
        }
      }
    }
    return null;
  }

  int _bySortOrder(Industry a, Industry b) {
    final int byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
  }

  int _byProfessionOrder(Profession a, Profession b) {
    final int byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
  }
}
