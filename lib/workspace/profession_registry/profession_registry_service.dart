import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// A two-tier taxonomy navigation tree: industries grouped with their
/// professions, each sorted by `sortOrder`.
typedef TaxonomyTree = Map<Industry, List<Profession>>;

/// Client-side taxonomy engine (EP-02-07).
///
/// Orchestrates the [TaxonomyRepository] to provide industry browsing,
/// profession listing by industry, hierarchical `Industry → Profession`
/// navigation, and pure client-side search / slug lookup. The corpus is loaded
/// through the repository's cache-first reads; search runs entirely in memory —
/// no RPC per keystroke (EP-02-07 plan §5.4). No pricing, matching,
/// verification, or financial logic lives here (AGENT.md Rule 4).
class ProfessionRegistryService {
  /// Creates the engine bound to [repository].
  ProfessionRegistryService({required this.repository});

  /// The repository backing the engine.
  final TaxonomyRepository repository;

  /// Browse all active industries in `sort_order ASC`.
  Future<List<Industry>> browseIndustries() => repository.getIndustries();

  /// List professions for [industryId] in `sort_order ASC`.
  Future<List<Profession>> professionsByIndustry(String industryId) =>
      repository.getProfessions(industryId: industryId);

  /// Builds the hierarchical `Industry → Profession` tree.
  ///
  /// Fetches all professions in a single RPC (`p_industry_id = null`) and
  /// groups them under their owning industry, preserving `sortOrder` ordering.
  Future<TaxonomyTree> getTree() async {
    final List<Industry> industries = await repository.getIndustries();
    final List<Profession> professions = await repository.getProfessions();
    final Map<String, Industry> byId = <String, Industry>{
      for (final Industry i in industries) i.id: i,
    };
    final TaxonomyTree tree = <Industry, List<Profession>>{};
    for (final Industry industry in industries) {
      tree[industry] = <Profession>[];
    }
    for (final Profession p in professions) {
      final Industry? owner = byId[p.industryId];
      if (owner != null) {
        tree[owner]!.add(p);
      }
    }
    for (final Industry industry in tree.keys) {
      _sortByOrder(tree[industry]!);
    }
    return tree;
  }

  /// Case-insensitive substring search across [corpus] on name/slug/description.
  ///
  /// An empty [query] returns the full corpus. Results preserve the corpus
  /// `sortOrder` ordering (relevance ranking is deferred to the future server
  /// search per EP-02-02 §52).
  List<Profession> searchProfessions(String query, List<Profession> corpus) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return List<Profession>.of(corpus);
    }
    return corpus
        .where(
          (Profession p) =>
              p.name.toLowerCase().contains(q) ||
              p.slug.toLowerCase().contains(q) ||
              (p.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  /// Resolves an industry by [slug] over the in-memory [industries] array.
  Industry? getIndustryBySlug(List<Industry> industries, String slug) {
    for (final Industry i in industries) {
      if (i.slug == slug) {
        return i;
      }
    }
    return null;
  }

  /// Resolves a profession by [slug] over the in-memory [professions] array.
  Profession? getProfessionBySlug(List<Profession> professions, String slug) {
    for (final Profession p in professions) {
      if (p.slug == slug) {
        return p;
      }
    }
    return null;
  }

  static void _sortByOrder(List<Profession> professions) {
    professions.sort((Profession a, Profession b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
  }
}
