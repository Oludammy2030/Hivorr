import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/verification/widgets/review_detail_panels.dart';
import 'package:provider/provider.dart';

/// Admin review detail screen (EP-02-11 §5.6).
///
/// Thin route host: resolves the entry from the queue and composes the
/// shared review panels ([ReviewEntityCard], [ReviewDocumentPanel],
/// [ReviewActionsPanel], [ReviewAuditList]) — the same widgets the wide
/// master-detail workspace renders. Behavior (notes, decisions, pop-back)
/// lives in the panels, not here.
class AdminReviewDetailScreen extends StatefulWidget {
  const AdminReviewDetailScreen({super.key, required this.submissionId});

  final String submissionId;

  @override
  State<AdminReviewDetailScreen> createState() =>
      _AdminReviewDetailScreenState();
}

class _AdminReviewDetailScreenState extends State<AdminReviewDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminReviewProvider>();
      unawaited(provider.loadAuditTrail(widget.submissionId));
      unawaited(provider.loadReviewProfile(widget.submissionId));
      // Explicit open claims the item for review (Phase 4); failures are
      // best-effort and never block the screen.
      unawaited(provider.startReview(widget.submissionId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminReviewProvider>();
    final queue = provider.queue;
    final entry = queue
        .where((e) => e.submissionId == widget.submissionId)
        .firstOrNull;

    // No nested AppBar: the shell top bar already titles the page (§13a).
    // A slim back row preserves the pop navigation the AppBar provided.
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: HivorrButton(
                label: 'Back',
                variant: HivorrButtonVariant.text,
                size: HivorrButtonSize.small,
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: () => context.pop(),
              ),
            ),
            Expanded(
              child: entry == null
                  ? HivorrEmptyState(
                      icon: Icon(
                        Icons.search_off,
                        color: context.colorScheme.primary,
                      ),
                      title: 'Submission not found',
                      subtitle:
                          'This submission may have been removed from the queue.',
                    )
                  : _body(entry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AdminReviewQueueEntry entry) {
    return ListView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      children: <Widget>[
        ReviewEntityCard(entry: entry),
        const SizedBox(height: HivorrSpacing.md),
        ReviewComparisonCard(
          key: ValueKey<String>('${entry.submissionId}-compare'),
          entry: entry,
        ),
        const SizedBox(height: HivorrSpacing.md),
        ReviewProfileSections(
          key: ValueKey<String>('${entry.submissionId}-profile'),
        ),
        const SizedBox(height: HivorrSpacing.md),
        ReviewDocumentPanel(
          key: ValueKey<String>(entry.submissionId),
          entry: entry,
        ),
        const SizedBox(height: HivorrSpacing.md),
        ReviewActionsPanel(
          key: ValueKey<String>('${entry.submissionId}-actions'),
          entry: entry,
          onResolved: () {
            if (mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: HivorrSpacing.lg),
        const ReviewAuditList(),
        const SizedBox(height: HivorrSpacing.lg),
      ],
    );
  }

}
