import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/repositories/taxonomy_repository.dart';

/// Lifecycle states exposed by [TaxonomyProvider].
enum TaxonomyProviderState {
  /// No operation has been performed yet.
  idle,

  /// An operation is in flight.
  loading,

  /// The last operation succeeded.
  loaded,

  /// The last operation failed (see [TaxonomyProvider.error]).
  error,
}

/// Provider exposing taxonomy data state to the widget tree.
///
/// Depends only on the [TaxonomyRepository] abstraction and surfaces a single
/// [ApiException] on failure. No Supabase/Dio imports (EP-02-07 plan §5.2,
/// §5.6). The taxonomy is the read-only classification backbone for onboarding
/// and profile workflows.
class TaxonomyProvider extends ChangeNotifier {
  /// Creates the provider bound to [repository].
  TaxonomyProvider({required this.repository});

  /// The repository backing this provider.
  final TaxonomyRepository repository;

  TaxonomyProviderState _state = TaxonomyProviderState.idle;
  List<Industry> _industries = <Industry>[];
  List<Profession> _professions = <Profession>[];
  List<Profession> _searchResults = <Profession>[];
  String? _selectedIndustryId;
  ApiException? _error;

  /// Current lifecycle state.
  TaxonomyProviderState get state => _state;

  /// The latest loaded industries (ordered by `sortOrder`).
  List<Industry> get industries => _industries;

  /// The latest loaded professions for the selected industry.
  List<Profession> get professions => _professions;

  /// The search-filtered professions (equal to [professions] when the query is
  /// empty).
  List<Profession> get searchResults => _searchResults;

  /// The currently selected industry id (resumable context).
  String? get selectedIndustryId => _selectedIndustryId;

  /// The latest error, if [state] is [TaxonomyProviderState.error].
  ApiException? get error => _error;

  /// Loads the industry list (cache-first).
  Future<void> loadIndustries() => _run(() async {
    _industries = await repository.getIndustries();
    if (_industries.isNotEmpty && _selectedIndustryId == null) {
      _selectedIndustryId = _industries.first.id;
    }
  });

  /// Loads professions for [industryId], sets it as the selected industry, and
  /// resets the search filter to the full list.
  Future<void> loadProfessions(String industryId) => _run(() async {
    _selectedIndustryId = industryId;
    _professions = await repository.getProfessions(industryId: industryId);
    _searchResults = _professions;
  });

  /// Selects [industryId] without a reload, retaining the current corpus. Used
  /// for instant picker navigation once professions are already loaded.
  void selectIndustry(String industryId) {
    _selectedIndustryId = industryId;
    notifyListeners();
  }

  /// Filters the in-memory corpus by [query] (case-insensitive substring on
  /// name/slug/description). Pure client-side: does not alter [state] or hit
  /// the network. An empty [query] restores the full [sortOrder] list.
  void search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _searchResults = _professions;
    } else {
      _searchResults = _professions
          .where(
            (Profession p) =>
                p.name.toLowerCase().contains(q) ||
                p.slug.toLowerCase().contains(q) ||
                (p.description?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    notifyListeners();
  }

  /// Clears the search filter, restoring the full [sortOrder] list.
  void clearSearch() {
    _searchResults = _professions;
    notifyListeners();
  }

  /// Refreshes the currently selected industry's professions (retry path).
  Future<void> retryLoad() {
    final String? id = _selectedIndustryId;
    if (id == null) {
      return loadIndustries();
    }
    return loadProfessions(id);
  }

  Future<void> _run(Future<void> Function() action) async {
    _state = TaxonomyProviderState.loading;
    _error = null;
    notifyListeners();
    try {
      await action();
      _state = TaxonomyProviderState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _state = TaxonomyProviderState.error;
    }
    notifyListeners();
  }
}
