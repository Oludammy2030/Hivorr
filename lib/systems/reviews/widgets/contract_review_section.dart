import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/reviews/services/service_review_service.dart';
import 'package:hivorr/systems/reviews/widgets/double_blind_status_card.dart';
import 'package:provider/provider.dart';

/// Composition-only review section for `contract_detail_screen` (EP-03-12).
///
/// Placed after `contract_timeline`, before `ContractWriteCtaPanel`.
/// Hidden entirely for non-participants (affordance only — enforcement stays
/// server-side). Loads at most one `get_mine` call per contract.
class ContractReviewSection extends StatefulWidget {
  const ContractReviewSection({
    super.key,
    required this.contract,
    required this.viewerId,
  });

  /// The authoritative contract row.
  final ServiceContract contract;

  /// The viewer `entity_id` (`''` when signed out).
  final String viewerId;

  @override
  State<ContractReviewSection> createState() => _ContractReviewSectionState();
}

class _ContractReviewSectionState extends State<ContractReviewSection> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (!_isParticipant) return;
    if (!ServiceReviewService.reviewableStatuses.contains(
      widget.contract.status,
    )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          context.read<ServiceReviewProvider?>()?.loadMyStatus(
            widget.contract.id,
          ),
        );
      } on Object {
        // Review layer not wired in this build — section stays hidden.
      }
    });
  }

  bool get _isParticipant =>
      widget.viewerId.isNotEmpty &&
      (widget.viewerId == widget.contract.clientEntityId ||
          widget.viewerId == widget.contract.professionalEntityId);

  @override
  Widget build(BuildContext context) {
    if (!_isParticipant) return const SizedBox.shrink();
    if (!ServiceReviewService.reviewableStatuses.contains(
      widget.contract.status,
    )) {
      return const SizedBox.shrink();
    }
    ServiceReviewProvider? provider;
    try {
      provider = context.watch<ServiceReviewProvider?>();
    } on Object {
      provider = null;
    }
    if (provider == null) return const SizedBox.shrink();
    final MyReviewStatus? status = provider.myStatusFor(widget.contract.id);
    if (status == null) {
      if (provider.isLoading) {
        return const SizedBox.shrink();
      }
      return const SizedBox.shrink();
    }
    final bool showCta = ServiceReviewService.canReview(
      contract: widget.contract,
      viewerEntityId: widget.viewerId,
      status: status,
    );
    if (!showCta && !status.youHaveSubmitted && status.revealedReviews.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Reviews', style: context.textTheme.titleMedium),
        const SizedBox(height: HivorrSpacing.xs),
        DoubleBlindStatusCard(
          status: status,
          compact: true,
          onWriteReview: showCta
              ? () => context.push(
                  RoutePaths.contractReviewFor(widget.contract.id),
                )
              : null,
          onViewReviews: () => context.push(
            RoutePaths.contractReviewsFor(widget.contract.id),
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
      ],
    );
  }
}
