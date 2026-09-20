import 'package:flutter/material.dart';
import 'package:hivorr/app/public/widgets/public_info_row.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Public `/about` page — mission, vision and the Universal Entity principle.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicPageScaffold(
      header: const _AboutHeader(),
      child: const Column(
        children: <Widget>[
          PublicSection(
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
          SizedBox(height: HivorrSpacing.xl),
          PublicSection(
            title: 'The Universal Entity Principle',
            body:
                'Every account is a single, fluid operational node. The same '
                'verified identity can be a professional, a client, a merchant '
                'and a logistics participant — and the platform compounds as '
                'people operate in more roles. Your reputation, trade record '
                'and trust travel with you across every role.',
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
        const SizedBox(height: HivorrSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Expanded(
              child: PublicInfoRow(
                icon: Icons.verified_user_outlined,
                title: 'Trust first',
                body:
                    'Verification, escrow and fair resolution come before '
                    'anything else.',
              ),
            ),
            SizedBox(width: HivorrSpacing.lg),
            Expanded(
              child: PublicInfoRow(
                icon: Icons.workspaces_outline,
                title: 'One identity',
                body:
                    'Professional, client, merchant — no second app, no '
                    'second identity.',
              ),
            ),
            Expanded(
              child: PublicInfoRow(
                icon: Icons.auto_awesome_outlined,
                title: 'AI-assisted',
                body:
                    'An operational partner that drafts, automates and '
                    'simplifies.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
