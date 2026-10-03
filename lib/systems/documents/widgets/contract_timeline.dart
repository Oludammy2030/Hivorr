import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/contract_event.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';

/// Vertical audit timeline for a service contract (EP-03-10 §8 D10).
///
/// Renders `contract_events[]` in `created_at` order verbatim (server order;
/// the client never re-sorts). Pure display widget: dot + event label +
/// formatted timestamp per row. Every color/token resolves from the theme —
/// no hardcoded colors.
class ContractTimeline extends StatelessWidget {
  const ContractTimeline({super.key, required this.events});

  /// Audit events in server (`created_at`) order.
  final List<ContractEvent> events;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ext.radiusMd),
          border: Border.all(color: colors.outline),
        ),
        child: Text(
          'No activity yet.',
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Activity', style: context.textTheme.titleSmall),
          const SizedBox(height: 12),
          for (int i = 0; i < events.length; i++)
            _TimelineRow(
              event: events[i],
              isLast: i == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final ContractEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAdverse ? colors.error : colors.primary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: colors.outline),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _label,
                    style: context.textTheme.bodyMedium,
                  ),
                  if (event.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      HivorrFormatters.dateTime(event.createdAt!),
                      style: context.textTheme.labelSmall?.copyWith(
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

  bool get _isAdverse =>
      event.eventType == 'cancelled' || event.eventType == 'disputed';

  String get _label {
    switch (event.eventType) {
      case 'offered':
        return 'Offer sent';
      case 'accepted':
        return 'Offer accepted';
      case 'cancelled':
        return 'Contract cancelled';
      case 'milestone_completed':
        return 'Milestone completed';
      case 'milestone_verified':
        return 'Milestone verified';
      case 'revision_requested':
        return 'Revision requested';
      case 'closed':
        return 'Contract closed';
      case 'disputed':
        return 'Dispute filed';
      default:
        return event.eventType;
    }
  }
}
