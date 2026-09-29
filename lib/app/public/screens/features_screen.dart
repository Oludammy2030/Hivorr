import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_feature_card.dart';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'CAPABILITY MAP',
            title: 'Every role, one account',
            body:
                'Features are delivered progressively from a lightweight core: '
                'trust, identity and finance first, then professional services, '
                'commerce and logistics — all sharing the same verified '
                'identity and trade record.',
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const _CapabilityGrid(),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrCtaBand(
            title: 'Start with trust, grow into everything.',
            subtitle:
                'Verification and payments first — commerce and logistics join '
                'the same account as you grow.',
            actions: <Widget>[
              HivorrButton(
                label: 'Create your free account',
                onPressed: () => context.go(RoutePaths.signup),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  static const List<_Capability> _items = <_Capability>[
    _Capability(
      icon: Icons.verified_user_outlined,
      title: 'Shoulder & trade verification',
      body:
          'Two-tier taxonomy (industry → profession), identity documents '
          'and trade-proof review before marketplace participation.',
    ),
    _Capability(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Escrow-protected payments',
      body:
          'Held against milestones, released on delivery, with a unified '
          'multi-currency financial profile and bound payout accounts.',
    ),
    _Capability(
      icon: Icons.workspaces_outline,
      title: 'Professional services',
      body:
          'Hire trusted professionals or offer your own work — bidding '
          'unlocks once your trade proof is approved.',
    ),
    _Capability(
      icon: Icons.storefront_outlined,
      title: 'Local commerce',
      body: 'Buy and sell locally with the same identity and payments rail.',
    ),
    _Capability(
      icon: Icons.local_shipping_outlined,
      title: 'Logistics & delivery',
      body:
          'Movement of goods inside the same account, dispatched through '
          'the network.',
    ),
    _Capability(
      icon: Icons.auto_awesome_outlined,
      title: 'AI-assisted operations',
      body:
          'Drafts proposals and documents, automates repetitive work and '
          'translates intent into actions — never overriding the core '
          'rules.',
    ),
    _Capability(
      icon: Icons.gavel_outlined,
      title: 'Fair resolution',
      body:
          'Structured, evidence-based dispute resolution keeps every '
          'engagement accountable.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool isWide = c.maxWidth >= 720;
        final double cardWidth = isWide
            ? (c.maxWidth - HivorrSpacing.md) / 2
            : c.maxWidth;
        return Wrap(
          spacing: HivorrSpacing.md,
          runSpacing: HivorrSpacing.md,
          children: <Widget>[
            for (final _Capability item in _items)
              SizedBox(
                width: cardWidth,
                child: HivorrFeatureCard(
                  icon: item.icon,
                  title: item.title,
                  body: item.body,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Capability {
  const _Capability({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
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
