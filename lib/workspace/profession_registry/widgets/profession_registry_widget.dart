import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/workspace/profession_registry/widgets/industry_picker.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_list.dart';
import 'package:provider/provider.dart';

/// Embeddable, callback-driven `Industry → Profession` selector.
///
/// Consumes a [TaxonomyProvider] from the widget tree, renders the browse /
/// search / selection workflow with on-brand loading, empty, and error states,
/// and emits the chosen [Profession] via [onSelected]. No router navigation is
/// performed here (owner integration happens in EP-02-18).
///
/// - [onSelected]: invoked with the tapped profession.
/// - [initialIndustryId]: pre-selects an industry and loads its professions.
/// - [showSearch]: whether to render the debounced (300ms) search field.
class ProfessionRegistryWidget extends StatefulWidget {
  const ProfessionRegistryWidget({
    super.key,
    required this.onSelected,
    this.initialIndustryId,
    this.showSearch = true,
  });

  /// Emits the selected profession.
  final ValueChanged<Profession> onSelected;

  /// Optional pre-selected industry id (resumable context).
  final String? initialIndustryId;

  /// Whether to show the in-memory search field.
  final bool showSearch;

  @override
  State<ProfessionRegistryWidget> createState() =>
      _ProfessionRegistryWidgetState();
}

class _ProfessionRegistryWidgetState extends State<ProfessionRegistryWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_scheduleFilter);
    _initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_scheduleFilter)
      ..dispose();
    super.dispose();
  }

  void _initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    // Defer the load out of the build phase: providers notify listeners
    // synchronously on start, which is invalid while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitial());
    });
  }

  /// Runs the initial load: industries first (so the picker renders), then the
  /// pre-selected industry's professions when [widget.initialIndustryId] is set.
  Future<void> _loadInitial() async {
    if (!mounted) {
      return;
    }
    final TaxonomyProvider provider = context.read<TaxonomyProvider>();
    final String? initialId = widget.initialIndustryId;
    if (initialId == null) {
      await provider.loadIndustries();
      return;
    }
    await provider.loadIndustries();
    if (!mounted) {
      return;
    }
    await provider.loadProfessions(initialId);
  }

  /// Retry path that re-runs the same initial-load sequence so a failure with
  /// [widget.initialIndustryId] recovers to the intended state.
  Future<void> _retry() => _loadInitial();

  void _scheduleFilter() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final TaxonomyProvider provider = context.read<TaxonomyProvider>();
      final String query = _searchController.text;
      provider.search(query);
      setState(() => _query = query);
    });
  }

  void _selectIndustry(TaxonomyProvider provider, String industryId) {
    unawaited(provider.loadProfessions(industryId));
  }

  @override
  Widget build(BuildContext context) {
    final TaxonomyProvider provider = context.watch<TaxonomyProvider>();

    switch (provider.state) {
      case TaxonomyProviderState.idle:
      case TaxonomyProviderState.loading:
        return const HivorrLoadingState(
          message: 'Loading professions\u2026',
        );
      case TaxonomyProviderState.error:
        return HivorrErrorState(
          message: provider.error?.message ??
              'Unable to load the registry right now.',
          onRetry: () => unawaited(_retry()),
        );
      case TaxonomyProviderState.loaded:
        return _buildLoaded(context, provider);
    }
  }

  Widget _buildLoaded(BuildContext context, TaxonomyProvider provider) {
    final List<Widget> children = <Widget>[];

    if (widget.showSearch) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: HivorrSpacing.sm,
          ),
          child: HivorrTextField(
            controller: _searchController,
            hint: 'Search professions',
            prefix: const Icon(Icons.search),
            suffix: _query.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      provider.clearSearch();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      );
    }

    children.add(
      IndustryPicker(
        industries: provider.industries,
        selectedId: provider.selectedIndustryId,
        onSelected: (String id) => _selectIndustry(provider, id),
      ),
    );

    if (provider.professions.isEmpty) {
      children.add(
        const Expanded(
          child: HivorrEmptyState(
            icon: Icon(Icons.work_outline),
            title: 'Select an industry',
            subtitle: 'Professions appear once an industry is chosen',
          ),
        ),
      );
    } else {
      children.add(
        Expanded(
          child: ProfessionList(
            professions: provider.searchResults,
            query: _query,
            onSelected: widget.onSelected,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
