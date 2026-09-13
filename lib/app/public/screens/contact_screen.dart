import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_info_row.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/contact` page — honest help routes. No invented addresses or
/// phone numbers; support is reached through the in-app Help center
/// (correction plan §15/Q4).
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return PublicPageScaffold(
      header: const _ContactHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PublicInfoRow(
            icon: Icons.help_outline,
            title: 'Help center',
            body:
                'Find answers about account, verification, payments and more.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: () => context.go(RoutePaths.help),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text('Open the Help center', style: context.textTheme.labelLarge),
          ),
          const SizedBox(height: HivorrSpacing.xl),
          PublicInfoRow(
            icon: Icons.shield_outlined,
            title: 'Security & trust',
            body: 'How Hivorr protects every engagement, start to finish.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: () => context.go(RoutePaths.security),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text('See our trust model', style: context.textTheme.labelLarge),
          ),
          const SizedBox(height: HivorrSpacing.xl),
          PublicInfoRow(
            icon: Icons.person_add_alt_outlined,
            title: 'Talk to us as a professional',
            body:
                'Support from the Hivorr help ecosystem is available in-app '
                'once your account is created.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Create your free account',
            onPressed: () => context.go(RoutePaths.signup),
          ),
        ],
      ),
    );
  }
}

class _ContactHeader extends StatelessWidget {
  const _ContactHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Contact',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'We’re building Hivorr in public and we want to hear from you. '
          'Reach the team through the channels below.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}