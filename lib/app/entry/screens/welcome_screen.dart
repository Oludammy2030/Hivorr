import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/entry/entry_query.dart';
import 'package:hivorr/app/public/widgets/public_nav_bar.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public Web landing experience (correction plan §4).
///
/// The unauthenticated SEO door on `/welcome`, aligned to the approved vision
/// ("operating system for modern human existence", Universal Entity) rather
/// than a marketplace pitch. Renders the hero, the Universal Entity explainer,
/// the trust strip, capability sections, a how-it-works teaser and a closing
/// CTA band wrapped in [PublicNavBar] + footer. Preserves any `?next=`
/// destination so sign-up resumes the original invite or SEO deep link. Pure
/// presentation — every token comes from [AppTheme] (AGENT.md Rule 5);
/// navigation is left to the caller.
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

/// Hero band: corrective positioning headline + the route into registration.
class _Hero extends StatelessWidget {
  const _Hero({this.next});

  final String? next;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Run your whole life on one operating system.',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'Hivorr is an AI-assisted infrastructure for modern human existence: '
          'hire and offer trusted professional services, buy and sell locally, '
          'and move goods — under one verified identity, with escrow-protected '
          'payments and a trade record that follows you.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xl),
        HivorrButton(
          label: 'Create your free account',
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          size: HivorrButtonSize.large,
          onPressed: () => context.go(_target(RoutePaths.signup, next)),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        HivorrButton(
          label: 'I already have an account — sign in',
          variant: HivorrButtonVariant.text,
          onPressed: () => context.go(_target(RoutePaths.login, next)),
        ),
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
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Trust is the foundation, not a feature',
          style: context.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Expanded(
              child: _Feature(
                icon: Icons.verified_user_outlined,
                title: 'Verified professionals',
                subtitle:
                    'ID and trade-proof verification keep every engagement '
                    'accountable.',
              ),
            ),
            SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: _Feature(
                icon: Icons.lock_outline,
                title: 'Escrow-protected payments',
                subtitle:
                    'Funds are held safely and released only when the work is '
                    'delivered.',
              ),
            ),
            Expanded(
              child: _Feature(
                icon: Icons.handshake_outlined,
                title: 'Work backed by a record',
                subtitle:
                    'Dispute resolution and a public trade history that '
                    'follows you.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Capability grid — hire, offer, and local commerce in one account.
class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Expanded(
          child: _CapabilityCard(
            icon: Icons.search_rounded,
            title: 'Find & hire',
            body:
                'Commission screened professionals with verified trade records '
                'and milestone-protected payments.',
          ),
        ),
        SizedBox(width: HivorrSpacing.md),
        Expanded(
          child: _CapabilityCard(
            icon: Icons.work_outline,
            title: 'Offer your work',
            body:
                'Get verified, win jobs and grow a portable reputation that '
                'travels with your one identity.',
          ),
        ),
        Expanded(
          child: _CapabilityCard(
            icon: Icons.storefront_outlined,
            title: 'Buy & sell locally',
            body:
                'Local commerce and delivery join the same account as your '
                'professional life.',
          ),
        ),
      ],
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _Step(
                step: 1,
                title: 'Create your account',
                body: 'One verified identity for every role you play.',
              ),
            ),
            const Expanded(
              child: _Step(
                step: 2,
                title: 'Tell us your capability',
                body: 'Hire, offer services, or both — add roles any time.',
              ),
            ),
            Expanded(
              child: _Step(
                step: 3,
                title: 'Start operating',
                body:
                    'Trusted professionals, escrow payments and a record that '
                    'follows you.',
              ),
            ),
          ],
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
    final ColorScheme colors = context.colorScheme;
    final String? next = this.next;
    final bool hasNext = next != null && next.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'One account. Every role your life needs.',
          style: context.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.lg),
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

/// Single value-prop column on the welcome landing.
class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: colors.primary, size: 28),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Capability card on the landing grid.
class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: colors.primary, size: 32),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          body,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Numbered how-it-works step.
class _Step extends StatelessWidget {
  const _Step({required this.step, required this.title, required this.body});

  final int step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '0$step',
          style: context.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          body,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
