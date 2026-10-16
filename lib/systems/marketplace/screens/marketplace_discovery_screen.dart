import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/engine/growth_engine/listing_seo_meta.dart';
import 'package:hivorr/engine/growth_engine/seo_head.dart';
import 'package:hivorr/engine/growth_engine/seo_meta_view.dart';
import 'package:hivorr/engine/search_engine/service_search_index.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_results_view.dart';
import 'package:hivorr/systems/marketplace/widgets/ranking_explainer_chip.dart';
import 'package:provider/provider.dart';

/// Public marketplace discovery screen at `/services` (EP-03-09).
///
/// Industry → profession browse over ranked defaults (empty query,
/// cache-first via [ServiceSearchIndex.warmBrowse] on `initState`). Consumes
/// [MarketplaceSearchProvider] verbatim — never re-sorts (AGENT.md:7).
/// The shared [TaxonomyProvider] is read for browse options only; its
/// selection is never mutated here. Follows the `MyListingsScreen` lifecycle
/// convention (one-shot initial load, resume refresh) and renders only
/// [AppTheme] tokens (AGENT.md Rule 5).
///
/// EP-03-19: [initialIndustrySlug] serves the SEO browse `/s/:industrySlug`
/// (validated against taxonomy; unknown slug renders SEO-404, never a
/// redirect loop). `null` preserves the legacy `/services` browse.
class MarketplaceDiscoveryScreen extends StatefulWidget {
  const MarketplaceDiscoveryScreen({super.key, this.initialIndustrySlug});

  /// SEO industry slug from `/s/:industrySlug` (cosmetic/validating only).
  final String? initialIndustrySlug;

  @override
  State<MarketplaceDiscoveryScreen> createState() =>
      _MarketplaceDiscoveryScreenState();
}

class _MarketplaceDiscoveryScreenState extends State<MarketplaceDiscoveryScreen>
    with WidgetsBindingObserver {
  bool _initialized = false;
  String? _industryId;
  bool _warming = false;
  bool _unknownSlug = false;

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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refresh());
    }
  }

  Future<void> _boot() async {
    final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
    if (taxonomy.industries.isEmpty) {
      await taxonomy.loadIndustries();
    }
    if (!mounted) return;
    // EP-03-19: resolve the SEO slug to a taxonomy id (slug is cosmetic,
    // the id filters the ranked search). Unknown slugs stay on this URL as
    // SEO-404 content — never a redirect loop.
    final String? slug = widget.initialIndustrySlug?.trim();
    if (slug != null && slug.isNotEmpty) {
      Industry? match;
      for (final Industry industry in taxonomy.industries) {
        if (industry.slug == slug) {
          match = industry;
          break;
        }
      }
      if (match == null) {
        setState(() {
          _unknownSlug = true;
          _industryId = null;
        });
        return;
      }
      _industryId = match.id;
      await taxonomy.loadProfessions(match.id);
      if (!mounted) return;
      final MarketplaceSearchProvider? provider =
          context.read<MarketplaceSearchProvider?>();
      if (provider != null) {
        final ServiceSearchFilters current = provider.filters;
        provider.setFilters(
          current.copyWith(industryId: match.id),
        );
      }
    }
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
    await _refresh();
  }

  Future<void> _refresh() {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return Future<void>.value();
    return provider.search();
  }

  Future<void> _selectIndustry(String? id) async {
    setState(() => _industryId = id);
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider != null) {
      final ServiceSearchFilters current = provider.filters;
      provider.setFilters(current.copyWith(industryId: id));
      unawaited(provider.search());
    }
    if (id != null) {
      await context.read<TaxonomyProvider>().loadProfessions(id);
    }
  }

  void _selectProfession(String? id) {
    final MarketplaceSearchProvider? provider =
        context.read<MarketplaceSearchProvider?>();
    if (provider == null) return;
    provider.setProfessionId(id);
    unawaited(provider.search());
  }

  @override
  Widget build(BuildContext context) {
    // EP-03-19: browse head for SEO discoverability (web-only side effect).
    final String? slug = widget.initialIndustrySlug?.trim();
    final String industryName = _industryNameFor(slug);
    final ListingSeoMeta browseMeta = ListingSeoMetaBuilder.buildBrowse(
      baseUrl: seoOrigin(),
      industrySlug: slug,
      industryName: industryName.isEmpty ? null : industryName,
    );
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text('Find services', style: context.textTheme.titleLarge),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Lists are full-width surfaces: a 1120dp cap replaces the 720dp form
      // pane so cards can breathe on desktop (VISUAL-IDENTITY.md §7).
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SeoHead(view: SeoMetaView.fromBrowse(browseMeta)),
              if (_unknownSlug)
                Expanded(
                  child: HivorrEmptyState(
                    title: 'No services found',
                    subtitle:
                        'This category is not available. Try browsing all services.',
                    actionButton: HivorrButton(
                      label: 'Browse all services',
                      onPressed: () =>
                          context.go(RoutePaths.serviceDiscovery),
                    ),
                  ),
                )
              else ...<Widget>[
                _SearchEntry(
                  onTap: () => context.push(RoutePaths.serviceSearch),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: RankingExplainerChip(),
                ),
                const SizedBox(height: HivorrSpacing.sm),
                HivorrSectionHeader(
                  title: 'Browse by profession',
                  action: HivorrButton(
                    label: 'Search',
                    size: HivorrButtonSize.small,
                    variant: HivorrButtonVariant.outline,
                    onPressed: () => context.push(RoutePaths.serviceSearch),
                  ),
                ),
                _IndustryChips(
                  selected: _industryId,
                  onSelected: _selectIndustry,
                ),
                const SizedBox(height: HivorrSpacing.xs),
                _ProfessionChips(
                  industryId: _industryId,
                  onSelected: _selectProfession,
                ),
                const SizedBox(height: HivorrSpacing.sm),
                const Expanded(
                  child: DiscoveryResultsView(
                    emptyTitle: 'No services yet',
                    emptySubtitle:
                        'Try another profession or check back soon — new verified services appear here first.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves the display name for an SEO slug from cached taxonomy.
  String _industryNameFor(String? slug) {
    if (slug == null || slug.isEmpty) return '';
    try {
      final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
      for (final Industry industry in taxonomy.industries) {
        if (industry.slug == slug) return industry.name;
      }
    } on Object {
      return '';
    }
    return '';
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(Icons.search, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Text(
              'Search services…',
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Icon(Icons.tune, color: context.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _IndustryChips extends StatelessWidget {
  const _IndustryChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final TaxonomyProvider taxonomy = context.watch<TaxonomyProvider>();
    final List<Industry> industries = taxonomy.industries;
    if (industries.isEmpty) {
      return Text(
        'Loading industries…',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: HivorrSpacing.xs,
      runSpacing: HivorrSpacing.xs,
      children: <Widget>[
        HivorrChip(
          label: 'All',
          isSelected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final Industry industry in industries)
          HivorrChip(
            label: industry.name,
            isSelected: selected == industry.id,
            onSelected: (_) =>
                onSelected(selected == industry.id ? null : industry.id),
          ),
      ],
    );
  }
}

class _ProfessionChips extends StatelessWidget {
  const _ProfessionChips({required this.industryId, required this.onSelected});

  final String? industryId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final String? industry = industryId;
    final MarketplaceSearchProvider? search =
        context.watch<MarketplaceSearchProvider?>();
    if (industry == null) {
      return const SizedBox.shrink();
    }
    final TaxonomyProvider taxonomy = context.watch<TaxonomyProvider>();
    final List<Profession> professions =
        taxonomy.professionsByIndustry[industry] ?? const <Profession>[];
    if (professions.isEmpty) {
      return Text(
        'Loading professions…',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final String? active = search?.professionId;
    return Wrap(
      spacing: HivorrSpacing.xs,
      runSpacing: HivorrSpacing.xs,
      children: <Widget>[
        for (final Profession profession in professions)
          HivorrChip(
            label: profession.name,
            variant: HivorrChipVariant.secondary,
            isSelected: active == profession.id,
            onSelected: (_) =>
                onSelected(active == profession.id ? null : profession.id),
          ),
      ],
    );
  }
}
