import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/platform/platform_file_picker.dart';
import 'package:hivorr/core/storage/storage_config.dart';
import 'package:hivorr/core/storage/storage_validators.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/providers/entity_provider.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/shell/client_mobile_chrome.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/models/picked_avatar.dart';
import 'package:provider/provider.dart';

/// Profile hub: the authenticated user's profile identity, contact,
///
/// live stats, and entry points into the existing verification, finance and
/// service surfaces (EP-04-03).
///
/// This is the renamed `Account` section: it represents the current user's
/// profile — not a separate identity. All displayed
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
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    // Fail-open pre-hydration: load both sides until the focus is known.
    EntityCapability? focus;
    try {
      focus = context.read<OnboardingProvider>().progress?.capability;
    } catch (_) {
      return;
    }
    final bool hire = focus == null || focus == EntityCapability.hire;
    final bool offer = focus == null || focus == EntityCapability.offer;
    try {
      final JobProvider jobs = context.read<JobProvider>();
      final HireProvider hires = context.read<HireProvider>();
      if (hire) {
        unawaited(jobs.loadMine(role: 'posted'));
        unawaited(hires.loadList(role: 'client'));
      }
      if (offer) {
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
    // Fail-open pre-hydration: hiring hub until the focus is known.
    final EntityCapability? focus = onboarding.progress?.capability;
    final DashboardCapability capability = DashboardCapability.fromEntity(
      focus ?? EntityCapability.hire,
    );
    final String email = auth.currentSession?.email ?? '';
    final bool isMobile = context.breakpoint == Breakpoint.mobile;

    // Professional Dashboard → Profile renders the reference long-form page
    // (cover header, Profile | Portfolio | Reviews | Settings tabs, editable
    // Profile tab). Other focuses keep the established hub below.
    if (capability == DashboardCapability.offer) {
      return _proScaffold(context, capability, email, isMobile);
    }

    Widget content = RefreshIndicator(
      onRefresh: () => _refresh(capability),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MobileCompact.scrollPaddingFor(c.maxWidth),
            child: _ProfileContent(
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
      // Shared chrome carries bell + pill + avatar; pull-to-refresh on the
      // content covers reloads.
      return Scaffold(
        drawer: const ClientDashboardDrawer(),
        appBar: const ClientMobileAppBar(title: 'Profile'),
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
        _ProfileTopBar(capability: capability, email: email),
        Expanded(child: content),
      ],
    );
  }

  /// Professional reference scaffold: the same top bar above one continuous
  /// scrollable Profile page (mobile keeps a slim app bar instead).
  Widget _proScaffold(
    BuildContext context,
    DashboardCapability capability,
    String email,
    bool isMobile,
  ) {
    Widget content = RefreshIndicator(
      onRefresh: () => _refresh(capability),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MobileCompact.scrollPaddingFor(c.maxWidth),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: _ProProfileBody(maxWidth: c.maxWidth),
              ),
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
            'Profile',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Notifications',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go(RoutePaths.dashboardNotifications),
            ),
            IconButton(
              tooltip: 'Refresh',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
        _ProfileTopBar(capability: capability, email: email),
        Expanded(child: content),
      ],
    );
  }
}

/// Reference top bar: menu tile, `Profile` title, notification bell with
/// attention dot, Client/Professional focus pill and account avatar
/// (mirrors the overview top bar; Hivorr terminology — never `Employer`).
class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.capability, required this.email});

  final DashboardCapability capability;
  final String email;

  @override
  Widget build(BuildContext context) {
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
    return HivorrDashboardTopBar(
      title: 'Profile',
      accentPrimary: _pillForeground(roles, capability),
      accentContainer: _pillContainer(roles, capability),
      modeLabel: capability.label,
      initials: _initials(identity),
      showDot: pendingApps > 0,
      onMenu: () {
        final ScaffoldState? scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onNotifications: () => context.go(RoutePaths.dashboardNotifications),
      onAvatar: () => context.go(RoutePaths.dashboardAccount),
    );
  }
}

/// Profile content: heading, identity + contact beside the stats rail on
/// wide layouts (≥1000dp), stacked otherwise, then the preserved hub links
/// and sign-out.
class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
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
        const _ClientPreferencesCard(),
        SizedBox(height: compact ? HivorrSpacing.md : HivorrSpacing.lg),
        _SignOutButton(onTap: onSignOut),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The shared mobile bar already titles this page on phones, so the
        // in-body heading shows on wider layouts only.
        if (!compact) ...<Widget>[
          Text(
            'Profile',
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        ],
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
        else ...<Widget>[main, SizedBox(height: sectionGap), rail],
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
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
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
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Contact',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
    final AppThemeExtension ext = context.appExtension;
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
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: HivorrSpacing.smMd,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(ext.radiusXs),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              color: muted ? colors.onSurfaceVariant : colors.onSurface,
            ),
          ),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
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
    final List<({String label, String value})> rows =
        <({String label, String value})>[
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
              value: hiresLoading && workHires.isEmpty
                  ? '…'
                  : '${workHires.length}',
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
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Stats',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Text(
                  rows[i].value,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
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

/// Client notification preferences (reference `Preferences` card).
///
/// MOCK: no notification-preference seam exists, so the switches stay local
/// with the reference defaults until one lands — same convention as the
/// professional Settings tab toggles.
class _ClientPreferencesCard extends StatefulWidget {
  const _ClientPreferencesCard();

  @override
  State<_ClientPreferencesCard> createState() => _ClientPreferencesCardState();
}

class _ClientPreferencesCardState extends State<_ClientPreferencesCard> {
  bool _email = true;
  bool _jobAlerts = true;
  bool _sms = false;
  bool _weekly = true;

  @override
  Widget build(BuildContext context) {
    final Color active = context.roleTheme.clientPrimary;
    return _SettingsCard(
      title: 'Preferences',
      children: <Widget>[
        _ToggleRow(
          label: 'Email notifications',
          value: _email,
          activeColor: active,
          onChanged: (bool v) => setState(() => _email = v),
        ),
        _ToggleRow(
          label: 'Job application alerts',
          value: _jobAlerts,
          activeColor: active,
          onChanged: (bool v) => setState(() => _jobAlerts = v),
        ),
        _ToggleRow(
          label: 'SMS updates',
          value: _sms,
          activeColor: active,
          onChanged: (bool v) => setState(() => _sms = v),
        ),
        _ToggleRow(
          label: 'Weekly digest',
          value: _weekly,
          last: true,
          activeColor: active,
          onChanged: (bool v) => setState(() => _weekly = v),
        ),
      ],
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
  };
}

Color _pillForeground(
  RoleThemeExtension roles,
  DashboardCapability capability,
) {
  return switch (capability) {
    DashboardCapability.hire => roles.clientPrimary,
    DashboardCapability.offer => roles.professionalPrimary,
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

// ── Professional long-form Profile (reference) ─────────────────────────────

/// Professional Profile page: ONE continuous scrollable interface.
///
/// Cover + identity header, the `Profile | Portfolio | Reviews | Settings`
/// tabs, then the tab content. Only the Profile tab is implemented — the
/// other tabs switch in place and render an honest placeholder until they
/// land. Identity (name/initials) derives from the live [AuthSession] first
/// + last names (never hardcoded); the form prefills from the same session.
/// Stats without a backend seam render the reference values (marked MOCK);
/// profile completeness reuses the live onboarding derivation, and the email
/// verification row follows the session's confirmation state.
class _ProProfileBody extends StatefulWidget {
  const _ProProfileBody({required this.maxWidth});

  final double maxWidth;

  @override
  State<_ProProfileBody> createState() => _ProProfileBodyState();
}

class _ProProfileBodyState extends State<_ProProfileBody> {
  static const List<String> _tabs = <String>[
    'Profile',
    'Portfolio',
    'Reviews',
    'Settings',
  ];

  /// Width at or above which the stats rail docks beside the content.
  static const double _railStart = 1000;

  int _tab = 0;
  bool _seeded = false;
  bool _saving = false;

  /// ONE shared professional identity picture for the whole Profile
  /// interface (Profile | Portfolio | Reviews | Settings). The cover header
  /// on every tab reads this single state, so a change reflects everywhere.
  /// Null renders the dynamic initials fallback.
  Uint8List? _avatarBytes;

  /// MOCK: reference portfolio projects until an owner-managed showcase
  /// seam exists (the portfolio backend is read-only public showcase).
  final List<({String title, String tech})> _projects =
      <({String title, String tech})>[
        (title: 'FinTrack Dashboard', tech: 'React / Node.js'),
        (title: 'AfriShop E-commerce', tech: 'Next.js / PostgreSQL'),
        (title: 'POS Mobile App', tech: 'React Native / AWS'),
      ];

  final GlobalKey _formKey = GlobalKey();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _bio = TextEditingController();

  /// MOCK: reference skill set until a skills seam exists.
  final List<String> _skills = <String>[
    'React',
    'Node.js',
    'TypeScript',
    'PostgreSQL',
    'AWS',
    'Docker',
    'GraphQL',
    'Next.js',
    'Redis',
    'Python',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    try {
      final session = context.read<AuthProvider>().currentSession;
      final String full = session?.fullName?.trim() ?? '';
      final String display = session?.displayName?.trim() ?? '';
      final String email = session?.email ?? '';
      _name.text = full.isNotEmpty
          ? full
          : (display.isNotEmpty ? display : _displayIdentity(email));
      _email.text = email;
    } catch (_) {
      // Auth provider absent — fields stay empty.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _rate.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _snack(String message, HivorrSnackbarVariant variant) {
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(context, message: message, variant: variant),
    );
  }

  /// Live identity: session first + last names, else display name, else the
  /// email local-part — never hardcoded. Edited form values overlay the
  /// header while typing.
  ({String name, String initials}) _identity() {
    String sessionName = 'Professional';
    String? sessionInitials;
    try {
      final session = context.watch<AuthProvider>().currentSession;
      final String? full = session?.fullName;
      final String? display = session?.displayName?.trim();
      final String email = session?.email ?? '';
      if (full != null && full.isNotEmpty) {
        sessionName = full;
        sessionInitials = session!.initials;
      } else if (display != null && display.isNotEmpty) {
        sessionName = display;
        sessionInitials = session!.initials;
      } else if (email.isNotEmpty) {
        sessionName = _displayIdentity(email);
      }
    } catch (_) {
      // Provider absent — fall through to defaults.
    }
    final String edited = _name.text.trim();
    final String name = edited.isNotEmpty ? edited : sessionName;
    final String initials = edited.isNotEmpty && edited != sessionName
        ? _initials(name)
        : (sessionInitials ?? _initials(name));
    return (name: name, initials: initials);
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final String email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) {
      _snack('Enter your full name and email.', HivorrSnackbarVariant.error);
      return;
    }
    EntityProvider? entities;
    String? entityId;
    try {
      entities = context.read<EntityProvider>();
      entityId = context.read<AuthProvider>().currentSession?.entityId;
    } catch (_) {
      entities = null;
      entityId = null;
    }
    setState(() => _saving = true);
    try {
      if (entities != null && entityId != null && entityId.isNotEmpty) {
        final String bio = _bio.text.trim();
        await entities.updateProfile(
          entityId: entityId,
          legalName: name,
          displayName: name,
          bio: bio.isEmpty ? null : bio,
        );
      }
      // TODO(profile-backend): persist title/phone/location/rate/skills once
      // seams exist — EntityProvider only carries legalName/displayName/bio
      // today (and is not in the widget tree yet, so saves stay local until
      // it is). The header already reflects the edited values.
      if (!mounted) return;
      _snack('Profile saved.', HivorrSnackbarVariant.success);
      setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Avatar control: pick → validate (profile-avatars bucket rules) →
  /// display instantly across every tab. Persists through
  /// [EntityProvider.updateAvatarPath] once the upload seam is wired.
  Future<void> _changePicture() async {
    PlatformFilePicker picker;
    try {
      picker = context.read<PlatformFilePicker>();
    } catch (_) {
      _snack(
        'Photo upload is not available here.',
        HivorrSnackbarVariant.error,
      );
      return;
    }
    final PickedAvatar? picked = await picker.pickAvatar();
    if (picked == null || !mounted) return;
    try {
      StorageValidators.validateForBucket(
        bucket: StorageBuckets.profileAvatars,
        mimeType: picked.mimeType,
        byteLength: picked.bytes.length,
      );
    } on Object {
      if (!mounted) return;
      _snack(
        'Use a JPEG, PNG, or WebP image under 5 MB.',
        HivorrSnackbarVariant.error,
      );
      return;
    }
    // TODO(profile-backend): upload to `profile-avatars/{entityId}/
    // avatar.{ext}` (upsert) via StorageService, then bind with
    // EntityProvider.updateAvatarPath — the canonical sequence mirrors
    // OnboardingService.completeProfile. Neither seam is in the widget tree
    // yet, so the picture stays in shared local state until it is.
    if (!mounted) return;
    setState(() => _avatarBytes = picked.bytes);
    _snack('Profile picture updated.', HivorrSnackbarVariant.success);
  }

  Future<void> _addProject() async {
    final ({String title, String tech})? result =
        await showDialog<({String title, String tech})>(
          context: context,
          builder: (BuildContext ctx) => const _AddProjectDialog(),
        );
    final String title = (result?.title ?? '').trim();
    if (title.isEmpty || !mounted) return;
    setState(
      () => _projects.add((title: title, tech: (result?.tech ?? '').trim())),
    );
    _snack('Project added.', HivorrSnackbarVariant.success);
  }

  void _scrollToForm() {
    final BuildContext? target = _formKey.currentContext;
    if (target == null) return;
    unawaited(
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      ),
    );
  }

  void _preview() {
    // TODO(profile-backend): deep-link the public preview once the own
    // public-profile URL seam exists (publicProfile needs slug + id).
    _snack('Public preview is not available yet.', HivorrSnackbarVariant.info);
  }

  Future<void> _addSkill() async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => const _AddSkillDialog(),
    );
    final String skill = (result ?? '').trim();
    if (skill.isEmpty || !mounted) return;
    if (_skills.any((String s) => s.toLowerCase() == skill.toLowerCase())) {
      return;
    }
    setState(() => _skills.add(skill));
  }

  @override
  Widget build(BuildContext context) {
    final double sectionGap = MobileCompact.sectionGapFor(widget.maxWidth);
    final ({String name, String initials}) identity = _identity();
    final String title = _title.text.trim().isEmpty
        ? 'Professional'
        : _title.text.trim();
    final String rate = _rate.text.trim().isEmpty ? '45' : _rate.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProCoverHeader(
          initials: identity.initials,
          avatarBytes: _avatarBytes,
          name: identity.name,
          title: title,
          rateText: '\$$rate/hr',
          onEdit: _scrollToForm,
          onPreview: _preview,
          onChangePicture: _changePicture,
        ),
        SizedBox(height: sectionGap),
        _ProTabs(
          tabs: _tabs,
          active: _tab,
          onSelect: (int i) => setState(() => _tab = i),
        ),
        SizedBox(height: sectionGap),
        if (_tab == 0)
          _profileTab(context, sectionGap)
        else if (_tab == 1)
          _portfolioTab(context, sectionGap)
        else if (_tab == 2)
          _reviewsTab(sectionGap)
        else if (_tab == 3)
          _ProSettingsTab(
            maxWidth: widget.maxWidth,
            sectionGap: sectionGap,
          )
        else
          HivorrEmptyState(
            title: _tabs[_tab],
            subtitle: 'This section is not available yet.',
            compact: MobileCompact.isCompactWidth(widget.maxWidth),
          ),
      ],
    );
  }

  /// Portfolio tab content: `Portfolio Items` header + Add Project, then the
  /// project grid (3 / 2 / 1 columns by width).
  Widget _portfolioTab(BuildContext context, double sectionGap) {
    final int columns = widget.maxWidth >= 1000
        ? 3
        : widget.maxWidth >= 600
        ? 2
        : 1;
    final List<List<int>> rows = <List<int>>[];
    for (int i = 0; i < _projects.length; i += columns) {
      rows.add(
        List<int>.generate(
          i + columns > _projects.length ? _projects.length - i : columns,
          (int j) => i + j,
        ),
      );
    }
    Widget card(int index) => _ProjectCard(
      title: _projects[index].title,
      tech: _projects[index].tech,
      tint: index % _projectTints.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Portfolio Items',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.md),
            _SmallPill(
              label: 'Add Project',
              icon: Icons.add,
              fill: context.colorScheme.primary,
              foreground: context.colorScheme.onPrimary,
              onTap: _addProject,
            ),
          ],
        ),
        SizedBox(height: sectionGap),
        for (int r = 0; r < rows.length; r++) ...<Widget>[
          if (r > 0) SizedBox(height: sectionGap),
          if (columns == 1)
            card(rows[r][0])
          else
            // A short final row keeps grid proportions via empty spacers.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int c = 0; c < columns; c++) ...<Widget>[
                  if (c > 0) const SizedBox(width: HivorrSpacing.md),
                  Expanded(
                    child: c < rows[r].length
                        ? card(rows[r][c])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }

  Widget _profileTab(BuildContext context, double sectionGap) {
    final bool wide = widget.maxWidth >= _railStart;
    final Widget personal = _PersonalCard(
      formKey: _formKey,
      maxWidth: widget.maxWidth,
      name: _name,
      title: _title,
      email: _email,
      phone: _phone,
      location: _location,
      rate: _rate,
      bio: _bio,
      saving: _saving,
      onChanged: (_) => setState(() {}),
      onSave: _save,
    );
    final Widget skills = _ProSkillsCard(
      skills: _skills,
      onRemove: (String s) => setState(() => _skills.remove(s)),
      onAdd: _addSkill,
    );
    final Widget rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ProStatsCard(),
        SizedBox(height: sectionGap),
        const _ProVerificationCard(),
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          personal,
          SizedBox(height: sectionGap),
          rail,
          SizedBox(height: sectionGap),
          skills,
        ],
      );
    }
    return Row(
      // NOTE: `start`, not `stretch` — this row lives inside a vertical
      // scroll view (unbounded height), where stretch forces infinite
      // height and crashes layout.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              personal,
              SizedBox(height: sectionGap),
              skills,
            ],
          ),
        ),
        const SizedBox(width: HivorrSpacing.lg),
        const SizedBox(width: 320, child: _ProStatsRail()),
      ],
    );
  }
}

/// Right rail column for wide layouts (stats + verification).
class _ProStatsRail extends StatelessWidget {
  const _ProStatsRail();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProStatsCard(),
        SizedBox(height: HivorrSpacing.lg),
        _ProVerificationCard(),
      ],
    );
  }
}

/// Green cover banner with the shared avatar control + camera badge, above
/// the white identity card (Edit / Preview, name, title, meta row).
///
/// The avatar control shows the uploaded picture when one exists, else the
/// dynamic initials fallback. Tapping the camera badge replaces the picture;
/// the bytes live in the single shared page state, so every tab reflects
/// the change.
class _ProCoverHeader extends StatelessWidget {
  const _ProCoverHeader({
    required this.initials,
    required this.avatarBytes,
    required this.name,
    required this.title,
    required this.rateText,
    required this.onEdit,
    required this.onPreview,
    required this.onChangePicture,
  });

  final String initials;
  final Uint8List? avatarBytes;
  final String name;
  final String title;
  final String rateText;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onChangePicture;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    final AppThemeExtension ext = context.appExtension;
    final Color green = roles.professionalPrimary;
    final Uint8List? bytes = avatarBytes;
    final Widget avatar = bytes == null
        ? Text(
            initials,
            style: context.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          )
        : Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              bytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          );
    // The badge straddles the banner/card boundary. It lives in the card's
    // own stack (painted after the card) so it stays tappable instead of
    // being covered by the card below.
    final Widget badge = Tooltip(
      message: 'Change profile picture',
      child: InkWell(
        onTap: onChangePicture,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Stack(
          children: <Widget>[
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Positioned(left: 48, bottom: 12, child: avatar),
          ],
        ),
        // The badge straddles the card's top edge. It lives in the card's
        // own stack (painted after the card) so it stays tappable instead
        // of being covered by the card below.
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            HivorrCard(
              elevation: 1,
              borderRadius: 20,
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Spacer(),
                      _SmallPill(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        fill: colors.primaryContainer,
                        foreground: colors.primary,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: HivorrSpacing.sm),
                      _SmallPill(
                        label: 'Preview',
                        icon: Icons.visibility_outlined,
                        fill: colors.primary,
                        foreground: colors.onPrimary,
                        onTap: onPreview,
                      ),
                    ],
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  Wrap(
                    spacing: HivorrSpacing.md,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.star, size: 16, color: ext.warning),
                          const SizedBox(width: 4),
                          Text(
                            '4.9',
                            style: context.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(142 reviews)',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Lagos, NG',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '89 jobs completed',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        rateText,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Available',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(left: 104, top: -13, child: badge),
          ],
        ),
      ],
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.icon,
    required this.fill,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab bar: white container with `Profile | Portfolio | Reviews | Settings`
/// pills — the active tab fills professional green. Selection stays on this
/// page; only the Profile tab content is implemented so far.
class _ProTabs extends StatelessWidget {
  const _ProTabs({
    required this.tabs,
    required this.active,
    required this.onSelect,
  });

  final List<String> tabs;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                Semantics(
                  button: true,
                  selected: i == active,
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: i == active
                            ? roles.professionalPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tabs[i],
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: i == active
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Editable Personal Information card: two columns on wide layouts, stacked
/// otherwise, then the bio field and the Save action.
class _PersonalCard extends StatelessWidget {
  const _PersonalCard({
    required this.formKey,
    required this.maxWidth,
    required this.name,
    required this.title,
    required this.email,
    required this.phone,
    required this.location,
    required this.rate,
    required this.bio,
    required this.saving,
    required this.onChanged,
    required this.onSave,
  });

  final GlobalKey formKey;
  final double maxWidth;
  final TextEditingController name;
  final TextEditingController title;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController location;
  final TextEditingController rate;
  final TextEditingController bio;
  final bool saving;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bool twoColumns = maxWidth >= 720;
    Widget pair(Widget a, Widget b) {
      if (!twoColumns) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            a,
            const SizedBox(height: HivorrSpacing.md),
            b,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: a),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(child: b),
        ],
      );
    }

    return HivorrCard(
      key: formKey,
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Personal Information',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          pair(
            _ProField(
              label: 'Full Name',
              controller: name,
              onChanged: onChanged,
            ),
            _ProField(
              label: 'Professional Title',
              controller: title,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          pair(
            _ProField(
              label: 'Email',
              controller: email,
              keyboardType: TextInputType.emailAddress,
            ),
            _ProField(
              label: 'Phone',
              controller: phone,
              keyboardType: TextInputType.phone,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          pair(
            _ProField(label: 'Location', controller: location),
            _ProField(
              label: 'Hourly Rate (USD)',
              controller: rate,
              keyboardType: TextInputType.number,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          _ProField(label: 'Professional Bio', controller: bio, maxLines: 5),
          const SizedBox(height: HivorrSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: HivorrButton(
              label: 'Save Profile',
              icon: const Icon(Icons.check, size: 20),
              isLoading: saving,
              onPressed: saving ? null : onSave,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled reference field: bold label above a borderless filled box.
class _ProField extends StatelessWidget {
  const _ProField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final OutlineInputBorder box = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : 1,
          onChanged: onChanged,
          style: context.textTheme.bodyMedium,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.md,
              vertical: 14,
            ),
            border: box,
            enabledBorder: box,
            focusedBorder: box.copyWith(
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Profile Stats rail card (reference). Completeness derives live from
/// onboarding progress (85% fallback, matching the dashboard card); the
/// remaining rows render the reference values until their seams exist.
class _ProStatsCard extends StatelessWidget {
  const _ProStatsCard();

  @override
  Widget build(BuildContext context) {
    int percent = 85;
    try {
      final progress = context.watch<OnboardingProvider>().progress;
      if (progress != null && progress.requiredSteps.isNotEmpty) {
        final int done = progress.requiredSteps
            .where((s) => progress.completedSteps.contains(s))
            .length;
        percent = ((done / progress.requiredSteps.length) * 100).round();
        if (progress.isComplete) percent = 100;
        if (percent == 100) {
          try {
            final bool hasItems =
                context.watch<JobProvider>().applied.isNotEmpty ||
                context.watch<HireProvider>().hires.isNotEmpty;
            if (!hasItems) percent = 85;
          } catch (_) {
            percent = 85;
          }
        }
      }
    } catch (_) {
      percent = 85;
    }
    return HivorrCard(
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Profile Stats',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          _StatRow(label: 'Profile Completeness', value: '$percent%'),
          const _StatRow(label: 'Total Reviews', value: '142'),
          const _StatRow(label: 'Avg Rating', value: '4.9 / 5.0'),
          const _StatRow(label: 'Jobs Completed', value: '89'),
          const _StatRow(label: 'Response Time', value: '< 2 hours'),
          const _StatRow(label: 'Availability', value: 'From Jul 8', last: true),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (!last)
          Divider(
            height: HivorrSpacing.lg,
            color: context.colorScheme.outlineVariant,
          ),
      ],
    );
  }
}

/// Verification Status rail card (reference). The email row follows the
/// session confirmation state; Identity/Phone render the reference verified
/// state until their seams exist; Bank Account links into KYC verification.
class _ProVerificationCard extends StatelessWidget {
  const _ProVerificationCard();

  @override
  Widget build(BuildContext context) {
    bool emailVerified = false;
    try {
      emailVerified =
          context.watch<AuthProvider>().currentSession?.isEmailConfirmed ??
          false;
    } catch (_) {
      emailVerified = false;
    }
    return HivorrCard(
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Verification Status',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          const _VerifyRow(label: 'Identity', verified: true),
          _VerifyRow(label: 'Email', verified: emailVerified),
          const _VerifyRow(label: 'Phone', verified: true),
          _VerifyRow(
            label: 'Bank Account',
            verified: false,
            last: true,
            actionLabel: 'Verify →',
            onAction: () => context.go(RoutePaths.kycStatus),
          ),
        ],
      ),
    );
  }
}

class _VerifyRow extends StatelessWidget {
  const _VerifyRow({
    required this.label,
    required this.verified,
    this.last = false,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final bool verified;
  final bool last;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: verified
                    ? ext.successContainer
                    : colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                verified ? Icons.check : Icons.close,
                size: 14,
                color: verified ? ext.success : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(width: HivorrSpacing.sm),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    actionLabel!,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!last)
          Divider(
            height: HivorrSpacing.lg,
            color: context.colorScheme.outlineVariant,
          ),
      ],
    );
  }
}

  /// Reviews tab content: the reference client-review list, single column.
  Widget _reviewsTab(double sectionGap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < _referenceReviews.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: sectionGap),
          _ReviewCard(review: _referenceReviews[i]),
        ],
      ],
    );
  }

/// MOCK: reference client reviews until a professional-reviews seam exists
/// (ratings surface only as marketplace aggregates today; client display
/// names are not exposed to the dashboard, so these stay fixed reference
/// rows rather than invented live data).
const List<({String author, String meta, String body, int stars})>
    _referenceReviews = <({String author, String meta, String body, int stars})>[
  (
    author: 'TechVentures Africa',
    meta: 'React Developer · 2 weeks ago',
    body:
        'Exceptional work. Amara delivered a production-ready fintech dashboard 2 weeks ahead of schedule.',
    stars: 5,
  ),
  (
    author: 'StartupHub GH',
    meta: 'Brand Platform · 1 month ago',
    body:
        'Outstanding design intuition paired with clean code. Our product is 10x better because of Amara.',
    stars: 5,
  ),
];

/// Reference review card: author + meta beside the star row, body below.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ({String author, String meta, String body, int stars}) review;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return HivorrCard(
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      review.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HivorrSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int s = 0; s < review.stars; s++)
                    Icon(Icons.star, size: 16, color: ext.warning),
                ],
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          Text(
            review.body,
          ),
        ],
      ),
    );
  }
}

/// Settings tab: Availability + Notifications switches, the Payout Account
/// mirror, and the account actions — one continuous layout (two columns on
/// wide layouts, stacked otherwise).
///
/// Wiring: payout rows read the live [FinancialPayoutProvider] mirror when
/// bound accounts exist (reference rows otherwise, marked MOCK); Sign Out
/// calls the existing [AuthProvider.signOut]; Add Payout Method routes into
/// the finance hub where binding lives. Availability/notification switches
/// and Delete Account have no backend seams today (the standalone settings
/// hub keeps its theme/locale behavior untouched), so switches stay local
/// with the reference defaults and deletion reports honestly.
class _ProSettingsTab extends StatefulWidget {
  const _ProSettingsTab({
    required this.maxWidth,
    required this.sectionGap,
  });

  final double maxWidth;
  final double sectionGap;

  @override
  State<_ProSettingsTab> createState() => _ProSettingsTabState();
}

class _ProSettingsTabState extends State<_ProSettingsTab> {
  /// MOCK: reference defaults until preference seams exist.
  bool _availableNew = true;
  bool _fullTime = false;
  bool _partTime = true;
  bool _remoteOnly = true;
  bool _jobMatches = true;
  bool _appUpdates = true;
  bool _paymentReceived = true;
  bool _messages = true;
  bool _weeklySummary = false;

  bool _payoutsRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_payoutsRequested) return;
    _payoutsRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        unawaited(context.read<FinancialPayoutProvider>().load());
      } catch (_) {
        // Payout provider absent — reference rows render instead.
      }
    });
  }

  void _snack(String message, HivorrSnackbarVariant variant) {
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(context, message: message, variant: variant),
    );
  }

  Future<void> _signOut() async {
    try {
      await context.read<AuthProvider>().signOut();
    } catch (_) {
      if (!mounted) return;
      _snack('Sign out is not available here.', HivorrSnackbarVariant.error);
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This permanently removes your Hivorr account and all of its data.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // TODO(account-backend): no self-service deletion seam exists (entity
    // lifecycle is admin-only) — route this once one lands.
    _snack(
      'Account deletion is not available yet.',
      HivorrSnackbarVariant.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = widget.maxWidth >= 1000;
    final Widget availability = _SettingsCard(
      title: 'Availability',
      children: <Widget>[
        _ToggleRow(
          label: 'Available for new work',
          value: _availableNew,
          onChanged: (bool v) => setState(() => _availableNew = v),
        ),
        _ToggleRow(
          label: 'Open to full-time roles',
          value: _fullTime,
          onChanged: (bool v) => setState(() => _fullTime = v),
        ),
        _ToggleRow(
          label: 'Open to part-time',
          value: _partTime,
          onChanged: (bool v) => setState(() => _partTime = v),
        ),
        _ToggleRow(
          label: 'Remote only',
          value: _remoteOnly,
          last: true,
          onChanged: (bool v) => setState(() => _remoteOnly = v),
        ),
      ],
    );
    final Widget notifications = _SettingsCard(
      title: 'Notifications',
      children: <Widget>[
        _ToggleRow(
          label: 'New job matches',
          value: _jobMatches,
          onChanged: (bool v) => setState(() => _jobMatches = v),
        ),
        _ToggleRow(
          label: 'Application updates',
          value: _appUpdates,
          onChanged: (bool v) => setState(() => _appUpdates = v),
        ),
        _ToggleRow(
          label: 'Payment received',
          value: _paymentReceived,
          onChanged: (bool v) => setState(() => _paymentReceived = v),
        ),
        _ToggleRow(
          label: 'Messages',
          value: _messages,
          onChanged: (bool v) => setState(() => _messages = v),
        ),
        _ToggleRow(
          label: 'Weekly summary',
          value: _weeklySummary,
          last: true,
          onChanged: (bool v) => setState(() => _weeklySummary = v),
        ),
      ],
    );
    final Widget payout = _PayoutCard(
      onAdd: () => context.go(RoutePaths.finance),
    );
    final Widget actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SignOutButton(onTap: _signOut),
        SizedBox(height: widget.sectionGap),
        _DeleteAccountButton(onTap: _deleteAccount),
      ],
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          availability,
          SizedBox(height: widget.sectionGap),
          notifications,
          SizedBox(height: widget.sectionGap),
          payout,
          SizedBox(height: widget.sectionGap),
          actions,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: availability),
            const SizedBox(width: HivorrSpacing.lg),
            Expanded(child: notifications),
          ],
        ),
        SizedBox(height: widget.sectionGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: payout),
            const SizedBox(width: HivorrSpacing.lg),
            Expanded(child: actions),
          ],
        ),
      ],
    );
  }
}

/// White settings section card (reference).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// Label + switch row with a hairline divider (reference).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
    this.activeColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  /// Active track override (client surfaces pass the client primary);
  /// defaults to the professional primary for the existing call sites.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
              ),
            ),
            const SizedBox(width: HivorrSpacing.md),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor:
                  activeColor ?? roles.professionalPrimary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: colors.outlineVariant,
            ),
          ],
        ),
        if (!last)
          Divider(
            height: HivorrSpacing.lg,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}

/// Payout Account card (reference): the live bound-account mirror when it
/// holds accounts, else the reference rows. Add routes into the finance hub
/// where binding lives.
class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    List<PayoutAccount> accounts = const <PayoutAccount>[];
    try {
      accounts = context.watch<FinancialPayoutProvider>().accounts;
    } catch (_) {
      accounts = const <PayoutAccount>[];
    }
    return HivorrCard(
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Payout Account',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          if (accounts.isEmpty) ...<Widget>[
            const _PayoutRow(
              icon: Icons.account_balance_wallet_outlined,
              text: 'GTBank — Savings **** 4521',
              primary: true,
              badge: 'Primary',
            ),
            const SizedBox(height: HivorrSpacing.sm),
            const _PayoutRow(
              icon: Icons.account_balance_wallet_outlined,
              text: 'Chipper Cash — @amara.diallo',
              primary: false,
            ),
          ] else
            for (int i = 0; i < accounts.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: HivorrSpacing.sm),
              _PayoutRow(
                icon: Icons.account_balance_wallet_outlined,
                text:
                    '${accounts[i].bankName} — ${accounts[i].maskedAccountNumber}',
                primary: accounts[i].isDefault,
                badge: accounts[i].isDefault ? 'Primary' : null,
              ),
            ],
          const SizedBox(height: HivorrSpacing.sm),
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colorScheme.outlineVariant,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+ Add Payout Method',
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.icon,
    required this.text,
    required this.primary,
    this.badge,
  });

  final IconData icon;
  final String text;
  final bool primary;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: primary
            ? ext.successContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: primary
            ? Border.all(color: ext.success.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 20,
            color: primary ? ext.success : colors.onSurfaceVariant,
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...<Widget>[
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              badge!,
              style: context.textTheme.labelLarge?.copyWith(
                color: ext.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sign Out action (reference): pink box, centered red label + icon. Uses
/// the existing [AuthProvider.signOut].
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.logout_outlined, size: 20, color: colors.error),
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              'Sign Out',
              style: context.textTheme.titleSmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delete Account action (reference): white bordered box, centered red
/// label. No self-service deletion seam exists (entity lifecycle is
/// admin-only), so the tap confirms intent and reports honestly.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(
          'Delete Account',
          style: context.textTheme.titleSmall?.copyWith(
            color: colors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Reference project tint cycle (pastel tile + saturated icon).
const List<({Color tile, Color icon})> _projectTints =
    <({Color tile, Color icon})>[
      (tile: Color(0xFFEAF0FE), icon: Color(0xFF2D3FE7)),
      (tile: Color(0xFFDCFCE7), icon: Color(0xFF16A34A)),
      (tile: Color(0xFFFFEDD5), icon: Color(0xFFF97316)),
      (tile: Color(0xFFF3E8FF), icon: Color(0xFF8B5CF6)),
      (tile: Color(0xFFE0F2FE), icon: Color(0xFF0891B2)),
      (tile: Color(0xFFFCE7F3), icon: Color(0xFFDB2777)),
    ];

/// Reference project card: pastel tile with a centered briefcase icon above
/// the title + tech subtitle.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.title,
    required this.tech,
    required this.tint,
  });

  final String title;
  final String tech;
  final int tint;

  @override
  Widget build(BuildContext context) {
    final ({Color tile, Color icon}) colors =
        _projectTints[tint % _projectTints.length];
    return HivorrCard(
      elevation: 1,
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: colors.tile,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.work_outline, size: 36, color: colors.icon),
          ),
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (tech.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    tech,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-owning Add Project dialog (controllers dispose with the route —
/// never while the exit transition still references them).
class _AddProjectDialog extends StatefulWidget {
  const _AddProjectDialog();

  @override
  State<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<_AddProjectDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _tech = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _tech.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.of(context).pop((title: _title.text, tech: _tech.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Project title'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: HivorrSpacing.md),
          TextField(
            controller: _tech,
            decoration: const InputDecoration(hintText: 'e.g. React / Node.js'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

/// Self-owning Add Skill dialog (same disposal contract as above).
class _AddSkillDialog extends StatefulWidget {
  const _AddSkillDialog();

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  final TextEditingController _skill = TextEditingController();

  @override
  void dispose() {
    _skill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Skill'),
      content: TextField(
        controller: _skill,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Figma'),
        onSubmitted: (String v) => Navigator.of(context).pop(v),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_skill.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Skills & Expertise card (reference): removable skill pills plus Add.
/// Local state until a skills seam exists.
class _ProSkillsCard extends StatelessWidget {
  const _ProSkillsCard({
    required this.skills,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> skills;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      elevation: 1,
      borderRadius: 20,
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Skills & Expertise',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            children: <Widget>[
              for (final String skill in skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(
                      alpha: context.isDarkMode ? 0.5 : 0.7,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        skill,
                        style: context.textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => onRemove(skill),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Text(
                    '+ Add Skill',
                    style: context.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
