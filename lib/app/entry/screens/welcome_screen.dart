import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/public/widgets/public_nav_bar.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_feature_card.dart';
import 'package:hivorr/shared/components/hivorr_hero_panel.dart';
import 'package:hivorr/shared/components/hivorr_step_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public Web landing experience (correction plan §4).
///
/// The unauthenticated SEO door on `/welcome`, aligned to the approved vision
/// ("operating system for modern human existence", Universal Entity) rather
/// than a marketplace pitch. Gradient hero, trust strip, capability sections,
/// a how-it-works teaser and a closing CTA band wrapped in [PublicNavBar] +
/// footer. Preserves any `?next=` destination so sign-up resumes the original
/// invite or SEO deep link. Pure presentation — every token comes from
/// [AppTheme] (AGENT.md Rule 5); navigation is left to the caller.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? next = EntryQuery.nextFrom(GoRouterState.of(context));

    return PublicPageScaffold(
      header: _Hero(next: next),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'ONE ACCOUNT, EVERY ROLE',
            title: 'Work, sell, serve and live — without app-switching',
            body:
                'Every Hivorr account is built on the Universal Entity: one '
                'verified identity that fluidly shifts between being a '
                'professional, a client, a merchant and a logistics '
                'participant. The platform compounds as you operate in more '
                'roles.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          const _TrustStrip(),
          const SizedBox(height: HivorrSpacing.xl),
          const PublicSection(
            eyebrow: 'WHAT YOU CAN DO',
            title: 'Built for the way modern life actually runs',
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const _CapabilityGrid(),
          const SizedBox(height: HivorrSpacing.xl),
          const _HowItWorks(),
          const SizedBox(height: HivorrSpacing.xl),
          _ClosingCta(next: next),
        ],
      ),
    );
  }
}

/// Hero band: gradient panel with corrective positioning headline, the route
/// into registration, and product-truth statistics.
class _Hero extends StatelessWidget {
  const _Hero({this.next});

  final String? next;

  @override
  Widget build(BuildContext context) {
    return HivorrHeroPanel(
      eyebrow: 'ONE ACCOUNT, EVERY ROLE',
      title: 'Run your whole life on one operating system.',
      subtitle:
          'Hivorr is an AI-assisted infrastructure for modern human existence: '
          'hire and offer trusted professional services, buy and sell locally, '
          'and move goods — under one verified identity, with escrow-protected '
          'payments and a trade record that follows you.',
      primaryLabel: 'Create your free account',
      onPrimary: () => context.go(_target(RoutePaths.signup, next)),
      secondaryLabel: 'I already have an account — sign in',
      onSecondary: () => context.go(_target(RoutePaths.login, next)),
      statistics: const <HivorrHeroStat>[
        HivorrHeroStat(value: '1', label: 'verified identity'),
        HivorrHeroStat(value: '3+', label: 'ways to operate'),
        HivorrHeroStat(value: '100%', label: 'escrow-protected payments'),
      ],
    );
  }

  /// Appends the preserved `?next=` so the invite/SEO flow resumes after
  /// sign-up (entry architecture §4).
  String _target(String route, String? next) {
    if (next == null || next.isEmpty) {
      return route;
    }
    return '$route?next=$next';
  }
}

/// Trust strip — the roadmap trust layer reframed for the landing.
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Trust is the foundation, not a feature',
          style: context.textTheme.titleLarge?.copyWith(
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
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
                  child: const HivorrFeatureCard(
                    icon: Icons.verified_user_outlined,
                    title: 'Verified professionals',
                    body:
                        'ID and trade-proof verification keep every engagement '
                        'accountable.',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const HivorrFeatureCard(
                    icon: Icons.lock_outline,
                    title: 'Escrow-protected payments',
                    body:
                        'Funds are held safely and released only when the work is '
                        'delivered.',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const HivorrFeatureCard(
                    icon: Icons.handshake_outlined,
                    title: 'Work backed by a record',
                    body:
                        'Dispute resolution and a public trade history that '
                        'follows you.',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Capability grid — hire, offer, and local commerce in one account,
/// role-tinted (Client / Professional / Both).
class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    return LayoutBuilder(
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
              child: HivorrFeatureCard(
                icon: Icons.search_rounded,
                iconBackground: roles.clientContainer,
                iconColor: roles.clientPrimary,
                title: 'Find & hire',
                body:
                    'Commission screened professionals with verified trade records '
                    'and milestone-protected payments.',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: HivorrFeatureCard(
                icon: Icons.work_outline,
                iconBackground: roles.professionalContainer,
                iconColor: roles.professionalPrimary,
                title: 'Offer your work',
                body:
                    'Get verified, win jobs and grow a portable reputation that '
                    'travels with your one identity.',
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: HivorrFeatureCard(
                icon: Icons.storefront_outlined,
                iconBackground: roles.bothContainer,
                iconColor: roles.bothPrimary,
                title: 'Buy & sell locally',
                body:
                    'Local commerce and delivery join the same account as your '
                    'professional life.',
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How-it-works teaser (3 steps) linking to the full page.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'How it works',
          style: context.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool isWide = c.maxWidth >= 720;
            final double cardWidth = isWide
                ? (c.maxWidth - 2 * HivorrSpacing.md) / 3
                : c.maxWidth;
            return Wrap(
              spacing: HivorrSpacing.md,
              runSpacing: HivorrSpacing.lg,
              children: <Widget>[
                SizedBox(
                  width: cardWidth,
                  child: const HivorrStepCard(
                    step: 1,
                    title: 'Create your account',
                    body: 'One verified identity for every role you play.',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const HivorrStepCard(
                    step: 2,
                    title: 'Tell us your capability',
                    body: 'Hire, offer services, or both — add roles any time.',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const HivorrStepCard(
                    step: 3,
                    title: 'Start operating',
                    body:
                        'Trusted professionals, escrow payments and a record that '
                        'follows you.',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: HivorrSpacing.md),
        TextButton(
          onPressed: () => context.go(RoutePaths.howItWorks),
          style: TextButton.styleFrom(foregroundColor: colors.primary),
          child: Text(
            'Learn how it works',
            style: context.textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

/// Closing band driving back to registration.
class _ClosingCta extends StatelessWidget {
  const _ClosingCta({this.next});

  final String? next;

  @override
  Widget build(BuildContext context) {
    final String? next = this.next;
    final bool hasNext = next != null && next.isNotEmpty;
    return HivorrCtaBand(
      title: 'One account. Every role your life needs.',
      subtitle:
          'Create one verified identity and operate as a professional, a '
          'client and a merchant — with protected payments throughout.',
      actions: <Widget>[
        HivorrButton(
          label: 'Create your free account',
          size: HivorrButtonSize.large,
          onPressed: () => context.go(
            hasNext ? '${RoutePaths.signup}?next=$next' : RoutePaths.signup,
          ),
        ),
      ],
    );
  }
}
