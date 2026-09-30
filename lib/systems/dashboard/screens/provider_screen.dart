import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Provider hub: the authenticated user's provider identity, contact,
///
/// live stats, and entry points into the existing verification, finance and
/// service surfaces (EP-04-03).
///
/// This is the renamed `Account` section: it represents the current user's
/// provider capability/profile — not a separate identity. All displayed
/// values come from the authoritative providers already in the widget tree
/// ([AuthProvider] session, [OnboardingProvider] capability, [JobProvider] /
/// [HireProvider] counts). Nothing is hard-coded: the display identity is
/// derived from the session email with the same rule as the overview hero,
/// the avatar uses [HivorrAvatar] initials, and genuinely unavailable fields
/// (e.g. phone — [EntityProvider] is not in the widget tree, see
/// `entity_profile.dart`) render an honest empty state instead of placeholder
/// data. Company name/size, website, ratings and payment methods have no
/// backend field and are therefore not shown.
///
/// Desktop (≥1000dp content width) renders the reference two-column layout
/// (identity + contact beside the stats rail); narrower widths stack the
/// same sections in the same order — one implementation, no desktop-only
/// assumptions.
class ProviderScreen extends StatefulWidget {
  const ProviderScreen({super.key});

  @override
  State<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends State<ProviderScreen> {
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hydrated) {
      _hydrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  Future<void> _hydrate() async {
    if (!mounted) return;
    DashboardCapability capability = DashboardCapability.both;
    try {
      capability = DashboardCapability.fromEntity(
        context.read<OnboardingProvider>().progress?.capability ??
            EntityCapability.both,
      );
    } catch (_) {
      return;
    }
    try {
      final JobProvider jobs = context.read<JobProvider>();
      final HireProvider hires = context.read<HireProvider>();
      if (capability.showsHiring) {
        unawaited(jobs.loadMine(role: 'posted'));
        unawaited(hires.loadList(role: 'client'));
      }
      if (capability.showsWork) {
        unawaited(jobs.loadDiscovery(refresh: true));
        unawaited(hires.loadList(role: 'professional'));
      }
    } catch (_) {
      // Jobs/hires providers absent (e.g. minimal test harness) — the
      // stats card degrades to empty states instead of crashing.
    }
  }

  Future<void> _refresh(DashboardCapability capability) async {
    try {
      final JobProvider jobs = context.read<JobProvider>();
      final HireProvider hires = context.read<HireProvider>();
      if (capability.showsHiring) {
        await jobs.loadMine(role: 'posted');
        await hires.loadList(role: 'client');
      }
      if (capability.showsWork) {
        await jobs.loadDiscovery(refresh: true);
        await hires.loadList(role: 'professional');
      }
    } catch (_) {
      // Providers absent — nothing to refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final DashboardCapability capability = DashboardCapability.fromEntity(
      onboarding.progress?.capability ?? EntityCapability.both,
    );
    final String email = auth.currentSession?.email ?? '';
    final bool isMobile = context.breakpoint == Breakpoint.mobile;

    Widget content = RefreshIndicator(
      onRefresh: () => _refresh(capability),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MobileCompact.scrollPaddingFor(c.maxWidth),
            child: _ProviderContent(
              maxWidth: c.maxWidth,
              capability: capability,
              email: email,
              onSignOut: () => auth.signOut(),
            ),
          );
        },
      ),
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          title: Text(
            'Provider',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Notifications',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go(RoutePaths.dashboardNotifications),
            ),
            IconButton(
              tooltip: 'Refresh',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(_refresh(capability)),
            ),
          ],
        ),
        body: MobileSafeBody(child: content),
      );
    }

    content = ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: content,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProviderTopBar(capability: capability, email: email),
        Expanded(child: content),
      ],
    );
  }
}

/// Reference top bar: menu tile, `Provider` title, notification bell with
/// attention dot, Client/Professional/Both role pill and account avatar
/// (mirrors the overview top bar; Hivorr terminology — never `Employer`).
class _ProviderTopBar extends StatelessWidget {
  const _ProviderTopBar({required this.capability, required this.email});

  final DashboardCapability capability;
  final String email;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    int pendingApps = 0;
    try {
      pendingApps = context
          .watch<JobProvider>()
          .posted
          .where((Job job) => job.isOpen)
          .fold<int>(0, (int sum, Job job) => sum + job.applicationsCount);
    } catch (_) {
      pendingApps = 0;
    }
    final String identity = _displayIdentity(email);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.lg,
        vertical: 14,
      ),
      child: Row(
        children: <Widget>[
          _TopBarTile(
            tooltip: 'Menu',
            icon: Icons.menu,
            onTap: () {
              final ScaffoldState? scaffold = Scaffold.maybeOf(context);
              if (scaffold != null && scaffold.hasDrawer) {
                scaffold.openDrawer();
              }
            },
          ),
          const SizedBox(width: HivorrSpacing.md),
          Text(
            'Provider',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _TopBarTile(
            tooltip: 'Notifications',
            icon: Icons.notifications_outlined,
            showDot: pendingApps > 0,
            onTap: () => context.go(RoutePaths.dashboardNotifications),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _pillContainer(roles, capability),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _pillForeground(roles, capability),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.xs),
                Text(
                  capability.label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: _pillForeground(roles, capability),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Tooltip(
            message: 'Provider',
            child: InkWell(
              onTap: () => context.go(RoutePaths.dashboardAccount),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer,
                  border: Border.all(color: colors.primary, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(identity),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
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

class _TopBarTile extends StatelessWidget {
  const _TopBarTile({
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
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, size: 22, color: colors.onSurfaceVariant),
              if (showDot)
                Positioned(
                  top: 10,
                  right: 11,
                  child: Container(
                    width: 9,
                    height: 9,
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
    );
  }
}

/// Provider content: heading, identity + contact beside the stats rail on
/// wide layouts (≥1000dp), stacked otherwise, then the preserved hub links
/// and sign-out.
class _ProviderContent extends StatelessWidget {
  const _ProviderContent({
    required this.maxWidth,
    required this.capability,
    required this.email,
    required this.onSignOut,
  });

  final double maxWidth;
  final DashboardCapability capability;
  final String email;
  final VoidCallback onSignOut;

  /// Width at or above which the stats rail docks beside the content.
  static const double railStart = 1000;

  @override
  Widget build(BuildContext context) {
    final bool wide = maxWidth >= railStart;
    final double sectionGap = MobileCompact.sectionGapFor(maxWidth);
    final bool compact = MobileCompact.isCompactWidth(maxWidth);
    final Widget main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _IdentityCard(capability: capability, email: email),
        SizedBox(height: sectionGap),
        _ContactCard(email: email, twoColumns: wide),
        SizedBox(height: sectionGap),
        const HivorrSectionHeader(title: 'Profile & verification'),
        _Link(
          icon: Icons.verified_user_outlined,
          label: 'Verification status',
          onTap: () => context.go(RoutePaths.verificationStatus),
        ),
        _Link(
          icon: Icons.badge_outlined,
          label: 'KYC status',
          onTap: () => context.go(RoutePaths.kycStatus),
        ),
        if (capability.showsWork)
          _Link(
            icon: Icons.work_outline,
            label: 'My service listings',
            onTap: () => context.go(RoutePaths.serviceListingsMine),
          ),
        SizedBox(height: sectionGap),
        const HivorrSectionHeader(title: 'Money & support'),
        _Link(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Wallet & finance',
          onTap: () => context.go(RoutePaths.finance),
        ),
        _Link(
          icon: Icons.flag_outlined,
          label: 'Disputes',
          onTap: () => context.go(RoutePaths.disputes),
        ),
      ],
    );
    final Widget rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StatsCard(capability: capability),
        SizedBox(height: compact ? HivorrSpacing.md : HivorrSpacing.lg),
        HivorrButton(
          label: 'Sign out',
          variant: HivorrButtonVariant.outline,
          onPressed: onSignOut,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Provider Profile',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 20 : 28,
          ),
        ),
        SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        if (wide)
          Row(
            // NOTE: `start`, not `stretch` — this row lives inside a
            // vertical scroll view (unbounded height), where stretch forces
            // infinite height and crashes layout.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: main),
              const SizedBox(width: HivorrSpacing.lg),
              SizedBox(width: 320, child: rail),
            ],
          )
        else ...<Widget>[
          main,
          SizedBox(height: sectionGap),
          rail,
        ],
      ],
    );
  }
}

/// Identity card: avatar with user-derived initials, display identity,
/// capability chip and session email (reference header card).
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.capability, required this.email});

  final DashboardCapability capability;
  final String email;

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final String identity = _displayIdentity(email);
    final String title = identity.isNotEmpty ? identity : capability.label;
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          HivorrAvatar(name: identity, size: compact ? 56 : 64),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: HivorrSpacing.sm),
                    _RoleChip(capability: capability),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email.isNotEmpty ? email : 'Email not available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contact card: session email plus the honestly-unavailable phone row.
///
/// Phone is genuinely not exposed to the dashboard widget tree (no
/// [EntityProvider] in scope), so it renders an empty state — never a
/// fabricated number.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.email, required this.twoColumns});

  final String email;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final Widget emailField = _Field(
      label: 'Email',
      value: email.isNotEmpty ? email : 'Not available',
      muted: email.isEmpty,
    );
    const Widget phoneField = _Field(
      label: 'Phone',
      value: 'Not provided',
      hint: 'No phone number on your profile yet.',
      muted: true,
    );
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Contact',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 15 : 18,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          if (twoColumns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: emailField),
                const SizedBox(width: HivorrSpacing.md),
                const Expanded(child: phoneField),
              ],
            )
          else ...<Widget>[
            emailField,
            const SizedBox(height: HivorrSpacing.md),
            phoneField,
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.hint,
    this.muted = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              color: muted ? colors.onSurfaceVariant : colors.onSurface,
              fontSize: compact ? 13 : null,
            ),
          ),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// Stats rail card (reference `Account Stats`): live counts only.
///
/// Averages, ratings and member-since have no backend seam and are therefore
/// not shown (see `client_overview_mock.dart` for the documented money-rail
/// seams; no equivalent seam exists for ratings/tenure).
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.capability});

  final DashboardCapability capability;

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    List<Job> posted = const <Job>[];
    List<Job> discovery = const <Job>[];
    List<Hire> clientHires = const <Hire>[];
    List<Hire> workHires = const <Hire>[];
    bool jobsLoading = false;
    bool hiresLoading = false;
    try {
      final JobProvider jobs = context.watch<JobProvider>();
      posted = jobs.posted;
      discovery = jobs.discovery;
      jobsLoading = jobs.isLoading;
    } catch (_) {
      // Jobs provider absent — rows fall back to empty states.
    }
    try {
      final HireProvider hires = context.watch<HireProvider>();
      clientHires = hires.hires;
      workHires = hires.hires;
      hiresLoading = hires.isLoading;
    } catch (_) {
      // Hires provider absent — rows fall back to empty states.
    }
    final List<({String label, String value})> rows = <({String label, String value})>[
      if (capability.showsHiring) ...<({String label, String value})>[
        (
          label: 'Jobs Posted',
          value: jobsLoading && posted.isEmpty ? '…' : '${posted.length}',
        ),
        (
          label: 'Hires',
          value: hiresLoading && clientHires.isEmpty
              ? '…'
              : '${clientHires.length}',
        ),
      ],
      if (capability.showsWork) ...<({String label, String value})>[
        (
          label: 'My Work',
          value:
              hiresLoading && workHires.isEmpty ? '…' : '${workHires.length}',
        ),
        (
          label: 'Open Jobs',
          value: jobsLoading && discovery.isEmpty
              ? '…'
              : '${discovery.length}',
        ),
      ],
    ];
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Stats',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 15 : 18,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: compact ? HivorrSpacing.md : HivorrSpacing.lg,
                color: context.colorScheme.outlineVariant,
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    rows[i].label,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Text(
                  rows[i].value,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.capability});

  final DashboardCapability capability;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    final (Color bg, Color fg) = switch (capability) {
      DashboardCapability.hire => (roles.clientContainer, roles.clientPrimary),
      DashboardCapability.offer => (
        roles.professionalContainer,
        roles.professionalPrimary,
      ),
      DashboardCapability.both => (roles.bothContainer, roles.bothPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        capability.label,
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
      child: HivorrCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: context.colorScheme.primary),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

Color _pillContainer(RoleThemeExtension roles, DashboardCapability capability) {
  return switch (capability) {
    DashboardCapability.hire => roles.clientContainer,
    DashboardCapability.offer => roles.professionalContainer,
    DashboardCapability.both => roles.bothContainer,
  };
}

Color _pillForeground(RoleThemeExtension roles, DashboardCapability capability) {
  return switch (capability) {
    DashboardCapability.hire => roles.clientPrimary,
    DashboardCapability.offer => roles.professionalPrimary,
    DashboardCapability.both => roles.bothPrimary,
  };
}

/// Display identity derived from the verified sign-in email (same rule as
/// the overview hero): the local-part stands in where no display name is
/// exposed to the dashboard widget tree. Never a fabricated company name.
String _displayIdentity(String email) {
  final String local = email.split('@').first.trim();
  if (local.isEmpty) {
    return '';
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
    return '';
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
