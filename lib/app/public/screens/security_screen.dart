import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_faq_item.dart';
import 'package:hivorr/shared/components/hivorr_feature_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/security` page — the trust architecture (roadmap §II trust layer)
/// described for visitors without revealing proprietary mechanics.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _SecurityHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'TRUST ARCHITECTURE',
            title: 'Enforced at every layer',
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const _TrustGrid(),
          const SizedBox(height: HivorrSpacing.xl),
          const PublicSection(title: 'Trust questions'),
          const SizedBox(height: HivorrSpacing.md),
          const HivorrFaqItem(
            question: 'How do I know professionals are real?',
            answer:
                'Entities are classified through a two-tier taxonomy '
                '(industry → profession). Identity documents are submitted and '
                'administered before trade activities unlock — and bidding stays '
                'locked until trade proof is approved.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const HivorrFaqItem(
            question: 'What happens to my money during a job?',
            answer:
                'Funds are held securely against milestone completion and '
                'released only on delivery, protecting both buyers and sellers '
                'on every engagement. Cashout limits and bound payout accounts '
                'are tied to verification depth.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const HivorrFaqItem(
            question: 'What if something goes wrong?',
            answer:
                'Conflicts are resolved through a structured, evidence-based '
                'process rather than ad-hoc complaints.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrCtaBand(
            title: 'Operate inside a system built for trust.',
            subtitle:
                'Verification, escrow and fair resolution on every engagement.',
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

class _TrustGrid extends StatelessWidget {
  const _TrustGrid();

  static const List<_TrustItem> _items = <_TrustItem>[
    _TrustItem(
      icon: Icons.verified_user_outlined,
      title: 'Verified identity',
      body:
          'Entities are classified through a two-tier taxonomy '
          '(industry → profession). Identity documents are submitted and '
          'administered before trade activities unlock.',
    ),
    _TrustItem(
      icon: Icons.fact_check_outlined,
      title: 'Trade verification gates',
      body:
          'Professionals get dashboard access immediately, but job '
          'bidding and accepting stay locked until their trade proof is '
          'approved.',
    ),
    _TrustItem(
      icon: Icons.lock_outline,
      title: 'Escrow-backed transactions',
      body:
          'Funds are held securely against milestone completion, '
          'protecting both buyers and sellers on every engagement.',
    ),
    _TrustItem(
      icon: Icons.key_outlined,
      title: 'KYC-driven limits',
      body:
          'Cashout limits and bound payout accounts are tied to '
          'verification depth, containing financial risk proportionally.',
    ),
    _TrustItem(
      icon: Icons.gavel_outlined,
      title: 'Evidence-based disputes',
      body:
          'Conflicts are resolved through a structured, evidence-based '
          'process rather than ad-hoc complaints.',
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
            for (final _TrustItem item in _items)
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

class _TrustItem {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Security & trust',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'Trust is Hivorr’s foundational competitive advantage — enforced at '
          'every layer from verification to escrow and fair resolution.',
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
