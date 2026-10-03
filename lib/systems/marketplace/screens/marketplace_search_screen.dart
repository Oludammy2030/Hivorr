import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_filter_sheet.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_results_view.dart';
import 'package:hivorr/systems/marketplace/widgets/ranking_explainer_chip.dart';
import 'package:hivorr/workspace/profession_registry/widgets/taxonomy_search_field.dart';
import 'package:provider/provider.dart';

/// Public marketplace search screen at `/services/search` (EP-03-09).
///
/// Debounced query (250ms via [MarketplaceSearchProvider.setQuery]) +
/// `ServiceSearchFilters` chips/sheet over the ranked RPC. Results render
/// verbatim in server order — never re-sorted (AGENT.md:7). Follows the
/// `MyListingsScreen` lifecycle convention and renders only [AppTheme]
/// tokens (AGENT.md Rule 5).
class MarketplaceSearchScreen extends StatefulWidget {
  const MarketplaceSearchScreen({
    super.key,
    this.initialQuery,
    this.initialProfessionId,
  });

  /// Optional deep-linked query (`?q=`).
  final String? initialQuery;

  /// Optional deep-linked profession (`?profession=`).
  final String? initialProfessionId;

  @override
  State<MarketplaceSearchScreen> createState() =>
      _MarketplaceSearchScreenState();
}

class _MarketplaceSearchScreenState extends State<MarketplaceSearchScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _queryController;
  Timer? _searchTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_boot());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final MarketplaceSearchProvider? provider =
          context.read<MarketplaceSearchProvider?>();
      if (provider != null) unawaited(provider.search());
    }
  }

  Future<void> _boot() async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null || !mounted) return;
    final String? professionId = widget.initialProfessionId;
    if (professionId != null && professionId.isNotEmpty) {
      provider.setProfessionId(professionId);
    }
    final String query = _queryController.text;
    if (query.trim().isNotEmpty) {
      // Deep-linked entry: propagate through the provider's debounced query
      // (single source of truth), wait past its window, then search once.
      provider.setQuery(query);
      await Future<void>.delayed(
        MarketplaceSearchProvider.searchDebounce +
            const Duration(milliseconds: 50),
      );
      if (!mounted) return;
    }
    await provider.search();
  }

  void _onQueryChanged(String query) {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    // The field already debounces keystrokes; the provider debounces query
    // propagation. This trailing timer fires the RPC search once typing
    // settles, past both windows.
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

  Future<void> _openFilters() async {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    final ServiceSearchFilters? applied = await DiscoveryFilterSheet.show(
      context: context,
      initial: provider.filters,
    );
    if (applied == null || !mounted) return;
    provider.setFilters(applied);
    await provider.search();
  }

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

  @override
  Widget build(BuildContext context) {
    final MarketplaceSearchProvider? provider =
        context.watch<MarketplaceSearchProvider?>();
    final bool hasActive = provider?.hasActiveFilters ?? false;
    return HivorrScreenScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/services'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Search services', style: context.textTheme.titleLarge),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TaxonomySearchField(
                      controller: _queryController,
                      hint: 'Search services…',
                      onQueryChanged: _onQueryChanged,
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.sm),
                  _FilterButton(
                    hasActive: hasActive,
                    onPressed: _openFilters,
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Row(
                children: <Widget>[
                  const RankingExplainerChip(),
                  const Spacer(),
                  if (hasActive)
                    HivorrChip(
                      label: 'Clear filters',
                      variant: HivorrChipVariant.secondary,
                      onSelected: (_) => _clearAll(),
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
                  onEmptyAction: hasActive ? _clearAll : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
