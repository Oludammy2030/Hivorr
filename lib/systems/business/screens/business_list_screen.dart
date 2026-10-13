import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/business.dart';
import 'package:hivorr/data/providers/business_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/business/widgets/business_status_badge.dart';
import 'package:provider/provider.dart';
/// Business identities the caller belongs to (identity audit Phase 2a).
///
/// `GET /businesses`. Rows navigate to `businessDetail(id)`; the empty state
/// carries an `Add business` action. Tokens only (`AGENT.md` Rule 5).
class BusinessListScreen extends StatefulWidget {
  const BusinessListScreen({super.key});

  @override
  State<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends State<BusinessListScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  /// Viewer entity id when a session is resolvable (`null` otherwise —
  /// the list then renders the signed-out empty state).
  String? get _viewerId {
    try {
      return Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentSession?.entityId;
    } on Object {
      return null;
    }
  }

  Future<void> _load() async {
    final String? entityId = _viewerId;
    if (entityId == null || entityId.isEmpty) return;
    await context.read<BusinessProvider>().loadMine(entityId: entityId);
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('My Businesses')),
      body: HivorrContentPane(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Consumer<BusinessProvider>(
                  builder:
                      (BuildContext context, BusinessProvider provider, _) {
                        switch (provider.loadState) {
                          case BusinessLoadState.idle:
                          case BusinessLoadState.loading:
                            if (provider.businesses.isEmpty) {
                              return const HivorrLoadingState(
                                message: 'Loading businesses…',
                              );
                            }
                            return _BusinessList(
                              businesses: provider.businesses,
                            );
                          case BusinessLoadState.loaded:
                            if (provider.isEmpty) {
                              return HivorrEmptyState(
                                title: 'No businesses yet',
                                subtitle:
                                    'Add a business to hire on its behalf once verified.',
                                actionButton: HivorrButton(
                                  label: 'Add business',
                                  onPressed: () => context.push(
                                    RoutePaths.businessNew,
                                  ),
                                  variant: HivorrButtonVariant.primary,
                                  isExpanded: true,
                                ),
                              );
                            }
                            return _BusinessList(
                              businesses: provider.businesses,
                            );
                          case BusinessLoadState.error:
                            final ApiException? error = provider.lastError;
                            if (error?.kind == ApiExceptionKind.auth) {
                              return const HivorrEmptyState(
                                title: 'Sign in required',
                                subtitle:
                                    'Sign in to manage your businesses.',
                              );
                            }
                            return HivorrErrorState(
                              message: 'Could not load businesses',
                              detail: error?.message,
                              onRetry: () => unawaited(_load()),
                            );
                        }
                      },
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: HivorrSpacing.md),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Consumer<BusinessProvider>(
        builder: (BuildContext context, BusinessProvider provider, _) {
          if (!provider.isLoaded || provider.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => context.push(RoutePaths.businessNew),
            label: const Text('Add business'),
            icon: const Icon(Icons.add_business_outlined),
          );
        },
      ),
    );
  }
}

class _BusinessList extends StatelessWidget {
  const _BusinessList({required this.businesses});

  final List<Business> businesses;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final Business business in businesses)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: _BusinessRow(business: business),
          ),
      ],
    );
  }
}

class _BusinessRow extends StatelessWidget {
  const _BusinessRow({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final BusinessMembership? membership = business.membership;
    return HivorrCard(
      onTap: () =>
          context.push(RoutePaths.businessDetail(business.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  business.tradingName.isEmpty
                      ? 'Unnamed business'
                      : business.tradingName,
                  style: context.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              BusinessStatusBadge(status: business.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            business.registeredLegalName,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (membership != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              membership.isRepresentative
                  ? 'Representative${membership.isAuthorized ? '' : ' · awaiting authorization'}'
                  : 'Member',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
