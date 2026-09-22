import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:provider/provider.dart';

/// Super Admin landing dashboard.
///
/// Shows operational stats only where backend data exists; everything else
/// is an explicit empty/loading/unavailable state (no mocked numbers).
/// Reuses [ManageUserProvider] and [AdminReviewProvider] — no duplicate services.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    if (!mounted) return;
    final AdminReviewProvider admin = context.read<AdminReviewProvider>();
    final ManageUserProvider users = context.read<ManageUserProvider>();
    await admin.checkAdmin();
    if (!mounted) return;
    if (AdminGate.isAdmin(admin)) {
      // Seed total users for stat cards. Failure surfaces via provider.lastError.
      if (!users.isListHydrated) {
        unawaited(users.loadUsers());
      }
      // Seed review queue count for pending approvals card.
      if (admin.queue.isEmpty && !admin.isLoadingQueue) {
        unawaited(admin.loadQueue());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider admin = context.watch<AdminReviewProvider>();
    final ManageUserProvider users = context.watch<ManageUserProvider>();
    final bool isAdmin = AdminGate.isAdmin(admin);

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              unawaited(users.loadUsers(
                search: users.search,
                status: users.statusFilter,
                capability: users.capabilityFilter,
              ));
              unawaited(admin.loadQueue());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: !isAdmin
            ? HivorrEmptyState(
                icon: Icon(Icons.admin_panel_settings_outlined,
                    color: context.colorScheme.primary),
                title: 'Admin access required',
                subtitle: 'You do not have platform admin privileges.',
              )
            : LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final bool isWide = c.maxWidth >= 720;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(HivorrSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text('Overview',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: HivorrSpacing.md),
                        Wrap(
                          spacing: HivorrSpacing.md,
                          runSpacing: HivorrSpacing.md,
                          children: <Widget>[
                            _StatCard(
                              icon: Icons.group_outlined,
                              label: 'Total Users',
                              value: users.isLoading && !users.isListHydrated
                                  ? '…'
                                  : users.isListHydrated
                                      ? '${users.totalCount}'
                                      : '—',
                              subtitle: users.lastError != null &&
                                      !users.isListHydrated
                                  ? users.lastError!.message
                                  : 'From directory',
                              onTap: () =>
                                  context.go(RoutePaths.adminManageUsers),
                              width: isWide ? 220 : c.maxWidth,
                            ),
                            _StatCard(
                              icon: Icons.verified_user_outlined,
                              label: 'Pending Verifications',
                              value: admin.isLoadingQueue && admin.queue.isEmpty
                                  ? '…'
                                  : '${admin.queue.length}',
                              subtitle: admin.lastError != null &&
                                      admin.queue.isEmpty
                                  ? admin.lastError!.message
                                  : 'Awaiting review',
                              onTap: () => context
                                  .go(RoutePaths.adminVerificationApprovals),
                              width: isWide ? 220 : c.maxWidth,
                            ),
                            _StatCard(
                              icon: Icons.task_alt,
                              label: 'Approved Submissions',
                              value: '—',
                              subtitle: 'Not yet connected',
                              width: isWide ? 220 : c.maxWidth,
                            ),
                            _StatCard(
                              icon: Icons.block_outlined,
                              label: 'Rejected',
                              value: '—',
                              subtitle: 'Not yet connected',
                              width: isWide ? 220 : c.maxWidth,
                            ),
                          ],
                        ),
                        const SizedBox(height: HivorrSpacing.xl),
                        Text('Quick actions',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: HivorrSpacing.sm),
                        Wrap(
                          spacing: HivorrSpacing.sm,
                          runSpacing: HivorrSpacing.sm,
                          children: <Widget>[
                            HivorrButton(
                              label: 'View users',
                              onPressed: () =>
                                  context.go(RoutePaths.adminManageUsers),
                            ),
                            HivorrButton(
                              label: 'Verification & Approvals',
                              variant: HivorrButtonVariant.outline,
                              onPressed: () => context.go(
                                  RoutePaths.adminVerificationApprovals),
                            ),
                          ],
                        ),
                        const SizedBox(height: HivorrSpacing.xl),
                        Text('Recent activity',
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: HivorrSpacing.sm),
                        HivorrCard(
                          child: Padding(
                            padding: const EdgeInsets.all(HivorrSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('No dedicated activity feed yet.',
                                    style: context.textTheme.bodyMedium),
                                const SizedBox(height: HivorrSpacing.xs),
                                Text(
                                  'Recent verification submissions and new registrations will appear here once the aggregation RPC lands. For now use Verification & Approvals and Users.',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: HivorrSpacing.lg),
                        HivorrCard(
                          child: Padding(
                            padding: const EdgeInsets.all(HivorrSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Charts',
                                    style: context.textTheme.titleSmall),
                                const SizedBox(height: HivorrSpacing.xs),
                                Text(
                                  'User growth and verification trend charts will render here when the analytics source is connected. No mock data.',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.width,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return SizedBox(
      width: width,
      child: HivorrCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(HivorrSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 18, color: colors.primary),
                  const SizedBox(width: HivorrSpacing.sm),
                  Expanded(
                    child: Text(label,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.sm),
              Text(value, style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: HivorrSpacing.xs),
              Text(subtitle,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
