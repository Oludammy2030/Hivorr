import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/entities/withdrawal_result.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/shared/components/hivorr_form_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/finance/widgets/payout_account_limit_display.dart';
import 'package:provider/provider.dart';

/// Withdrawal form (EP-02-16).
///
/// Submits through the server-authoritative `financial_withdraw` RPC via
/// [FinancialPayoutProvider]. Only verified, active payout accounts are
/// offered as destinations (mirroring the server's `is_verified` gate).
class PayoutWithdrawFormView extends StatefulWidget {
  const PayoutWithdrawFormView({
    super.key,
    this.cashoutLimit,
    this.currencyCode = 'NGN',
    this.onWithdrawSuccess,
  });

  /// KYC-derived cashout limit (optional; shows a limit summary when present
  /// and bounds client-side validation).
  final double? cashoutLimit;

  /// Display currency for [cashoutLimit].
  final String currencyCode;

  /// Invoked with the server-confirmed [WithdrawalResult].
  final ValueChanged<WithdrawalResult>? onWithdrawSuccess;

  @override
  State<PayoutWithdrawFormView> createState() =>
      _PayoutWithdrawFormViewState();
}

class _PayoutWithdrawFormViewState extends State<PayoutWithdrawFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  String? _selectedAccountId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  List<PayoutAccount> _verifiedAccounts(FinancialPayoutProvider provider) {
    return provider.accounts.where((PayoutAccount a) => a.isUsable).toList();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final FocusScopeNode focus = FocusScope.of(context);
    if (focus.hasFocus) focus.unfocus();
    final FinancialPayoutProvider provider =
        context.read<FinancialPayoutProvider>();
    final List<PayoutAccount> verified = _verifiedAccounts(provider);
    if (verified.isEmpty) return;
    final String accountId = _selectedAccountId ?? verified.first.id;
    final double amount = double.tryParse(_amount.text.trim()) ?? 0.0;
    final WithdrawalResult? result = await provider.withdraw(
      payoutAccountId: accountId,
      amount: amount,
    );
    if (!mounted) return;
    if (result != null) {
      _amount.clear();
      widget.onWithdrawSuccess?.call(result);
    }
  }

  String? _validateAmount(String? value) {
    final String trimmed = value?.trim() ?? '';
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      return 'Enter an amount greater than zero';
    }
    final double? limit = widget.cashoutLimit;
    if (limit != null && parsed > limit) {
      return 'Withdrawals are capped by your cashout limit';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final FinancialPayoutProvider provider =
        context.watch<FinancialPayoutProvider>();
    final List<PayoutAccount> verified = _verifiedAccounts(provider);

    if (verified.isEmpty) {
      return HivorrEmptyState(
        icon: const Icon(Icons.verified_outlined),
        title: 'No verified payout accounts',
        subtitle:
            'Withdrawals are enabled after a payout account passes ownership '
            'verification. Bind an account and wait for verification.',
      );
    }

    // Keep a valid selection when the mirror changes under us.
    for (final PayoutAccount a in verified) {
      if (a.id == _selectedAccountId) {
        break;
      }
    }
    final String selectedId = _selectedAccountId ?? verified.first.id;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Payout account',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  context.appExtension.radiusSm,
                ),
              ),
            ),
            items: verified
                .map((PayoutAccount a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(
                        '${a.bankName} \u2022 ${a.maskedAccountNumber} '
                        '(${a.currencyCode})',
                        style: context.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(growable: false),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _selectedAccountId = value);
              }
            },
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _amount,
            label: 'Amount',
            hint: 'e.g. 50000.00',
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: true,
            ),
            validator: _validateAmount,
          ),
          if (widget.cashoutLimit != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            PayoutAccountLimitDisplay(
              limit: widget.cashoutLimit!,
              currencyCode: widget.currencyCode,
            ),
          ],
          if (provider.lastError != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              provider.lastError!.message,
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Withdraw',
            isLoading: provider.isWithdrawing,
            isExpanded: true,
            onPressed: () => _submit(),
          ),
        ],
      ),
    );
  }
}