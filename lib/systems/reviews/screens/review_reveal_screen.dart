import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/reviews/widgets/double_blind_status_card.dart';
import 'package:hivorr/systems/reviews/widgets/review_list_tile.dart';
import 'package:provider/provider.dart';

/// Review reveal screen at `/contracts/:id/reviews` (EP-03-12).
///
/// Loads `ServiceReviewProvider.loadMyStatus` (which lazy-triggers the
/// server reveal on expiry) and renders the [DoubleBlindStatusCard] plus the
/// `revealed_reviews[]` list. Pre-reveal shows the status card with a waiting
/// empty state; post-reveal lists both reviews. Pull-to-refresh re-calls
/// `get_mine`. Only [AppTheme] tokens are used (`AGENT.md` Rule 5).
class ReviewRevealScreen extends StatefulWidget {
  const ReviewRevealScreen({super.key, required this.contractId});

  /// The `service_contracts.id` from the route (`:id`) — authoritative.
  final String contractId;

  @override
  State<ReviewRevealScreen> createState() => _ReviewRevealScreenState();
}

class _ReviewRevealScreenState extends State<ReviewRevealScreen> {
  bool _initialized = false;
  int _lastRevealedCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.contractId.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    ServiceReviewProvider? provider;
    try {
      provider = context.read<ServiceReviewProvider>();
    } on Object {
      provider = null;
    }
    if (provider == null) return;
    final MyReviewStatus? status = await provider.loadMyStatus(
      widget.contractId.trim(),
      refresh: true,
    );
    if (!mounted || status == null) return;
    if (_lastRevealedCount == 0 && status.revealedReviews.length >= 2) {
      unawaited(_notifyRevealed(widget.contractId.trim()));
    }
    _lastRevealedCount = status.revealedReviews.length;
  }

  Future<void> _notifyRevealed(String contractId) async {
    NotificationProvider? notifications;
    try {
      notifications = context.read<NotificationProvider?>();
    } on Object {
      notifications = null;
    }
    if (notifications == null) return;
    await notifications.showLocal(
      HivorrNotification(
        id: 'review:$contractId:revealed'.hashCode & 0x7fffffff,
        title: 'Reviews revealed',
        body: 'Both parties submitted — tap to view the reviews.',
        channelId: 'hivorr_default',
        priority: NotificationPriority.normal,
        timestamp: DateTime.now(),
        actionRoute: RoutePaths.contractReviewsFor(contractId),
        payload: <String, dynamic>{
          'contractId': contractId,
          'eventType': 'review_revealed',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.contractId.trim().isEmpty) {
      return HivorrScreenScaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.contracts),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text('Reviews', style: context.textTheme.titleLarge),
        ),
        body: HivorrEmptyState(
          title: 'Review context not found',
          subtitle:
              'This contract may not exist or you may not be a participant.',
          actionButton: HivorrButton(
            label: 'Back to contracts',
            onPressed: () => context.go(RoutePaths.contracts),
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
        title: Text('Reviews', style: context.textTheme.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: HivorrContentPane(
            child: Consumer<ServiceReviewProvider>(
              builder:
                  (
                    BuildContext context,
                    ServiceReviewProvider provider,
                    _,
                  ) {
                    final MyReviewStatus? status = provider.myStatusFor(
                      widget.contractId.trim(),
                    );
                    final ApiException? error = provider.lastError;
                    if (provider.isLoading && status == null) {
                      return const HivorrLoadingState(
                        message: 'Loading reviews…',
                      );
                    }
                    if (status == null) {
                      if (error != null &&
                          (error.code == 'PLT004' ||
                              error.kind == ApiExceptionKind.notFound)) {
                        return HivorrEmptyState(
                          title: 'Review context not found',
                          subtitle:
                              'This contract may not exist or you may not be a participant.',
                          actionButton: HivorrButton(
                            label: 'Back to contracts',
                            onPressed: () => context.go(RoutePaths.contracts),
                          ),
                        );
                      }
                      return HivorrErrorState(
                        message: 'Could not load reviews',
                        detail: error?.message,
                        onRetry: _load,
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () => provider.refreshMyStatus(
                        widget.contractId.trim(),
                      ),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            DoubleBlindStatusCard(
                              status: status,
                              onWriteReview: status.youHaveSubmitted
                                  ? null
                                  : () => context.push(
                                      RoutePaths.contractReviewFor(
                                        widget.contractId.trim(),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: HivorrSpacing.md),
                            if (status.revealedReviews.isEmpty)
                              HivorrEmptyState(
                                compact: true,
                                title: status.youHaveSubmitted
                                    ? 'Waiting for the other party'
                                    : 'Others hidden until reveal',
                                subtitle:
                                    'Reviews appear here once both parties submit or the 14-day window ends.',
                              )
                            else ...<Widget>[
                              for (final ServiceReview review
                                  in status.revealedReviews) ...<Widget>[
                                ReviewListTile(review: review),
                                const SizedBox(height: HivorrSpacing.sm),
                              ],
                            ],
                            const SizedBox(height: HivorrSpacing.lg),
                          ],
                        ),
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
