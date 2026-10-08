import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';

/// Vertical audit timeline for an appointment (EP-03-14 §8 D10).
///
/// Renders `appointment_events[]` in `created_at` order verbatim (server
/// order; the client never re-sorts). Pure display widget: dot + event label
/// + formatted timestamp per row. Every color/token resolves from the theme —
/// no hardcoded colors.
class AppointmentTimeline extends StatelessWidget {
  const AppointmentTimeline({super.key, required this.events});

  /// Audit events in server (`created_at`) order.
  final List<AppointmentEvent> events;

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

  final AppointmentEvent event;
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
                  color: colors.primary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: colors.outline,
                  ),
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
                  if (event.createdAt != null)
                    Text(
                      HivorrFormatters.dateTime(event.createdAt!.toLocal()),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (event.eventType) {
      case 'booked':
        return 'Appointment booked';
      case 'confirmed':
        return 'Appointment confirmed';
      case 'rescheduled':
        return 'Appointment rescheduled';
      case 'cancelled':
        return 'Appointment cancelled';
      case 'completed':
        return 'Appointment completed';
      default:
        return event.eventType;
    }
  }
}
