import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';

/// Summary metric card for dashboard overviews (EP-04-03).
///
/// Tappable stat tile built on [HivorrCard] (mirrors the admin `_StatCard`
/// without duplicating it).
class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
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
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            value,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              subtitle!,
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

/// Job row card used across hiring/discovery lists (EP-04-03).
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.onTap});

  final Job job;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  job.title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HiringStatusBadge(code: job.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            job.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (job.budgetMin != null || job.budgetMax != null)
                _Meta(icon: Icons.payments_outlined, text: _budgetLabel(job)),
              if (job.location != null && job.location!.isNotEmpty)
                _Meta(icon: Icons.place_outlined, text: job.location!),
              _Meta(
                icon: Icons.group_outlined,
                text: '${job.applicationsCount} applications',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _budgetLabel(Job job) {
    final String code = job.currencyCode;
    String compact(double v) => HivorrFormatters.number(v, decimals: 0);
    if (job.budgetMin != null && job.budgetMax != null) {
      return '$code ${compact(job.budgetMin!)} – ${compact(job.budgetMax!)}';
    }
    final double? single = job.budgetMax ?? job.budgetMin;
    if (single != null) {
      return '$code ${compact(single)}';
    }
    return code;
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
