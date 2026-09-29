import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';

/// Application row card (EP-04-03).
///
/// Shows the applicant-neutral summary for owners (quote, duration, status)
/// and the job context for applicants. Never exposes the cover note on the
/// card — it belongs to the detail screen.
class ApplicationCard extends StatelessWidget {
  const ApplicationCard({super.key, required this.application, this.onTap});

  final JobApplication application;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  application.jobTitle ?? 'Application',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HiringStatusBadge(code: application.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (application.quotedAmount != null)
                _Meta(
                  icon: Icons.payments_outlined,
                  text:
                      '${application.currencyCode} '
                      '${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}',
                ),
              if (application.durationDays != null)
                _Meta(
                  icon: Icons.schedule_outlined,
                  text: '${application.durationDays} days',
                ),
              _Meta(
                icon: Icons.access_time_outlined,
                text: HivorrFormatters.relative(application.submittedAt),
              ),
            ],
          ),
          if (application.jobStatus != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              'Job ${application.jobStatus}',
              style: context.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hire row card (EP-04-03).
///
/// Shows the job title, live (contract-derived) status, and parties-agnostic
/// meta. Tapping opens the hire detail.
class HireCard extends StatelessWidget {
  const HireCard({super.key, required this.hire, this.onTap});

  final Hire hire;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hire.jobTitle ?? 'Hire',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HiringStatusBadge(code: hire.liveStatus),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          _Meta(
            icon: Icons.access_time_outlined,
            text: 'Hired ${HivorrFormatters.relative(hire.hiredAt)}',
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: context.textTheme.labelSmall),
      ],
    );
  }
}
