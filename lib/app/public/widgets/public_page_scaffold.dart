import 'package:flutter/material.dart';
import 'package:hivorr/app/public/widgets/public_footer.dart';
import 'package:hivorr/app/public/widgets/public_nav_bar.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';

/// Standard chrome for a public Website page: [PublicNavBar] on top, the page
/// body in a constrained [HivorrContentPane], and [PublicFooter] below.
///
/// Pure presentation (AGENT.md Rule 5). Spacing/colors via tokens; the body is
/// scrollable end to end so the footer lands after short pages.
class PublicPageScaffold extends StatelessWidget {
  const PublicPageScaffold({super.key, required this.child, this.header});

  /// The scrollable body content of the page.
  final Widget child;

  /// Optional hero/intro block rendered above the body (still scrolls with it).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: <Widget>[
          const PublicNavBar(),
          Expanded(
            child: ListView(
              children: <Widget>[
                if (header != null)
                  HivorrContentPane(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HivorrSpacing.lg,
                        HivorrSpacing.xl,
                        HivorrSpacing.lg,
                        HivorrSpacing.xl,
                      ),
                      child: header,
                    ),
                  ),
                HivorrContentPane(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      HivorrSpacing.lg,
                      HivorrSpacing.xl,
                      HivorrSpacing.lg,
                      HivorrSpacing.xxl,
                    ),
                    child: child,
                  ),
                ),
                const PublicFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled section on a public page: optional eyebrow label, a heading, and
/// body content. Uses the display/headline tokens so every page reads as the
/// same product (VISUAL-IDENTITY.md §9).
class PublicSection extends StatelessWidget {
  const PublicSection({
    super.key,
    required this.title,
    this.eyebrow,
    this.body,
    this.children = const <Widget>[],
  });

  final String? eyebrow;
  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow != null) ...<Widget>[
          Text(
            eyebrow!,
            style: context.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
        ],
        Text(
          title,
          style: context.textTheme.headlineMedium?.copyWith(
            color: colors.onSurface,
          ),
        ),
        if (body != null) ...<Widget>[
          const SizedBox(height: HivorrSpacing.md),
          Text(
            body!,
            style: context.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (body != null) const SizedBox(height: HivorrSpacing.lg),
        if (body == null && children.isNotEmpty)
          const SizedBox(height: HivorrSpacing.lg),
        ...children,
      ],
    );
  }
}