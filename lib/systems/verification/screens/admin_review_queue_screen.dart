import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Admin review queue screen (EP-02-11 §5.6, §10).
///
/// Displays pending verification submissions fetched from the server via the
/// admin review RPCs. Tapping a queue entry navigates to the detail screen.
/// Approve/reject actions are handled by the detail screen; this screen
/// provides the overview list with optional type filtering.
class AdminReviewQueueScreen extends StatefulWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  State<AdminReviewQueueScreen> createState() => _AdminReviewQueueScreenState();
}

class _AdminReviewQueueScreenState extends State<AdminReviewQueueScreen> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminReviewProvider>();
      // Ensure admin flag is hydrated, then load queue.
      unawaited(provider.checkAdmin().then((_) {
        if (!mounted) return;
        if (AdminGate.isAdmin(provider)) {
          unawaited(provider.loadQueue());
        }
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminReviewProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Review queue', style: context.textTheme.titleLarge),
        actions: <Widget>[
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String? type) {
              setState(() => _selectedType = type);
              unawaited(provider.loadQueue(submissionType: type));
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
              const PopupMenuItem<String?>(
                value: null,
                child: Text('All types'),
              ),
              const PopupMenuItem<String?>(
                value: 'trade_proof',
                child: Text('Trade proof'),
              ),
              const PopupMenuItem<String?>(
                value: 'identity_document',
                child: Text('Identity document'),
              ),
              const PopupMenuItem<String?>(
                value: 'certification',
                child: Text('Certification'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _body(provider)),
    );
  }

  Widget _body(AdminReviewProvider provider) {
    if (!AdminGate.isAdmin(provider)) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.admin_panel_settings_outlined,
          color: context.colorScheme.primary,
        ),
        title: 'Admin access required',
        subtitle: 'You do not have platform admin privileges.',
      );
    }
    if (provider.isLoadingQueue && provider.queue.isEmpty) {
      return const HivorrLoadingState();
    }
    if (provider.lastError != null && provider.queue.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.error_outline,
          color: context.colorScheme.error,
        ),
        title: 'Failed to load queue',
        subtitle: provider.lastError!.message,
      );
    }
    if (provider.queue.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.task_alt,
          color: context.colorScheme.primary,
        ),
        title: 'Queue is clear',
        subtitle: 'No submissions are awaiting review.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.loadQueue(submissionType: _selectedType),
      child: ListView.builder(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        itemCount: provider.queue.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == provider.queue.length) {
            // Load more trigger.
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
              child: Center(
                child: provider.isLoadingQueue
                    ? const CircularProgressIndicator()
                    : HivorrButton(
                        label: 'Load more',
                        onPressed: () =>
                            provider.loadMore(submissionType: _selectedType),
                      ),
              ),
            );
          }
          final entry = provider.queue[index];
          return _QueueCard(
            key: ValueKey<String>(entry.submissionId),
            entry: entry,
            onTap: () => context.pushNamed(
              RouteNames.adminReviewDetail,
              pathParameters: <String, String>{
                'submissionId': entry.submissionId,
              },
            ),
          );
        },
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final AdminReviewQueueEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.md),
      child: HivorrCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.entityName.isNotEmpty
                      ? entry.entityName
                      : 'Unknown entity',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  '${entry.submissionType} — ${entry.credentialName}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'Status: ${entry.status}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
