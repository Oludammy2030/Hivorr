import 'dart:async';

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

/// Provider exposing taxonomy (industry/profession) state to the widget tree.
///
/// Depends only on the [TaxonomyRepository] abstraction and surfaces a single
/// [ApiException] on failure. Holds the hierarchical selection
/// (`selectedIndustry`/`selectedProfession`) across navigation so onboarding
/// can exit and return without losing picker state (EP-02-07 plan §5.5, §11).
class TaxonomyProvider extends ChangeNotifier {
  /// Creates the provider bound to [repository].
  TaxonomyProvider({required this.repository});

  /// The repository backing this provider.
  final TaxonomyRepository repository;

  /// Debounce window for search query propagation (plan §5.5).
  static const Duration searchDebounce = Duration(milliseconds: 250);

  TaxonomyProviderState _state = TaxonomyProviderState.idle;
  List<Industry> _industries = <Industry>[];
  final Map<String, List<Profession>> _professionsByIndustry =
      <String, List<Profession>>{};
  Industry? _selectedIndustry;
  Profession? _selectedProfession;
  String _searchQuery = '';
  ApiException? _error;
  Timer? _searchTimer;

  /// Current lifecycle state.
  TaxonomyProviderState get state => _state;

  /// The latest loaded industries.
  List<Industry> get industries => _industries;

  /// Professions keyed by owning industry id.
  Map<String, List<Profession>> get professionsByIndustry =>
      Map<String, List<Profession>>.unmodifiable(_professionsByIndustry);

  /// The currently selected industry, if any.
  Industry? get selectedIndustry => _selectedIndustry;

  /// The currently selected profession, if any.
  Profession? get selectedProfession => _selectedProfession;

  /// The raw current search query.
  String get searchQuery => _searchQuery;

  /// The latest error, if [state] is [TaxonomyProviderState.error].
  ApiException? get error => _error;

  /// Professions for the currently selected industry (unfiltered).
  List<Profession> get professionsForSelectedIndustry {
    final Industry? industry = _selectedIndustry;
    if (industry == null) {
      return const <Profession>[];
    }
    return _professionsByIndustry[industry.id] ?? const <Profession>[];
  }

  /// Professions for the selected industry filtered by the current query.
  List<Profession> get filteredProfessions {
    final List<Profession> scope = professionsForSelectedIndustry;
    final String query = _searchQuery.trim();
    if (query.isEmpty) {
      return scope;
    }
    return _match(query, scope);
  }

  /// Loads industries into the provider.
  Future<void> loadIndustries({bool includeInactive = false}) =>
      _run(() async {
        _industries = await repository.getIndustries(
          includeInactive: includeInactive,
        );
      });

  /// Loads professions for [industryId] into the provider.
  Future<void> loadProfessions(
    String industryId, {
    bool includeInactive = false,
  }) => _run(() async {
    _professionsByIndustry[industryId] = await repository.getProfessions(
      industryId: industryId,
      includeInactive: includeInactive,
    );
  });

  /// Selects an industry by id, resetting the selected profession and the
  /// search query (plan §5.5).
  void selectIndustry(String id) {
    Industry? match;
    for (final Industry industry in _industries) {
      if (industry.id == id) {
        match = industry;
        break;
      }
    }
    if (match == null) {
      return;
    }
    _selectedIndustry = match;
    _selectedProfession = null;
    _clearSearch();
    notifyListeners();
  }

  /// Selects a profession.
  void selectProfession(Profession profession) {
    _selectedProfession = profession;
    notifyListeners();
  }

  /// Sets the search query, debounced so per-keystroke filtering is avoided.
  void setSearchQuery(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      _searchQuery = query;
      notifyListeners();
    });
  }

  /// Resets the search query immediately.
  void clearSearch() {
    _clearSearch();
    notifyListeners();
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchTimer = null;
    _searchQuery = '';
  }

  List<Profession> _match(String query, List<Profession> scope) {
    final String needle = query.toLowerCase();
    return scope
        .where((Profession p) {
          final String haystack =
              '${p.name} ${p.slug} ${p.description ?? ''}'.toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
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

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
