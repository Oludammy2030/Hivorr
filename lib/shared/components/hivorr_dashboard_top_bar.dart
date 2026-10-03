import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Standard dashboard top bar (VISUAL-IDENTITY.md §13a): menu tile, chrome
/// title, notification bell with attention dot, role mode pill, and account
/// avatar — replacing the copy-pasted per-screen bars.
///
/// Tiles render a 44dp visual inside a 48dp hit area (§25a); the avatar is a
/// 40dp visual inside a 48dp hit area. Vertical bar padding is `smMd`
/// (12dp): the legacy 14dp literal is retired.
class HivorrDashboardTopBar extends StatelessWidget {
  const HivorrDashboardTopBar({
    super.key,
    required this.title,
    required this.accentPrimary,
    required this.accentContainer,
    required this.modeLabel,
    required this.initials,
    this.showDot = false,
    this.onMenu,
    this.onNotifications,
    this.onAvatar,
    this.avatarTooltip = 'Profile',
  });

  /// Chrome title (e.g. `Dashboard`, `Find Work`).
  final String title;

  /// Role accent for the mode pill dot + label.
  final Color accentPrimary;

  /// Role tint for the mode pill background.
  final Color accentContainer;

  /// Mode pill text (e.g. capability label).
  final String modeLabel;

  /// Account avatar initials.
  final String initials;

  /// Attention dot on the notification bell.
  final bool showDot;

  final VoidCallback? onMenu;
  final VoidCallback? onNotifications;
  final VoidCallback? onAvatar;

  /// Avatar tooltip. Defaults to `Profile`.
  final String avatarTooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.lg,
        vertical: HivorrSpacing.smMd,
      ),
      child: Row(
        children: <Widget>[
          if (onMenu != null) ...<Widget>[
            HivorrTopBarTile(
              tooltip: 'Menu',
              icon: Icons.menu,
              onTap: onMenu!,
            ),
            const SizedBox(width: HivorrSpacing.md),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onNotifications != null) ...<Widget>[
            HivorrTopBarTile(
              tooltip: 'Notifications',
              icon: Icons.notifications_outlined,
              showDot: showDot,
              onTap: onNotifications!,
            ),
            const SizedBox(width: HivorrSpacing.sm),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.smMd,
              vertical: HivorrSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: accentContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: HivorrSpacing.sm,
                  height: HivorrSpacing.sm,
                  decoration: BoxDecoration(
                    color: accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.xs),
                Text(
                  modeLabel,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Tooltip(
            message: avatarTooltip,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: InkWell(
                  onTap: onAvatar,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentContainer,
                      border: Border.all(color: accentPrimary, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square chrome tile: 44dp visual inside a 48dp hit area (§25a), with an
/// optional attention dot. Shared by dashboard top bars (menu, bell) and any
/// other chrome surface that needs the same tile.
class HivorrTopBarTile extends StatelessWidget {
  const HivorrTopBarTile({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Material(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(ext.radiusXs),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ext.radiusXs),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Icon(icon, size: 22, color: colors.onSurfaceVariant),
                    if (showDot)
                      Positioned(
                        top: HivorrSpacing.sm,
                        right: HivorrSpacing.sm,
                        child: Container(
                          width: HivorrSpacing.sm,
                          height: HivorrSpacing.sm,
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surfaceContainerHighest,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
