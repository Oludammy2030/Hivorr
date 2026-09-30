import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_colors.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/models/client_overview_mock.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/quick_actions.dart';
import 'package:provider/provider.dart';

/// Client payments hub — desktop-first reference presentation.
///
/// Desktop (≥1024dp, validated first against `payment.png`) renders the
/// reference layout: a top bar (`Payments` title, notification bell, role
/// pill, avatar), a three-card summary row (blue Company Balance, totals,
/// spending by category), the escrow-hold banner, and the filterable Payment
/// History list. Narrower layouts stack the same sections in the same order
/// — no desktop-only assumptions, no separate mobile implementation.
///
/// The pre-existing mobile functionality is preserved below the reference
/// sections (`Money movement` quick actions and `Hires to fund`), so nothing
/// that worked on phones is removed; it simply follows the history list.
/// Money movement stays owned by the finance providers — this screen routes
/// and summarizes.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<HireProvider>().loadList(role: 'client');

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final bool isMobile = context.breakpoint == Breakpoint.mobile;

    Widget content = RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MobileCompact.scrollPaddingFor(c.maxWidth),
            child: _PaymentsContent(
              maxWidth: c.maxWidth,
              hires: hires,
              filter: _filter,
              onFilter: ( _HistoryFilter f) =>
                  setState(() => _filter = f),
              onRetry: () => unawaited(_load()),
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
            'Payments',
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
              onPressed: () => unawaited(_load()),
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
        const _PaymentsTopBar(),
        Expanded(child: content),
      ],
    );
  }
}

/// History filter behind the `Payment History` chips (reference).
enum _HistoryFilter {
  all('All'),
  made('Payments Made'),
  escrow('Escrow');

  const _HistoryFilter(this.label);

  final String label;
}

/// One filterable row behind the `Payment History` card.
///
/// Presentation detail (subtitle, status) enriches
/// [ClientPaymentMock.reference] — the source of truth for title, date and
/// amount stays the shared mock, so connecting live data means swapping that
/// list (see `client_overview_mock.dart` for the needed seams).
class _PaymentHistoryEntry {
  const _PaymentHistoryEntry({
    required this.title,
    required this.meta,
    required this.amountText,
    required this.isEscrow,
    required this.status,
  });

  final String title;
  final String meta;
  final String amountText;
  final bool isEscrow;
  final String status;
}

/// Reference history rows: mock title/date/amount + reference subtitle/status.
List<_PaymentHistoryEntry> _historyEntries() {
  String grouped(double v) => HivorrFormatters.number(v, decimals: 0);
  const Map<String, (String, String)> detail = <String, (String, String)>{
    'Payment to Amara Diallo': (
      'Today, 09:14 \u00B7 React Developer',
      'completed',
    ),
    'Escrow: Office Renovation': ('Jun 28 \u00B7 Electrical Work', 'held'),
    'Payment to Kwame Asante': ('Jun 25 \u00B7 Brand Design', 'completed'),
  };
  return <_PaymentHistoryEntry>[
    for (final ClientPaymentMock m in ClientPaymentMock.reference)
      () {
        final bool escrow = m.kind == ClientPaymentKind.escrow;
        final (String, String)? extra = detail[m.title];
        return _PaymentHistoryEntry(
          title: m.title,
          meta: extra?.$1 ?? m.date,
          amountText: escrow
              ? '${m.symbol}${grouped(m.amount)}'
              : '-${m.symbol}${grouped(m.amount.abs())}',
          isEscrow: escrow,
          status: extra?.$2 ?? (escrow ? 'held' : 'completed'),
        );
      }(),
  ];
}

/// Reference category split behind `Spending by Category` (placeholder).
enum _CategoryTint { development, design, physical }

const List<({String label, double share, _CategoryTint tint})>
    _spendingCategories = <({String label, double share, _CategoryTint tint})>[
  (label: 'Development', share: 0.55, tint: _CategoryTint.development),
  (label: 'Design', share: 0.25, tint: _CategoryTint.design),
  (label: 'Physical', share: 0.20, tint: _CategoryTint.physical),
];

/// Reference top bar: menu tile, `Payments` title, notification bell with
/// attention dot, role pill and account avatar (mirrors the overview top bar).
class _PaymentsTopBar extends StatelessWidget {
  const _PaymentsTopBar();

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
    String displayName = 'TV';
    try {
      final String? email = context.watch<AuthProvider>().currentSession?.email;
      if (email != null && email.isNotEmpty) {
        displayName = _initials(_prettifyEmailPrefix(email));
      }
    } catch (_) {
      displayName = 'TV';
    }
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
            'Payments',
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
              color: roles.clientContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: roles.clientPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.xs),
                Text(
                  'Employer',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: roles.clientPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Tooltip(
            message: 'Account',
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
                  displayName,
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

/// Payments content column: summary cards, escrow banner, history, then the
/// preserved money-movement and hires sections. Wide layouts (≥1000dp) render
/// the reference three-column summary row; narrower widths stack the same
/// cards so phones never squeeze or overflow.
class _PaymentsContent extends StatelessWidget {
  const _PaymentsContent({
    required this.maxWidth,
    required this.hires,
    required this.filter,
    required this.onFilter,
    required this.onRetry,
  });

  final double maxWidth;
  final HireProvider hires;
  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onFilter;
  final VoidCallback onRetry;

  /// Width at or above which the three-card summary row docks side by side.
  static const double summaryRowStart = 1000;

  @override
  Widget build(BuildContext context) {
    final double sectionGap = MobileCompact.sectionGapFor(maxWidth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SummaryCards(maxWidth: maxWidth),
        SizedBox(height: sectionGap),
        const _EscrowBanner(),
        SizedBox(height: sectionGap),
        _PaymentHistorySection(
          maxWidth: maxWidth,
          filter: filter,
          onFilter: onFilter,
        ),
        SizedBox(height: sectionGap),
        const HivorrSectionHeader(title: 'Money movement'),
        DashboardQuickActions(
          actions: <DashboardQuickAction>[
            DashboardQuickAction(
              label: 'Wallet',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => context.go(RoutePaths.finance),
            ),
            DashboardQuickAction(
              label: 'Escrow',
              icon: Icons.lock_outline,
              onTap: () => context.go(RoutePaths.escrow),
            ),
            DashboardQuickAction(
              label: 'Convert',
              icon: Icons.currency_exchange_outlined,
              onTap: () => context.go(RoutePaths.convert),
            ),
            DashboardQuickAction(
              label: 'Disputes',
              icon: Icons.flag_outlined,
              onTap: () => context.go(RoutePaths.disputes),
            ),
          ],
        ),
        SizedBox(height: sectionGap),
        const HivorrSectionHeader(title: 'Hires to fund'),
        _HiresToFund(hires: hires, onRetry: onRetry),
      ],
    );
  }
}

/// Reference summary row: blue balance, totals, spending by category.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bool wide =
        maxWidth >= _PaymentsContent.summaryRowStart;
    final double gap = MobileCompact.minorGapFor(maxWidth);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CompanyBalanceCard(),
          SizedBox(height: gap),
          const _TotalsCard(),
          SizedBox(height: gap),
          const _SpendingByCategoryCard(),
        ],
      );
    }
    return Row(
      // NOTE: `start`, not `stretch` — this row lives inside a vertical
      // scroll view (unbounded height), where stretch forces infinite
      // height and crashes layout. Cards keep natural heights instead.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(flex: 5, child: _CompanyBalanceCard()),
        SizedBox(width: gap),
        const Expanded(flex: 4, child: _TotalsCard()),
        SizedBox(width: gap),
        const Expanded(flex: 4, child: _SpendingByCategoryCard()),
      ],
    );
  }
}

/// Blue `Company Balance` hero card (reference, left column).
class _CompanyBalanceCard extends StatelessWidget {
  const _CompanyBalanceCard();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
      ),
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Company Balance',
            style: (compact
                    ? context.textTheme.bodySmall
                    : context.textTheme.bodyMedium)
                ?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: compact ? 13 : null,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.sm),
          Text(
            r'$8,600.00',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.headlineSmall
                    : context.textTheme.headlineMedium)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '~\u20A613,720,000',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: compact ? 12 : null,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.md : HivorrSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go(RoutePaths.finance),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Fund'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 10 : 14,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.finance),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text('Statement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    side: const BorderSide(
                      color: Colors.white60,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: compact ? 10 : 14,
                    ),
                    textStyle: const TextStyle(
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

/// White totals card: `Total Spent (MTD)` + `In Escrow` (reference, middle).
///
/// MOCK: renders [ClientSpendingMock.reference] until the monthly-spend and
/// escrow-hold seams exist — see `client_overview_mock.dart`.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard();

  @override
  Widget build(BuildContext context) {
    const ClientSpendingMock summary = ClientSpendingMock.reference;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    String grouped(double v) => HivorrFormatters.number(v, decimals: 0);
    return HivorrCard(
      borderRadius: compact ? 14 : 20,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _TotalRow(
            icon: Icons.arrow_upward,
            label: 'Total Spent (MTD)',
            value: '${summary.symbol}${grouped(summary.spent)}',
          ),
          Divider(
            height: compact ? HivorrSpacing.lg : HivorrSpacing.xl,
            color: context.colorScheme.outlineVariant,
          ),
          _TotalRow(
            icon: Icons.lock_outline,
            tile: _TotalTile.orange,
            label: 'In Escrow',
            value: '${summary.symbol}${grouped(summary.escrowHeld)}',
          ),
        ],
      ),
    );
  }
}

enum _TotalTile { red, orange }

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tile = _TotalTile.red,
  });

  final IconData icon;
  final String label;
  final String value;
  final _TotalTile tile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final Color tileBg =
        tile == _TotalTile.orange ? ext.warningContainer : colors.errorContainer;
    final Color iconFg =
        tile == _TotalTile.orange ? ext.warning : colors.error;
    final double tileSize = compact ? 44 : 52;
    return Row(
      children: <Widget>[
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
          ),
          child: Icon(icon, size: compact ? 22 : 26, color: iconFg),
        ),
        const SizedBox(width: HivorrSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? context.textTheme.titleLarge
                        : context.textTheme.headlineSmall)
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// White `Spending by Category` card (reference, right column).
class _SpendingByCategoryCard extends StatelessWidget {
  const _SpendingByCategoryCard();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return HivorrCard(
      borderRadius: compact ? 14 : 20,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Spending by Category',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 15 : 18,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          for (int i = 0; i < _spendingCategories.length; i++) ...<Widget>[
            if (i > 0)
              SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
            _CategoryRow(
              label: _spendingCategories[i].label,
              share: _spendingCategories[i].share,
              tint: _spendingCategories[i].tint,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.share,
    required this.tint,
  });

  final String label;
  final double share;
  final _CategoryTint tint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final Color bar = switch (tint) {
      _CategoryTint.development => colors.primary,
      _CategoryTint.design => colors.secondary,
      _CategoryTint.physical => context.appExtension.warning,
    };
    final String percent = '${(share * 100).round()}%';
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
                  color: colors.onSurfaceVariant,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              percent,
              style: context.textTheme.labelMedium?.copyWith(
                color: bar,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: compact ? 6 : 8,
            backgroundColor: colors.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(bar),
          ),
        ),
      ],
    );
  }
}

/// Orange escrow-hold banner (reference, below the summary row).
///
/// MOCK: placeholder copy/amount until the escrow-hold seam exists — see
/// `client_overview_mock.dart` (`escrowHeld`).
class _EscrowBanner extends StatelessWidget {
  const _EscrowBanner();

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Container(
      decoration: BoxDecoration(
        color: ext.warningContainer,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(
          color: ext.warning.withValues(alpha: 0.25),
        ),
      ),
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: compact ? 40 : 48,
            height: compact ? 40 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
            child: Icon(
              Icons.lock_outline,
              size: compact ? 20 : 24,
              color: ext.warning,
            ),
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Escrow Held \u2014 Office Renovation & Electrical',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Releases upon your approval \u00B7 Lagos Properties Ltd',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Text(
            r'$1,200',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleMedium
                    : context.textTheme.titleLarge)
                ?.copyWith(
              color: ext.warning,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reference `Payment History` section: title, filter chips, history card.
class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({
    required this.maxWidth,
    required this.filter,
    required this.onFilter,
  });

  final double maxWidth;
  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final bool compact = MobileCompact.isCompactWidth(maxWidth);
    final List<_PaymentHistoryEntry> all = _historyEntries();
    final List<_PaymentHistoryEntry> visible = switch (filter) {
      _HistoryFilter.all => all,
      _HistoryFilter.made =>
        all.where((_PaymentHistoryEntry e) => !e.isEscrow).toList(),
      _HistoryFilter.escrow =>
        all.where((_PaymentHistoryEntry e) => e.isEscrow).toList(),
    };
    final Widget chips = Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: <Widget>[
        for (final _HistoryFilter f in _HistoryFilter.values)
          _FilterChip(
            label: f.label,
            selected: f == filter,
            onTap: () => onFilter(f),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (compact) ...<Widget>[
          Text(
            'Payment History',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: chips,
          ),
        ] else
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Payment History',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.md),
              chips,
            ],
          ),
        SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        _HistoryCard(entries: visible, compact: compact),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(color: colors.outlineVariant),
        ),
        child: Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: selected
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

/// White history list card (reference): icon tile, title/meta, amount/status.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entries, required this.compact});

  final List<_PaymentHistoryEntry> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return HivorrCard(
        borderRadius: compact ? 14 : 16,
        child: Text(
          'No payments match this filter',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < entries.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            _HistoryRow(entry: entries[i], compact: compact),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.compact});

  final _PaymentHistoryEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final Color tileBg =
        entry.isEscrow ? ext.warningContainer : colors.errorContainer;
    final Color iconFg = entry.isEscrow ? ext.warning : colors.error;
    final Color amountFg = entry.isEscrow ? ext.warning : colors.error;
    final Color pillBg =
        entry.isEscrow ? ext.warningContainer : ext.successContainer;
    final Color pillFg = entry.isEscrow ? ext.warning : ext.success;
    final double tileSize = compact ? 40 : 48;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? HivorrSpacing.md : HivorrSpacing.lg,
        vertical: compact ? HivorrSpacing.sm + 4 : HivorrSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
            child: Icon(
              entry.isEscrow ? Icons.lock_outline : Icons.arrow_upward,
              size: compact ? 20 : 22,
              color: iconFg,
            ),
          ),
          SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                entry.amountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  color: amountFg,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 13 : 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.status,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: pillFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

/// Preserved hires list (existing mobile functionality): loading, error,
/// empty (`No payments yet`) and funded/fundable escrow rows.
class _HiresToFund extends StatelessWidget {
  const _HiresToFund({required this.hires, required this.onRetry});

  final HireProvider hires;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (hires.isLoading && hires.hires.isEmpty) {
      return const HivorrLoadingState();
    }
    if (hires.lastError != null && hires.hires.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load hires',
        detail: hires.lastError!.message,
        onRetry: onRetry,
      );
    }
    if (hires.hires.isEmpty) {
      return HivorrEmptyState(
        title: 'No payments yet',
        subtitle:
            'Funded escrows for your hires will appear here. Hire a professional to get started.',
        actionButton: HivorrButton(
          label: 'My Jobs',
          onPressed: () => context.go(RoutePaths.dashboardJobs),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Hire hire in hires.hires)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: HireCard(
              hire: hire,
              onTap: () =>
                  context.go(RoutePaths.dashboardHireDetail(hire.id)),
            ),
          ),
      ],
    );
  }
}

/// Identity name derived from the verified sign-in email (mirrors overview).
String _prettifyEmailPrefix(String email) {
  final String local = email.split('@').first.trim();
  if (local.isEmpty) {
    return 'TV';
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
    return 'TV';
  }
  return words.join(' ');
}

/// Up-to-two-letter avatar initials for a display name.
String _initials(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'TV';
  }
  final String first = words.first[0].toUpperCase();
  if (words.length == 1) {
    return first;
  }
  return '$first${words[1][0].toUpperCase()}';
}

/// Professional earnings hub (EP-04-03).
///
/// Composes the professional's work (hires won) with entry points into the
/// existing finance surfaces. Payouts and balances stay owned by the finance
/// providers.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      context.read<HireProvider>().loadList(role: 'professional');

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final int active = hires.hires.where((Hire h) => h.isActive).length;
    final int completed = hires.hires
        .where((Hire h) => h.liveStatus == 'completed')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Earnings', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HivorrCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _Stat(label: 'Active work', value: '$active'),
                      ),
                      Expanded(
                        child: _Stat(label: 'Completed', value: '$completed'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
                DashboardQuickActions(
                  actions: <DashboardQuickAction>[
                    DashboardQuickAction(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => context.go(RoutePaths.finance),
                    ),
                    DashboardQuickAction(
                      label: 'Escrow',
                      icon: Icons.lock_outline,
                      onTap: () => context.go(RoutePaths.escrow),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.xl),
                const HivorrSectionHeader(title: 'Work history'),
                if (hires.isLoading && hires.hires.isEmpty)
                  const HivorrLoadingState()
                else if (hires.lastError != null && hires.hires.isEmpty)
                  HivorrErrorState(
                    message: 'Could not load work',
                    detail: hires.lastError!.message,
                    onRetry: () => unawaited(_load()),
                  )
                else if (hires.hires.isEmpty)
                  HivorrEmptyState(
                    title: 'No earnings yet',
                    subtitle:
                        'Win work through applications — completed hires and their payouts land here.',
                    actionButton: HivorrButton(
                      label: 'Find Jobs',
                      onPressed: () =>
                          context.go(RoutePaths.dashboardOpportunities),
                    ),
                  )
                else
                  ...hires.hires.map(
                    (Hire hire) => Padding(
                      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
                      child: HireCard(
                        hire: hire,
                        onTap: () =>
                            context.go(RoutePaths.dashboardHireDetail(hire.id)),
                      ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
