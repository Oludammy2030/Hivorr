import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/engine/search_engine/service_search_index.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/dashboard/shell/client_mobile_chrome.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_filter_sheet.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_results_view.dart';
import 'package:hivorr/systems/marketplace/widgets/ranking_explainer_chip.dart';
import 'package:hivorr/workspace/profession_registry/widgets/taxonomy_search_field.dart';
import 'package:provider/provider.dart';

/// Client Find Service workspace at `/dashboard/services`.
///
/// The single cohesive hiring-side discovery surface inside the dashboard
/// shell: inline search, contextual filters and ranked results live in one
/// content area. The shell (sidebar + top chrome) persists — only this
/// content swaps on navigation.
///
/// State ownership mirrors the public discovery/search pair it consolidates:
/// [MarketplaceSearchProvider] owns query/filters/results (verbatim RPC
/// order, never re-sorted), [TaxonomyProvider] is read to resolve the names
/// behind the active-filter chips only (its selection is never mutated
/// here), and filter drafts stay local. Applying filters never touches the
/// search query; clearing restores the unfiltered ranked defaults.
/// All styling resolves to [AppTheme] tokens.
class ClientFindServiceScreen extends StatefulWidget {
  const ClientFindServiceScreen({super.key});

  @override
  State<ClientFindServiceScreen> createState() =>
      _ClientFindServiceScreenState();
}

class _ClientFindServiceScreenState extends State<ClientFindServiceScreen>
    with WidgetsBindingObserver {
  bool _initialized = false;
  bool _warming = false;
  late final TextEditingController _queryController;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    // Seed the field from the provider's preserved query (returning from a
    // detail keeps the query — the provider outlives this screen). Seeding
    // text never triggers a search on its own; [_boot] searches once.
    try {
      final String query =
          context.read<MarketplaceSearchProvider?>()?.query ?? '';
      if (query.isNotEmpty) _queryController.text = query;
    } catch (_) {
      // Provider absent (isolated test) — boot degrades to empty state.
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_boot());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      try {
        final MarketplaceSearchProvider? provider =
            context.read<MarketplaceSearchProvider?>();
        if (provider != null) unawaited(provider.search());
      } catch (_) {
        // Provider absent — nothing to refresh.
      }
    }
  }

  Future<void> _boot() async {
    final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
    if (taxonomy.industries.isEmpty) {
      await taxonomy.loadIndustries();
    }
    if (!mounted) return;
    final ServiceSearchIndex? index = context.read<ServiceSearchIndex?>();
    if (index != null && !_warming) {
      _warming = true;
      try {
        await index.warmBrowse();
      } on Object {
        // Warm failures degrade to the live search below — never block boot.
      }
    }
    if (!mounted) return;
    // Load the preserved filter's professions (e.g. back from a detail) so
    // the active-filter chips can resolve the profession name.
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    await _ensureProfessions(provider?.filters.industryId);
    if (!mounted) return;
    await provider?.search();
  }

  /// Loads [industryId]'s professions into the shared [TaxonomyProvider] so
  /// the active-filter chips can name the selected profession. No-op when no
  /// industry is selected or its professions are already loaded.
  Future<void> _ensureProfessions(String? industryId) async {
    if (industryId == null) return;
    final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
    if (taxonomy.professionsByIndustry.containsKey(industryId)) return;
    await taxonomy.loadProfessions(industryId);
  }

  void _onQueryChanged(String query) {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    // The field already debounces keystrokes; the provider debounces query
    // propagation. This trailing timer fires the RPC search once typing
    // settles, past both windows (mirrors `MarketplaceSearchScreen`).
    provider.setQuery(query);
    _searchTimer?.cancel();
    _searchTimer = Timer(
      MarketplaceSearchProvider.searchDebounce +
          const Duration(milliseconds: 300),
      () {
        if (mounted) unawaited(provider.search());
      },
    );
  }

  /// Opens the contextual filter overlay (dialog on tablet/desktop,
  /// bottom sheet on phones) and applies the result in place.
  ///
  /// Dismissal without applying (`null`) leaves filters, query and results
  /// untouched. Applying preserves the search query and keeps the user in
  /// this workspace — no navigation, no shell rebuild.
  Future<void> _openFilters() async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    final ServiceSearchFilters? applied = await DiscoveryFilterSheet.show(
      context: context,
      initial: provider.filters,
    );
    if (applied == null || !mounted) return;
    // Load the applied industry's professions so the active-filter chips can
    // name the selected profession. The search query is never touched.
    await _ensureProfessions(applied.industryId);
    if (!mounted) return;
    provider.setFilters(applied);
    await provider.search();
  }

  /// Clears every filter dimension and restores the unfiltered defaults,
  /// staying inside this workspace.
  Future<void> _clearAll() async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    _searchTimer?.cancel();
    _queryController.clear();
    provider
      ..clearQuery()
      ..setProfessionId(null)
      ..setFilters(const ServiceSearchFilters());
    await provider.search();
  }

  /// Applies a derived filter set (single-chip dismissal) in place.
  Future<void> _updateFilters(ServiceSearchFilters filters) async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    provider.setFilters(filters);
    await provider.search();
  }

  /// Dismisses the industry dimension everywhere it is held (filter value
  /// object and the dependent profession dimension).
  Future<void> _clearIndustry(ServiceSearchFilters current) async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    provider.setProfessionId(null);
    await _updateFilters(
      current.copyWith(industryId: null, professionId: null),
    );
  }

  /// Dismisses the profession dimension (filter + profession selection).
  Future<void> _clearProfession(ServiceSearchFilters current) async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    provider.setProfessionId(null);
    await _updateFilters(current.copyWith(professionId: null));
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = context.breakpoint == Breakpoint.mobile;
    if (isMobile) {
      // Single page title (`Find Services`) on the shared client chrome; no
      // refresh action — pull-to-refresh on the content covers reloads.
      return Scaffold(
        drawer: const ClientDashboardDrawer(),
        appBar: const ClientMobileAppBar(title: 'Find Services'),
        body: MobileSafeBody(
          child: _FindServiceContent(
            queryController: _queryController,
            onQueryChanged: _onQueryChanged,
            onOpenFilters: _openFilters,
            onClearAll: _clearAll,
            onUpdateFilters: _updateFilters,
            onClearIndustry: _clearIndustry,
            onClearProfession: _clearProfession,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ClientFindServiceTopBar(),
        Expanded(
          child: _FindServiceContent(
            queryController: _queryController,
            onQueryChanged: _onQueryChanged,
            onOpenFilters: _openFilters,
            onClearAll: _clearAll,
            onUpdateFilters: _updateFilters,
            onClearIndustry: _clearIndustry,
            onClearProfession: _clearProfession,
          ),
        ),
      ],
    );
  }
}

/// Client chrome for the Find Service workspace (mirrors `_ClientTopBar`).
class _ClientFindServiceTopBar extends StatelessWidget {
  const _ClientFindServiceTopBar();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    int pendingApps = 0;
    try {
      pendingApps = context
          .watch<JobProvider>()
          .posted
          .where((Job job) => job.isOpen)
          .fold<int>(0, (int sum, Job job) => sum + job.applicationsCount);
    } catch (_) {
      pendingApps = 0;
    }
    String displayName = 'Client';
    try {
      final String? email =
          context.watch<AuthProvider>().currentSession?.email;
      if (email != null && email.isNotEmpty) {
        displayName = _prettifyEmailPrefix(email);
      }
    } catch (_) {
      displayName = 'Client';
    }
    return HivorrDashboardTopBar(
      title: 'Find Services',
      accentPrimary: roles.clientPrimary,
      accentContainer: roles.clientContainer,
      modeLabel: 'Client',
      initials: _initials(displayName),
      showDot: pendingApps > 0,
      onMenu: () {
        final ScaffoldState? scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onNotifications: () => context.go(RoutePaths.dashboardNotifications),
      onAvatar: () => context.go(RoutePaths.dashboardAccount),
    );
  }
}

String _prettifyEmailPrefix(String email) {
  final String local = email.split('@').first.trim();
  if (local.isEmpty) return 'Client';
  final List<String> words = local
      .split(RegExp(r'[._\-]+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .toList(growable: false);
  if (words.isEmpty) return 'Client';
  return words.join(' ');
}

String _initials(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'C';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0].toUpperCase()}${words[1][0].toUpperCase()}';
}

/// Single-workspace content: inline search + filter entry, active-filter
/// chips and ranked results. No navigation — search and filter both resolve
/// in place via [MarketplaceSearchProvider].
class _FindServiceContent extends StatelessWidget {
  const _FindServiceContent({
    required this.queryController,
    required this.onQueryChanged,
    required this.onOpenFilters,
    required this.onClearAll,
    required this.onUpdateFilters,
    required this.onClearIndustry,
    required this.onClearProfession,
  });

  final TextEditingController queryController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenFilters;
  final Future<void> Function() onClearAll;
  final Future<void> Function(ServiceSearchFilters) onUpdateFilters;
  final Future<void> Function(ServiceSearchFilters) onClearIndustry;
  final Future<void> Function(ServiceSearchFilters) onClearProfession;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = context.breakpoint == Breakpoint.mobile;
    final MarketplaceSearchProvider? provider =
        context.watch<MarketplaceSearchProvider?>();
    final bool hasActive = provider?.hasActiveFilters ?? false;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          // Screen rhythm: 16dp mobile / 24dp web (VISUAL-IDENTITY.md §7).
          padding: isMobile
              ? const EdgeInsets.fromLTRB(
                  HivorrSpacing.md,
                  HivorrSpacing.md,
                  HivorrSpacing.md,
                  HivorrSpacing.xl,
                )
              : const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TaxonomySearchField(
                      controller: queryController,
                      hint: 'Search services…',
                      onQueryChanged: onQueryChanged,
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.sm),
                  _FilterButton(
                    hasActive: hasActive,
                    onPressed: onOpenFilters,
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.xs),
              // Wrap (not Row): chip intrinsic widths vary with locale and
              // text scale — wrapping never overflows on narrow screens.
              Wrap(
                spacing: HivorrSpacing.xs,
                runSpacing: HivorrSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const RankingExplainerChip(),
                  if (provider != null)
                    ..._activeFilterChips(context, provider),
                  if (hasActive)
                    HivorrChip(
                      label: 'Clear filters',
                      variant: HivorrChipVariant.secondary,
                      onSelected: (_) => onClearAll(),
                    ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.sm),
              Expanded(
                child: DiscoveryResultsView(
                  emptyTitle: 'No matching services',
                  emptySubtitle:
                      'Try a different keyword or clear filters to see more verified services.',
                  emptyActionLabel: hasActive ? 'Clear filters' : null,
                  onEmptyAction: hasActive ? () => onClearAll() : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact active-filter summary (e.g. `Technology ×`,
  /// `Software Developer ×`, `₦100k – ₦500k ×`). Each chip dismisses its
  /// own dimension in place; names resolve from [TaxonomyProvider].
  List<Widget> _activeFilterChips(
    BuildContext context,
    MarketplaceSearchProvider provider,
  ) {
    final ServiceSearchFilters filters = provider.filters;
    final TaxonomyProvider taxonomy = context.watch<TaxonomyProvider>();
    final List<Widget> chips = <Widget>[];
    if (filters.industryId != null) {
      final String name =
          _industryName(taxonomy, filters.industryId!) ?? 'Industry';
      chips.add(
        HivorrChip(
          label: name,
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onClearIndustry(filters),
        ),
      );
    }
    final String? professionId = filters.professionId ?? provider.professionId;
    if (professionId != null) {
      final String name =
          _professionName(taxonomy, filters.industryId, professionId) ??
              'Profession';
      chips.add(
        HivorrChip(
          label: name,
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onClearProfession(filters),
        ),
      );
    }
    if (filters.priceMin != null || filters.priceMax != null) {
      chips.add(
        HivorrChip(
          label: _priceLabel(
            filters.priceMin,
            filters.priceMax,
            filters.currencyCode,
          ),
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onUpdateFilters(
            filters.copyWith(priceMin: null, priceMax: null),
          ),
        ),
      );
    }
    if (filters.currencyCode != null &&
        filters.priceMin == null &&
        filters.priceMax == null) {
      chips.add(
        HivorrChip(
          label: filters.currencyCode!,
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onUpdateFilters(
            filters.copyWith(currencyCode: null),
          ),
        ),
      );
    }
    if (filters.ratingMin != null) {
      chips.add(
        HivorrChip(
          label: '${filters.ratingMin!.toStringAsFixed(1)}+',
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onUpdateFilters(
            filters.copyWith(ratingMin: null),
          ),
        ),
      );
    }
    if (filters.isTradeVerifiedOnly == true) {
      chips.add(
        HivorrChip(
          label: 'Verified only',
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onUpdateFilters(
            filters.copyWith(isTradeVerifiedOnly: null),
          ),
        ),
      );
    }
    if (filters.availabilityDate != null) {
      chips.add(
        HivorrChip(
          label: HivorrFormatters.date(filters.availabilityDate!),
          isSelected: true,
          variant: HivorrChipVariant.secondary,
          onDismissed: () => onUpdateFilters(
            filters.copyWith(availabilityDate: null),
          ),
        ),
      );
    }
    return chips;
  }
}

String? _industryName(TaxonomyProvider taxonomy, String id) {
  for (final Industry industry in taxonomy.industries) {
    if (industry.id == id) return industry.name;
  }
  return null;
}

String? _professionName(
  TaxonomyProvider taxonomy,
  String? industryId,
  String professionId,
) {
  final Map<String, List<Profession>> scoped =
      taxonomy.professionsByIndustry;
  if (industryId != null) {
    for (final Profession profession in scoped[industryId] ??
        const <Profession>[]) {
      if (profession.id == professionId) return profession.name;
    }
  }
  for (final List<Profession> professions in scoped.values) {
    for (final Profession profession in professions) {
      if (profession.id == professionId) return profession.name;
    }
  }
  return null;
}

String _priceLabel(double? min, double? max, String? currencyCode) {
  final String symbol = currencyCode == null
      ? ''
      : '${SupportedCurrency.fromCode(currencyCode)?.symbol ?? currencyCode} ';

  String amount(double value) =>
      '$symbol${HivorrFormatters.number(value, decimals: 0)}';
  if (min != null && max != null) return '${amount(min)} – ${amount(max)}';
  if (min != null) return 'Min ${amount(min)}';
  return 'Max ${amount(max!)}';
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.hasActive, required this.onPressed});

  final bool hasActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hasActive ? 'Edit filters (active)' : 'Open filters',
      child: HivorrButton(
        label: hasActive ? 'Filters ·' : 'Filters',
        variant: hasActive
            ? HivorrButtonVariant.primary
            : HivorrButtonVariant.outline,
        icon: const Icon(Icons.tune, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
