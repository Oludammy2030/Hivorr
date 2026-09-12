import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Path-aware linear wizard tracker (EP-02-18 FV-35, capability-corrected).
///
/// Segment count equals the number of steps on the current capability's path
/// ([OnboardingProgress.requiredSteps]) — two for a hire-only entity, five for
/// professional/`both`. Filled segments equal the position of the current step
/// on that path. Done segments use `ColorScheme.primary`; pending use
/// `surfaceVariant`. No hardcoded hex values.
class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({super.key, required this.progress});

  /// The active wizard position, or `null` before hydration.
  final OnboardingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final OnboardingProgress? p = progress;
    final List<OnboardingStepCode> requiredSteps =
        p?.requiredSteps ?? const <OnboardingStepCode>[
          OnboardingStepCode.capability,
          OnboardingStepCode.profile,
          OnboardingStepCode.industry,
          OnboardingStepCode.identityDocument,
          OnboardingStepCode.tradeProof,
        ];
    final int total = requiredSteps.length;
    final int position = p == null
        ? 0
        : requiredSteps.indexOf(p.step) + 1;
    final int filled = position.clamp(0, total);

    return Semantics(
      label: 'Step $filled of $total',
      value: '$total steps',
      child: Row(
        children: <Widget>[
          for (int segment = 0; segment < total; segment++) ...<Widget>[
            if (segment > 0) const SizedBox(width: HivorrSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  color: segment < filled
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(ext.radiusSm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}