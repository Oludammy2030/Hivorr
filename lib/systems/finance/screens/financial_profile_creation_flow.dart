import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/data/providers/financial_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/services/financial_service.dart';
import 'package:provider/provider.dart';

/// Financial profile creation flow (EP-02-13 §5.6).
///
/// Default currency selector (radio group with symbols) and "Create Profile"
/// CTA. Uses only [AppTheme] tokens (AGENT.md Rule 5).
class FinancialProfileCreationFlow extends StatefulWidget {
  const FinancialProfileCreationFlow({super.key});

  @override
  State<FinancialProfileCreationFlow> createState() =>
      _FinancialProfileCreationFlowState();
}

class _FinancialProfileCreationFlowState
    extends State<FinancialProfileCreationFlow> {
  String _selectedCurrency = 'NGN';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Financial Profile',
          style: context.textTheme.titleLarge,
        ),
      ),
      body: Consumer<FinancialProvider>(
        builder: (BuildContext context, FinancialProvider provider, _) {
          if (provider.isCreating) {
            return const HivorrLoadingState(
              message: 'Creating your financial profile...',
            );
          }

          if (provider.profile != null) {
            return HivorrSuccessState(
              title: 'Profile created',
              subtitle:
                  'Your default currency is ${_currencyLabel(provider.profile!.defaultCurrency)}. '
                  'You can now start receiving payments.',
              actionButton: HivorrButton(
                label: 'View Profile',
                onPressed: () => context.go('/finance'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            children: <Widget>[
              Text(
                'Choose your default currency',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                'This will be the primary currency for receiving payments. '
                'You can add more currencies later.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: HivorrSpacing.lg),
              ...FinancialService.supportedCurrencies.map(
                (SupportedCurrency currency) => Padding(
                  padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
                  child: _CurrencyRadio(
                    currency: currency,
                    isSelected: _selectedCurrency == currency.code,
                    onTap: () {
                      setState(() => _selectedCurrency = currency.code);
                    },
                  ),
                ),
              ),
              const SizedBox(height: HivorrSpacing.xl),
              if (provider.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: HivorrSpacing.md),
                  child: Text(
                    provider.lastError!.message,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              HivorrButton(
                label: 'Create Profile',
                isLoading: provider.isCreating,
                isExpanded: true,
                onPressed: () => provider.createProfile(
                  defaultCurrency: _selectedCurrency,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _currencyLabel(String code) {
    final currency = SupportedCurrency.fromCode(code);
    return currency != null ? '${currency.symbol} ${currency.name}' : code;
  }
}

class _CurrencyRadio extends StatelessWidget {
  const _CurrencyRadio({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  final SupportedCurrency currency;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    return Semantics(
      label: '${currency.name} ${currency.symbol}',
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(HivorrSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? colors.primaryContainer : colors.surface,
            borderRadius: BorderRadius.circular(ext.radiusMd),
            border: Border.all(
              color: isSelected ? colors.primary : colors.outline,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${currency.symbol} ${currency.name}',
                      style: context.textTheme.bodyLarge,
                    ),
                    Text(
                      currency.code,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
