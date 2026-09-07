import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/models/payout_tab.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_card.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_form_view.dart';
import 'package:hivorr/systems/finance/widgets/payout_withdraw_form_view.dart';
import 'package:provider/provider.dart';

/// Payout accounts section (EP-02-16 §5.6).
///
/// Hosts the Accounts / Withdraw tabs and the bind form. Bound accounts come
/// from the client mirror (the authenticated role has no SELECT grant on
/// `financial_payout_accounts`); binding and withdrawal are server-authoritative
/// RPCs.
class PayoutAccountView extends StatefulWidget {
  const PayoutAccountView({
    super.key,
    this.cashoutLimit,
    this.currencyCode = 'NGN',
    this.onWithdrawSuccess,
  });

  /// KYC-derived cashout limit forwarded to the withdraw form.
  final double? cashoutLimit;

  /// Currency code used to display [cashoutLimit].
  final String currencyCode;

  /// Invoked after a server-confirmed withdrawal (e.g. balance refresh).
  final ValueChanged<WithdrawalResult>? onWithdrawSuccess;

  @override
  State<PayoutAccountView> createState() => _PayoutAccountViewState();
}

class _PayoutAccountViewState extends State<PayoutAccountView> {
  PayoutTab _tab = PayoutTab.accounts;
  bool _showForm = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final FinancialPayoutProvider provider =
          context.read<FinancialPayoutProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(provider.load());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TabSelector(
          tab: _tab,
          onChanged: (PayoutTab tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: HivorrSpacing.md),
        if (_tab == PayoutTab.accounts)
          _buildAccountsTab(context)
        else
          _buildWithdrawTab(context),
      ],
    );
  }

  Widget _buildAccountsTab(BuildContext context) {
    final FinancialPayoutProvider provider = context
        .watch<FinancialPayoutProvider>();

    if (provider.isLoading && !provider.isLoaded) {
      return const HivorrLoadingState(message: 'Loading payout accounts...');
    }
    if (provider.lastError != null && !provider.isLoaded) {
      return HivorrErrorState(
        message: 'Failed to load payout accounts',
        detail: provider.lastError!.message,
        onRetry: () => provider.load(),
      );
    }

    if (_showForm) {
      return PayoutAccountFormView(
        onBound: (PayoutAccount _) => setState(() => _showForm = false),
      );
    }

    if (provider.accounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HivorrEmptyState(
            icon: const Icon(Icons.account_balance_outlined),
            title: 'No payout accounts bound',
            subtitle:
                'Bind a bank account to receive payouts. Ownership is verified '
                'before withdrawals are allowed.',
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Bind payout account',
            isExpanded: true,
            onPressed: () => setState(() => _showForm = true),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...provider.accounts.map(
          (PayoutAccount account) => Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: PayoutAccountCard(account: account),
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        HivorrButton(
          label: 'Bind payout account',
          variant: HivorrButtonVariant.outline,
          isExpanded: true,
          onPressed: () => setState(() => _showForm = true),
        ),
      ],
    );
  }

  Widget _buildWithdrawTab(BuildContext context) {
    return PayoutWithdrawFormView(
      cashoutLimit: widget.cashoutLimit,
      currencyCode: widget.currencyCode,
      onWithdrawSuccess: widget.onWithdrawSuccess,
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.tab, required this.onChanged});

  final PayoutTab tab;
  final ValueChanged<PayoutTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TabSegment(
            label: 'Accounts',
            isSelected: tab == PayoutTab.accounts,
            onTap: () => onChanged(PayoutTab.accounts),
          ),
        ),
        const SizedBox(width: HivorrSpacing.sm),
        Expanded(
          child: _TabSegment(
            label: 'Withdraw',
            isSelected: tab == PayoutTab.withdraw,
            onTap: () => onChanged(PayoutTab.withdraw),
          ),
        ),
      ],
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.appExtension.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(context.appExtension.radiusSm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
