import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/widgets/escrow_card.dart';
import 'package:provider/provider.dart';

/// Escrow list screen (EP-02-14 §5.6).
///
/// Loads the known escrow headers for a project and renders one [EscrowCard]
/// per escrow. Tapping a card routes to the detail screen
/// (`/finance/escrow/:id`). Follows the `FinancialProfileScreen` lifecycle
/// convention (lifecycle-observed, one-shot initial load).
class EscrowListScreen extends StatefulWidget {
  const EscrowListScreen({
    super.key,
    this.projectId = 'default',
    this.escrowIds = const <String>[],
  });

  /// Project scope for the list (placeholder until project routing lands).
  final String projectId;

  /// Known escrow ids for the project, enumerated by the caller.
  final List<String> escrowIds;

  @override
  State<EscrowListScreen> createState() => _EscrowListScreenState();
}

class _EscrowListScreenState extends State<EscrowListScreen>
    with WidgetsBindingObserver {
  late final EscrowProvider _provider;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<EscrowProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            _provider.loadForProject(
              projectId: widget.projectId,
              escrowIds: widget.escrowIds,
            ),
          );
        }
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

  Future<void> _load() => _provider.loadForProject(
        projectId: widget.projectId,
        escrowIds: widget.escrowIds,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Escrows', style: context.textTheme.titleLarge),
      ),
      body: Consumer<EscrowProvider>(
        builder: (BuildContext context, EscrowProvider provider, _) {
          if (provider.isLoading && !provider.isLoaded) {
            return const HivorrLoadingState(message: 'Loading escrows...');
          }

          if (provider.lastError != null && !provider.isLoaded) {
            return HivorrErrorState(
              message: 'Failed to load escrows',
              detail: provider.lastError!.message,
              onRetry: () => provider.loadForProject(
                projectId: widget.projectId,
                escrowIds: widget.escrowIds,
              ),
            );
          }

          if (provider.escrows.isEmpty) {
            return HivorrEmptyState(
              icon: const Icon(Icons.lock_outline),
              title: 'No active escrows',
              subtitle:
                  'Escrows appear here once a project contract is funded. '
                  'Funds stay locked until milestone release.',
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              itemCount: provider.escrows.length,
              separatorBuilder:
                  (BuildContext context, int index) =>
                      const SizedBox(height: HivorrSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final escrow = provider.escrows[index];
                return EscrowCard(
                  escrow: escrow,
                  onTap: () => context.push(
                    '/finance/escrow/${escrow.id}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}