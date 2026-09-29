import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Themed FAQ accordion item (VISUAL-IDENTITY.md §§14–15).
///
/// Flat card wrapping an [ExpansionTile]: card-heading question, supporting
/// answer, primary-colored trailing icon. Use in a list for Help / Pricing /
/// Security supporting information.
class HivorrFaqItem extends StatelessWidget {
  const HivorrFaqItem({super.key, required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: colors.primary,
        collapsedIconColor: colors.primary,
        title: Text(
          question,
          style: context.textTheme.titleMedium?.copyWith(
            color: colors.onSurface,
          ),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HivorrSpacing.md,
              0,
              HivorrSpacing.md,
              HivorrSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
