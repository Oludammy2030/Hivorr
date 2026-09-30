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
/// without duplicating it). Tint the icon tile via [accent]/[accentContainer]
/// — e.g. the role containers from `context.roleTheme` — so hiring metrics
/// read Client and work metrics read Professional (VISUAL-IDENTITY.md §3).
class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
    this.accent,
    this.accentContainer,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? accent;
  final Color? accentContainer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.screenWidth < 600;
    return HivorrCard(
      onTap: onTap,
      padding: compact
          ? const EdgeInsets.all(HivorrSpacing.sm + 4)
          : const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(HivorrSpacing.xs),
                decoration: BoxDecoration(
                  color: accentContainer ?? colors.primaryContainer,
                  borderRadius: BorderRadius.circular(ext.radiusSm),
                ),
                child: Icon(
                  icon,
                  size: compact ? 16 : 18,
                  color: accent ?? colors.primary,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: compact ? 11 : null,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: compact ? HivorrSpacing.xs + 2 : HivorrSpacing.sm,
          ),
          Text(
            value,
            style: (compact
                    ? context.textTheme.titleLarge
                    : context.textTheme.headlineSmall)
                ?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : null,
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
    final bool compact = context.screenWidth < 600;
    return HivorrCard(
      onTap: onTap,
      padding: compact
          ? const EdgeInsets.all(HivorrSpacing.sm + 4)
          : const EdgeInsets.all(HivorrSpacing.md),
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
                    fontSize: compact ? 13.5 : null,
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
              fontSize: compact ? 12 : null,
            ),
          ),
          SizedBox(
            height: compact ? HivorrSpacing.xs + 2 : HivorrSpacing.sm,
          ),
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
