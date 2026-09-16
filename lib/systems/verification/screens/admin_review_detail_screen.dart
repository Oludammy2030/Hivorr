import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Admin review detail screen (EP-02-11 §5.6).
///
/// Displays the submission details, credential document viewer (via signed
/// URL), approve/reject actions, and audit trail for a single submission.
class AdminReviewDetailScreen extends StatefulWidget {
  const AdminReviewDetailScreen({
    super.key,
    required this.submissionId,
  });

  final String submissionId;

  @override
  State<AdminReviewDetailScreen> createState() =>
      _AdminReviewDetailScreenState();
}

class _AdminReviewDetailScreenState extends State<AdminReviewDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _documentLoaded = false;
  String? _signedUrl;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminReviewProvider>();
      unawaited(provider.loadAuditTrail(widget.submissionId));
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminReviewProvider>();
    final queue = provider.queue;
    final entry = queue
        .where((e) => e.submissionId == widget.submissionId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review detail', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
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
            : _body(entry, provider),
      ),
    );
  }

  Widget _body(
    AdminReviewQueueEntry entry,
    AdminReviewProvider provider,
  ) {
    return ListView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      children: <Widget>[
        // Entity info card
        HivorrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.entityName.isNotEmpty ? entry.entityName : 'Unknown entity',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                'Submission type: ${entry.submissionType}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                'Credential: ${entry.credentialName}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                'Submitted: ${_formatDate(entry.submittedAt)}',
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
        const SizedBox(height: HivorrSpacing.md),

        // Document viewer
        HivorrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Document', style: context.textTheme.titleSmall),
              const SizedBox(height: HivorrSpacing.sm),
              if (_documentLoaded && _signedUrl != null)
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Image.network(
                    _signedUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text('Unable to load document.'),
                    ),
                  ),
                )
              else
                HivorrButton(
                  label: 'Load document',
                  isLoading: _documentLoaded == false && _signedUrl == null,
                  onPressed: () => _loadDocument(provider, entry.credentialId),
                ),
            ],
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),

        // Notes input
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Decision notes (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),

        // Feedback
        if (_feedback != null && _feedback!.isNotEmpty) ...<Widget>[
          Text(
            _feedback!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
        ],

        // Approve / Reject
        Row(
          children: <Widget>[
            Expanded(
              child: HivorrButton(
                label: 'Approve',
                isLoading: provider.isActing,
                onPressed: () => _approve(provider, entry.submissionId),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: HivorrButton(
                label: 'Reject',
                variant: HivorrButtonVariant.outline,
                isLoading: provider.isActing,
                onPressed: () => _reject(provider, entry.submissionId),
              ),
            ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.lg),

        // Audit trail
        Text('Audit trail', style: context.textTheme.titleSmall),
        const SizedBox(height: HivorrSpacing.sm),
        if (provider.isLoadingAudit)
          const HivorrLoadingState()
        else if (provider.auditTrail.isEmpty)
          Text(
            'No audit entries yet.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final audit in provider.auditTrail)
            _AuditTile(audit: audit),
      ],
    );
  }

  Future<void> _loadDocument(
    AdminReviewProvider provider,
    String credentialId,
  ) async {
    try {
      final String url = await provider.createDocumentSignedUrl(credentialId);
      setState(() {
        _signedUrl = url;
        _documentLoaded = true;
      });
    } catch (e) {
      setState(() {
        _feedback = 'Failed to load document: $e';
      });
    }
  }

  Future<void> _approve(
    AdminReviewProvider provider,
    String submissionId,
  ) async {
    await provider.approveSubmission(
      submissionId,
      notes: _notesController.text.trim(),
    );
    if (mounted && provider.lastError == null) {
      setState(() => _feedback = 'Submission approved.');
      // Pop back to queue after a short delay.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _feedback = 'Approve failed: ${provider.lastError?.message}');
    }
  }

  Future<void> _reject(
    AdminReviewProvider provider,
    String submissionId,
  ) async {
    await provider.rejectSubmission(
      submissionId,
      notes: _notesController.text.trim(),
    );
    if (mounted && provider.lastError == null) {
      setState(() => _feedback = 'Submission rejected.');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _feedback = 'Reject failed: ${provider.lastError?.message}');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.audit});

  final AdminReviewAuditEntry audit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
      child: HivorrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              audit.eventType,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HivorrSpacing.xs),
            if (audit.fromState != null || audit.toState != null)
              Text(
                '${audit.fromState ?? '?'} → ${audit.toState ?? '?'}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              _formatDate(audit.createdAt),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
