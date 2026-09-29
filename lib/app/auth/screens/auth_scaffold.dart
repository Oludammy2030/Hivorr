import 'package:flutter/material.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';

/// Shared chrome for the auth screens (login, register, password recovery).
///
/// Mobile/narrow: the established centered pane (VISUAL-IDENTITY.md §7) with
/// the stacked brand lockup, a title/subtitle block and the caller's form.
/// Wide (≥900dp): a high-class split — a gradient brand panel (lockup,
/// headline, trust highlights) beside a centered form pane capped at 480dp.
///
/// Pure presentation and token-driven (AGENT.md Rule 5). The [title],
/// [subtitle] and [child] API is unchanged, so all auth screens work without
/// modification; pass [highlights] to tailor the brand panel per screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.highlights = const <AuthHighlight>[
      AuthHighlight(
        icon: Icons.verified_user_outlined,
        text: 'Verified identities on every engagement.',
      ),
      AuthHighlight(
        icon: Icons.lock_outline,
        text: 'Escrow-protected payments throughout.',
      ),
      AuthHighlight(
        icon: Icons.workspaces_outline,
        text: 'One account for hiring, work and commerce.',
      ),
    ],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<AuthHighlight> highlights;

  /// Width (dp) at or above which the split brand panel applies. Above the
  /// default widget-test viewport (800) so existing behavior is preserved
  /// under test and the split appears on real desktop/web widths.
  static const double wideStart = 900;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            if (c.maxWidth >= wideStart) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _BrandPanel(title: title, highlights: highlights),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(HivorrSpacing.xl),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: _FormPane(
                            title: title,
                            subtitle: subtitle,
                            centered: false,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(HivorrSpacing.lg),
                child: HivorrContentPane(
                  child: _FormPane(
                    title: title,
                    subtitle: subtitle,
                    centered: true,
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Gradient brand panel for wide auth layouts.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.title, required this.highlights});

  final String title;
  final List<AuthHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.roleTheme.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(HivorrSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const LogoMonochrome(height: 40),
          const SizedBox(height: HivorrSpacing.xl),
          Text(
            'Run your whole life on one operating system.',
            style: context.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          for (final AuthHighlight highlight in highlights) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(highlight.icon, color: Colors.white, size: 22),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: Text(
                    highlight.text,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Title/subtitle block plus the caller's form content.
class _FormPane extends StatelessWidget {
  const _FormPane({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.centered,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (centered) ...<Widget>[
          const Center(child: LogoStacked(height: 88)),
          const SizedBox(height: HivorrSpacing.md),
        ],
        Text(
          title,
          style: context.textTheme.headlineMedium?.copyWith(
            color: colors.onSurface,
          ),
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          subtitle,
          style: context.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: HivorrSpacing.xl),
        child,
      ],
    );
  }
}

/// Single trust/capability bullet for the wide brand panel.
class AuthHighlight {
  const AuthHighlight({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

/// Inline error text used under auth forms; surfaces the safe [message]
/// carried by [ApiException] without leaking raw payloads.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Text(
      message,
      style: context.textTheme.bodySmall?.copyWith(color: colors.error),
      textAlign: TextAlign.center,
    );
  }
}
