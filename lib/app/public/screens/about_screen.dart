import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_feature_card.dart';
import 'package:hivorr/shared/components/hivorr_stat_band.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/about` page — mission, vision and the Universal Entity principle.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _AboutHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'OUR MISSION',
            title: 'One operating system for modern human existence',
            body:
                'Hivorr is a universal business and daily lifestyle '
                'infrastructure — not a single app competing in a single '
                'category. It brings professional services, local commerce and '
                'logistics together under one verified identity, so people '
                'operate their professional and personal lives without '
                'app-switching.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          const HivorrStatBand(
            items: <HivorrStatItem>[
              HivorrStatItem(
                value: '1',
                label: 'verified identity',
                icon: Icons.badge_outlined,
              ),
              HivorrStatItem(
                value: '3+',
                label: 'roles per account',
                icon: Icons.workspaces_outline,
              ),
              HivorrStatItem(
                value: '100%',
                label: 'escrow-protected payments',
                icon: Icons.lock_outline,
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xl),
          const PublicSection(
            title: 'The Universal Entity Principle',
            body:
                'Every account is a single, fluid operational node. The same '
                'verified identity can be a professional, a client, a merchant '
                'and a logistics participant — and the platform compounds as '
                'people operate in more roles. Your reputation, trade record '
                'and trust travel with you across every role.',
          ),
          const SizedBox(height: HivorrSpacing.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final bool isWide = c.maxWidth >= 720;
              final double cardWidth = isWide
                  ? (c.maxWidth - HivorrSpacing.md) / 2
                  : c.maxWidth;
              return Wrap(
                spacing: HivorrSpacing.md,
                runSpacing: HivorrSpacing.md,
                children: <Widget>[
                  SizedBox(
                    width: cardWidth,
                    child: HivorrFeatureCard(
                      icon: Icons.verified_user_outlined,
                      iconBackground: context.colorScheme.primaryContainer,
                      iconColor: context.colorScheme.primary,
                      title: 'Trust first',
                      body:
                          'Verification, escrow and fair resolution come before '
                          'anything else.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: HivorrFeatureCard(
                      icon: Icons.auto_awesome_outlined,
                      iconBackground: context.roleTheme.bothContainer,
                      iconColor: context.roleTheme.bothPrimary,
                      title: 'AI-assisted',
                      body:
                          'An operational partner that drafts, automates and '
                          'simplifies.',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrCtaBand(
            title: 'Operate your whole life on Hivorr.',
            subtitle:
                'One identity for professional work, hiring and local commerce.',
            actions: <Widget>[
              HivorrButton(
                label: 'Create your free account',
                onPressed: () => context.go(RoutePaths.signup),
              ),
              HivorrButton(
                label: 'How it works',
                variant: HivorrButtonVariant.outline,
                onPressed: () => context.go(RoutePaths.howItWorks),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'About Hivorr',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'Built on trust, financial integrity and one fluid identity for '
          'everyone. Hivorr is an AI-assisted infrastructure for modern human '
          'existence.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
