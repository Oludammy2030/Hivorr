import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/marketplace/services/service_listing_service.dart';
import 'package:hivorr/systems/marketplace/widgets/favorite_toggle_button.dart';
import 'package:hivorr/systems/marketplace/widgets/service_media_carousel.dart';
import 'package:hivorr/systems/verification/widgets/trade_verified_badge.dart';
import 'package:provider/provider.dart';

/// Public service detail screen at `/services/:id` (alias `/s/:slug/:id`)
/// (EP-03-09).
///
/// Renders the authoritative row via `service_listing_get` re-read
/// ([ServiceListingService.getListing]); the optional [initialListing] (route
/// `extra`) paints first so navigation feels instant, then upgrades to the
/// authoritative row with ordered media (`sort_order ASC, created_at ASC`
/// verbatim). Media URLs resolve via `mediaPublicUrl` with placeholder
/// fallback. The `Book / Request Proposal` CTA is a client affordance only:
/// self-listings render disabled with guidance, signed-out viewers resume via
/// login `?next=`, and enforcement stays server-side (AGENT.md Rule 2/4).
/// Only [AppTheme] tokens are used (AGENT.md Rule 5).
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  /// The `service_listings.id` from the route (`:id`) — authoritative.
  final String listingId;

  /// Ranked row passed as route `extra` for instant paint (optional).
  final ServiceListing? initialListing;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  _DetailModel? _model;
  List<ListingMedia> _media = const <ListingMedia>[];
  bool _loadingAuthoritative = true;
  ApiException? _error;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final ServiceListing? initial = widget.initialListing;
    if (initial != null) {
      _model = _DetailModel.fromRanked(initial);
    }
    if (widget.listingId.trim().isEmpty) {
      _loadingAuthoritative = false;
      _error = const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Listing not found.',
        code: 'PLT004',
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadAuthoritative());
    });
  }

  Future<void> _loadAuthoritative() async {
    ServiceListingService? service;
    try {
      service = context.read<ServiceListingService?>();
    } on Object {
      service = null;
    }
    if (service == null) {
      // No detail seam in this build: keep the instant-paint row (if any) and
      // surface media as unavailable.
      if (!mounted) return;
      setState(() => _loadingAuthoritative = false);
      return;
    }
    try {
      final listing = await service.getListing(widget.listingId.trim());
      if (!mounted) return;
      setState(() {
        _model = _DetailModel.fromOwner(
          id: listing.id,
          entityId: listing.entityId,
          title: listing.title,
          description: listing.description,
          pricingType: listing.pricingType,
          priceMin: listing.priceMin,
          priceMax: listing.priceMax,
          currencyCode: listing.currencyCode,
          avgRating: listing.avgRating,
          reviewCount: listing.reviewCount,
          isTradeVerifiedCache: listing.isTradeVerifiedCache,
          professionName: listing.professionName,
          industryName: listing.industryName,
          publishedAt: listing.publishedAt,
        );
        // Server order is preserved verbatim (never re-sorted).
        _media = List<ListingMedia>.unmodifiable(listing.media);
        _loadingAuthoritative = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAuthoritative = false;
        _error = e;
      });
    }
  }

  String? _imageUrlFor(String storagePath) {
    try {
      return context.read<ServiceListingService?>()?.mediaPublicUrl(
        storagePath,
      );
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ApiException? error = _error;
    final _DetailModel? model = _model;
    if (error != null && model == null) {
      if (error.code == 'PLT004' ||
          error.kind == ApiExceptionKind.notFound) {
        return HivorrDetailScaffold(
          title: 'Service',
          body: HivorrEmptyState(
            title: 'Listing not found',
            subtitle:
                'This service may have been paused or removed. Try browsing similar services.',
            actionButton: HivorrButton(
              label: 'Browse services',
              onPressed: () => context.go(RoutePaths.serviceDiscovery),
            ),
          ),
        );
      }
      return HivorrDetailScaffold(
        title: 'Service',
        body: HivorrErrorState(
          message: 'Could not load this service',
          detail: error.message,
          onRetry: () {
            setState(() {
              _loadingAuthoritative = true;
              _error = null;
            });
            unawaited(_loadAuthoritative());
          },
        ),
      );
    }
    if (model == null) {
      return const HivorrDetailScaffold(
        title: 'Service',
        body: HivorrLoadingState(message: 'Loading service…'),
      );
    }
    return HivorrDetailScaffold(
      title: 'Service',
      body: RefreshIndicator(
        onRefresh: _loadAuthoritative,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: _DetailBody(
            model: model,
            media: _media,
            refreshing: _loadingAuthoritative,
            imageUrlFor: _imageUrlFor,
            listingId: widget.listingId.trim(),
          ),
        ),
      ),
    );
  }
}

/// Slim scaffold shared by detail states (keeps AppBar consistent).
class HivorrDetailScaffold extends StatelessWidget {
  const HivorrDetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
  });

  final String title;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.serviceDiscovery),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(title, style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HivorrSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: body,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

class _DetailModel {
  const _DetailModel({
    required this.id,
    required this.entityId,
    required this.title,
    required this.description,
    required this.pricingType,
    required this.priceMin,
    required this.priceMax,
    required this.currencyCode,
    required this.avgRating,
    required this.reviewCount,
    required this.isTradeVerifiedCache,
    required this.professionName,
    required this.industryName,
    required this.publishedAt,
  });

  factory _DetailModel.fromRanked(ServiceListing listing) => _DetailModel(
    id: listing.id,
    entityId: listing.entityId,
    title: listing.title,
    description: listing.description,
    pricingType: listing.pricingType,
    priceMin: listing.priceMin,
    priceMax: listing.priceMax,
    currencyCode: listing.currencyCode,
    avgRating: listing.avgRating,
    reviewCount: listing.reviewCount,
    isTradeVerifiedCache: listing.isTradeVerifiedCache,
    professionName: listing.professionName,
    industryName: listing.industryName,
    publishedAt: listing.publishedAt,
  );

  factory _DetailModel.fromOwner({
    required String id,
    required String entityId,
    required String title,
    required String description,
    required String pricingType,
    required double? priceMin,
    required double? priceMax,
    required String currencyCode,
    required double avgRating,
    required int reviewCount,
    required bool isTradeVerifiedCache,
    required String? professionName,
    required String? industryName,
    required DateTime? publishedAt,
  }) => _DetailModel(
    id: id,
    entityId: entityId,
    title: title,
    description: description,
    pricingType: pricingType,
    priceMin: priceMin,
    priceMax: priceMax,
    currencyCode: currencyCode,
    avgRating: avgRating,
    reviewCount: reviewCount,
    isTradeVerifiedCache: isTradeVerifiedCache,
    professionName: professionName,
    industryName: industryName,
    publishedAt: publishedAt,
  );

  final String id;
  final String entityId;
  final String title;
  final String description;
  final String pricingType;
  final double? priceMin;
  final double? priceMax;
  final String currencyCode;
  final double avgRating;
  final int reviewCount;
  final bool isTradeVerifiedCache;
  final String? professionName;
  final String? industryName;
  final DateTime? publishedAt;
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.model,
    required this.media,
    required this.refreshing,
    required this.imageUrlFor,
    required this.listingId,
  });

  final _DetailModel model;
  final List<ListingMedia> media;
  final bool refreshing;
  final String? Function(String storagePath) imageUrlFor;
  final String listingId;

  @override
  Widget build(BuildContext context) {
    String? viewerId;
    try {
      viewerId = context.read<AuthProvider?>()?.currentSession?.entityId;
    } on Object {
      viewerId = null;
    }
    final bool isOwner = viewerId != null && viewerId == model.entityId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (refreshing) const LinearProgressIndicator(),
        const SizedBox(height: HivorrSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                model.title,
                style: context.textTheme.headlineSmall,
              ),
            ),
            FavoriteToggleButton(listingId: model.id),
          ],
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Wrap(
          spacing: HivorrSpacing.xs,
          runSpacing: HivorrSpacing.xs,
          children: <Widget>[
            if ((model.professionName ?? '').isNotEmpty)
              HivorrBadge(
                label: model.professionName!,
                variant: HivorrBadgeVariant.info,
              ),
            if ((model.industryName ?? '').isNotEmpty)
              HivorrBadge(
                label: model.industryName!,
                variant: HivorrBadgeVariant.neutral,
              ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          _priceLine(),
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        _RatingLine(model: model),
        if (model.publishedAt != null) ...<Widget>[
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Published ${HivorrFormatters.date(model.publishedAt!)}',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: HivorrSpacing.md),
        if (model.isTradeVerifiedCache)
          TradeVerifiedBadge(
            professionName: (model.professionName ?? '').isNotEmpty
                ? model.professionName!
                : 'Trade verified professional',
            subtitle: 'Identity and trade proof approved',
          ),
        const SizedBox(height: HivorrSpacing.md),
        ServiceMediaCarousel(media: media, imageUrlFor: imageUrlFor),
        const SizedBox(height: HivorrSpacing.md),
        Text('About this service', style: context.textTheme.titleMedium),
        const SizedBox(height: HivorrSpacing.xs),
        Text(model.description, style: context.textTheme.bodyMedium),
        const SizedBox(height: HivorrSpacing.md),
        _ProofSlot(isOwner: isOwner),
        const SizedBox(height: HivorrSpacing.md),
        _BookingCta(
          model: model,
          isOwner: isOwner,
          viewerId: viewerId,
          listingId: listingId,
        ),
        const SizedBox(height: HivorrSpacing.lg),
      ],
    );
  }

  String _priceLine() {
    if (model.pricingType == 'custom') {
      return '${model.currencyCode} Custom quote';
    }
    final double? min = model.priceMin;
    if (min == null) return '${model.currencyCode} —';
    final String minStr = HivorrFormatters.number(min, decimals: 0);
    final double? max = model.priceMax;
    if (max == null) return '${model.currencyCode} $minStr';
    return '${model.currencyCode} $minStr – ${HivorrFormatters.number(max, decimals: 0)}';
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.model});

  final _DetailModel model;

  @override
  Widget build(BuildContext context) {
    final String count = model.reviewCount == 1
        ? '1 review'
        : '${model.reviewCount} reviews';
    return Semantics(
      label: 'Rated ${model.avgRating.toStringAsFixed(1)} out of 5 from $count',
      child: Row(
        children: <Widget>[
          Icon(Icons.star, size: 18, color: context.colorScheme.secondary),
          const SizedBox(width: 4),
          Text(
            model.avgRating.toStringAsFixed(1),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Portfolio proof placeholder (EP-03-09 read-only hook; linking ships in
/// EP-03-15 — no link-write is attempted here).
class _ProofSlot extends StatelessWidget {
  const _ProofSlot({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Proof of work', style: context.textTheme.titleMedium),
          const SizedBox(height: HivorrSpacing.xs),
          HivorrEmptyState(
            compact: true,
            title: 'No proof linked yet',
            subtitle: isOwner
                ? 'Link portfolio pieces to this service to convert more views.'
                : 'Proof of work will appear here once the professional links it.',
            actionButton: isOwner
                ? HivorrButton(
                    label: 'Add portfolio',
                    variant: HivorrButtonVariant.outline,
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      HivorrSnackbar.show(
                        context,
                        message:
                            'Portfolio linking for services arrives next (EP-03-15).',
                        variant: HivorrSnackbarVariant.info,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// Booking CTA (client affordance only — contract enforcement in EP-03-10).
class _BookingCta extends StatelessWidget {
  const _BookingCta({
    required this.model,
    required this.isOwner,
    required this.viewerId,
    required this.listingId,
  });

  final _DetailModel model;
  final bool isOwner;
  final String? viewerId;
  final String listingId;

  @override
  Widget build(BuildContext context) {
    if (isOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivorrButton(
            label: 'Book / Request proposal',
            isExpanded: true,
            onPressed: null,
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'This is your listing — you cannot hire yourself.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return HivorrButton(
      label: 'Book / Request proposal',
      isExpanded: true,
      onPressed: () {
        if (viewerId == null) {
          unawaited(
            context.push(
              '${RoutePaths.login}?next=${Uri.encodeComponent(RoutePaths.serviceDetail(listingId))}',
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          HivorrSnackbar.show(
            context,
            message:
                'Proposal requests open with milestone contracts (coming next).',
            variant: HivorrSnackbarVariant.info,
          ),
        );
      },
    );
  }
}
