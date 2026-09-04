import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/widgets/balance_overview_card.dart';
import 'package:hivorr/systems/finance/widgets/currency_account_card.dart';
import 'package:hivorr/systems/finance/widgets/financial_profile_card.dart';
import 'package:provider/provider.dart';

/// Main financial profile overview screen (EP-02-13 §5.6).
///
/// Shows profile card, balance overview, and currency account list. When no
/// profile exists, shows an empty state with a creation CTA. Pauses/resumes
/// provider polling with the app lifecycle via [WidgetsBindingObserver].
class FinancialProfileScreen extends StatefulWidget {
  const FinancialProfileScreen({super.key});

  @override
  State<FinancialProfileScreen> createState() => _FinancialProfileScreenState();
}

class _FinancialProfileScreenState extends State<FinancialProfileScreen>
    with WidgetsBindingObserver {
  late final FinancialProvider _provider;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<FinancialProvider>();
    if (!_initialized) {
      _initialized = true;
      _provider.startPolling();
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_provider.load());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.resumePolling();
    } else {
      _provider.pausePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Financial Profile',
          style: context.textTheme.titleLarge,
        ),
        actions: <Widget>[
          Consumer<FinancialProvider>(
            builder: (BuildContext context, FinancialProvider provider, _) {
              if (provider.profile == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Manage',
                onPressed: () => context.push('/finance/create'),
              );
            },
          ),
        ],
      ),
      body: Consumer<FinancialProvider>(
        builder: (BuildContext context, FinancialProvider provider, _) {
          if (provider.isLoading && !provider.isLoaded) {
            return const HivorrLoadingState(
              message: 'Loading financial profile...',
            );
          }

          if (provider.lastError != null && !provider.isLoaded) {
            return HivorrErrorState(
              message: 'Failed to load financial profile',
              detail: provider.lastError!.message,
              onRetry: () => provider.load(),
            );
          }

          // Profile not created yet.
          if (provider.profile == null) {
            return HivorrEmptyState(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              title: 'No financial profile yet',
              subtitle:
                  'Create your financial profile to start receiving payments in NGN, GHS, USD, or GBP.',
              actionButton: HivorrButton(
                label: 'Set up your financial profile',
                onPressed: () => context.push('/finance/create'),
              ),
            );
          }

          // Terminal status: balances still visible read-only, but surface a
          // warm state with a "Contact support" call to action (FV-34).
          final String profileStatus = provider.status?.profileStatus ?? '';
          final bool terminal = profileStatus == 'suspended' ||
              profileStatus == 'closed';
          if (terminal) {
            return ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                HivorrErrorState(
                  message: profileStatus == 'suspended'
                      ? 'Your financial profile is suspended'
                      : 'Your financial profile is closed',
                  detail: 'Contact support to resolve this.',
                ),
                const SizedBox(height: HivorrSpacing.md),
                FinancialProfileCard(profile: provider.profile!),
                if (provider.balances.isNotEmpty) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.lg),
                  BalanceOverviewCard(
                    balances: provider.balances,
                    defaultCurrencyCode:
                        provider.profile!.defaultCurrency,
                  ),
                ],
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.refreshStatus(),
            child: ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                // Profile header card.
                FinancialProfileCard(profile: provider.profile!),
                const SizedBox(height: HivorrSpacing.lg),

                // Balance overview.
                BalanceOverviewCard(
                  balances: provider.balances,
                  defaultCurrencyCode:
                      provider.profile!.defaultCurrency,
                ),
                const SizedBox(height: HivorrSpacing.lg),

                // Currency accounts list.
                if (provider.accounts.isNotEmpty) ...<Widget>[
                  Text('Receiving Accounts', style: context.textTheme.titleMedium),
                  const SizedBox(height: HivorrSpacing.sm),
                  ...provider.accounts.map(
                    (CurrencyAccount account) => Padding(
                      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
                      child: CurrencyAccountCard(account: account),
                    ),
                  ),
                ] else ...<Widget>[
                  Text('Receiving Accounts', style: context.textTheme.titleMedium),
                  const SizedBox(height: HivorrSpacing.sm),
                  Text(
                    'No receiving accounts configured yet.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
