import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_input.dart';

/// Review submission screen at `/contracts/:id/review` (EP-03-12).
///
/// Contract-scoped form: 1–5 [StarRatingInput] + optional `10-2000` comment
/// via [HivorrTextField]. Loads `ServiceContractProvider.selected` for the
/// counterparty role label + reviewable-gate hint and
/// `ServiceReviewProvider.loadMyStatus`; when `you_have_submitted` the screen
/// redirects to the reveal route (no double-submit UI).
///
/// Client validation mirrors the server CHECKs fail-fast only; enforcement
/// stays server-side (`AGENT.md` Rule 4). Only [AppTheme] tokens are used
/// (Rule 5).
class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({super.key, required this.contractId});

  /// The `service_contracts.id` from the route (`:id`) — authoritative.
  final String contractId;

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  bool _initialized = false;
  bool _submitting = false;
  bool _submitted = false;
  int _rating = 0;
  String? _ratingError;
  String? _commentError;
  ApiException? _loadError;
  final TextEditingController _commentController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.contractId.trim().isEmpty) {
      _loadError = const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Review context not found.',
        code: 'PLT004',
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadStatus());
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    ServiceReviewProvider? provider;
    try {
      provider = context.read<ServiceReviewProvider>();
    } on Object {
      provider = null;
    }
    if (provider == null) return;
    final MyReviewStatus? status = await provider.loadMyStatus(
      widget.contractId.trim(),
    );
    if (!mounted) return;
    if (status == null && provider.lastError != null) {
      setState(() => _loadError = provider!.lastError);
      return;
    }
    if (status != null && status.youHaveSubmitted && !_submitted) {
      // Already submitted — reveal route owns this state (no double-submit).
      context.go(RoutePaths.contractReviewsFor(widget.contractId.trim()));
    }
  }

  String get _viewerId {
    try {
      return context.read<AuthProvider?>()?.currentSession?.entityId ?? '';
    } on Object {
      return '';
    }
  }

  Future<void> _submit() async {
    final String contractId = widget.contractId.trim();
    setState(() {
      _ratingError = null;
      _commentError = null;
    });
    if (!ServiceReviewService.validateRating(_rating == 0 ? null : _rating)) {
      setState(() => _ratingError = 'Select a rating from 1 to 5.');
      return;
    }
    if (!ServiceReviewService.validateComment(_commentController.text)) {
      setState(
        () => _commentError = 'Comment must be between 10 and 2000 characters.',
      );
      return;
    }
    ServiceReviewProvider? provider;
    try {
      provider = context.read<ServiceReviewProvider>();
    } on Object {
      provider = null;
    }
    if (provider == null) return;
    setState(() => _submitting = true);
    try {
      final String? comment = _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim();
      await provider.submit(
        contractId: contractId,
        rating: _rating,
        comment: comment,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
      unawaited(_notifySubmitted(contractId));
      if (!mounted) return;
      context.go(RoutePaths.contractReviewsFor(contractId));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e.code == 'PLT005' &&
          e.message.toLowerCase().contains('already submitted')) {
        ScaffoldMessenger.of(context).showSnackBar(
          HivorrSnackbar.show(
            context,
            message: 'You already submitted a review for this contract.',
            variant: HivorrSnackbarVariant.info,
          ),
        );
        context.go(RoutePaths.contractReviewsFor(contractId));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    }
  }

  Future<void> _notifySubmitted(String contractId) async {
    NotificationProvider? notifications;
    try {
      notifications = context.read<NotificationProvider?>();
    } on Object {
      notifications = null;
    }
    if (notifications == null) return;
    await notifications.showLocal(
      HivorrNotification(
        id: 'review:$contractId:submitted'.hashCode & 0x7fffffff,
        title: 'Review submitted',
        body:
            'Your review stays hidden until both parties submit or the 14-day window ends.',
        channelId: 'hivorr_default',
        priority: NotificationPriority.normal,
        timestamp: DateTime.now(),
        actionRoute: RoutePaths.contractReviewsFor(contractId),
        payload: <String, dynamic>{
          'contractId': contractId,
          'eventType': 'review_submitted',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ApiException? loadError = _loadError;
    if (loadError != null) {
      return HivorrScreenScaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.contracts),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text('Review', style: context.textTheme.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: loadError.code == 'PLT004' ||
                    loadError.kind == ApiExceptionKind.notFound
                ? HivorrEmptyState(
                    title: 'Review context not found',
                    subtitle:
                        'This contract may not exist or you may not be a participant.',
                    actionButton: HivorrButton(
                      label: 'Back to contracts',
                      onPressed: () => context.go(RoutePaths.contracts),
                    ),
                  )
                : HivorrErrorState(
                    message: 'Could not load review status',
                    detail: loadError.message,
                    onRetry: () {
                      setState(() => _loadError = null);
                      unawaited(_loadStatus());
                    },
                  ),
          ),
        ),
      );
    }
    if (_submitted) {
      return HivorrScreenScaffold(
        appBar: AppBar(title: Text('Review', style: context.textTheme.titleLarge)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: HivorrSuccessState(
              title: 'Review submitted',
              subtitle:
                  'Your review stays hidden until both parties submit or the 14-day window ends.',
              actionButton: HivorrButton(
                label: 'View status',
                onPressed: () => context.go(
                  RoutePaths.contractReviewsFor(widget.contractId.trim()),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return HivorrScreenScaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(
                  RoutePaths.contractDetail(widget.contractId.trim()),
                ),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Write a review', style: context.textTheme.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: HivorrContentPane(
            child: Consumer2<ServiceContractProvider, ServiceReviewProvider>(
              builder:
                  (
                    BuildContext context,
                    ServiceContractProvider contracts,
                    ServiceReviewProvider reviews,
                    _,
                  ) {
                    if (reviews.isLoading && !_submitting) {
                      return const HivorrLoadingState(
                        message: 'Loading review status…',
                      );
                    }
                    final String? contractStatus =
                        contracts.selected?.id == widget.contractId.trim()
                        ? contracts.selected!.status
                        : null;
                    final bool notReviewable =
                        contractStatus != null &&
                        !ServiceReviewService.reviewableStatuses.contains(
                          contractStatus,
                        );
                    if (notReviewable) {
                      return HivorrErrorState(
                        message: 'Contract not in reviewable state',
                        detail:
                            'Reviews open once the contract is active, completed, or closed.',
                        onRetry: null,
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _RoleHeader(
                            viewerId: _viewerId,
                            contractId: widget.contractId.trim(),
                          ),
                          const SizedBox(height: HivorrSpacing.md),
                          HivorrCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Your rating',
                                  style: context.textTheme.titleMedium,
                                ),
                                const SizedBox(height: HivorrSpacing.xs),
                                StarRatingInput(
                                  value: _rating,
                                  enabled: !_submitting,
                                  onChanged: (int v) => setState(() {
                                    _rating = v;
                                    _ratingError = null;
                                  }),
                                ),
                                if (_ratingError != null) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    _ratingError!,
                                    style: context.textTheme.labelSmall
                                        ?.copyWith(
                                          color: context
                                              .colorScheme
                                              .error,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: HivorrSpacing.md),
                                HivorrTextField(
                                  controller: _commentController,
                                  label: 'Comment (optional)',
                                  hint:
                                      'Share what went well (optional, min 10 characters)',
                                  helperText:
                                      'Optional — 10 character minimum if provided',
                                  errorText: _commentError,
                                  minLines: 4,
                                  maxLines: 6,
                                  maxLength: 2000,
                                  enabled: !_submitting,
                                  onChanged: (_) {
                                    if (_commentError != null) {
                                      setState(() => _commentError = null);
                                    }
                                  },
                                ),
                                const SizedBox(height: HivorrSpacing.sm),
                                Text(
                                  'Your review stays hidden until both parties submit or the 14-day window ends.',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: HivorrSpacing.md),
                          HivorrButton(
                            label: 'Submit review',
                            isExpanded: true,
                            isLoading: _submitting,
                            onPressed: _submitting ? null : _submit,
                          ),
                          const SizedBox(height: HivorrSpacing.lg),
                        ],
                      ),
                    );
                  },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  const _RoleHeader({required this.viewerId, required this.contractId});

  final String viewerId;
  final String contractId;

  @override
  Widget build(BuildContext context) {
    ServiceContractProvider? contracts;
    try {
      contracts = context.watch<ServiceContractProvider?>();
    } on Object {
      contracts = null;
    }
    final contract = contracts?.selected;
    if (contract == null || contract.id != contractId) {
      return const SizedBox.shrink();
    }
    final bool isClient = viewerId == contract.clientEntityId;
    final bool isProfessional = viewerId == contract.professionalEntityId;
    final String role = isClient
        ? 'You are rating: Professional'
        : isProfessional
        ? 'You are rating: Client'
        : 'You are not a participant';
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  contract.listingTitle ?? 'Service contract',
                  style: context.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 12),
              ContractStatusBadge(status: contract.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
