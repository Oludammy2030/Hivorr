import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';

/// Discovery filter bottom-sheet (EP-03-09).
///
/// Edits a draft [ServiceSearchFilters] value object and reports it via
/// [onApply]; the caller owns composing `p_filters` through
/// `MarketplaceSearchProvider.setFilters` + `search()`. Filter state here is
/// strictly local — the shared [TaxonomyProvider] selection is never mutated
/// (its loads are reused read-only for industry/profession options).
/// Server-side validation stays authoritative; client checks (price range
/// order, numeric parsing) are fail-fast UX mirrors only.
///
/// All styling resolves to [AppTheme] tokens (AGENT.md Rule 5).
class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  /// The active filters to edit (typically `provider.filters`).
  final ServiceSearchFilters initial;

  /// Called with the edited filters when the user applies.
  final ValueChanged<ServiceSearchFilters> onApply;

  /// Presents the sheet and returns the applied filters, if any.
  static Future<ServiceSearchFilters?> show({
    required BuildContext context,
    required ServiceSearchFilters initial,
  }) {
    return HivorrBottomSheet.show<ServiceSearchFilters>(
      context: context,
      title: 'Filter services',
      child: DiscoveryFilterSheet(
        initial: initial,
        onApply: (ServiceSearchFilters filters) =>
            Navigator.of(context).pop(filters),
      ),
    );
  }

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  static const List<double?> _ratingOptions = <double?>[null, 3.0, 4.0, 4.5];

  String? _industryId;
  String? _professionId;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _currencyCode;
  double? _ratingMin;
  bool _verifiedOnly = false;
  DateTime? _availabilityDate;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final ServiceSearchFilters initial = widget.initial;
    _industryId = initial.industryId;
    _professionId = initial.professionId;
    _minController = TextEditingController(
      text: initial.priceMin == null
          ? ''
          : HivorrFormatters.number(initial.priceMin!, decimals: 0),
    );
    _maxController = TextEditingController(
      text: initial.priceMax == null
          ? ''
          : HivorrFormatters.number(initial.priceMax!, decimals: 0),
    );
    _currencyCode = initial.currencyCode;
    _ratingMin = initial.ratingMin;
    _verifiedOnly = initial.isTradeVerifiedOnly ?? false;
    _availabilityDate = initial.availabilityDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ensureTaxonomy());
    });
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _ensureTaxonomy() async {
    final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
    if (taxonomy.industries.isEmpty) {
      await taxonomy.loadIndustries();
    }
    final String? industryId = _industryId;
    if (industryId != null && mounted) {
      await taxonomy.loadProfessions(industryId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectIndustry(String? id) async {
    setState(() {
      _industryId = id;
      _professionId = null;
    });
    if (id != null) {
      await context.read<TaxonomyProvider>().loadProfessions(id);
      if (mounted) setState(() {});
    }
  }

  double? _parsePrice(String raw) {
    final String cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final double? value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return value;
  }

  void _apply() {
    final double? min = _parsePrice(_minController.text);
    final double? max = _parsePrice(_maxController.text);
    if (min == null && _minController.text.trim().isNotEmpty ||
        max == null && _maxController.text.trim().isNotEmpty) {
      setState(
        () => _priceError = 'Enter valid amounts of 0 or more.',
      );
      return;
    }
    if (min != null && max != null && max < min) {
      setState(
        () => _priceError = 'Maximum must be greater than minimum.',
      );
      return;
    }
    setState(() => _priceError = null);
    widget.onApply(
      ServiceSearchFilters(
        professionId: _professionId,
        industryId: _industryId,
        priceMin: min,
        priceMax: max,
        currencyCode: _currencyCode,
        ratingMin: _ratingMin,
        isTradeVerifiedOnly: _verifiedOnly ? true : null,
        availabilityDate: _availabilityDate,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _industryId = null;
      _professionId = null;
      _minController.clear();
      _maxController.clear();
      _currencyCode = null;
      _ratingMin = null;
      _verifiedOnly = false;
      _availabilityDate = null;
      _priceError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SectionLabel('Industry'),
          _IndustryRow(
            selected: _industryId,
            onSelected: _selectIndustry,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          _SectionLabel('Profession'),
          _ProfessionRow(
            industryId: _industryId,
            selected: _professionId,
            onSelected: (String? id) => setState(() => _professionId = id),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          _SectionLabel('Price range'),
          Row(
            children: <Widget>[
              Expanded(
                child: HivorrTextField(
                  controller: _minController,
                  hint: 'Min',
                  keyboardType: TextInputType.number,
                  errorText: _priceError,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: HivorrTextField(
                  controller: _maxController,
                  hint: 'Max',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Wrap(
            spacing: HivorrSpacing.xs,
            children: <Widget>[
              HivorrChip(
                label: 'Any currency',
                isSelected: _currencyCode == null,
                onSelected: (_) => setState(() => _currencyCode = null),
              ),
              for (final String code in DiscoveryCurrencies.active)
                HivorrChip(
                  label: code,
                  isSelected: _currencyCode == code,
                  onSelected: (_) => setState(() => _currencyCode = code),
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          _SectionLabel('Minimum rating'),
          Wrap(
            spacing: HivorrSpacing.xs,
            children: <Widget>[
              for (final double? option in _ratingOptions)
                HivorrChip(
                  label: option == null ? 'Any' : '${option.toStringAsFixed(1)}+',
                  isSelected: _ratingMin == option,
                  onSelected: (_) => setState(() => _ratingMin = option),
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Verified professionals only',
              style: context.textTheme.bodyMedium,
            ),
            value: _verifiedOnly,
            onChanged: (bool value) => setState(() => _verifiedOnly = value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Available on',
              style: context.textTheme.bodyMedium,
            ),
            subtitle: Text(
              _availabilityDate == null
                  ? 'Any date'
                  : HivorrFormatters.date(_availabilityDate!),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: _availabilityDate == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    tooltip: 'Clear date',
                    onPressed: () =>
                        setState(() => _availabilityDate = null),
                    icon: const Icon(Icons.close),
                  ),
            onTap: () => _pickDate(context),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Row(
            children: <Widget>[
              HivorrButton(
                label: 'Clear all',
                variant: HivorrButtonVariant.text,
                onPressed: _clearAll,
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: HivorrButton(
                  label: 'Apply filters',
                  isExpanded: true,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _availabilityDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _availabilityDate = picked);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
      child: Text(
        text,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IndustryRow extends StatelessWidget {
  const _IndustryRow({required this.selected, required this.onSelected});

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
            onSelected: (_) => onSelected(
              selected == industry.id ? null : industry.id,
            ),
          ),
      ],
    );
  }
}

class _ProfessionRow extends StatelessWidget {
  const _ProfessionRow({
    required this.industryId,
    required this.selected,
    required this.onSelected,
  });

  final String? industryId;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final String? industry = industryId;
    if (industry == null) {
      return Text(
        'Choose an industry to narrow by profession.',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
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
    return Wrap(
      spacing: HivorrSpacing.xs,
      runSpacing: HivorrSpacing.xs,
      children: <Widget>[
        HivorrChip(
          label: 'All',
          isSelected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final Profession profession in professions)
          HivorrChip(
            label: profession.name,
            isSelected: selected == profession.id,
            onSelected: (_) => onSelected(
              selected == profession.id ? null : profession.id,
            ),
          ),
      ],
    );
  }
}

/// Currency vocabulary shared with the owner flow (display-only reuse).
class DiscoveryCurrencies {
  const DiscoveryCurrencies._();

  /// Active currency subset (mirrors `ServiceListingService.currencies`).
  static List<String> get active => ServiceListingService.currencies;
}
