import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Account hub: identity, capability, verification, and service surfaces
/// (EP-04-03).
///
/// Composes existing destinations (professional profile, verification, KYC,
/// finance, listings, portfolio) instead of duplicating them. Replaces the
/// `/profile` placeholder for dashboard users.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final DashboardCapability capability = DashboardCapability.fromEntity(
      onboarding.progress?.capability ?? EntityCapability.both,
    );
    final String email = auth.currentSession?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Account', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              HivorrCard(
                child: Row(
                  children: <Widget>[
                    const HivorrAvatar(size: 56),
                    const SizedBox(width: HivorrSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            capability.label,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HivorrSpacing.xl),
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
              if (capability.showsWork) ...<Widget>[
                _Link(
                  icon: Icons.work_outline,
                  label: 'My service listings',
                  onTap: () => context.go(RoutePaths.serviceListingsMine),
                ),
              ],
              const SizedBox(height: HivorrSpacing.xl),
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
              const SizedBox(height: HivorrSpacing.xl),
              HivorrButton(
                label: 'Sign out',
                variant: HivorrButtonVariant.outline,
                onPressed: () => auth.signOut(),
              ),
            ],
          ),
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
