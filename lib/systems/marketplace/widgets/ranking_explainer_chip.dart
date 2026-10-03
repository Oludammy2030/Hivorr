import 'package:flutter/material.dart';

import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Ranking explainability chip for discovery headers (EP-03-09).
///
/// Display-only affordance over `RankingFormula.explain`
/// (`lib/engine/recommendation_engine/ranking_formula.dart`): tapping opens a
/// calm dialog describing the verifiable signals behind the order. Never
/// influences ordering — the server RPC `service_ranking_search` remains the
/// sole authority (AGENT.md:7). All styling resolves to [AppTheme] tokens
/// (AGENT.md Rule 5).
class RankingExplainerChip extends StatelessWidget {
  const RankingExplainerChip({super.key});

  static const String _dialogTitle = 'How ranking works';

  static const String _dialogBody =
      'Services are ranked by verifiable signals — trade verification, '
      'client ratings, completion history, recency, and how closely they '
      'match your search. The order is computed on our servers and is the '
      'same for everyone with the same search. Nothing you see here is '
      'reordered on your device.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'How ranking works',
      child: InkWell(
        onTap: () => _showExplanation(context),
        borderRadius: BorderRadius.circular(999),
        child: const HivorrBadge(
          label: 'Ranked fairly · Why?',
          variant: HivorrBadgeVariant.neutral,
        ),
      ),
    );
  }

  Future<void> _showExplanation(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => HivorrDialog(
        title: _dialogTitle,
        content: Text(
          _dialogBody,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: <Widget>[
          HivorrButton(
            label: 'Got it',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Vertical spacing helper shared by discovery headers.
class DiscoveryHeaderSpacing {
  const DiscoveryHeaderSpacing._();

  /// Gap between the search header and the ranking explainer row.
  static const double explainerGap = HivorrSpacing.xs;
}
