import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/shared/components/hivorr_form_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/finance/helpers/bank_account_number_validator.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/services/financial_payout_service.dart';
import 'package:provider/provider.dart';

/// Bind-payout-account form (EP-02-16).
///
/// Collects currency, bank name, NUBAN/account number, and account name, then
/// submits through the server-authoritative `financial_payout_account_bind`
/// RPC (via [FinancialPayoutProvider]). Uses only [AppTheme] tokens
/// (AGENT.md Rule 5).
class PayoutAccountFormView extends StatefulWidget {
  const PayoutAccountFormView({
    super.key,
    this.onBound,
  });

  /// Invoked with the server-confirmed account after a successful bind.
  final ValueChanged<PayoutAccount>? onBound;

  @override
  State<PayoutAccountFormView> createState() => _PayoutAccountFormViewState();
}

class _PayoutAccountFormViewState extends State<PayoutAccountFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _bankName = TextEditingController();
  final TextEditingController _accountNumber = TextEditingController();
  final TextEditingController _accountName = TextEditingController();
  String _currencyCode = 'NGN';

  @override
  void dispose() {
    _bankName.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final FocusScopeNode focus = FocusScope.of(context);
    if (focus.hasFocus) focus.unfocus();
    final FinancialPayoutProvider provider =
        context.read<FinancialPayoutProvider>();
    final PayoutAccount? account = await provider.bindAccount(
      currencyCode: _currencyCode,
      bankName: _bankName.text,
      accountNumber: _accountNumber.text,
      accountName: _accountName.text,
    );
    if (!mounted) return;
    if (account != null) {
      _formKey.currentState?.reset();
      _bankName.clear();
      _accountNumber.clear();
      _accountName.clear();
      widget.onBound?.call(account);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final FinancialPayoutProvider provider =
        context.watch<FinancialPayoutProvider>();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
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
            items: FinancialPayoutService.supportedCurrencies
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
            controller: _bankName,
            label: 'Bank name',
            maxLength: 255,
            validator: (String? value) {
              final String trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Enter the bank name';
              return null;
            },
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _accountNumber,
            label: 'Account number',
            keyboardType: TextInputType.number,
            maxLength: 50,
            validator: (String? value) => BankAccountNumberValidator.validate(
              value: value,
              currencyCode: _currencyCode,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          HivorrFormField(
            controller: _accountName,
            label: 'Account name',
            maxLength: 255,
            validator: (String? value) {
              final String trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Enter the account name';
              return null;
            },
          ),
          if (provider.lastError != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              provider.lastError!.message,
              style: context.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Bind payout account',
            isLoading: provider.isBinding,
            isExpanded: true,
            onPressed: () => _submit(),
          ),
        ],
      ),
    );
  }
}