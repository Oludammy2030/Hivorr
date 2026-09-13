import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// A public Page nav destination (public navigation §5 of the correction plan).
enum PublicNavItem {
  home('Home', RoutePaths.welcome, RouteNames.welcome),
  howItWorks('How it works', RoutePaths.howItWorks, RouteNames.howItWorks),
  features('Features', RoutePaths.features, RouteNames.features),
  pricing('Pricing', RoutePaths.pricing, RouteNames.pricing),
  security('Security', RoutePaths.security, RouteNames.security),
  contact('Contact', RoutePaths.contact, RouteNames.contact),
  help('Help', RoutePaths.help, RouteNames.help);

  const PublicNavItem(this.label, this.path, this.name);

  final String label;
  final String path;
  final String name;
}

/// Public Website top bar: brand lockup, site navigation, and auth CTAs.
///
/// Pure presentation, token-driven (AGENT.md Rule 5). Links collapse behind a
/// menu below the tablet breakpoint; `Sign in` and `Get started` always remain
/// visible. Navigates via [GoRouter] (goNamed) and is safe to render on any
/// public route.
class PublicNavBar extends StatelessWidget {
  const PublicNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool isDesktop =
        context.breakpoint == Breakpoint.desktop ||
        context.breakpoint == Breakpoint.tablet;

    return Material(
      color: colors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.lg,
              vertical: HivorrSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: () => context.go(RoutePaths.welcome),
                  borderRadius: BorderRadius.circular(8),
                  child: const LogoHorizontal(height: 32),
                ),
                const Spacer(),
                if (isDesktop) ...<Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final PublicNavItem item in PublicNavItem.values)
                            if (item != PublicNavItem.home)
                              TextButton(
                                onPressed: () => context.goNamed(item.name),
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.onSurfaceVariant,
                                ),
                                child: Text(
                                  item.label,
                                  style: context.textTheme.labelLarge,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.sm),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.login),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                    ),
                    child: Text(
                      'Sign in',
                      style: context.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.xs),
                  HivorrButton(
                    label: 'Get started',
                    size: HivorrButtonSize.small,
                    onPressed: () => context.go(RoutePaths.signup),
                  ),
                ] else ...<Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          TextButton(
                            onPressed: () => context.go(RoutePaths.login),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.primary,
                            ),
                            child: Text(
                              'Sign in',
                              style: context.textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(width: HivorrSpacing.xs),
                          HivorrButton(
                            label: 'Get started',
                            size: HivorrButtonSize.small,
                            onPressed: () => context.go(RoutePaths.signup),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.xs),
                  _NavMenu(onSelected: (PublicNavItem item) {
                    context.goNamed(item.name);
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overflow menu for the mobile public nav (all destinations + sign out link).
class _NavMenu extends StatelessWidget {
  const _NavMenu({required this.onSelected});

  final ValueChanged<PublicNavItem> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return PopupMenuButton<PublicNavItem>(
      icon: Icon(Icons.menu, color: colors.onSurface),
      tooltip: 'Menu',
      color: colors.surface,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<PublicNavItem>>[
        for (final PublicNavItem item in PublicNavItem.values)
          PopupMenuItem<PublicNavItem>(
            value: item,
            child: Text(item.label, style: context.textTheme.bodyMedium),
          ),
      ],
    );
  }
}