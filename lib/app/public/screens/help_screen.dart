import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/components/hivorr_faq_item.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/help` hub — routes visitors to the right next step without
/// pretending listed support exists yet.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return PublicPageScaffold(
      header: const _HelpHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'SELF-SERVE FIRST',
            title: 'Answers, then a human path',
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const HivorrFaqItem(
            question: 'Getting started',
            answer:
                'Create an account, complete your Basic Information and '
                'pick your focus — hire, or offer your services.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          TextButton(
            onPressed: () => context.go(RoutePaths.howItWorks),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text('How it works', style: context.textTheme.labelLarge),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const HivorrFaqItem(
            question: 'Account & verification',
            answer:
                'One verified identity. Sign in, reset your password, and '
                'manage verification from your account.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: () => context.go(RoutePaths.login),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
                child: Text('Sign in', style: context.textTheme.labelLarge),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.forgotPassword),
                style: TextButton.styleFrom(foregroundColor: colors.primary),
                child: Text(
                  'Forgot password',
                  style: context.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const HivorrFaqItem(
            question: 'Trust & safety',
            answer:
                'Escrow-protected payments, verification gates and evidence-'
                'based dispute resolution.',
          ),
          const SizedBox(height: HivorrSpacing.sm),
          TextButton(
            onPressed: () => context.go(RoutePaths.security),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text(
              'Security & trust',
              style: context.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const HivorrFaqItem(
            question: 'Still stuck?',
            answer:
                'If you can’t find an answer here, our in-app support guides '
                'you to the right place once you’re signed in.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrCtaBand(
            title: 'Get the full help ecosystem in-app.',
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

class _HelpHeader extends StatelessWidget {
  const _HelpHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Help center',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'Everything you need to get operating on Hivorr.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
