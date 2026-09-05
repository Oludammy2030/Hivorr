import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Local zero-RPC estimate for the active pair with the execution CTA
/// (EP-02-15 §5.4).
///
/// Displays the give → fee → net (`toAmount`) summary computed by the
/// repository from the trusted [ConversionRateSource] seam, the net line
/// emphasized in `colorScheme.primary` (DoD TT-09), and a disclaimer that it
/// is an estimate. The authoritative amounts are always the server's
/// `financial_convert_currency` response, never this client-computed estimate
/// (DoD SV-07).
class ConversionPreviewCard extends StatelessWidget {
  const ConversionPreviewCard({
    super.key,
    required this.preview,
    required this.onExecute,
    required this.isExecuting,
  });

  /// The computed local estimate.
  final ConversionPreview preview;

  /// Execution callback, or `null` to disable the CTA.
  final VoidCallback? onExecute;

  /// Whether an execution is in flight (CTA shows a loader).
  final bool isExecuting;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('You give', style: context.textTheme.labelMedium),
          Text(
            BalanceFormatter.formatBalance(
              preview.fromAmount,
              preview.fromCurrency,
            ),
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          if (preview.fee > 0) ...<Widget>[
            Text('Fee', style: context.textTheme.labelMedium),
            Text(
              BalanceFormatter.formatBalance(preview.fee, preview.toCurrency),
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: HivorrSpacing.sm),
          ],
          Text('You receive', style: context.textTheme.labelMedium),
          Text(
            BalanceFormatter.formatBalance(preview.toAmount, preview.toCurrency),
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            'This is an estimate \u2014 the final amount is confirmed on execution.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrButton(
            label: 'Convert now',
            isExpanded: true,
            isLoading: isExecuting,
            onPressed: onExecute,
          ),
        ],
      ),
    );
  }
}