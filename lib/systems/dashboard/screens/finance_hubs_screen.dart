import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/components/hivorr_month_bars.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/analytics/services/service_analytics_service.dart';
import 'package:hivorr/systems/dashboard/models/client_overview_mock.dart';
import 'package:hivorr/systems/dashboard/shell/client_mobile_chrome.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/quick_actions.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/widgets/earnings_transaction_tile.dart';
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
      // Single page title (`Payments`) on the shared client chrome; no
      // refresh action — the content RefreshIndicator below covers reloads.
      return Scaffold(
        drawer: const ClientDashboardDrawer(),
        appBar: const ClientMobileAppBar(title: 'Payments'),
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
    return HivorrDashboardTopBar(
      title: 'Payments',
      accentPrimary: roles.clientPrimary,
      accentContainer: roles.clientContainer,
      modeLabel: 'Client',
      initials: displayName,
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

/// Payments content column: summary cards, escrow banner, history, then the
/// preserved money-movement and hires sections. Wide layouts (≥1000dp) render
/// the reference three-column summary row; tablets stack the same cards, and
/// phones (<600dp) show the balance hero only per the mobile reference — so
/// phones never squeeze or overflow.
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
      // Phones (<600dp) show the reference balance hero only — the mobile
      // reference flows straight into the escrow banner, and both hidden
      // cards are mock placeholders (their live counterparts: the escrow
      // banner, history list and money-movement section below). Tablets keep
      // the stacked trio untouched.
      if (MobileCompact.isCompactWidth(maxWidth)) {
        return const _CompanyBalanceCard();
      }
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
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(ext.radiusMd),
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
              // White-on-brand is a deliberate §16-style exception: the
              // balance fill is brand in both themes.
              color: Colors.white.withValues(alpha: 0.85),
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
              fontWeight: FontWeight.w700,
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
                    foregroundColor: colors.primary,
                    elevation: 0,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ext.radiusXs),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: HivorrSpacing.smMd,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
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
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ext.radiusXs),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: HivorrSpacing.smMd,
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
    final double tileSize = compact ? 32 : 40;
    return Row(
      children: <Widget>[
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(
              compact ? ext.radiusXs : ext.radiusMd,
            ),
          ),
          child: Icon(icon, size: compact ? 20 : 24, color: iconFg),
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
                    ?.copyWith(fontWeight: FontWeight.w700),
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
              fontWeight: FontWeight.w600,
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
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              percent,
              style: context.textTheme.labelMedium?.copyWith(
                color: bar,
                fontWeight: FontWeight.w700,
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
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(
                compact ? ext.radiusXs : ext.radiusMd,
              ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Releases upon your approval \u00B7 Lagos Properties Ltd',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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
              fontWeight: FontWeight.w700,
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
          HivorrChip(
            label: f.label,
            isSelected: f == filter,
            onSelected: (_) => onFilter(f),
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
              fontWeight: FontWeight.w600,
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
                    fontWeight: FontWeight.w600,
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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
                  fontWeight: FontWeight.w700,
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

/// Professional earnings hub (EP-04-03) — Professional Dashboard → Earnings.
///
/// Desktop (≥1024dp, validated first against `pro earning.png`) renders the
/// reference layout: a top bar (`Earnings` title, notification bell, green
/// `Professional` pill, dynamic-initials avatar), a three-card summary row
/// (green Available Balance, totals, Monthly Earnings chart), the
/// escrow-pending banner, and the filterable Earnings History list. Narrower
/// layouts stack the same sections in the same order — no desktop-only
/// assumptions, no separate mobile implementation.
///
/// The pre-existing professional functionality is preserved below the
/// reference sections (the `Work history` hires list with loading / error /
/// empty states), so nothing that worked is removed; it simply follows the
/// history list. Money movement stays owned by the finance providers — this
/// screen routes and summarizes.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  _EarningsFilter _filter = _EarningsFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final HireProvider hires = context.read<HireProvider>();
    final EarningsProvider? earnings = _maybeEarnings(context);
    final TransactionHistoryProvider? history = _maybeHistory(context);
    await hires.loadList(role: 'professional');
    if (!mounted) return;
    await earnings?.load();
    if (!mounted) return;
    await history?.load();
  }

  /// Reads the earnings summary provider when mounted in the tree; `null`
  /// in isolated widget harnesses (honest loading/empty states render).
  EarningsProvider? _maybeEarnings(BuildContext context) {
    try {
      return context.read<EarningsProvider>();
    } on Object catch (_) {
      debugPrint('Earnings summary provider unavailable; showing fallback.');
      return null;
    }
  }

  /// Reads the history provider when mounted in the tree; `null` in
  /// isolated widget harnesses.
  TransactionHistoryProvider? _maybeHistory(BuildContext context) {
    try {
      return context.read<TransactionHistoryProvider>();
    } on Object catch (_) {
      debugPrint('Transaction history provider unavailable; showing fallback.');
      return null;
    }
  }

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
            child: _EarningsContent(
              maxWidth: c.maxWidth,
              hires: hires,
              filter: _filter,
              onFilter: (_EarningsFilter f) {
                setState(() => _filter = f);
                // Drive the server filter alongside the chip selection;
                // absence (isolated harnesses) keeps chip-only behavior.
                try {
                  unawaited(
                    context.read<TransactionHistoryProvider>().setType(
                      _earningsHistoryType(f),
                    ),
                  );
                } on Object catch (_) {
                  debugPrint('History filter is chip-only without provider.');
                }
              },
              onRetry: () => unawaited(_load()),
            ),
          );
        },
      ),
    );

    if (isMobile) {
      // Single page title (`Earnings`); no refresh action — the content
      // RefreshIndicator below covers reloads.
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 48,
          title: Text(
            'Earnings',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
        const _EarningsTopBar(),
        Expanded(child: content),
      ],
    );
  }
}

/// History filter behind the `Earnings History` chips (reference).
enum _EarningsFilter {
  all('All'),
  earned('Earned'),
  withdrawn('Withdrawn');

  const _EarningsFilter(this.label);

  final String label;
}

/// Maps a hub filter chip to the EP-03-16 server filter vocabulary.
String _earningsHistoryType(_EarningsFilter filter) => switch (filter) {
  _EarningsFilter.all => EarningsHistoryFilter.all,
  _EarningsFilter.earned => EarningsHistoryFilter.earned,
  _EarningsFilter.withdrawn => EarningsHistoryFilter.withdrawn,
};

/// Live server-verified summary when the EP-03-16 providers are mounted;
/// `null` in isolated harnesses (honest loading/empty states preserved).
EarningsSummary? _liveEarningsSummary(BuildContext context) {
  try {
    return context.watch<EarningsProvider>().summary;
  } catch (_) {
    return null;
  }
}

/// Live history provider when mounted; `null` in isolated harnesses.
TransactionHistoryProvider? _liveHistory(BuildContext context) {
  try {
    return context.watch<TransactionHistoryProvider>();
  } catch (_) {
    return null;
  }
}

/// Reference top bar: menu tile, `Earnings` title, notification bell with
/// attention dot, green `Professional` pill and dynamic-initials avatar
/// (mirrors the professional overview top bar).
class _EarningsTopBar extends StatelessWidget {
  const _EarningsTopBar();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    int activeHires = 0;
    int appliedCount = 0;
    try {
      activeHires = context
          .watch<HireProvider>()
          .hires
          .where((Hire hire) => hire.isActive)
          .length;
    } catch (_) {
      activeHires = 0;
    }
    try {
      appliedCount = context.watch<JobProvider>().applied.length;
    } catch (_) {
      appliedCount = 0;
    }
    final bool hasDot = activeHires > 0 || appliedCount > 0;
    final ({String name, String initials}) identity =
        _earningsProIdentity(context);
    return HivorrDashboardTopBar(
      title: 'Earnings',
      accentPrimary: roles.professionalPrimary,
      accentContainer: roles.professionalContainer,
      modeLabel: 'Professional',
      initials: identity.initials,
      avatarTooltip: identity.name,
      showDot: hasDot,
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

/// Earnings content column: summary cards, escrow banner, history, then the
/// preserved work-history section. Wide layouts (≥1000dp) render the
/// reference three-column summary row; narrower widths stack the same cards
/// so phones never squeeze or overflow.
class _EarningsContent extends StatelessWidget {
  const _EarningsContent({
    required this.maxWidth,
    required this.hires,
    required this.filter,
    required this.onFilter,
    required this.onRetry,
  });

  final double maxWidth;
  final HireProvider hires;
  final _EarningsFilter filter;
  final ValueChanged<_EarningsFilter> onFilter;
  final VoidCallback onRetry;

  /// Width at or above which the three-card summary row docks side by side.
  static const double summaryRowStart = 1000;

  @override
  Widget build(BuildContext context) {
    final double sectionGap = MobileCompact.sectionGapFor(maxWidth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EarningsSummaryCards(maxWidth: maxWidth),
        SizedBox(height: sectionGap),
        const _EarningsEscrowBanner(),
        SizedBox(height: sectionGap),
        _EarningsHistorySection(
          maxWidth: maxWidth,
          filter: filter,
          onFilter: onFilter,
        ),
        SizedBox(height: sectionGap),
        const HivorrSectionHeader(title: 'Work history'),
        _EarningsWorkHistory(hires: hires, onRetry: onRetry),
      ],
    );
  }
}

/// Reference summary row: green balance, totals, monthly chart.
class _EarningsSummaryCards extends StatelessWidget {
  const _EarningsSummaryCards({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bool wide =
        maxWidth >= _EarningsContent.summaryRowStart;
    final double gap = MobileCompact.minorGapFor(maxWidth);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _AvailableBalanceCard(),
          SizedBox(height: gap),
          const _EarningsTotalsCard(),
          SizedBox(height: gap),
          const _MonthlyEarningsCard(),
        ],
      );
    }
    return Row(
      // NOTE: `start`, not `stretch` — this row lives inside a vertical
      // scroll view (unbounded height), where stretch forces infinite
      // height and crashes layout. Cards keep natural heights instead.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(flex: 5, child: _AvailableBalanceCard()),
        SizedBox(width: gap),
        const Expanded(flex: 4, child: _EarningsTotalsCard()),
        SizedBox(width: gap),
        const Expanded(flex: 4, child: _MonthlyEarningsCard()),
      ],
    );
  }
}

/// Green `Available Balance` hero card (reference, left column).
class _AvailableBalanceCard extends StatelessWidget {
  const _AvailableBalanceCard();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final AppThemeExtension ext = context.appExtension;
    final Color green = roles.professionalPrimary;
    return Container(
      decoration: BoxDecoration(
        color: green,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Available Balance',
            style: (compact
                    ? context.textTheme.bodySmall
                    : context.textTheme.bodyMedium)
                ?.copyWith(
              // White-on-brand is a deliberate §16-style exception: the
              // balance fill is brand in both themes.
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.sm),
          Builder(
            builder: (BuildContext context) {
              // Live server-verified available balance (EP-03-16); the
              // reference figure below renders only when the earnings
              // providers are absent (isolated harnesses).
              final EarningsSummary? live = _liveEarningsSummary(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    live == null
                        ? r'$6,154.00'
                        : BalanceFormatter.formatBalance(
                            live.availableBalance,
                            live.currencyCode,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (compact
                            ? context.textTheme.headlineSmall
                            : context.textTheme.headlineMedium)
                        ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    live == null
                        ? '≈ \u20A69,806,000'
                        : 'Server-verified · ${live.currencyCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: compact ? HivorrSpacing.md : HivorrSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go(RoutePaths.finance),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Withdraw'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: green,
                    elevation: 0,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ext.radiusXs),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: HivorrSpacing.smMd,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
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
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ext.radiusXs),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: HivorrSpacing.smMd,
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

/// White totals card: `Total Earned (All Time)` + `In Escrow (Pending)`
/// (reference, middle). Values are live server aggregates when the EP-03-16
/// providers are mounted, reference figures otherwise.
class _EarningsTotalsCard extends StatelessWidget {
  const _EarningsTotalsCard();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    // Live server-verified totals (EP-03-16); reference figures render only
    // when the earnings providers are absent (isolated harnesses).
    final EarningsSummary? live = _liveEarningsSummary(context);
    final String earned = live == null
        ? r'$28,900'
        : BalanceFormatter.formatBalance(
            live.lifetimeEarned,
            live.currencyCode,
          );
    final String held = live == null
        ? r'$2,800'
        : BalanceFormatter.formatBalance(live.heldBalance, live.currencyCode);
    return HivorrCard(
      borderRadius: compact ? 14 : 20,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _EarningsTotalRow(
            icon: Icons.trending_up,
            label: 'Total Earned (All Time)',
            value: earned,
            tile: _EarningsTotalTile.green,
          ),
          Divider(
            height: compact ? HivorrSpacing.lg : HivorrSpacing.xl,
            color: context.colorScheme.outlineVariant,
          ),
          _EarningsTotalRow(
            icon: Icons.lock_outline,
            tile: _EarningsTotalTile.orange,
            label: 'In Escrow (Pending)',
            value: held,
          ),
        ],
      ),
    );
  }
}

enum _EarningsTotalTile { green, orange }

class _EarningsTotalRow extends StatelessWidget {
  const _EarningsTotalRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tile = _EarningsTotalTile.green,
  });

  final IconData icon;
  final String label;
  final String value;
  final _EarningsTotalTile tile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final Color tileBg =
        tile == _EarningsTotalTile.orange ? ext.warningContainer : ext.successContainer;
    final Color iconFg =
        tile == _EarningsTotalTile.orange ? ext.warning : ext.success;
    final double tileSize = compact ? 32 : 40;
    return Row(
      children: <Widget>[
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(
              compact ? ext.radiusXs : ext.radiusMd,
            ),
          ),
          child: Icon(icon, size: compact ? 20 : 24, color: iconFg),
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
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// White `Monthly Earnings` chart card (reference, right column).
///
/// Live server month buckets via [HivorrMonthBars] when the EP-03-16
/// providers are mounted (honest `No earnings yet` when empty — never
/// invented bars); the reference shape below renders only when the earnings
/// providers are absent (isolated harnesses).
class _MonthlyEarningsCard extends StatelessWidget {
  const _MonthlyEarningsCard();

  static const ServiceAnalyticsService _analytics = ServiceAnalyticsService();

  static const List<double> _bars = <double>[
    0.35, 0.55, 0.45, 0.7, 0.6, 0.75, 0.65, 0.85, 0.7, 0.8, 0.6, 1.0,
  ];

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final RoleThemeExtension roles = context.roleTheme;
    // Live server buckets (EP-03-16) take precedence over the reference
    // shape below.
    final EarningsSummary? live = _liveEarningsSummary(context);
    if (live != null) {
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
              'Monthly Earnings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
            HivorrMonthBars(
              items: _analytics.monthBucketsToChartData(live.monthly),
              emptyLabel: 'No earnings yet.',
              accent: roles.professionalPrimary,
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              live.releaseCount == 1
                  ? 'Across 1 release'
                  : 'Across ${live.releaseCount} releases',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final Color barLight =
        roles.professionalPrimary.withValues(alpha: 0.18);
    final Color barDark = roles.professionalPrimary;
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
            'Monthly Earnings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < _bars.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 3,
                        right: i == _bars.length - 1 ? 0 : 3,
                      ),
                      child: Container(
                        height: 120 * _bars[i],
                        decoration: BoxDecoration(
                          color: i == _bars.length - 1 ? barDark : barLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            '+23% vs last month',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Orange escrow-pending banner (reference, below the summary row).
///
/// Live held balance when the EP-03-16 providers are mounted; honest copy in
/// both cases (no client-specific placeholders).
class _EarningsEscrowBanner extends StatelessWidget {
  const _EarningsEscrowBanner();

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    // Live server-verified held balance (EP-03-16); the reference figure
    // renders only when the earnings providers are absent.
    final EarningsSummary? live = _liveEarningsSummary(context);
    final String held = live == null
        ? r'$2,800'
        : BalanceFormatter.formatBalance(
            live.heldBalance,
            live.currencyCode,
          );
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
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(
                compact ? ext.radiusXs : ext.radiusMd,
              ),
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
                  'Held in escrow',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Releases when the client approves your delivery',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Text(
            held,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleMedium
                    : context.textTheme.titleLarge)
                ?.copyWith(
              color: ext.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reference `Earnings History` section: title, filter chips, history card.
class _EarningsHistorySection extends StatelessWidget {
  const _EarningsHistorySection({
    required this.maxWidth,
    required this.filter,
    required this.onFilter,
  });

  final double maxWidth;
  final _EarningsFilter filter;
  final ValueChanged<_EarningsFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final bool compact = MobileCompact.isCompactWidth(maxWidth);
    // Live server ledger (EP-03-16) when mounted; honest empty state in
    // isolated harnesses (mock rows removed — see TIP §7.4).
    final TransactionHistoryProvider? live = _liveHistory(context);
    final Widget chips = Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: <Widget>[
        for (final _EarningsFilter f in _EarningsFilter.values)
          _EarningsFilterChip(
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
            'Earnings History',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
                  'Earnings History',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.md),
              chips,
            ],
          ),
        SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        if (live == null)
          const HivorrEmptyState(
            title: 'No activity yet',
            subtitle: 'Released payments and withdrawals will appear here.',
            compact: true,
          )
        else
          _LiveEarningsHistory(provider: live, compact: compact),
      ],
    );
  }
}

class _EarningsFilterChip extends StatelessWidget {
  const _EarningsFilterChip({
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
    final RoleThemeExtension roles = context.roleTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? roles.professionalPrimary : colors.surface,
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
          ),
        ),
      ),
    );
  }
}

/// Live server-ledger history list (EP-03-16): rows render verbatim in server
/// order via [EarningsTransactionTile] and drill into the attributed
/// contract. Honest empty/error states — no invented rows.
class _LiveEarningsHistory extends StatelessWidget {
  const _LiveEarningsHistory({required this.provider, required this.compact});

  final TransactionHistoryProvider provider;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const HivorrLoadingState(message: 'Loading history...');
    }
    if (provider.lastError != null && provider.items.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load history',
        detail: provider.lastError!.message,
        onRetry: () => provider.load(),
      );
    }
    if (provider.items.isEmpty) {
      final bool filtered =
          provider.typeFilter != EarningsHistoryFilter.all;
      return HivorrEmptyState(
        title: filtered ? 'No matches' : 'No activity yet',
        subtitle: filtered
            ? 'No earnings match this filter.'
            : 'Released payments and withdrawals will appear here.',
        compact: true,
      );
    }
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < provider.items.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            EarningsTransactionTile(
              transaction: provider.items[i],
              onTap: provider.items[i].contractId == null
                  ? null
                  : () => context.push(
                      RoutePaths.contractEarningsDetail(
                        provider.items[i].contractId!,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Preserved work-history list (existing professional functionality):
/// loading, error, empty (`No earnings yet`) and live hire rows.
class _EarningsWorkHistory extends StatelessWidget {
  const _EarningsWorkHistory({required this.hires, required this.onRetry});

  final HireProvider hires;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (hires.isLoading && hires.hires.isEmpty) {
      return const HivorrLoadingState();
    }
    if (hires.lastError != null && hires.hires.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load work',
        detail: hires.lastError!.message,
        onRetry: onRetry,
      );
    }
    if (hires.hires.isEmpty) {
      return HivorrEmptyState(
        title: 'No earnings yet',
        subtitle:
            'Win work through applications — completed hires and their payouts land here.',
        actionButton: HivorrButton(
          label: 'Find Jobs',
          onPressed: () => context.go(RoutePaths.dashboardOpportunities),
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

/// Professional identity from stored backend profile data.
///
/// Prefers AuthSession first/last names (`user_metadata` /
/// `entity_profiles`); falls back to displayName, then the email
/// local-part — never hardcoded. Reuses the file-local
/// [_prettifyEmailPrefix] / [_initials] helpers.
({String name, String initials}) _earningsProIdentity(BuildContext context) {
  try {
    final AuthProvider auth = context.watch<AuthProvider>();
    final session = auth.currentSession;
    final String? full = session?.fullName;
    if (full != null && full.isNotEmpty) {
      return (
        name: full,
        initials: session!.initials ?? _initials(full),
      );
    }
    final String? display = session?.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return (
        name: display,
        initials: session!.initials ?? _initials(display),
      );
    }
    final String? email = session?.email;
    if (email != null && email.isNotEmpty) {
      final String pretty = _prettifyEmailPrefix(email);
      return (name: pretty, initials: _initials(pretty));
    }
  } catch (_) {
    // Auth provider absent (isolated test) — fall through.
  }
  return (name: 'Professional', initials: 'P');
}
