import 'package:flutter/material.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:intl/intl.dart';

/// A vertical step indicating the current verification stage (EP-02-10 §5.6).
enum VerificationTimelineStep { submitted, pending, inReview, decided }

/// Reusable vertical timeline for the identity-verification lifecycle
/// (EP-02-10 §10).
///
/// Renders Submitted → Pending → In Review → Decided with dot colors sourced
/// exclusively from [ColorScheme] (active = primary, pending = outline,
/// decided = successContainer for approved / error for rejected). Dates use
/// `onSurfaceVariant` captions; connectors use `outline`. No hardcoded colors.
class VerificationTimeline extends StatelessWidget {
  const VerificationTimeline({
    super.key,
    required this.status,
    this.submittedAt,
    this.reviewedAt,
    this.decisionNotes,
  });

  /// The current verification status driving the active step.
  final VerificationStatusKind status;

  /// When the submission was queued (step 1 caption).
  final DateTime? submittedAt;

  /// When the submission was decided (final step caption).
  final DateTime? reviewedAt;

  /// Admin decision notes for `rejected` / `requires_resubmission`.
  final String? decisionNotes;

  /// Maps a status to its step index in the 4-step progression.
  static int stepIndexFor(VerificationStatusKind status) =>
      switch (status) {
        VerificationStatusKind.pending => 1,
        VerificationStatusKind.inReview => 2,
        VerificationStatusKind.approved ||
        VerificationStatusKind.rejected ||
        VerificationStatusKind.requiresResubmission => 3,
      };

  @override
  Widget build(BuildContext context) {
    final int activeIndex = stepIndexFor(status);
    return Column(
      children: <Widget>[
        _StepTile(
          step: VerificationTimelineStep.submitted,
          activeIndex: activeIndex,
          status: status,
          title: 'Submitted',
          caption: submittedAt == null
              ? null
              : DateFormat('MMM d, yyyy · h:mm a').format(submittedAt!),
        ),
        const _Connector(),
        _StepTile(
          step: VerificationTimelineStep.pending,
          activeIndex: activeIndex,
          status: status,
          title: 'Pending review',
        ),
        const _Connector(),
        _StepTile(
          step: VerificationTimelineStep.inReview,
          activeIndex: activeIndex,
          status: status,
          title: 'In review',
        ),
        const _Connector(),
        _StepTile(
          step: VerificationTimelineStep.decided,
          activeIndex: activeIndex,
          status: status,
          title: _decidedTitle(status),
          caption: reviewedAt == null
              ? null
              : DateFormat('MMM d, yyyy · h:mm a').format(reviewedAt!),
        ),
        if (needsNotes && decisionNotes != null && decisionNotes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: HivorrSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                decisionNotes!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool get needsNotes =>
      status == VerificationStatusKind.rejected ||
      status == VerificationStatusKind.requiresResubmission;

  static String _decidedTitle(VerificationStatusKind status) =>
      switch (status) {
        VerificationStatusKind.approved => 'Approved',
        VerificationStatusKind.rejected => 'Rejected',
        VerificationStatusKind.requiresResubmission =>
          'Requires resubmission',
        _ => 'Decision',
      };
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 11),
      width: 2,
      height: HivorrSpacing.lg,
      color: context.colorScheme.outline,
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.activeIndex,
    required this.status,
    required this.title,
    this.caption,
  });

  final VerificationTimelineStep step;
  final int activeIndex;
  final VerificationStatusKind status;
  final String title;
  final String? caption;

  int get index => switch (step) {
        VerificationTimelineStep.submitted => 0,
        VerificationTimelineStep.pending => 1,
        VerificationTimelineStep.inReview => 2,
        VerificationTimelineStep.decided => 3,
      };

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool completed = index <= activeIndex;
    final bool isCurrent = index == activeIndex;

    return Semantics(
      label: title,
      selected: isCurrent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _Dot(
              color: _dotColor(colors, ext),
              filled: completed,
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: completed
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                      fontWeight: isCurrent ? FontWeight.w600 : null,
                    ),
                  ),
                  if (caption != null && caption!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      caption!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(ColorScheme colors, AppThemeExtension ext) {
    if (status == VerificationStatusKind.rejected ||
        status == VerificationStatusKind.requiresResubmission) {
      return colors.error;
    }
    if (status == VerificationStatusKind.approved && index == 3) {
      return ext.successContainer;
    }
    return colors.primary;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
      child: filled
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.onPrimary,
                ),
              ),
            )
          : null,
    );
  }
}
