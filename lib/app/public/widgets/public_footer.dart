import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Public Website footer: sectioned navigation links and the entity statement.
///
/// Pure presentation, token-driven (AGENT.md Rule 5). Links navigate via
/// [GoRouter]; the footer is safe to render on any public route.
class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Material(
      color: colors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.lg,
              vertical: HivorrSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FooterColumn(
                  title: 'Company',
                  links: const <_FooterLink>[
                    _FooterLink('Home', RoutePaths.welcome),
                    _FooterLink('About', RoutePaths.about),
                    _FooterLink('Contact', RoutePaths.contact),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.lg),
                _FooterColumn(
                  title: 'Platform',
                  links: const <_FooterLink>[
                    _FooterLink('How it works', RoutePaths.howItWorks),
                    _FooterLink('Features', RoutePaths.features),
                    _FooterLink('Security', RoutePaths.security),
                    _FooterLink('Help', RoutePaths.help),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.lg),
                _FooterColumn(
                  title: 'Get started',
                  links: const <_FooterLink>[
                    _FooterLink('Create account', RoutePaths.signup),
                    _FooterLink('Sign in', RoutePaths.login),
                    _FooterLink('Forgot password', RoutePaths.forgotPassword),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.xl),
                const _FooterDivider(),
                const SizedBox(height: HivorrSpacing.md),
                Text(
                  'Hivorr — an operating system for modern human existence.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  '© Hivorr · AfriNova Digital Limited',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLink> links;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        for (final _FooterLink link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
            child: TextButton(
              onPressed: () => context.go(link.path),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(link.label, style: context.textTheme.bodyMedium),
              ),
            ),
          ),
      ],
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.path);

  final String label;
  final String path;
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(height: 1, color: colors.outlineVariant);
  }
}
