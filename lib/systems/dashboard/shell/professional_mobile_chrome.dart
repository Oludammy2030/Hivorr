import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Shared mobile chrome for the Professional Dashboard (<600dp).
///
/// Why a separate component instead of reusing [ClientMobileAppBar]:
/// the client bar hardcodes the client identity (`clientContainer` /
/// `clientPrimary`, the `Client` pill, the hire-label fallback) and the
/// hamburger drawer. Parameterizing it would risk the client reference
/// (asserted pixel-identical by `client_mobile_app_bar_test.dart`). This
/// bar mirrors its metrics exactly — 48dp toolbar, 20dp icons, 40dp minimum
/// hit areas, `HivorrSpacing` gaps — while carrying the professional green
/// identity and no drawer (professional overflow lives in the shell `More`
/// sheet, so there is no menu tile).
///
/// One app bar serves every professional top-level page: the shell owns no
/// app bar on mobile, so this single implementation keeps the page title on
/// the left and bell + Professional pill + avatar on the right — one compact
/// row everywhere, mirroring the desktop `HivorrDashboardTopBar` with
/// `modeLabel: Professional`. Reloads stay on the content
/// `RefreshIndicator` below (same contract as the client chrome), so this
/// bar carries no refresh action.
class ProfessionalMobileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfessionalMobileAppBar({super.key, required this.title});

  /// Page title (`Dashboard`, `Find Work`, `My Jobs`, `Earnings`, …).
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 48,
      automaticallyImplyLeading: false,
      titleSpacing: HivorrSpacing.sm,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: <Widget>[
        _ProBellAction(hasDot: _hasWorkAvailable(context)),
        const _ProfessionalPill(),
        _ProAvatarAction(displayName: _displayName(context)),
      ],
    );
  }

  /// Attention dot when professional work is available (same signal as the
  /// desktop `Find Work` top bar). Missing providers resolve to no dot.
  static bool _hasWorkAvailable(BuildContext context) {
    try {
      return context.watch<JobProvider>().discovery.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Account name from the verified sign-in identity (same rule as the
  /// desktop professional top bars); falls back to the professional label
  /// when unavailable. Never a fabricated name.
  static String _displayName(BuildContext context) {
    try {
      final AuthProvider auth = context.watch<AuthProvider>();
      final String? full = auth.currentSession?.fullName;
      if (full != null && full.isNotEmpty) return full;
      final String? display = auth.currentSession?.displayName?.trim();
      if (display != null && display.isNotEmpty) return display;
      final String? email = auth.currentSession?.email;
      if (email != null && email.isNotEmpty) {
        return _prettifyEmailPrefix(email);
      }
    } catch (_) {
      // Provider absent — fall through to the label.
    }
    return DashboardCapability.offer.label;
  }
}

/// Whether the professional mobile chrome applies here.
///
/// Offer focus (and fail-open pre-hydration is handled by the caller — this
/// returns true only for professional-only focus so hire surfaces keep the
/// client chrome untouched). A missing provider (isolated widget tests)
/// resolves to false so legacy bars keep rendering.
bool showProfessionalMenu(BuildContext context) {
  try {
    final EntityCapability? focus = context
        .read<OnboardingProvider>()
        .progress
        ?.capability;
    if (focus == null) {
      return false;
    }
    final DashboardCapability capability = DashboardCapability.fromEntity(
      focus,
    );
    return capability.showsWork && !capability.showsHiring;
  } catch (_) {
    return false;
  }
}

/// Notification bell with the attention dot (desktop top-bar language).
class _ProBellAction extends StatelessWidget {
  const _ProBellAction({required this.hasDot});

  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return IconButton(
      tooltip: 'Notifications',
      iconSize: 20,
      padding: const EdgeInsets.all(HivorrSpacing.sm),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: () => context.go(RoutePaths.dashboardNotifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.notifications_outlined),
          if (hasDot)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: HivorrSpacing.sm,
                height: HivorrSpacing.sm,
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact Professional indicator pill (desktop top-bar language).
class _ProfessionalPill extends StatelessWidget {
  const _ProfessionalPill();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    return Center(
      child: Container(
        key: const ValueKey<String>('professional-indicator'),
        margin: const EdgeInsets.only(right: HivorrSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.sm,
          vertical: HivorrSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: roles.professionalContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: roles.professionalPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: HivorrSpacing.xs),
            Text(
              'Professional',
              style: context.textTheme.labelSmall?.copyWith(
                color: roles.professionalPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact account avatar opening the profile (desktop top-bar language).
class _ProAvatarAction extends StatelessWidget {
  const _ProAvatarAction({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    return Tooltip(
      message: 'Profile',
      child: SizedBox(
        width: 44,
        height: 48,
        child: Center(
          child: InkWell(
            onTap: () => context.go(RoutePaths.dashboardAccount),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roles.professionalContainer,
                border: Border.all(
                  color: roles.professionalPrimary,
                  width: 1.5,
                ),
              ),
              child: Text(
                _initials(displayName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: roles.professionalPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Display identity derived from the verified sign-in email: the local-part
/// stands in where no display name is exposed. Never a fabricated name.
/// (Mirrors the client chrome helper; kept local so the client file stays
/// untouched.)
String _prettifyEmailPrefix(String email) {
  final String local = email.split('@').first.trim();
  if (local.isEmpty) {
    return DashboardCapability.offer.label;
  }
  final List<String> words = local
      .split(RegExp(r'[._\-]+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .toList(growable: false);
  if (words.isEmpty) {
    return DashboardCapability.offer.label;
  }
  return words.join(' ');
}

/// Up-to-two-letter avatar initials for a display identity.
String _initials(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return '•';
  }
  final String first = words.first[0].toUpperCase();
  if (words.length == 1) {
    return first;
  }
  return '$first${words[1][0].toUpperCase()}';
}
