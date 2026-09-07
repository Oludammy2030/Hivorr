import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/deposit.dart';
import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/shared/components/hivorr_form_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/widgets/deposit_name_match_indicator.dart';
import 'package:provider/provider.dart';

/// Deposit details section (EP-02-16).
///
/// Lists the authenticated entity's deposits read through the RLS-scoped REST
/// select on `financial_deposits`, each with its server-computed name-match
/// indicator (Unverified / Pending / Verified / Failed). Recording deposits is
/// service-role work, so the panel surfaces a read-only showcase form that
/// explains the server-side verification path instead of writing.
class DepositDetailsPanel extends StatefulWidget {
  const DepositDetailsPanel({super.key});

  @override
  State<DepositDetailsPanel> createState() => _DepositDetailsPanelState();
}

class _DepositDetailsPanelState extends State<DepositDetailsPanel> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final FinancialDepositProvider provider =
          context.read<FinancialDepositProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(provider.load());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinancialDepositProvider provider = context
        .watch<FinancialDepositProvider>();

    if (provider.isLoading && !provider.isLoaded) {
      return const HivorrLoadingState(message: 'Loading deposits...');
    }

    if (provider.lastError != null && !provider.isLoaded) {
      return HivorrErrorState(
        message: 'Failed to load deposits',
        detail: provider.lastError!.message,
        onRetry: () => provider.load(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (provider.deposits.isEmpty)
          const _NoDeposits()
        else
          ...provider.deposits.map(
            (Deposit d) => Padding(
              padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
              child: _DepositRow(deposit: d),
            ),
          ),
        const SizedBox(height: HivorrSpacing.sm),
        const _DepositRecordShowcase(),
      ],
    );
  }
}

class _NoDeposits extends StatelessWidget {
  const _NoDeposits();

  @override
  Widget build(BuildContext context) {
    return HivorrEmptyState(
      icon: const Icon(Icons.payments_outlined),
      title: 'No deposits recorded yet',
      subtitle:
          'Payer names are verified against your profile legal name. '
          'Matching deposits are credited automatically.',
    );
  }
}

class _DepositRow extends StatelessWidget {
  const _DepositRow({required this.deposit});

  final Deposit deposit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final String amount = BalanceFormatter.formatBalance(
      deposit.amount,
      deposit.currencyCode,
    );

    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(amount, style: context.textTheme.titleMedium),
              ),
              DepositNameMatchIndicator(status: deposit.nameMatchStatus),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            deposit.isCredited ? 'Credited to your balance' : 'Awaiting credit',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only showcase of the deposit-recording flow (TT-17).
///
/// The real client path cannot record deposits — `financial_deposit_record` is
/// service-role only — so the form is informational: it previews the credited
/// amount and explains the server-side name-match verification.
class _DepositRecordShowcase extends StatefulWidget {
  const _DepositRecordShowcase();

  @override
  State<_DepositRecordShowcase> createState() => _DepositRecordShowcaseState();
}

class _DepositRecordShowcaseState extends State<_DepositRecordShowcase> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  String _currencyCode = 'NGN';
  String? _confirmation;
  double? _parsedAmount;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    final SupportedCurrency? currency = SupportedCurrency.fromCode(
      _currencyCode,
    );
    final double? amount = double.tryParse(_amount.text.trim());
    _parsedAmount = (amount != null && amount > 0) ? amount : null;

    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Record a deposit', style: context.textTheme.titleMedium),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Deposits are recorded and name-verified by the Hivorr processing '
            'service, not the app client. When the payer name on a transfer '
            'matches your profile legal name, the amount is credited to your '
            'balance automatically.',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _currencyCode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Currency',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  context.appExtension.radiusSm,
                ),
              ),
            ),
            items: SupportedCurrency.values
                .map(
                  (SupportedCurrency c) => DropdownMenuItem<String>(
                    value: c.code,
                    child: Text(
                      '${c.code} \u2014 ${c.symbol} ${c.name}',
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value != null) setState(() => _currencyCode = value);
            },
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _amount,
            label: 'Amount',
            hint: 'e.g. 150000.00',
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _reference,
            label: 'Reference (optional)',
            hint: 'Transfer reference from your bank',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            _parsedAmount != null
                ? 'You will receive: '
                      '${BalanceFormatter.formatBalance(_parsedAmount!, _currencyCode)} '
                      '${currency?.code ?? _currencyCode}'
                : 'Enter an amount to preview what would be received.',
            style: context.textTheme.bodyMedium,
          ),
          if (_confirmation != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Container(
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(
                  context.appExtension.radiusSm,
                ),
              ),
              child: Text(
                _confirmation!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Verify deposit server-side',
            variant: HivorrButtonVariant.secondary,
            isExpanded: true,
            onPressed: () {
              if (_parsedAmount == null) return;
              setState(() {
                _confirmation =
                    'Received. The processing service will run the name-match '
                    'against your profile legal name and credit $_currencyCode '
                    'if it matches.';
              });
            },
          ),
        ],
      ),
    );
  }
}
