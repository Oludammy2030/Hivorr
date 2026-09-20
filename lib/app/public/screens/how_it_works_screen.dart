import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Public `/how-it-works` page — the one-account journey and trust flywheel.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return PublicPageScaffold(
      header: const _HowHeader(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const PublicSection(
            eyebrow: 'FROM FIRST LAUNCH',
            title: 'Get operating in three steps',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          for (final _Step step in _steps) ...<Widget>[
            _StepCard(step: step),
            const SizedBox(height: HivorrSpacing.lg),
          ],
          const SizedBox(height: HivorrSpacing.md),
          const PublicSection(
            title: 'The trust flywheel',
            body:
                'Every role you add deepens a single verified identity. '
                'Verified professionals earn more work; clients get screened '
                'providers and protected payments; commerce and logistics slot '
                'into the same account. Trust compounds as you operate in more '
                'dimensions — that is what makes Hivorr hard to leave.',
          ),
          const SizedBox(height: HivorrSpacing.xl),
          HivorrButton(
            label: 'Create your free account',
            size: HivorrButtonSize.large,
            onPressed: () => context.go(RoutePaths.signup),
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextButton(
            onPressed: () => context.go(RoutePaths.features),
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text(
              'See what you can do',
              style: context.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

const List<_Step> _steps = <_Step>[
  _Step(
    number: 1,
    title: 'Create your account',
    body:
        'One verified identity for every role you play. Registration captures '
        'your email and password; your account is provisioned securely, and '
        'Basic Information comes next.',
  ),
  _Step(
    number: 2,
    title: 'Complete your Basic Information',
    body:
        'Add your names, bio and avatar. Then tell us your capability — hire, '
        'offer professional services, or both. You can adopt the other side '
        'any time later.',
  ),
  _Step(
    number: 3,
    title: 'Get verified and start operating',
    body:
        'Professionals submit identity and trade proof; work and bidding unlock '
        'once approved. Clients can commission with escrow-protected payments. '
        'Then every role you add lives in the same account.',
  ),
];

class _HowHeader extends StatelessWidget {
  const _HowHeader();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'How it works',
          style: context.textTheme.displaySmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'One account, one identity, every role your life needs — powered by '
          'verification, escrow and a record that follows you.',
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '0${step.number}',
          style: context.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          step.title,
          style: context.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          step.body,
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Step {
  const _Step({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;
}
