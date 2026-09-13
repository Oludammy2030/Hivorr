import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_info_row.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/features` page — the capability map under one Universal Entity.
class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _FeaturesHeader(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PublicSection(
            eyebrow: 'CAPABILITY MAP',
            title: 'Every role, one account',
            body:
                'Features are delivered progressively from a lightweight core: '
                'trust, identity and finance first, then professional services, '
                'commerce and logistics — all sharing the same verified '
                'identity and trade record.',
          ),
          SizedBox(height: HivorrSpacing.xl),
          PublicInfoRow(
            icon: Icons.verified_user_outlined,
            title: 'Shoulder & trade verification',
            body:
                'Two-tier taxonomy (industry → profession), identity documents '
                'and trade-proof review before marketplace participation.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Escrow-protected payments',
            body:
                'Held against milestones, released on delivery, with a unified '
                'multi-currency financial profile and bound payout accounts.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.workspaces_outline,
            title: 'Professional services',
            body:
                'Hire trusted professionals or offer your own work — bidding '
                'unlocks once your trade proof is approved.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.storefront_outlined,
            title: 'Local commerce',
            body:
                'Buy and sell locally with the same identity and payments rail.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.local_shipping_outlined,
            title: 'Logistics & delivery',
            body:
                'Movement of goods inside the same account, dispatched through '
                'the network.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.auto_awesome_outlined,
            title: 'AI-assisted operations',
            body:
                'Drafts proposals and documents, automates repetitive work and '
                'translates intent into actions — never overriding the core '
                'rules.',
          ),
          SizedBox(height: HivorrSpacing.lg),
          PublicInfoRow(
            icon: Icons.gavel_outlined,
            title: 'Fair resolution',
            body:
                'Structured, evidence-based dispute resolution keeps every '
                'engagement accountable.',
          ),
        ],
      ),
    );
  }
}

class _FeaturesHeader extends StatelessWidget {
  const _FeaturesHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Features',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'An operating system for modern human existence — every capability '
          'shares one identity, one wallet and one trade record.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.lg),
        HivorrButton(
          label: 'Create your free account',
          onPressed: () => context.go(RoutePaths.signup),
        ),
      ],
    );
  }
}