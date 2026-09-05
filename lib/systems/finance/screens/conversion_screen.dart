import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/providers/conversion_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/finance/widgets/conversion_amount_field.dart';
import 'package:hivorr/systems/finance/widgets/conversion_history_list.dart';
import 'package:hivorr/systems/finance/widgets/conversion_pair_selector.dart';
import 'package:hivorr/systems/finance/widgets/conversion_preview_card.dart';
import 'package:hivorr/systems/finance/widgets/conversion_rate_card.dart';
import 'package:hivorr/systems/finance/widgets/conversion_result_card.dart';
import 'package:provider/provider.dart';

/// Currency-conversion screen (EP-02-15 §5.8).
///
/// Prefixes the conversion form with the flag-gated pair selector, amount
/// entry, trusted rate + estimate cards, and a "Convert now" CTA, then lists
/// the executed history below. The [ConversionProvider] owns all state; this
/// screen only binds callbacks and lifecycle (history reload on resume). No
/// raw color tokens, hex literals, or font-family strings — AppTheme tokens
/// only (AGENT.md Rule 5).
class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen>
    with WidgetsBindingObserver {
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey _historyKey = GlobalKey();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ConversionProvider provider = context.read<ConversionProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(provider.loadHistory());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The provider's own lifecycle gate already prevents background loads;
    // on resume we re-fetch so the history reflects server state.
    if (state == AppLifecycleState.resumed) {
      final ConversionProvider provider = context.read<ConversionProvider>();
      if (mounted) unawaited(provider.loadHistory());
    }
  }

  void _onAmountChanged(String raw) {
    final double parsed = double.tryParse(raw.trim()) ?? 0;
    context.read<ConversionProvider>().setAmount(parsed);
  }

  void _onFromSelected(String code) {
    final ConversionProvider provider = context.read<ConversionProvider>();
    final String? currentTo = provider.toCurrency;
    final String? currentFrom = provider.fromCurrency;
    // Avoid self-pairs: swap the other leg instead of rejecting the tap. The
    // swap only makes sense once both legs are set (a null other leg cannot be
    // swapped, so the pair is simply updated).
    if (currentTo == code && currentFrom != null && currentFrom != code) {
      provider.setDestination(currentFrom);
    }
    provider.setSource(code);
    unawaited(provider.loadRate());
  }

  void _onToSelected(String code) {
    final ConversionProvider provider = context.read<ConversionProvider>();
    final String? currentFrom = provider.fromCurrency;
    final String? currentTo = provider.toCurrency;
    if (currentFrom == code && currentTo != null && currentTo != code) {
      provider.setSource(currentTo);
    }
    provider.setDestination(code);
    unawaited(provider.loadRate());
  }

  void _scrollToHistory() {
    final BuildContext? historyContext = _historyKey.currentContext;
    if (historyContext == null) return;
    Scrollable.ensureVisible(
      historyContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Convert', style: context.textTheme.titleLarge),
      ),
      body: Consumer<ConversionProvider>(
        builder: (BuildContext context, ConversionProvider provider, _) {
          if (!provider.isConversionEnabled) {
            return HivorrEmptyState(
              icon: const Icon(Icons.currency_exchange),
              title: 'Currency conversion unavailable',
              subtitle:
                  'Conversions are not enabled for your account yet. Check back soon.',
            );
          }
          return RefreshIndicator(
            onRefresh: provider.loadHistory,
            child: ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                ConversionPairSelector(
                  fromCurrency: provider.fromCurrency,
                  toCurrency: provider.toCurrency,
                  onFromSelected: _onFromSelected,
                  onToSelected: _onToSelected,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                ConversionAmountField(
                  controller: _amountController,
                  currencyCode: provider.fromCurrency,
                  onChanged: _onAmountChanged,
                ),
                const SizedBox(height: HivorrSpacing.md),
                ConversionRateCard(
                  rate: provider.rate,
                  fromCurrency: provider.fromCurrency,
                  toCurrency: provider.toCurrency,
                  isLoading: provider.isRateLoading,
                  isUnavailable: provider.isRateUnavailable,
                  onRetry: provider.loadRate,
                ),
                const SizedBox(height: HivorrSpacing.md),
                if (provider.lastError != null)
                  _FailedOperationCard(
                    message: 'Conversion not completed',
                    detail: provider.lastError!.message,
                    onRetry: () => provider.refreshPreview(),
                  ),
                if (provider.preview != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.md),
                  ConversionPreviewCard(
                    preview: provider.preview!,
                    isExecuting: provider.isConverting,
                    onExecute:
                        provider.isPreviewing || provider.isConverting
                            ? null
                            : () => provider.execute(),
                  ),
                ] else if (provider.canConvert && !provider.isPreviewing)
                  ...<Widget>[
                    HivorrButton(
                      label: 'See estimate',
                      variant: HivorrButtonVariant.secondary,
                      isExpanded: true,
                      onPressed: () => provider.refreshPreview(),
                    ),
                  ],
                if (provider.lastConversion != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.md),
                  ConversionResultCard(
                    conversion: provider.lastConversion!,
                    onViewHistory: _scrollToHistory,
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
                Text(
                  'History',
                  key: _historyKey,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: HivorrSpacing.sm),
                ConversionHistoryList(history: provider.history),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FailedOperationCard extends StatelessWidget {
  const _FailedOperationCard({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: context.colorScheme.error),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: _InlineError(
              message: message,
              detail: detail,
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact inline error line (message + detail + retry) without the full-page
/// [HivorrErrorState] chrome — used inside the scrollable form.
class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(message, style: context.textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          detail,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}