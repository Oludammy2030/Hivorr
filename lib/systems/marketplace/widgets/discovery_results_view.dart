import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/data/providers/marketplace_search_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/marketplace/widgets/discovery_service_card.dart';
import 'package:provider/provider.dart';

/// Shared ranked-results body for discovery + search screens (EP-03-09).
///
/// Renders [MarketplaceSearchProvider] state verbatim in RPC order (never
/// re-sorts — AGENT.md:7): loading, error + retry, empty, or the responsive
/// 1/2/3-column card grid with a keyset `Load more` footer. Card taps
/// deep-link to the public detail with the row passed as `extra` (the detail
/// re-reads the authoritative row via `service_listing_get`).
/// All styling resolves to [AppTheme] tokens (AGENT.md Rule 5).
class DiscoveryResultsView extends StatelessWidget {
  const DiscoveryResultsView({
    super.key,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  /// Empty-state title (browse vs search copy differs).
  final String emptyTitle;

  /// Empty-state subtitle.
  final String emptySubtitle;

  /// Optional empty-state action label (e.g. `Clear filters`).
  final String? emptyActionLabel;

  /// Empty-state action handler.
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    final MarketplaceSearchProvider? provider =
        context.watch<MarketplaceSearchProvider?>();
    if (provider == null) {
      return const HivorrErrorState(
        message: 'Search is unavailable',
        detail: 'Ranked discovery is not wired in this build.',
      );
    }
    if (provider.isLoading && provider.items.isEmpty) {
      return const HivorrLoadingState(message: 'Finding services…');
    }
    final ApiException? error = provider.error;
    if (provider.state == MarketplaceSearchState.error &&
        provider.items.isEmpty) {
      // No-oracle uniformity: an unknown/inactive profession (`PLT004`)
      // renders exactly like an empty page — never a distinct error that
      // would let viewers enumerate taxonomy or supply.
      if (error?.code == 'PLT004') {
        final String? actionLabel = emptyActionLabel;
        final VoidCallback? action = onEmptyAction;
        return HivorrEmptyState(
          title: emptyTitle,
          subtitle: emptySubtitle,
          actionButton: actionLabel != null && action != null
              ? HivorrButton(label: actionLabel, onPressed: action)
              : null,
        );
      }
      return HivorrErrorState(
        message: 'Could not load services',
        detail: error?.message,
        onRetry: () => unawaited(provider.search()),
      );
    }
    if (provider.isEmpty) {
      final String? actionLabel = emptyActionLabel;
      final VoidCallback? action = onEmptyAction;
      return HivorrEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionButton: actionLabel != null && action != null
            ? HivorrButton(label: actionLabel, onPressed: action)
            : null,
      );
    }
    return _ResultsList(provider: provider);
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.provider});

  final MarketplaceSearchProvider provider;

  @override
  Widget build(BuildContext context) {
    final List<ServiceListing> items = provider.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
          child: Text(
            items.length == 1 ? '1 service' : '${items.length} services',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.search,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Breakpoint breakpoint =
                    Breakpoints.fromWidth(constraints.maxWidth);
                if (breakpoint == Breakpoint.mobile) {
                  return ListView.separated(
                    itemCount: items.length + (provider.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: HivorrSpacing.sm),
                    itemBuilder: (BuildContext context, int index) =>
                        _item(context, items, index),
                  );
                }
                final int columns =
                    breakpoint == Breakpoint.tablet ? 2 : 3;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: HivorrSpacing.sm,
                    mainAxisSpacing: HivorrSpacing.sm,
                    mainAxisExtent: 268,
                  ),
                  itemCount: items.length + (provider.hasMore ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) =>
                      _item(context, items, index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    List<ServiceListing> items,
    int index,
  ) {
    if (index >= items.length) {
      return _LoadMore(provider: provider);
    }
    final ServiceListing listing = items[index];
    return DiscoveryServiceCard(
      key: ValueKey<String>(listing.id),
      listing: listing,
      onTap: () => context.push(
        RoutePaths.serviceDetail(listing.id),
        extra: listing,
      ),
    );
  }
}

class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.provider});

  final MarketplaceSearchProvider provider;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
        child: HivorrButton(
          label: 'Load more',
          variant: HivorrButtonVariant.outline,
          isLoading: _loading,
          onPressed: () async {
            setState(() => _loading = true);
            try {
              await widget.provider.loadMore();
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
        ),
      ),
    );
  }
}
