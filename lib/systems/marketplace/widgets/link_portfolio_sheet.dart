import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/shared/components/hivorr_bottom_sheet.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:provider/provider.dart';

/// Owner-only bottom sheet for linking portfolio pieces to a service listing
/// as proof-of-work (EP-03-15).
///
/// Loads the owner's `portfolio_items` via [PortfolioRepository] (public
/// profile read), offers search + multi-select (capped at
/// [ServiceListingService.maxLinkedProofs]), and saves through
/// [ServiceListingService.linkProofs] (full-replace) — or unlinks every
/// previously linked piece when the selection is cleared. Saving with an
/// empty selection and no prior links is disabled; ownership and
/// published-visibility stay server-side. Returns `true` from [show] when
/// the authoritative set changed so the caller can reload.
///
/// Only [AppTheme] tokens are used (AGENT.md Rule 5).
class LinkPortfolioSheet extends StatefulWidget {
  const LinkPortfolioSheet({
    super.key,
    required this.listingId,
    required this.ownerEntityId,
    this.initialSelection = const <String>[],
  });

  /// The `service_listings.id` being linked.
  final String listingId;

  /// The listing owner's entity id (picker source).
  final String ownerEntityId;

  /// Currently linked portfolio item ids (pre-selected).
  final List<String> initialSelection;

  /// Presents the sheet and returns `true` when links changed.
  static Future<bool?> show(
    BuildContext context, {
    required String listingId,
    required String ownerEntityId,
    List<String> initialSelection = const <String>[],
  }) {
    return HivorrBottomSheet.show<bool>(
      context: context,
      title: 'Link portfolio proof',
      child: LinkPortfolioSheet(
        listingId: listingId,
        ownerEntityId: ownerEntityId,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  State<LinkPortfolioSheet> createState() => _LinkPortfolioSheetState();
}

class _LinkPortfolioSheetState extends State<LinkPortfolioSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  List<PortfolioItem> _items = const <PortfolioItem>[];
  bool _loadingItems = true;
  ApiException? _itemsError;
  bool _noProfile = false;
  bool _noSeam = false;
  bool _saving = false;
  String _query = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _selected.addAll(widget.initialSelection);
    ServiceListingService? service;
    try {
      service = context.read<ServiceListingService?>();
    } on Object {
      service = null;
    }
    if (service == null) {
      _noSeam = true;
      _loadingItems = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadItems());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    PortfolioRepository? repository;
    try {
      repository = context.read<PortfolioRepository?>();
    } on Object {
      repository = null;
    }
    if (repository == null) {
      if (!mounted) return;
      setState(() {
        _loadingItems = false;
        _itemsError = const ApiException(
          kind: ApiExceptionKind.server,
          message: 'Portfolio is unavailable.',
          code: 'PLT999',
        );
      });
      return;
    }
    try {
      final profile = await repository.getPublicProfile(widget.ownerEntityId);
      if (!mounted) return;
      setState(() {
        _loadingItems = false;
        if (profile == null) {
          // PLT004 → owner has no public (approved) profile yet.
          _noProfile = true;
          _items = const <PortfolioItem>[];
        } else {
          _items = List<PortfolioItem>.unmodifiable(profile.portfolioItems);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingItems = false;
        _itemsError = e;
      });
    }
  }

  List<PortfolioItem> get _filtered {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return <PortfolioItem>[
      for (final PortfolioItem item in _items)
        if ('${item.title ?? ''} ${item.description ?? ''}'
            .toLowerCase()
            .contains(query))
          item,
    ];
  }

  void _toggle(String id, bool add) {
    if (add &&
        !_selected.contains(id) &&
        _selected.length >= ServiceListingService.maxLinkedProofs) {
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message:
              'You can only link up to ${ServiceListingService.maxLinkedProofs} pieces.',
          variant: HivorrSnackbarVariant.info,
        ),
      );
      return;
    }
    setState(() {
      if (add) {
        _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  Future<void> _save() async {
    ServiceListingService? service;
    try {
      service = context.read<ServiceListingService?>();
    } on Object {
      service = null;
    }
    if (service == null || _saving) return;
    // Ordered by the owner's list (deterministic); stale ids (no longer in
    // the profile fetch) are dropped — full-replace supersedes them.
    final List<String> ordered = <String>[
      for (final PortfolioItem item in _items)
        if (_selected.contains(item.id)) item.id,
    ];
    if (ordered.isNotEmpty &&
        !ServiceListingService.validateProofSelection(ordered)) {
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Select up to ${ServiceListingService.maxLinkedProofs} pieces.',
          variant: HivorrSnackbarVariant.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (ordered.isEmpty) {
        // Selection cleared: unlink every previously linked piece.
        for (final String id in widget.initialSelection) {
          await service.unlinkProof(
            listingId: widget.listingId,
            portfolioItemId: id,
          );
        }
      } else {
        await service.linkProofs(
          listingId: widget.listingId,
          portfolioItemIds: ordered,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrTextField(
          controller: _searchController,
          hint: 'Search portfolio…',
          prefix: const Icon(Icons.search),
          textInputAction: TextInputAction.search,
          onChanged: (String value) => setState(() => _query = value),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: _body(),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          'Only published listings show proof publicly. Up to ${ServiceListingService.maxLinkedProofs} pieces — pick your strongest work.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HivorrSpacing.sm),
        HivorrButton(
          label: 'Save (${_selected.length})',
          isExpanded: true,
          isLoading: _saving,
          onPressed: (_selected.isEmpty && widget.initialSelection.isEmpty) ||
                  _saving ||
                  _noSeam
              ? null
              : () => unawaited(_save()),
        ),
      ],
    );
  }

  Widget _body() {
    if (_noSeam) {
      return const HivorrErrorState(
        message: 'Proof linking is unavailable',
      );
    }
    if (_loadingItems) {
      return const HivorrLoadingState(message: 'Loading portfolio…');
    }
    final ApiException? error = _itemsError;
    if (error != null) {
      return HivorrErrorState(
        message: 'Could not load portfolio',
        detail: error.message,
        onRetry: () {
          setState(() {
            _loadingItems = true;
            _itemsError = null;
          });
          unawaited(_loadItems());
        },
      );
    }
    if (_noProfile || _items.isEmpty) {
      return const HivorrEmptyState(
        compact: true,
        title: 'No portfolio pieces yet',
        subtitle:
            'Add portfolio pieces to your public profile first, then link them here as proof of work.',
      );
    }
    final List<PortfolioItem> filtered = _filtered;
    if (filtered.isEmpty) {
      return const HivorrEmptyState(
        compact: true,
        title: 'No matches',
        subtitle: 'Try a different search.',
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        final PortfolioItem item = filtered[index];
        final bool selected = _selected.contains(item.id);
        final String title = (item.title ?? '').trim().isEmpty
            ? 'Untitled piece'
            : item.title!.trim();
        final String? type = (item.itemType ?? '').trim().isEmpty
            ? null
            : item.itemType!.trim();
        return Semantics(
          label: selected ? 'Selected — $title' : title,
          selected: selected,
          // Own Material so the tile ink paints above the sheet's
          // DecoratedBox background (framework ink-visibility assertion).
          child: Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: selected,
              onChanged: (bool? value) => _toggle(item.id, value ?? false),
              title: Text(title, style: context.textTheme.titleSmall),
              subtitle: type == null
                  ? null
                  : Text(
                      type,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        );
      },
    );
  }
}
