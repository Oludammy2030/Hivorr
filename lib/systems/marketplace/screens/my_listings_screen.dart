import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/data/providers/service_listing_provider.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/marketplace/widgets/service_listing_card.dart';
import 'package:provider/provider.dart';

/// Owner listings screen (EP-03-08 §8 D9).
///
/// `GET /services/mine`. Renders one [ServiceListingCard] per listing with a
/// status filter chip row, a create FAB, pull-to-refresh, keyset pagination,
/// and branded loading/error/empty states. Follows the `DisputeListScreen`
/// lifecycle convention (one-shot initial load, resume reload).
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with WidgetsBindingObserver {
  late final ServiceListingProvider _provider;
  bool _initialized = false;
  String? _statusFilter;
  bool _acting = false;

  static const List<String?> _filters = <String?>[null, 'draft', 'published', 'paused'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<ServiceListingProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() => _provider.loadMine(status: _statusFilter);

  void _applyFilter(String? status) {
    setState(() => _statusFilter = status);
    unawaited(_provider.loadMine(status: status));
  }

  String _filterLabel(String status) =>
      status[0].toUpperCase() + status.substring(1);

  Future<void> _publish(MyServiceListing listing) async {
    setState(() => _acting = true);
    try {
      await _provider.publish(listing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Listing published.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showActionError(e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _confirmUnpublish(MyServiceListing listing) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => HivorrDialog(
        title: 'Pause listing?',
        content: const Text(
          'Published buyers will no longer see this listing until you republish it.',
        ),
        actions: <Widget>[
          HivorrButton(
            label: 'Cancel',
            variant: HivorrButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HivorrButton(
            label: 'Pause',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await _provider.unpublish(listing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Listing paused.',
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showActionError(e);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showActionError(ApiException e) {
    final bool isTradeGate =
        e.kind == ApiExceptionKind.conflict || e.code == 'PLT005';
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(
        context,
        message: isTradeGate
            ? 'Trade verification required. Complete verification before publishing.'
            : e.message,
        variant: HivorrSnackbarVariant.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text('My listings', style: context.textTheme.titleLarge),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RoutePaths.serviceListingNew),
        tooltip: 'Create listing',
        child: const Icon(Icons.add),
      ),
      body: HivorrContentPane(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HivorrSectionHeader(
              title: 'My listings',
              action: HivorrButton(
                label: 'New',
                size: HivorrButtonSize.small,
                onPressed: () => context.push(RoutePaths.serviceListingNew),
              ),
            ),
            _FilterRow(
              selected: _statusFilter,
              onSelected: _applyFilter,
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Expanded(
              child: Consumer<ServiceListingProvider>(
                builder: (
                  BuildContext context,
                  ServiceListingProvider provider,
                  _,
                ) {
                  if (provider.isLoading && !provider.isLoaded) {
                    return const HivorrLoadingState(
                      message: 'Loading listings…',
                    );
                  }
                  if (provider.lastError != null && !provider.isLoaded) {
                    return HivorrErrorState(
                      message: 'Failed to load listings',
                      detail: provider.lastError!.message,
                      onRetry: _load,
                    );
                  }
                  if (provider.listings.isEmpty) {
                    return HivorrEmptyState(
                      title: 'No listings yet',
                      subtitle:
                          'Create your first service listing to start receiving work.',
                      actionButton: HivorrButton(
                        label: 'Create listing',
                        onPressed: () =>
                            context.push(RoutePaths.serviceListingNew),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: HivorrSpacing.xs,
                        ),
                        child: Text(
                          _statusFilter == null
                              ? '${provider.listings.length} listings'
                              : '${provider.listings.length} · ${_filterLabel(_statusFilter!)}',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: provider.listings.length +
                                (provider.hasMore ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(
                              height: HivorrSpacing.sm,
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              if (index >= provider.listings.length) {
                                return _LoadMore(
                                  onLoadMore: provider.loadMore,
                                );
                              }
                              final MyServiceListing listing =
                                  provider.listings[index];
                              return ServiceListingCard(
                                listing: listing,
                                isBusy: _acting,
                                onTap: () => context.push(
                                  RoutePaths.serviceListingEditFor(
                                    id: listing.id,
                                  ),
                                ),
                                onEdit: () => context.push(
                                  RoutePaths.serviceListingEditFor(
                                    id: listing.id,
                                  ),
                                ),
                                onMedia: () => context.push(
                                  RoutePaths.serviceListingMediaFor(
                                    id: listing.id,
                                  ),
                                ),
                                onPublish: () => _publish(listing),
                                onUnpublish: () =>
                                    _confirmUnpublish(listing),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HivorrSpacing.xs,
      children: <Widget>[
        for (final String? value in _MyListingsScreenState._filters)
          HivorrChip(
            label: value ?? 'All',
            isSelected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.onLoadMore});

  final Future<void> Function() onLoadMore;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: HivorrButton(
        label: 'Load more',
        variant: HivorrButtonVariant.outline,
        isLoading: _loading,
        onPressed: () async {
          setState(() => _loading = true);
          try {
            await widget.onLoadMore();
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
      ),
    );
  }
}
