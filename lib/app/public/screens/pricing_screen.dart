import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_faq_item.dart';
import 'package:hivorr/shared/components/hivorr_pricing_tier.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/pricing` page — an honest structure preview. No committed fee
/// figures exist yet; wording states fees are disclosed at transaction time
/// rather than inventing numbers (correction plan §15/Q3).
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _PricingHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'HOW HIVORR EARNS',
            title: 'Simple, transparent structure',
          ),
          const SizedBox(height: HivorrSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final bool isWide = c.maxWidth >= 720;
              final double cardWidth = isWide
                  ? (c.maxWidth - 2 * HivorrSpacing.md) / 3
                  : c.maxWidth;
              return Wrap(
                spacing: HivorrSpacing.md,
                runSpacing: HivorrSpacing.md,
                children: <Widget>[
                  SizedBox(
                    width: cardWidth,
                    child: HivorrPricingTier(
                      name: 'START',
                      price: 'Free',
                      caption: 'Always free to start',
                      features: const <String>[
                        'Creating your account is free',
                        'Basic Information is free',
                        'Getting verified is free',
                        'No subscription to register or browse',
                      ],
                      ctaLabel: 'Create your free account',
                      onCta: () => context.go(RoutePaths.signup),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: HivorrPricingTier(
                      name: 'TRANSACT',
                      price: 'Pay when value moves',
                      caption:
                          'Fees apply per transaction, disclosed up front.',
                      features: const <String>[
                        'Professional services transactions',
                        'Commerce and logistics transactions',
                        'Always disclosed before you confirm',
                        'No hidden charges',
                      ],
                      ctaLabel: 'Create your free account',
                      highlighted: true,
                      onCta: () => context.go(RoutePaths.signup),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: HivorrPricingTier(
                      name: 'PROTECTED',
                      price: 'Included',
                      caption: 'Protection comes with every transaction.',
                      features: const <String>[
                        'Funds held in escrow against milestones',
                        'Released only on delivery',
                        'Bound, verified payout accounts',
                        'Limits tied to verification depth',
                      ],
                      ctaLabel: 'See our trust model',
                      onCta: () => context.go(RoutePaths.security),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: HivorrSpacing.xl),
          const PublicSection(title: 'Pricing questions'),
          const SizedBox(height: HivorrSpacing.md),
          const HivorrFaqItem(
            question: 'Is there a subscription?',
            answer:
                'No. Registering, completing Basic Information and getting '
                'verified are free, and browsing requires no subscription.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const HivorrFaqItem(
            question: 'When do fees apply?',
            answer:
                'Fees apply to transactions on the platform — professional '
                'services, commerce and logistics — and are always disclosed '
                'clearly before you confirm.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          const HivorrFaqItem(
            question: 'How are my payments protected?',
            answer:
                'Funds are held in escrow against milestones and released only '
                'on delivery. Payouts go to bound, verified accounts, with '
                'limits tied to your verification depth.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrCtaBand(
            title: 'Start free. Pay only when value moves.',
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

class _PricingHeader extends StatelessWidget {
  const _PricingHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Pricing',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'We earn when you do. Pricing on Hivorr is transparent, '
          'transaction-based and disclosed up front.',
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
