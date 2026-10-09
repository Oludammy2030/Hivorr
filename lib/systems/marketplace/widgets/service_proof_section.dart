import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/data/entities/service_listing_proof.dart';
import 'package:hivorr/data/providers/service_proof_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/link_portfolio_sheet.dart';
import 'package:hivorr/systems/portfolio/services/professional_profile_service.dart';
import 'package:hivorr/systems/portfolio/widgets/portfolio_grid.dart';
import 'package:provider/provider.dart';

/// Linked proof-of-work section for the service detail screen (EP-03-15).
///
/// Replaces the EP-03-09 `_ProofSlot` placeholder with the real linked-proof
/// experience: loading / empty / grid / error states over
/// `service_listing_portfolio_list`, reusing [PortfolioGrid] +
/// `PortfolioItemCard` verbatim and resolving thumbnails via
/// [ProfessionalProfileService.mediaPublicUrl] (public `portfolio-items`
/// CDN URLs, placeholder fallback). Server order (link `sort_order`) is
/// rendered verbatim and never re-sorted.
///
/// Owner-only `Add portfolio` / `Edit` entries open [LinkPortfolioSheet];
/// a saved sheet triggers an authoritative reload (no optimistic tiles).
/// Verification badges stay authoritative elsewhere — proof never implies
/// verification. Only [AppTheme] tokens are used (AGENT.md Rule 5).
class ServiceProofSection extends StatefulWidget {
  const ServiceProofSection({
    super.key,
    required this.listingId,
    required this.ownerEntityId,
    required this.isOwner,
    this.profileSlug,
  });

  /// The `service_listings.id` whose proof is shown.
  final String listingId;

  /// The listing owner's entity id (picker source + profile deep-link).
  final String ownerEntityId;

  /// Whether the viewer owns the listing (gates the link entries).
  final bool isOwner;

  /// The listing's profession slug for the `View full portfolio` deep-link
  /// (`/p/:slug/:id`). When null/empty the link is hidden.
  final String? profileSlug;

  @override
  State<ServiceProofSection> createState() => _ServiceProofSectionState();
}

class _ServiceProofSectionState extends State<ServiceProofSection> {
  ServiceProofProvider? _provider;
  ProfessionalProfileService? _profileService;
  bool _initialized = false;
  bool _noSeam = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    ServiceListingService? service;
    try {
      service = context.read<ServiceListingService?>();
    } on Object {
      service = null;
    }
    try {
      _profileService = context.read<ProfessionalProfileService?>();
    } on Object {
      _profileService = null;
    }
    if (service == null) {
      // No proof seam in this build: render the static empty state instead
      // of crashing (mirrors the detail screen fail-soft).
      _noSeam = true;
      return;
    }
    final ServiceProofProvider provider = ServiceProofProvider(
      service: service,
      listingId: widget.listingId,
    );
    provider.addListener(_onProofChanged);
    _provider = provider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProofChanged);
    _provider?.dispose();
    super.dispose();
  }

  void _onProofChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() async {
    final ServiceProofProvider? provider = _provider;
    if (provider == null) return;
    try {
      await provider.load();
    } on ApiException {
      // State is held by the provider; the error branch renders it.
    }
  }

  String? _proofMediaUrl(PortfolioItem item) {
    final String? path = item.mediaPath;
    if (path == null || path.isEmpty) return null;
    try {
      return _profileService?.mediaPublicUrl(path);
    } on Object {
      return null;
    }
  }

  Future<void> _openSheet(List<String> initialSelection) async {
    final bool? saved = await LinkPortfolioSheet.show(
      context,
      listingId: widget.listingId,
      ownerEntityId: widget.ownerEntityId,
      initialSelection: initialSelection,
    );
    if (saved == true && mounted) {
      try {
        await _provider?.refresh();
      } on ApiException {
        // Provider holds the error state.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServiceProofProvider? provider = _provider;
    if (_noSeam || provider == null) {
      return _shell(
        context,
        isOwner: widget.isOwner,
        proofCount: 0,
        onEdit: null,
        child: _emptyBody(context, isOwner: widget.isOwner, onAdd: null),
      );
    }
    switch (provider.state) {
      case ServiceProofLoadState.idle:
      case ServiceProofLoadState.loading:
        return _shell(
          context,
          isOwner: widget.isOwner,
          proofCount: provider.proofs.length,
          onEdit: null,
          child: const HivorrLoadingState(message: 'Loading proof of work…'),
        );
      case ServiceProofLoadState.error:
        final ApiException? error = provider.lastError;
        return _shell(
          context,
          isOwner: widget.isOwner,
          proofCount: 0,
          onEdit: null,
          child: HivorrErrorState(
            message: 'Could not load proof of work',
            detail: error?.message,
            onRetry: () {
              unawaited(_reload());
            },
          ),
        );
      case ServiceProofLoadState.loaded:
        final List<LinkedPortfolioItem> proofs = provider.proofs;
        if (proofs.isEmpty) {
          return _shell(
            context,
            isOwner: widget.isOwner,
            proofCount: 0,
            onEdit: null,
            child: _emptyBody(
              context,
              isOwner: widget.isOwner,
              onAdd: widget.isOwner ? () => _openSheet(const <String>[]) : null,
            ),
          );
        }
        return _shell(
          context,
          isOwner: widget.isOwner,
          proofCount: proofs.length,
          onEdit: widget.isOwner
              ? () => _openSheet(
                  <String>[for (final LinkedPortfolioItem p in proofs) p.item.id],
                )
              : null,
          child: PortfolioGrid(
            items: <PortfolioItem>[
              for (final LinkedPortfolioItem p in proofs) p.item,
            ],
            mediaUrlBuilder: _proofMediaUrl,
          ),
        );
    }
  }

  Widget _shell(
    BuildContext context, {
    required bool isOwner,
    required int proofCount,
    required VoidCallback? onEdit,
    required Widget child,
  }) {
    final VoidCallback? edit = onEdit;
    final String? slug = widget.profileSlug?.trim();
    final bool canViewProfile =
        slug != null && slug.isNotEmpty && widget.ownerEntityId.isNotEmpty;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Proof of work',
                  style: context.textTheme.titleMedium,
                ),
              ),
              if (edit != null)
                HivorrButton(
                  label: 'Edit',
                  variant: HivorrButtonVariant.text,
                  size: HivorrButtonSize.small,
                  onPressed: edit,
                ),
            ],
          ),
          if (canViewProfile) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: HivorrButton(
                label: 'View full portfolio',
                variant: HivorrButtonVariant.text,
                size: HivorrButtonSize.small,
                onPressed: () => context.push(
                  RoutePaths.publicProfile(
                    slug: slug,
                    id: widget.ownerEntityId,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: HivorrSpacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _emptyBody(
    BuildContext context, {
    required bool isOwner,
    required VoidCallback? onAdd,
  }) {
    final VoidCallback? add = onAdd;
    return HivorrEmptyState(
      compact: true,
      title: 'No proof linked yet',
      subtitle: isOwner
          ? 'Link portfolio pieces to this service to convert more views.'
          : 'Proof of work will appear here once the professional links it.',
      actionButton: (isOwner && add != null)
          ? HivorrButton(
              label: 'Add portfolio',
              variant: HivorrButtonVariant.outline,
              onPressed: add,
            )
          : null,
    );
  }
}
