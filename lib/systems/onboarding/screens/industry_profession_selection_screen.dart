import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

/// Step 3 — industry & profession selection (EP-02-18 FV-19–FV-21, merged).
///
/// A single step captures both the industry and the profession (the dependent
/// value) with one `Save & continue` action — no intermediate save between the
/// two dropdowns. Professions are gated on the industry choice (the menu stays
/// disabled until an industry is selected) and the professions for that
/// industry are preloaded on selection. Selecting a profession on submit calls
/// [OnboardingProvider.bindProfession] (`entity_profession_bind`) and then
/// advances to identity verification. `PLT005` duplicate binding surfaces as
/// inline guidance; the RPC is only invoked on an explicit tap.
class IndustryProfessionSelectionScreen extends StatefulWidget {
  const IndustryProfessionSelectionScreen({
    super.key,
    required this.active,
    required this.controller,
  });

  final bool active;
  final OnboardingStepController controller;

  @override
  State<IndustryProfessionSelectionScreen> createState() =>
      _IndustryProfessionSelectionScreenState();
}

class _IndustryProfessionSelectionScreenState
    extends State<IndustryProfessionSelectionScreen> {
  String? _conflictMessage;

  @override
  void didUpdateWidget(
    covariant IndustryProfessionSelectionScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _onActivated();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onActivated());
    }
  }

  void _onActivated() {
    final TaxonomyProvider provider = context.read<TaxonomyProvider>();
    unawaited(provider.loadIndustries());
  }

  Future<void> _submit() async {
    final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
    final OnboardingProvider provider = context.read<OnboardingProvider>();
    final Industry? industry = taxonomy.selectedIndustry;
    final Profession? profession = taxonomy.selectedProfession;
    if (industry == null || profession == null) {
      return;
    }
    setState(() => _conflictMessage = null);
    await provider.bindProfession(
      industryId: industry.id,
      professionId: profession.id,
    );
    if (!mounted) {
      return;
    }
    if (provider.submitState == SubmitState.success) {
      await provider.advance();
      if (!mounted) {
        return;
      }
      context.goNamed(RouteNames.onboardingIdentity);
      return;
    }
    if (provider.lastError?.code == 'PLT005') {
      setState(() {
        _conflictMessage =
            'This profession is already linked to your account. Choose '
            'another one or continue with your selection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final TaxonomyProvider taxonomy = context.watch<TaxonomyProvider>();
    final ColorScheme colors = context.colorScheme;

    widget.controller.configure(
      label: 'Save & continue',
      canPrimary: taxonomy.selectedIndustry != null &&
          taxonomy.selectedProfession != null,
      onPrimary: () => unawaited(_submit()),
    );

    final bool loadingInitial =
        taxonomy.industries.isEmpty &&
        (taxonomy.state == TaxonomyProviderState.loading ||
            taxonomy.state == TaxonomyProviderState.idle);
    if (loadingInitial) {
      return const HivorrLoadingState(message: 'Loading industries…');
    }

    final Industry? industry = taxonomy.selectedIndustry;
    final List<Profession> professions =
        List<Profession>.of(taxonomy.professionsForSelectedIndustry);
    professions.sort((Profession a, Profession b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Which industry best describes you?',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            'Search or choose from the list below.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          DropdownMenu<Industry>(
            expandedInsets: EdgeInsets.zero,
            label: const Text('Industry'),
            hintText: 'Select your industry',
            enableFilter: true,
            requestFocusOnTap: true,
            initialSelection: industry,
            dropdownMenuEntries: <DropdownMenuEntry<Industry>>[
              for (final Industry item in _sortedIndustries(taxonomy))
                DropdownMenuEntry<Industry>(
                  value: item,
                  label: item.name,
                ),
            ],
            onSelected: (Industry? value) {
              if (value == null) {
                return;
              }
              setState(() => _conflictMessage = null);
              final TaxonomyProvider provider =
                  context.read<TaxonomyProvider>();
              provider.selectIndustry(value.id);
              unawaited(provider.loadProfessions(value.id));
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: HivorrSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.arrow_downward, size: 18),
            ),
          ),
          Text(
            'Which profession best describes you?',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            'Your profession unlocks trade verification — you must be '
            'approved to place bids (marketplace Rule 2).',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          if (industry == null)
            _disabledProfessionField(colors)
          else
            _professionField(taxonomy, professions, colors),
          if (_conflictMessage != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              _conflictMessage!,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.error,
              ),
            ),
          ],
          if (taxonomy.state == TaxonomyProviderState.error &&
              taxonomy.error != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Text(
              taxonomy.error!.message,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Industry> _sortedIndustries(TaxonomyProvider taxonomy) {
    final List<Industry> industries = List<Industry>.of(taxonomy.industries);
    industries.sort((Industry a, Industry b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return industries;
  }

  /// The profession field rendered (visibly disabled) until an industry is
  /// chosen — the two selections stay visually connected on the same step.
  Widget _disabledProfessionField(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AbsorbPointer(
          child: Opacity(
            opacity: 0.6,
            child: DropdownMenu<Profession>(
              expandedInsets: EdgeInsets.zero,
              label: const Text('Profession'),
              hintText: 'Search or choose a profession',
              enableFilter: true,
              requestFocusOnTap: true,
              dropdownMenuEntries: const <DropdownMenuEntry<Profession>>[],
            ),
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          'First choose an industry to pick a profession.',
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _professionField(
    TaxonomyProvider taxonomy,
    List<Profession> professions,
    ColorScheme colors,
  ) {
    final Profession? profession = taxonomy.selectedProfession;
    final bool loadingProfessions =
        taxonomy.state == TaxonomyProviderState.loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownMenu<Profession>(
          expandedInsets: EdgeInsets.zero,
          label: const Text('Profession'),
          hintText: 'Search or choose a profession',
          enableFilter: true,
          requestFocusOnTap: true,
          initialSelection: profession,
          dropdownMenuEntries: <DropdownMenuEntry<Profession>>[
            for (final Profession item in professions)
              DropdownMenuEntry<Profession>(
                value: item,
                label: item.name,
              ),
          ],
          onSelected: (Profession? value) {
            if (value == null) {
              return;
            }
            setState(() => _conflictMessage = null);
            context.read<TaxonomyProvider>().selectProfession(value);
          },
        ),
        const SizedBox(height: HivorrSpacing.sm),
        if (loadingProfessions && professions.isEmpty)
          Text(
            'Loading professions…',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          )
        else if (!loadingProfessions &&
            industryHasNoProfessions(professions))
          Text(
            'No professions are available for this industry yet.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.error,
            ),
          )
        else if (!loadingProfessions && profession == null)
          Text(
            'Select a profession to continue.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.error,
            ),
          ),
      ],
    );
  }

  bool industryHasNoProfessions(List<Profession> professions) =>
      professions.isEmpty;
}