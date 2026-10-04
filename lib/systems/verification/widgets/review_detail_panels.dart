import 'dart:async';
import 'package:dio/dio.dart';
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
import 'package:pdfx/pdfx.dart';
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

/// Fetches raw document bytes for the in-app PDF viewer. Injectable so
/// widget tests stay hermetic (no network); production uses Dio.
typedef DocumentBytesFetcher = Future<Uint8List> Function(String url);

/// Production bytes fetch over the short-lived signed URL.
Future<Uint8List> fetchDocumentBytes(String url) async {
  final Dio dio = Dio();
  final Response<List<int>> response = await dio.get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final List<int>? data = response.data;
  if (data == null || data.isEmpty) throw Exception('Empty document.');
  return Uint8List.fromList(data);
}

/// Credential document viewer with lazy signed-URL loading.
///
/// Images render inline; PDFs render in-app via [PdfViewPinch] (pinch zoom,
/// vertical paging) with a copy-link fallback that always stays available.
class ReviewDocumentPanel extends StatefulWidget {
  const ReviewDocumentPanel({
    super.key,
    required this.entry,
    this.bytesFetcher = fetchDocumentBytes,
  });

  final AdminReviewQueueEntry entry;

  /// Override in tests to avoid network.
  final DocumentBytesFetcher bytesFetcher;

  @override
  State<ReviewDocumentPanel> createState() => _ReviewDocumentPanelState();
}

class _ReviewDocumentPanelState extends State<ReviewDocumentPanel> {
  bool _loaded = false;
  bool _loading = false;
  bool _copied = false;
  String? _signedUrl;
  String? _error;
  PdfControllerPinch? _pdfController;
  PdfDocument? _pdfDocument;
  int? _pageCount;
  int _currentPage = 1;

  /// PDFs render in-app ([PdfViewPinch]); the copy-link fallback stays for
  /// load failures and expired URLs.
  bool get _isPdf =>
      (widget.entry.documentPath?.toLowerCase().endsWith('.pdf')) ?? false;

  @override
  void dispose() {
    _pdfController?.dispose();
    unawaited(_closePdfDocument());
    super.dispose();
  }

  Future<void> _closePdfDocument() async {
    try {
      await _pdfDocument?.close();
    } catch (_) {
      // Best-effort native cleanup.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    String? url;
    try {
      url = await context
          .read<AdminReviewProvider>()
          .createDocumentSignedUrl(widget.entry.credentialId);
      if (!mounted) return;
      if (_isPdf) {
        final Uint8List bytes = await widget.bytesFetcher(url);
        if (!mounted) return;
        _pdfController?.dispose();
        await _closePdfDocument();
        _pdfDocument = null;
        final PdfControllerPinch controller = PdfControllerPinch(
          document: PdfDocument.openData(bytes),
        );
        setState(() {
          _signedUrl = url;
          _pdfController = controller;
          _pageCount = null;
          _currentPage = 1;
          _loaded = true;
          _loading = false;
        });
      } else {
        setState(() {
          _signedUrl = url;
          _loaded = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep the signed URL when the PDF bytes failed so Copy link
        // still offers a way out.
        _signedUrl = url ?? _signedUrl;
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
            _pdfBody(context)
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
            if (_signedUrl != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.sm),
              _copyLinkButton(),
            ],
          ],
        ],
      ),
    );
  }

  /// In-app PDF viewer: header with page position, pinch-to-zoom paging
  /// area, and the copy-link fallback.
  Widget _pdfBody(BuildContext context) {
    final PdfControllerPinch? controller = _pdfController;
    return Column(
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
            if (_pageCount != null)
              Text(
                'Page $_currentPage of $_pageCount',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        if (controller != null)
          SizedBox(
            height: 420,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                context.appExtension.radiusSm,
              ),
              child: PdfViewPinch(
                controller: controller,
                onPageChanged: (int page) {
                  if (mounted) setState(() => _currentPage = page);
                },
                onDocumentLoaded: (PdfDocument document) {
                  if (mounted) {
                    setState(() {
                      _pdfDocument = document;
                      _pageCount = document.pagesCount;
                    });
                  }
                },
                onDocumentError: (Object error) {
                  if (mounted) {
                    setState(
                      () => _error = 'Unable to render this PDF: $error',
                    );
                  }
                },
              ),
            ),
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
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          'Pinch to zoom · scroll to turn pages.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        _copyLinkButton(),
      ],
    );
  }

  Widget _copyLinkButton() {
    final String? url = _signedUrl;
    return HivorrButton(
      label: _copied ? 'Link copied' : 'Copy link',
      variant: HivorrButtonVariant.outline,
      size: HivorrButtonSize.small,
      icon: const Icon(Icons.content_copy, size: 16),
      onPressed: url == null
          ? null
          : () {
              unawaited(
                Clipboard.setData(ClipboardData(text: url)),
              );
              setState(() => _copied = true);
            },
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
  String? _notesError;

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
          label: 'Decision notes',
          helperText: 'Required to reject; attached to the audit record.',
          errorText: _notesError,
          maxLines: 3,
          onChanged: (_) {
            if (_notesError != null) setState(() => _notesError = null);
          },
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
    if (!approved && notes.isEmpty) {
      setState(() {
        _notesError = 'A reason is required to reject.';
        _feedback = null;
      });
      return;
    }
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

/// Applicant profile depth for the review: work experience, education, and
/// skills served by `verification_review_profile_get` (resolved per
/// submission by the provider). Shared by the pushed detail route and the
/// wide workspace so both stay identical by construction. Empty sections
/// render explicit empty states — the applicant recorded nothing, which is
/// valid and never an error. Skills carry years only: the platform collects
/// no proficiency scale, so none is shown.
class ReviewProfileSections extends StatelessWidget {
  const ReviewProfileSections({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider provider = context.watch<AdminReviewProvider>();
    if (provider.isLoadingProfile) {
      return HivorrCard(
        child: Row(
          children: <Widget>[
            const HivorrLoader(size: 20),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: Text(
                'Loading profile…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final AdminReviewProfile profile = provider.reviewProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _sectionCard(
          context,
          title: 'Work Experience',
          count: profile.experiences.length,
          emptyText: 'No work history recorded by the applicant.',
          children: <Widget>[
            for (final ReviewExperience experience in profile.experiences)
              _experienceRow(context, experience),
          ],
        ),
        const SizedBox(height: HivorrSpacing.md),
        _sectionCard(
          context,
          title: 'Education',
          count: profile.educations.length,
          emptyText: 'No education recorded by the applicant.',
          children: <Widget>[
            for (final ReviewEducation education in profile.educations)
              _educationRow(context, education),
          ],
        ),
        const SizedBox(height: HivorrSpacing.md),
        _sectionCard(
          context,
          title: 'Skills',
          count: profile.skills.length,
          emptyText: 'No skills recorded by the applicant.',
          children: <Widget>[
            if (profile.skills.isNotEmpty)
              Wrap(
                spacing: HivorrSpacing.sm,
                runSpacing: HivorrSpacing.sm,
                children: <Widget>[
                  for (final ReviewSkill skill in profile.skills)
                    HivorrBadge(
                      label: skill.yearsExperience == null
                          ? skill.name
                          : '${skill.name} · ${skill.yearsExperience} yrs',
                      variant: HivorrBadgeVariant.primary,
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required int count,
    required String emptyText,
    required List<Widget> children,
  }) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (count > 0) ...<Widget>[
                const SizedBox(width: HivorrSpacing.sm),
                HivorrBadge(
                  label: '$count',
                  variant: HivorrBadgeVariant.neutral,
                ),
              ],
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          if (children.isEmpty)
            Text(
              emptyText,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _experienceRow(BuildContext context, ReviewExperience experience) {
    final String range = _reviewRange(experience);
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  experience.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (experience.isCurrent) ...<Widget>[
                const SizedBox(width: HivorrSpacing.sm),
                const HivorrBadge(
                  label: 'Current',
                  variant: HivorrBadgeVariant.info,
                ),
              ],
            ],
          ),
          Text(
            experience.organization,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (range.isNotEmpty)
            Text(
              range,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          if ((experience.description ?? '').trim().isNotEmpty)
            Text(
              experience.description!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _educationRow(BuildContext context, ReviewEducation education) {
    final List<String> detail = <String>[
      if ((education.degree ?? '').trim().isNotEmpty)
        education.degree!.trim(),
      if ((education.fieldOfStudy ?? '').trim().isNotEmpty)
        education.fieldOfStudy!.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            education.school,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail.isNotEmpty)
            Text(
              detail.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          if (education.graduationYear != null)
            Text(
              'Class of ${education.graduationYear}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

String _reviewRange(ReviewExperience experience) {
  final String start = _reviewMonthYear(
    experience.startYear,
    experience.startMonth,
  );
  final String end = experience.isCurrent
      ? 'Present'
      : _reviewMonthYear(experience.endYear, experience.endMonth);
  if (start.isEmpty) return end;
  if (end.isEmpty) return start;
  return '$start – $end';
}

String _reviewMonthYear(int? year, int? month) {
  if (year == null) return '';
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  if (month == null || month < 1 || month > 12) return '$year';
  return '${months[month - 1]} $year';
}
