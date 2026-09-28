import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/shared/components/hivorr_form_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/mixins/form_validation_mixin.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/pricing_type_selector.dart';
import 'package:hivorr/workspace/profession_registry/widgets/profession_registry_browser.dart';
import 'package:provider/provider.dart';

/// Service listing create/edit form (EP-03-08 §8 D7).
///
/// Three steps (`Profession → Details → Pricing & Publish`): Step 1 embeds
/// the reusable [ProfessionRegistryBrowser] (no new taxonomy UI); Step 2
/// captures title (10–120) + description (50–5000); Step 3 captures
/// `pricing_type` + prices + currency with draft-save vs publish CTAs.
/// Client validation mirrors the server CHECKs; the RPCs stay authoritative
/// (AGENT.md Rule 4). All styling uses [AppTheme] tokens (Rule 5).
class ServiceListingFormScreen extends StatefulWidget {
  const ServiceListingFormScreen({super.key, this.listingId});

  /// When non-null the screen edits the existing listing.
  final String? listingId;

  @override
  State<ServiceListingFormScreen> createState() =>
      _ServiceListingFormScreenState();
}

class _ServiceListingFormScreenState extends State<ServiceListingFormScreen>
    with FormValidationMixin {
  int _step = 0;
  Profession? _profession;
  String? _professionId;
  bool _loadingDetail = false;
  bool _saving = false;
  bool _published = false;
  String? _loadError;
  String? _pricingType = 'fixed';
  String _currencyCode = 'NGN';

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceMinController;
  late final TextEditingController _priceMaxController;

  bool get _isEdit => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceMinController = TextEditingController();
    _priceMaxController = TextEditingController();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadDetail());
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final ServiceListingProvider provider =
        context.read<ServiceListingProvider>();
    setState(() {
      _loadingDetail = true;
      _loadError = null;
    });
    try {
      await provider.select(widget.listingId!);
      final MyServiceListing? listing = provider.selected;
      if (listing != null && mounted) {
        _titleController.text = listing.title;
        _descriptionController.text = listing.description;
        _priceMinController.text =
            listing.priceMin != null ? '${listing.priceMin}' : '';
        _priceMaxController.text =
            listing.priceMax != null ? '${listing.priceMax}' : '';
        setState(() {
          _professionId = listing.professionId;
          _pricingType = listing.pricingType;
          _currencyCode = listing.currencyCode;
          // Skip the profession step when editing — profession is shown
          // read-only with an option to change.
          _step = 1;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  String? _validateTitle(String? value) {
    if (value == null ||
        !ServiceListingService.validateTitle(value)) {
      return 'Title must be between 10 and 120 characters';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null ||
        !ServiceListingService.validateDescription(value)) {
      return 'Description must be between 50 and 5000 characters';
    }
    return null;
  }

  String? _validatePriceMin(String? value) {
    if (_pricingType == 'custom' && (value == null || value.trim().isEmpty)) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Enter a minimum price';
    }
    final double? parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Enter a valid amount of 0 or more';
    }
    return null;
  }

  String? _validatePriceMax(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final double? max = double.tryParse(value.trim());
    if (max == null || max < 0) {
      return 'Enter a valid amount of 0 or more';
    }
    final double? min = double.tryParse(_priceMinController.text.trim());
    if (min != null && max < min) {
      return 'Maximum must be equal to or greater than minimum';
    }
    return null;
  }

  double? _parsePrice(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> _save({required bool publish}) async {
    if (_professionId == null && !_isEdit) {
      setState(() => _step = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Choose a profession first.',
          variant: HivorrSnackbarVariant.warning,
        ),
      );
      return;
    }
    if (!validate()) {
      setState(() {
        // Jump to the first invalid step for progressive disclosure.
        if (_validateTitle(_titleController.text) != null ||
            _validateDescription(_descriptionController.text) != null) {
          _step = 1;
        } else {
          _step = 2;
        }
      });
      return;
    }
    final ServiceListingProvider provider =
        context.read<ServiceListingProvider>();
    setState(() => _saving = true);
    try {
      MyServiceListing listing;
      if (_isEdit) {
        listing = await provider.update(
          listingId: widget.listingId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pricingType: _pricingType,
          priceMin: _parsePrice(_priceMinController.text),
          priceMax: _parsePrice(_priceMaxController.text),
          currencyCode: _currencyCode,
        );
      } else {
        listing = await provider.create(
          professionId: _professionId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pricingType: _pricingType ?? 'fixed',
          priceMin: _parsePrice(_priceMinController.text),
          priceMax: _parsePrice(_priceMaxController.text),
          currencyCode: _currencyCode,
        );
      }
      if (publish) {
        await provider.publish(listing.id);
      }
      if (!mounted) return;
      setState(() => _published = publish);
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: publish ? 'Listing published.' : 'Draft saved.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
      if (publish && mounted) {
        context.go(RoutePaths.serviceListingsMine);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final bool isTradeGate =
          e.kind == ApiExceptionKind.conflict || e.code == 'PLT005';
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: isTradeGate && publish
              ? 'Trade verification required. Complete verification before publishing — your draft is saved.'
              : e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit listing' : 'New listing',
          style: context.textTheme.titleLarge,
        ),
      ),
      body: HivorrContentPane(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingDetail) {
      return const HivorrLoadingState(message: 'Loading listing…');
    }
    if (_loadError != null) {
      return HivorrErrorState(
        message: 'Failed to load listing',
        detail: _loadError,
        onRetry: _loadDetail,
      );
    }
    if (_published) {
      return HivorrSuccessState(
        title: 'Listing published',
        subtitle: 'Buyers can now discover your service.',
        actionButton: HivorrButton(
          label: 'View my listings',
          onPressed: () => context.go(RoutePaths.serviceListingsMine),
        ),
      );
    }
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _StepIndicator(step: _step),
          const SizedBox(height: HivorrSpacing.md),
          Expanded(child: _buildStep(context)),
          const SizedBox(height: HivorrSpacing.md),
          _buildNav(context),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        if (_isEdit) {
          return _buildEditProfessionHint(context);
        }
        return ProfessionRegistryBrowser(
          continueLabel: 'Use profession',
          onContinue: (Profession profession) {
            setState(() {
              _profession = profession;
              _professionId = profession.id;
              _step = 1;
            });
          },
        );
      case 1:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_profession != null || _professionId != null)
                Text(
                  _profession != null
                      ? 'Profession: ${_profession!.name}'
                      : 'Profession selected',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: HivorrSpacing.sm),
              HivorrFormField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g. Certified home plumbing repair with warranty',
                maxLength: 120,
                validator: _validateTitle,
              ),
              const SizedBox(height: HivorrSpacing.sm),
              HivorrFormField(
                controller: _descriptionController,
                label: 'Description',
                hint:
                    'Describe scope, deliverables, timeline, and what is included (50–5000 characters).',
                maxLines: 6,
                maxLength: 5000,
                validator: _validateDescription,
              ),
            ],
          ),
        );
      case 2:
      default:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Pricing type', style: context.textTheme.titleSmall),
              const SizedBox(height: HivorrSpacing.xs),
              PricingTypeSelector(
                selected: _pricingType,
                onSelected: (String type) =>
                    setState(() => _pricingType = type),
              ),
              const SizedBox(height: HivorrSpacing.sm),
              HivorrFormField(
                controller: _priceMinController,
                label: _pricingType == 'custom'
                    ? 'Minimum price (optional)'
                    : 'Minimum price',
                hint: 'e.g. 5000',
                keyboardType: TextInputType.number,
                validator: _validatePriceMin,
              ),
              const SizedBox(height: HivorrSpacing.sm),
              HivorrFormField(
                controller: _priceMaxController,
                label: 'Maximum price (optional)',
                hint: 'Leave empty for a single price',
                keyboardType: TextInputType.number,
                validator: _validatePriceMax,
              ),
              const SizedBox(height: HivorrSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _currencyCode,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: ServiceListingService.currencies
                    .map(
                      (String code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (String? value) {
                  if (value != null) setState(() => _currencyCode = value);
                },
              ),
            ],
          ),
        );
    }
  }

  Widget _buildEditProfessionHint(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Profession is fixed after creation for this listing.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        HivorrButton(
          label: 'Continue to details',
          onPressed: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _buildNav(BuildContext context) {
    return Row(
      children: <Widget>[
        if (_step > 0)
          Expanded(
            child: HivorrButton(
              label: 'Back',
              variant: HivorrButtonVariant.outline,
              onPressed: _saving
                  ? null
                  : () => setState(() => _step = _step - 1),
            ),
          ),
        if (_step > 0) const SizedBox(width: HivorrSpacing.sm),
        if (_step < 2)
          Expanded(
            child: HivorrButton(
              label: _step == 0 && !_isEdit ? 'Skip' : 'Continue',
              onPressed: _saving
                  ? null
                  : () {
                      if (_step == 0 && _isEdit) {
                        setState(() => _step = 1);
                        return;
                      }
                      if (_step == 1) {
                        final String? titleError =
                            _validateTitle(_titleController.text);
                        final String? descError = _validateDescription(
                          _descriptionController.text,
                        );
                        if (titleError != null || descError != null) {
                          validate();
                          return;
                        }
                      }
                      setState(() => _step = _step + 1);
                    },
            ),
          ),
        if (_step == 2) ...<Widget>[
          Expanded(
            child: HivorrButton(
              label: 'Save draft',
              variant: HivorrButtonVariant.outline,
              isLoading: _saving,
              onPressed: _saving ? null : () => _save(publish: false),
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: HivorrButton(
              label: 'Publish',
              isLoading: _saving,
              onPressed: _saving ? null : () => _save(publish: true),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Profession',
      'Details',
      'Pricing',
    ];
    return Row(
      children: <Widget>[
        for (int i = 0; i < labels.length; i++) ...<Widget>[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= step
                    ? context.colorScheme.primary
                    : context.colorScheme.outline,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.xs,
            ),
            child: Text(
              labels[i],
              style: context.textTheme.labelMedium?.copyWith(
                color: i == step
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
