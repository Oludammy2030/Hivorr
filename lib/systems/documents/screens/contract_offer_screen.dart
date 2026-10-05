import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/repositories/service_contract_repository.dart';
import 'package:hivorr/shared/components/hivorr_form_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/mixins/form_validation_mixin.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';
import 'package:hivorr/systems/documents/services/contract_service.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';

/// Contract offer composer (EP-03-10 §8 D7).
///
/// `GET /contracts/new?listingId=`. Listing context header (via
/// [ServiceListingService.getListing]) + total/currency/expiry form + dynamic
/// milestone list (add/remove, live `Σ milestones vs total` indicator) +
/// draft-validated `Send offer`. Writes only via `service_contract_offer`;
/// all authoritative checks stay server-side (`AGENT.md` Rule 4). Tokens only
/// (Rule 5).
class ContractOfferScreen extends StatefulWidget {
  const ContractOfferScreen({super.key, required this.listingId});

  /// The `service_listings.id` the offer is created from.
  final String listingId;

  @override
  State<ContractOfferScreen> createState() => _ContractOfferScreenState();
}

class _MilestoneDraft {
  _MilestoneDraft({required this.title, required this.amount});

  String title;
  String? description;
  double amount;
}

class _ContractOfferScreenState extends State<ContractOfferScreen>
    with FormValidationMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _totalController = TextEditingController();
  final List<_MilestoneDraft> _milestones = <_MilestoneDraft>[
    _MilestoneDraft(title: '', amount: 0),
  ];
  String _currency = 'NGN';
  DateTime? _expiry;
  MyServiceListing? _listing;
  bool _loadingListing = true;
  ApiException? _listingError;
  bool _sending = false;
  bool _sent = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadListing());
      });
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    setState(() {
      _loadingListing = true;
      _listingError = null;
    });
    try {
      final MyServiceListing listing = await context
          .read<ServiceListingService>()
          .getListing(widget.listingId);
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _loadingListing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _listingError = e;
        _loadingListing = false;
      });
    }
  }

  double get _total => double.tryParse(_totalController.text.trim()) ?? 0;

  double get _milestoneSum => _milestones.fold(
    0.0,
    (double acc, _MilestoneDraft m) => acc + m.amount,
  );

  bool get _sumsBalanced =>
      _milestones.isNotEmpty &&
      ContractService.validateMilestoneSums(
        totalAmount: _total,
        milestoneAmounts: _milestones.map((m) => m.amount).toList(),
      );

  Future<void> _sendOffer() async {
    if (!_formKey.currentState!.validate()) return;
    final List<ContractMilestoneInput> inputs = <ContractMilestoneInput>[];
    for (int i = 0; i < _milestones.length; i++) {
      final _MilestoneDraft m = _milestones[i];
      inputs.add(
        ContractMilestoneInput(
          milestoneNumber: i + 1,
          title: m.title,
          description: m.description,
          amount: m.amount,
        ),
      );
    }
    setState(() => _sending = true);
    try {
      final created = await context.read<ServiceContractProvider>().offer(
        serviceListingId: widget.listingId,
        totalAmount: _total,
        currencyCode: _currency,
        milestones: inputs,
        offerExpiresAt: _expiry,
      );
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Offer sent.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
      context.pushReplacement(RoutePaths.contractDetail(created.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Request service')),
      body: _loadingListing
          ? const HivorrLoadingState(message: 'Loading listing…')
          : _listingError != null
          ? HivorrErrorState(
              message: 'Listing not found',
              detail: _listingError?.message,
              onRetry: () => unawaited(_loadListing()),
            )
          : _sent
          ? const HivorrSuccessState(
              title: 'Offer sent',
              subtitle: 'The professional will review your request.',
              celebrate: true,
            )
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: HivorrSpacing.md,
                ),
                children: <Widget>[
                  _ListingHeader(listing: _listing!),
                  const SizedBox(height: HivorrSpacing.md),
                  HivorrFormField(
                    controller: _totalController,
                    label: 'Total amount',
                    hint: 'e.g. 30000',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? v) {
                      final double? amount = double.tryParse(
                        (v ?? '').trim(),
                      );
                      if (!ContractService.validateTotal(amount)) {
                        return 'Enter an amount greater than zero.';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                    ),
                    items: ContractService.currencies
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? v) {
                      if (v != null) setState(() => _currency = v);
                    },
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _expiry == null
                              ? 'No expiry set'
                              : 'Expires ${_expiry!.toLocal().toString().split(' ').first}',
                          style: context.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            firstDate: now.add(const Duration(days: 1)),
                            lastDate: now.add(const Duration(days: 90)),
                            initialDate: now.add(const Duration(days: 7)),
                          );
                          if (picked != null && mounted) {
                            setState(() => _expiry = picked);
                          }
                        },
                        child: const Text('Set expiry'),
                      ),
                    ],
                  ),
                  const SizedBox(height: HivorrSpacing.md),
                  Text(
                    'Milestones',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  for (int i = 0; i < _milestones.length; i++)
                    _MilestoneEditor(
                      key: ValueKey<int>(i),
                      index: i,
                      draft: _milestones[i],
                      canRemove: _milestones.length > 1,
                      onRemove: () => setState(
                        () => _milestones.removeAt(i),
                      ),
                      onChanged: () => setState(() {}),
                    ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _milestones.add(
                        _MilestoneDraft(title: '', amount: 0),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add milestone'),
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrChip(
                    label: _sumsBalanced
                        ? 'Milestones sum matches total'
                        : 'Milestones sum (${_milestoneSum.toStringAsFixed(2)}) differs from total',
                    isSelected: _sumsBalanced,
                    onSelected: (_) {},
                  ),
                  const SizedBox(height: HivorrSpacing.md),
                  HivorrButton(
                    label: 'Send offer',
                    onPressed: _sending ? null : _sendOffer,
                    variant: HivorrButtonVariant.primary,
                    isExpanded: true,
                    isLoading: _sending,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ListingHeader extends StatelessWidget {
  const _ListingHeader({required this.listing});

  final MyServiceListing listing;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(listing.title, style: context.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            listing.description,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MilestoneEditor extends StatefulWidget {
  const _MilestoneEditor({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _MilestoneDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_MilestoneEditor> createState() => _MilestoneEditorState();
}

class _MilestoneEditorState extends State<_MilestoneEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _descController = TextEditingController(
      text: widget.draft.description ?? '',
    );
    _amountController = TextEditingController(
      text: widget.draft.amount == 0 ? '' : widget.draft.amount.toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Milestone ${widget.index + 1}',
                style: context.textTheme.titleSmall,
              ),
              const Spacer(),
              if (widget.canRemove)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove milestone',
                ),
            ],
          ),
          HivorrFormField(
            controller: _titleController,
            label: 'Title',
            hint: 'e.g. Inspection visit',
            maxLength: 255,
            validator: (String? v) {
              if (!ContractService.validateMilestoneTitle(v ?? '')) {
                return 'Title must be 1 to 255 characters.';
              }
              return null;
            },
            onChanged: (String v) {
              widget.draft.title = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _descController,
            label: 'Description (optional)',
            hint: 'What does this milestone cover?',
            maxLines: 3,
            maxLength: 2000,
            validator: (String? v) {
              if (!ContractService.validateMilestoneDescription(v)) {
                return 'Description must be at most 2000 characters.';
              }
              return null;
            },
            onChanged: (String v) {
              widget.draft.description = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _amountController,
            label: 'Amount',
            hint: 'e.g. 10000',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (String? v) {
              final double? amount = double.tryParse((v ?? '').trim());
              if (amount == null || amount <= 0) {
                return 'Enter an amount greater than zero.';
              }
              return null;
            },
            onChanged: (String v) {
              widget.draft.amount = double.tryParse(v.trim()) ?? 0;
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }
}
