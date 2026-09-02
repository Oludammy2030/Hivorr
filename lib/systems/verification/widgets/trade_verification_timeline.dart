import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// The step within the per-profession trade-verification progression.
enum TradeTimelineStep { unverified, submitted, pending, decided }

/// Reusable vertical timeline for a profession's trade-verification lifecycle
/// (EP-02-11 §5.6, §10): `Unverified → Submitted → Pending → Approved/Rejected`.
///
/// Dot colors are sourced exclusively from [ColorScheme]/[AppThemeExtension]
/// (active = primary, pending = outline, approved = successContainer, rejected
/// = error); connectors use `outline`. No hardcoded colors.
class TradeVerificationTimeline extends StatelessWidget {
  const TradeVerificationTimeline({
    super.key,
    required this.entry,
    this.submittedAt,
    this.reviewedAt,
    this.decisionNotes,
  });

  /// The per-profession trade verification entry.
  final TradeVerification entry;

  /// When the proof was queued (submitted caption).
  final DateTime? submittedAt;

  /// When the proof was decided (final caption).
  final DateTime? reviewedAt;

  /// Admin decision notes for a rejected proof.
  final String? decisionNotes;

  /// Maps a status kind to its active step index in the 4-step progression.
  static int stepIndexFor(TradeVerificationStatusKind kind) => switch (kind) {
        TradeVerificationStatusKind.unverified => 0,
        TradeVerificationStatusKind.pending => 2,
        TradeVerificationStatusKind.approved ||
        TradeVerificationStatusKind.rejected => 3,
      };

  @override
  Widget build(BuildContext context) {
    final int activeIndex = stepIndexFor(entry.statusKind);
    return Column(
      children: <Widget>[
        _StepTile(
          step: TradeTimelineStep.unverified,
          kind: entry.statusKind,
          activeIndex: activeIndex,
          title: 'Unverified',
        ),
        const _Connector(),
        _StepTile(
          step: TradeTimelineStep.submitted,
          kind: entry.statusKind,
          activeIndex: activeIndex,
          title: 'Submitted',
          caption: submittedAt == null ? null : _formatDate(submittedAt!),
        ),
        const _Connector(),
        _StepTile(
          step: TradeTimelineStep.pending,
          kind: entry.statusKind,
          activeIndex: activeIndex,
          title: 'Pending review',
        ),
        const _Connector(),
        _StepTile(
          step: TradeTimelineStep.decided,
          kind: entry.statusKind,
          activeIndex: activeIndex,
          title: _decidedTitle(entry.statusKind),
          caption:
              reviewedAt == null ? null : _formatDate(reviewedAt!),
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

  bool get needsNotes => entry.statusKind == TradeVerificationStatusKind.rejected;

  static String _decidedTitle(TradeVerificationStatusKind kind) =>
      switch (kind) {
        TradeVerificationStatusKind.approved => 'Approved',
        TradeVerificationStatusKind.rejected => 'Rejected',
        _ => 'Decision',
      };

  static String _formatDate(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)} · '
      '${_two(value.hour)}:${_two(value.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
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
    required this.kind,
    required this.activeIndex,
    required this.title,
    this.caption,
  });

  final TradeTimelineStep step;
  final TradeVerificationStatusKind kind;
  final int activeIndex;
  final String title;
  final String? caption;

  int get index => switch (step) {
        TradeTimelineStep.unverified => 0,
        TradeTimelineStep.submitted => 1,
        TradeTimelineStep.pending => 2,
        TradeTimelineStep.decided => 3,
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
    if (kind == TradeVerificationStatusKind.rejected) {
      return colors.error;
    }
    if (kind == TradeVerificationStatusKind.approved && index == 3) {
      return ext.successContainer;
    }
    if (index == 0) {
      return colors.outline;
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
        color: filled ? color : null,
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
