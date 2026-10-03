import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:provider/provider.dart';

/// Shared building blocks for reviewing one verification submission.
///
/// The same widgets render inside the pushed detail route
/// ([AdminReviewDetailScreen]) and inside the wide master-detail workspace,
/// so both experiences stay identical by construction. Hosts differ only in
/// [onResolved]: the route pops, the workspace advances selection.
///
/// Human labels for server submission-type codes (never raw codes in UI).
String reviewTypeLabel(String type) => switch (type) {
  'trade_proof' => 'Trade proof',
  'identity_document' => 'Identity document',
  'certification' => 'Certification',
  _ => type,
};

/// Server `in_review` and legacy camelCase `inReview` mean the same thing.
String reviewNormalizedStatus(String status) => switch (status) {
  'in_review' || 'inReview' => 'in_review',
  _ => status,
};

String reviewStatusLabel(String status) =>
    switch (reviewNormalizedStatus(status)) {
      'pending' => 'Pending',
      'in_review' => 'In review',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'requires_resubmission' => 'Requires resubmission',
      _ => status,
    };

HivorrBadgeVariant reviewStatusVariant(String status) =>
    switch (reviewNormalizedStatus(status)) {
      'pending' => HivorrBadgeVariant.warning,
      'in_review' => HivorrBadgeVariant.info,
      'approved' => HivorrBadgeVariant.success,
      'rejected' => HivorrBadgeVariant.error,
      'requires_resubmission' => HivorrBadgeVariant.warning,
      _ => HivorrBadgeVariant.neutral,
    };

/// Entity + submission summary card: name, status badge, and the filed rows.
class ReviewEntityCard extends StatelessWidget {
  const ReviewEntityCard({super.key, required this.entry});

  final AdminReviewQueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String name = entry.entityName.isNotEmpty
        ? entry.entityName
        : 'Unknown entity';
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HivorrBadge(
                label: reviewStatusLabel(entry.status),
                variant: reviewStatusVariant(entry.status),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          _row(
            context,
            'Submission type',
            reviewTypeLabel(entry.submissionType),
          ),
          _row(context, 'Credential', entry.credentialName),
          _row(
            context,
            'Submitted',
            reviewFormatDay(entry.submittedAt),
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {ColorScheme? colors}) {
    final ColorScheme scheme = colors ?? context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
      child: Text(
        '$label: $value',
        style: context.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Day-precision date shared by review panels (review decisions read dates,
/// not timestamps).
String reviewFormatDay(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Credential document viewer with lazy signed-URL loading.
class ReviewDocumentPanel extends StatefulWidget {
  const ReviewDocumentPanel({super.key, required this.entry});

  final AdminReviewQueueEntry entry;

  @override
  State<ReviewDocumentPanel> createState() => _ReviewDocumentPanelState();
}

class _ReviewDocumentPanelState extends State<ReviewDocumentPanel> {
  bool _loaded = false;
  bool _loading = false;
  bool _copied = false;
  String? _signedUrl;
  String? _error;

  /// PDFs have no in-app viewer (no viewer dependency): they render a file
  /// row with a copyable signed link instead of a broken image.
  bool get _isPdf =>
      (widget.entry.documentPath?.toLowerCase().endsWith('.pdf')) ?? false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String url = await context
          .read<AdminReviewProvider>()
          .createDocumentSignedUrl(widget.entry.credentialId);
      if (!mounted) return;
      setState(() {
        _signedUrl = url;
        _loaded = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load document: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Document', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          if (_loaded && _signedUrl != null && !_isPdf)
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Image.network(
                _signedUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Unable to load document.')),
              ),
            )
          else if (_loaded && _signedUrl != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: context.colorScheme.error,
                    ),
                    const SizedBox(width: HivorrSpacing.sm),
                    Expanded(
                      child: Text(
                        'PDF document',
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'Preview is unavailable for PDFs in-app. Copy the link '
                  'to open it in a browser.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.sm),
                HivorrButton(
                  label: _copied ? 'Link copied' : 'Copy link',
                  variant: HivorrButtonVariant.outline,
                  size: HivorrButtonSize.small,
                  icon: const Icon(Icons.content_copy, size: 16),
                  onPressed: () {
                    unawaited(
                      Clipboard.setData(
                        ClipboardData(text: _signedUrl!),
                      ),
                    );
                    setState(() => _copied = true);
                  },
                ),
              ],
            )
          else ...<Widget>[
            HivorrButton(
              label: 'Load document',
              isLoading: _loading,
              onPressed: _loading ? null : _load,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.sm),
              Text(
                _error!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Approve / reject actions with decision notes.
///
/// [onResolved] runs after a successful decision: the pushed route pops,
/// the workspace advances selection.
class ReviewActionsPanel extends StatefulWidget {
  const ReviewActionsPanel({
    super.key,
    required this.entry,
    required this.onResolved,
  });

  final AdminReviewQueueEntry entry;
  final VoidCallback onResolved;

  @override
  State<ReviewActionsPanel> createState() => _ReviewActionsPanelState();
}

class _ReviewActionsPanelState extends State<ReviewActionsPanel> {
  final TextEditingController _notesController = TextEditingController();
  String? _feedback;

  /// Explicit resubmission choice for Reject (server flag, Phase 4).
  /// Off = final rejection; on = the applicant must resubmit.
  bool _requireResubmission = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider provider = context.watch<AdminReviewProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrTextField(
          controller: _notesController,
          label: 'Decision notes (optional)',
          maxLines: 3,
        ),
        const SizedBox(height: HivorrSpacing.md),
        if (_feedback != null && _feedback!.isNotEmpty) ...<Widget>[
          Text(
            _feedback!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
        ],
        Row(
          children: <Widget>[
            Checkbox(
              value: _requireResubmission,
              activeColor: context.colorScheme.primary,
              onChanged: provider.isActing
                  ? null
                  : (bool? value) => setState(
                      () => _requireResubmission = value ?? false,
                    ),
            ),
            Expanded(
              child: Text(
                'Require the applicant to resubmit',
                style: context.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: HivorrButton(
                label: 'Approve',
                isLoading: provider.isActing,
                onPressed: () => _decide(provider, approved: true),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: HivorrButton(
                label: 'Reject',
                variant: HivorrButtonVariant.outline,
                isLoading: provider.isActing,
                onPressed: () => _decide(provider, approved: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _decide(AdminReviewProvider provider, {required bool approved}) async {
    final String notes = _notesController.text.trim();
    if (approved) {
      await provider.approveSubmission(widget.entry.submissionId, notes: notes);
    } else {
      await provider.rejectSubmission(
        widget.entry.submissionId,
        notes: notes,
        requiresResubmission: _requireResubmission,
      );
    }
    if (!mounted) return;
    if (provider.lastError == null) {
      setState(
        () => _feedback = approved
            ? 'Submission approved.'
            : 'Submission rejected.',
      );
      // Brief confirmation beat so the decision registers before the host
      // moves on (pop on route, advance in workspace).
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      widget.onResolved();
    } else {
      setState(
        () => _feedback =
            '${approved ? 'Approve' : 'Reject'} failed: '
            '${provider.lastError?.message}',
      );
    }
  }
}

/// Audit trail for the selected submission: loading, empty, and event rows
/// including the acting reviewer.
class ReviewAuditList extends StatelessWidget {
  const ReviewAuditList({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider provider = context.watch<AdminReviewProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
          for (final AdminReviewAuditEntry audit in provider.auditTrail)
            _ReviewAuditTile(audit: audit),
      ],
    );
  }
}

class _ReviewAuditTile extends StatelessWidget {
  const _ReviewAuditTile({required this.audit});

  final AdminReviewAuditEntry audit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
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
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (audit.actorId != null && audit.actorId!.isNotEmpty)
              Text(
                'By ${audit.actorId}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            Text(
              _formatDate(audit.createdAt),
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
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

/// Registered-vs-submitted comparison card (Phase 3).
///
/// Left column: the registered account posture, resolved read-only through
/// [ManageUserProvider.fetchUserDetail] (cached, never disturbing the
/// user-detail flow). Right column: the submission. Name rows carry a
/// match verdict; every other row is informational — different vocabularies
/// are shown side by side, never force-matched. A mismatch is a prompt to
/// verify against the document, never evidence of fraud (stated below).
class ReviewComparisonCard extends StatefulWidget {
  const ReviewComparisonCard({super.key, required this.entry});

  final AdminReviewQueueEntry entry;

  @override
  State<ReviewComparisonCard> createState() => _ReviewComparisonCardState();
}

class _ReviewComparisonCardState extends State<ReviewComparisonCard> {
  bool _noProvider = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final ManageUserProvider users = context.read<ManageUserProvider>();
        final String id = widget.entry.entityId;
        if (users.cachedDetail(id) == null && !users.detailFailed(id)) {
          unawaited(users.fetchUserDetail(id));
        }
      } catch (_) {
        if (mounted) setState(() => _noProvider = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    ManageUserProvider? users;
    try {
      users = context.watch<ManageUserProvider>();
    } catch (_) {
      users = null;
    }
    final ManageUserDetail? registered =
        users?.cachedDetail(widget.entry.entityId);
    final bool failed =
        _noProvider || (users?.detailFailed(widget.entry.entityId) ?? false);
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Registered vs submitted',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Differences are prompts to verify against the document — '
            'never evidence of fraud.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          if (registered == null) ...<Widget>[
            if (failed) ...<Widget>[
              Text(
                'Registered data unavailable.',
                style: context.textTheme.bodyMedium,
              ),
              if (users != null) ...<Widget>[
                const SizedBox(height: HivorrSpacing.sm),
                HivorrButton(
                  label: 'Retry',
                  variant: HivorrButtonVariant.text,
                  size: HivorrButtonSize.small,
                  onPressed: () {
                    final String id = widget.entry.entityId;
                    users!.retryUserDetail(id);
                    unawaited(users.fetchUserDetail(id));
                  },
                ),
              ],
            ] else
              Row(
                children: <Widget>[
                  const HivorrLoader(size: 20),
                  const SizedBox(width: HivorrSpacing.sm),
                  Expanded(
                    child: Text(
                      'Loading registered data…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
          ] else ...<Widget>[
            _headerRow(context),
            const SizedBox(height: HivorrSpacing.xs),
            _namePair(context, registered),
            _infoPair(
              context,
              label: 'Status',
              registered: registered.entity.status,
              submitted: widget.entry.status,
            ),
            _infoPair(
              context,
              label: 'Verification',
              registered:
                  'KYC ${_tierLabel(registered.kyc?.tierCode)}',
              submitted:
                  '${reviewTypeLabel(widget.entry.submissionType)} · ${widget.entry.credentialName}',
            ),
            _infoPair(
              context,
              label: 'Role',
              registered: registered.entity.capability ?? '—',
              submitted: widget.entry.professionName ?? '—',
            ),
            _infoPair(
              context,
              label: 'Joined',
              registered: reviewFormatDay(registered.entity.createdAt),
              submitted: reviewFormatDay(widget.entry.submittedAt),
            ),
            if (widget.entry.assignedReviewer != null &&
                widget.entry.assignedReviewer!.isNotEmpty)
              _contextRow(
                context,
                'Reviewer: ${widget.entry.assignedReviewer}',
              ),
            if (widget.entry.decisionNotes != null &&
                widget.entry.decisionNotes!.isNotEmpty)
              _contextRow(
                context,
                'Prior notes: ${widget.entry.decisionNotes}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    final TextStyle? style = context.textTheme.labelSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: <Widget>[
        const SizedBox(width: 20),
        const SizedBox(width: HivorrSpacing.xs),
        Expanded(child: Text('Registered account', style: style)),
        const SizedBox(width: HivorrSpacing.sm),
        Expanded(child: Text('Submitted', style: style)),
      ],
    );
  }

  Widget _namePair(BuildContext context, ManageUserDetail registered) {
    final String? legal = registered.profile?.legalName?.trim().isNotEmpty ?? false
        ? registered.profile!.legalName!.trim()
        : null;
    final String display = registered.profile?.displayName?.trim().isNotEmpty ?? false
        ? registered.profile!.displayName!.trim()
        : '';
    final String registeredName =
        legal ?? (display.isNotEmpty ? display : '—');
    final String submittedName = widget.entry.entityName.trim();
    final bool? matched = registeredName == '—' || submittedName.isEmpty
        ? null
        : registeredName.toLowerCase() == submittedName.toLowerCase();
    return _pairRow(
      context,
      matched: matched,
      registered: registeredName,
      submitted: submittedName.isNotEmpty ? submittedName : '—',
    );
  }

  Widget _infoPair(
    BuildContext context, {
    required String label,
    required String registered,
    required String submitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: HivorrSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          _pairRow(
            context,
            matched: null,
            registered: registered,
            submitted: submitted,
          ),
        ],
      ),
    );
  }

  Widget _pairRow(
    BuildContext context, {
    required bool? matched,
    required String registered,
    required String submitted,
  }) {
    final ColorScheme colors = context.colorScheme;
    final Widget indicator;
    if (matched == null) {
      indicator = Icon(Icons.remove, size: 16, color: colors.onSurfaceVariant);
    } else if (matched) {
      indicator = Icon(
        Icons.check_circle_outline,
        size: 16,
        color: context.appExtension.success,
      );
    } else {
      indicator = Icon(
        Icons.error_outline,
        size: 16,
        color: context.appExtension.warning,
      );
    }
    TextStyle? valueStyle({bool muted = false}) =>
        context.textTheme.bodyMedium?.copyWith(
          color: muted ? colors.onSurfaceVariant : colors.onSurface,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 20, child: Center(child: indicator)),
        const SizedBox(width: HivorrSpacing.xs),
        Expanded(
          child: Text(
            registered,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: valueStyle(muted: registered == '—'),
          ),
        ),
        const SizedBox(width: HivorrSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                submitted,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: valueStyle(muted: submitted == '—'),
              ),
              if (matched == false) ...<Widget>[
                const SizedBox(height: 2),
                const HivorrBadge(
                  label: 'Differs',
                  variant: HivorrBadgeVariant.warning,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _contextRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: HivorrSpacing.xs),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _tierLabel(String? code) => switch (code) {
    'tier_0' => 'Unverified',
    'tier_1' => 'Basic',
    'tier_2' => 'Standard',
    'tier_3' => 'Premium',
    null || '' => '—',
    _ => code,
  };
}
