import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/workspace/profession_registry/widgets/industry_picker.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_picker.dart';
import 'package:hivorr/workspace/profession_registry/widgets/taxonomy_search_field.dart';
import 'package:provider/provider.dart';

/// Two-step hierarchical `Industry → Profession` registry browser
/// (AGENT.md Rule 2).
///
/// Step 1 renders the industry picker; Step 2 renders the selected industry's
/// professions with a debounced search field and a `Continue` action gated on a
/// profession being selected. Consumes [TaxonomyProvider] from the widget tree
/// via [Provider] (EP-02-07 plan §5.7, §11), so it is directly reusable by
/// onboarding (EP-02-18) and profile (EP-02-19).
class ProfessionRegistryBrowser extends StatefulWidget {
  const ProfessionRegistryBrowser({
    super.key,
    this.onContinue,
    this.continueLabel = 'Continue',
  });

  /// Called with the selected profession when `Continue` is tapped.
  final ValueChanged<Profession>? onContinue;

  /// Label for the confirm action.
  final String continueLabel;

  @override
  State<ProfessionRegistryBrowser> createState() =>
      _ProfessionRegistryBrowserState();
}

class _ProfessionRegistryBrowserState extends State<ProfessionRegistryBrowser> {
  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_load));
  }

  Future<void> _load() async {
    final TaxonomyProvider provider = context.read<TaxonomyProvider>();
    await provider.loadIndustries();
  }

  @override
  Widget build(BuildContext context) {
    final TaxonomyProvider provider = context.watch<TaxonomyProvider>();
    final bool inStepTwo = provider.selectedIndustry != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          inStepTwo
              ? 'Step 2 — Choose your profession'
              : 'Step 1 — Choose your industry',
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: HivorrSpacing.md),
        Expanded(child: _buildBody(context, provider)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, TaxonomyProvider provider) {
    switch (provider.state) {
      case TaxonomyProviderState.idle:
      case TaxonomyProviderState.loading:
        return const HivorrLoadingState(message: 'Loading professions…');
      case TaxonomyProviderState.error:
        return HivorrErrorState(
          message: provider.error?.message ?? 'Something went wrong.',
          onRetry: _load,
        );
      case TaxonomyProviderState.loaded:
        return _buildLoaded(context);
    }
  }

  Widget _buildLoaded(BuildContext context) {
    final TaxonomyProvider provider = context.watch<TaxonomyProvider>();
    final Industry? selectedIndustry = provider.selectedIndustry;

    if (selectedIndustry == null) {
      return SingleChildScrollView(
        child: IndustryPicker(
          industries: _sortedIndustries(provider.industries),
          selectedId: null,
          onSelected: (Industry industry) {
            provider.selectIndustry(industry.id);
            unawaited(provider.loadProfessions(industry.id));
          },
        ),
      );
    }

    return Column(
      children: <Widget>[
        TaxonomySearchField(onQueryChanged: provider.setSearchQuery),
        const SizedBox(height: HivorrSpacing.md),
        Expanded(
          child: ProfessionPicker(
            professions: provider.filteredProfessions,
            selectedId: provider.selectedProfession?.id,
            onSelected: provider.selectProfession,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        HivorrButton(
          label: widget.continueLabel,
          onPressed: provider.selectedProfession == null
              ? null
              : () => widget.onContinue?.call(provider.selectedProfession!),
          isExpanded: true,
        ),
      ],
    );
  }

  List<Industry> _sortedIndustries(List<Industry> industries) {
    final List<Industry> sorted = List<Industry>.from(industries);
    sorted.sort((Industry a, Industry b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return sorted;
  }
}
