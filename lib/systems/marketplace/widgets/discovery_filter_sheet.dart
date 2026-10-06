import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/components/hivorr_select_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';

/// Discovery filter overlay (EP-03-09).
///
/// Edits a draft [ServiceSearchFilters] value object and reports it via
/// [onApply]; the caller owns composing `p_filters` through
/// `MarketplaceSearchProvider.setFilters` + `search()`. Filter state here is
/// strictly local — the shared [TaxonomyProvider] selection is never mutated
/// (its loads are reused read-only for industry/profession options).
/// Server-side validation stays authoritative; client checks (price range
/// order, numeric parsing) are fail-fast UX mirrors only.
///
/// The panel is a compact control surface: Industry, Profession, Currency
/// and Minimum Rating are single [HivorrSelectField] rows whose option lists
/// open in their own scrollable/searchable surface, so the card keeps a
/// constant height at any dataset size. Profession options stay scoped to
/// the selected industry via the data-driven `Profession.industryId` link.
///
/// Presentation is adaptive: [show] renders a keyboard-aware
/// [HivorrBottomSheet] on phones and a dimmed-background [HivorrDialog] card
/// on tablet/desktop, so the underlying Find Service workspace stays visible
/// behind the filter. Dismissing without applying (backdrop, ESC/back, or
/// Cancel) returns `null` and leaves the caller's filters untouched.
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

  /// Presents the filter and returns the applied filters, if any.
  ///
  /// Returns `null` when the user dismisses without applying (backdrop tap,
  /// ESC/back navigation, swipe, or Cancel) — the caller must leave its
  /// filters and search state untouched in that case.
  static Future<ServiceSearchFilters?> show({
    required BuildContext context,
    required ServiceSearchFilters initial,
  }) {
    // Desktop/tablet: bright focused card over the dimmed workspace. The
    // dialog is barrier-dismissible with ESC support; the 480–560dp cap
    // keeps it a contextual card, never a full page.
    if (context.breakpoint != Breakpoint.mobile) {
      return showDialog<ServiceSearchFilters>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: HivorrDialog(
            title: 'Filter services',
            content: SizedBox(
              width: 480,
              child: DiscoveryFilterSheet(
                initial: initial,
                onApply: (ServiceSearchFilters filters) =>
                    Navigator.of(dialogContext).pop(filters),
              ),
            ),
          ),
        ),
      );
    }
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
  /// Fixed rating scale (subset of the server-validated 0..5 continuum).
  static const List<SelectOption<double?>> _ratingOptions =
      <SelectOption<double?>>[
    SelectOption<double?>(value: null, label: 'Any rating'),
    SelectOption<double?>(value: 3.0, label: '3.0+'),
    SelectOption<double?>(value: 4.0, label: '4.0+'),
    SelectOption<double?>(value: 4.5, label: '4.5+'),
  ];

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
    // Guard: never submit an industry/profession combination that no longer
    // belongs together (e.g. the taxonomy reloaded mid-edit). The dependent
    // selectors already reset the profession on industry change; this covers
    // the residual stale-draft case without failing the whole submission.
    String? professionId = _professionId;
    if (_industryId != null && professionId != null) {
      try {
        final TaxonomyProvider taxonomy = context.read<TaxonomyProvider>();
        final List<Profession> scoped =
            taxonomy.professionsByIndustry[_industryId] ??
                const <Profession>[];
        if (scoped.isNotEmpty &&
            !scoped.any(
              (Profession profession) => profession.id == professionId,
            )) {
          professionId = null;
        }
      } catch (_) {
        // Provider absent (isolated widget test) — keep the draft as-is.
      }
    }
    widget.onApply(
      ServiceSearchFilters(
        professionId: professionId,
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

  /// Industry options from the data-driven taxonomy (sortOrder → name),
  /// shared read-only — the provider selection is never mutated here.
  List<SelectOption<String>> _industryOptions(BuildContext context) {
    final List<Industry> industries = List<Industry>.of(
      context.watch<TaxonomyProvider>().industries,
    );
    industries.sort((Industry a, Industry b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return <SelectOption<String>>[
      for (final Industry industry in industries)
        SelectOption<String>(value: industry.id, label: industry.name),
    ];
  }

  /// Profession options scoped to the selected industry — the dependent
  /// relationship stays data-driven via `Profession.industryId`.
  List<SelectOption<String>> _professionOptions(BuildContext context) {
    final String? industryId = _industryId;
    if (industryId == null) return const <SelectOption<String>>[];
    final List<Profession> professions = List<Profession>.of(
      context.watch<TaxonomyProvider>().professionsByIndustry[industryId] ??
          const <Profession>[],
    );
    professions.sort((Profession a, Profession b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return <SelectOption<String>>[
      for (final Profession profession in professions)
        SelectOption<String>(value: profession.id, label: profession.name),
    ];
  }

  bool _industriesLoading(BuildContext context) {
    try {
      return context.watch<TaxonomyProvider>().industries.isEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _professionsLoading(BuildContext context) {
    final String? industryId = _industryId;
    if (industryId == null) return false;
    try {
      return (context
                  .watch<TaxonomyProvider>()
                  .professionsByIndustry[industryId] ??
              const <Profession>[])
          .isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Currency options from the existing marketplace vocabulary with display
  /// symbols (e.g. `NGN ₦ — Nigerian Naira`); never hardcoded in the UI.
  List<SelectOption<String>> _currencyOptions() {
    return <SelectOption<String>>[
      for (final String code in DiscoveryCurrencies.active)
        SelectOption<String>(
          value: code,
          label: '$code ${SupportedCurrency.fromCode(code)?.symbol ?? ''}'
              .trim(),
          subtitle: SupportedCurrency.fromCode(code)?.name,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Currency symbol prefixes the price hints so the selected currency
    // updates the price presentation (e.g. `Min ₦`).
    final SupportedCurrency? currency = _currencyCode == null
        ? null
        : SupportedCurrency.fromCode(_currencyCode!);
    final String symbol = currency == null ? '' : '${currency.symbol} ';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Compact control panel: each dimension is a single select row.
          // Option lists live in their own scrollable/searchable surface,
          // so this card keeps a constant height at any dataset size.
          HivorrSelectField<String>(
            label: 'Industry',
            hint: 'Select industry',
            options: _industryOptions(context),
            selected: _industryId,
            clearLabel: 'All industries',
            searchHint: 'Search industries…',
            optionsTitle: 'Industry',
            loading: _industriesLoading(context),
            onSelected: (String? id) {
              if (id != _industryId) unawaited(_selectIndustry(id));
            },
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrSelectField<String>(
            label: 'Profession',
            hint: _industryId == null
                ? 'Select industry first'
                : 'Select profession',
            helperText: _industryId == null
                ? 'Choose an industry to narrow by profession.'
                : null,
            enabled: _industryId != null,
            options: _professionOptions(context),
            selected: _professionId,
            clearLabel: 'All professions',
            searchHint: 'Search professions…',
            optionsTitle: 'Profession',
            loading: _industryId != null && _professionsLoading(context),
            onSelected: (String? id) => setState(() => _professionId = id),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const _SectionLabel('Price range'),
          Row(
            children: <Widget>[
              Expanded(
                child: HivorrTextField(
                  controller: _minController,
                  hint: symbol.isEmpty ? 'Min' : 'Min $symbol',
                  keyboardType: TextInputType.number,
                  errorText: _priceError,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: HivorrTextField(
                  controller: _maxController,
                  hint: symbol.isEmpty ? 'Max' : 'Max $symbol',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrSelectField<String>(
            label: 'Currency',
            hint: 'Any currency',
            options: _currencyOptions(),
            selected: _currencyCode,
            clearLabel: 'Any currency',
            optionsTitle: 'Currency',
            onSelected: (String? code) =>
                setState(() => _currencyCode = code),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrSelectField<double?>(
            label: 'Minimum rating',
            hint: 'Any rating',
            options: _ratingOptions,
            selected: _ratingMin,
            optionsTitle: 'Minimum rating',
            onSelected: (double? value) =>
                setState(() => _ratingMin = value),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          // Plain rows (not ListTile): the sheet body is a DecoratedBox
          // without a Material ancestor, which ListTile asserts against in
          // debug builds. Switch/ink both resolve to theme tokens.
          InkWell(
            onTap: () => setState(() => _verifiedOnly = !_verifiedOnly),
            borderRadius: BorderRadius.circular(
              context.appExtension.radiusSm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Verified professionals only',
                    style: context.textTheme.bodyMedium,
                  ),
                ),
                Switch(
                  value: _verifiedOnly,
                  onChanged: (bool value) =>
                      setState(() => _verifiedOnly = value),
                ),
              ],
            ),
          ),          InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(
              context.appExtension.radiusSm,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: HivorrSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Available on',
                          style: context.textTheme.bodyMedium,
                        ),
                        Text(
                          _availabilityDate == null
                              ? 'Any date'
                              : HivorrFormatters.date(_availabilityDate!),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_availabilityDate == null)
                    Icon(
                      Icons.calendar_today_outlined,
                      color: context.colorScheme.onSurfaceVariant,
                    )
                  else
                    IconButton(
                      tooltip: 'Clear date',
                      onPressed: () =>
                          setState(() => _availabilityDate = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
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
          // Explicit dismiss without applying (backdrop/ESC/back also
          // return null). Full-width text keeps the 320dp footer free of
          // a cramped three-button row.
          HivorrButton(
            label: 'Cancel',
            variant: HivorrButtonVariant.text,
            isExpanded: true,
            onPressed: () => Navigator.of(context).maybePop(),
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

/// Currency vocabulary shared with the owner flow (display-only reuse).
class DiscoveryCurrencies {
  const DiscoveryCurrencies._();

  /// Active currency subset (mirrors `ServiceListingService.currencies`).
  static List<String> get active => ServiceListingService.currencies;
}
