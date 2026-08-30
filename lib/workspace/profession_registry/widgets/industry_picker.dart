import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';

/// Browsable, single-select industry grid/list (tier-1 of the two-tier
/// taxonomy, AGENT.md Rule 2).
///
/// Renders industries in `sortOrder`, active-only by default, and reports the
/// selection via [onSelected]. Built entirely from [AppTheme] tokens and the
/// shared [HivorrChip] primitive (AGENT.md Rule 5).
class IndustryPicker extends StatelessWidget {
  const IndustryPicker({
    super.key,
    required this.industries,
    this.selectedId,
    this.onSelected,
  });

  /// The industries to render (already ordered by the caller).
  final List<Industry> industries;

  /// The currently selected industry id, if any.
  final String? selectedId;

  /// Called when an industry is tapped.
  final ValueChanged<Industry>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (industries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: <Widget>[
        for (final Industry industry in industries)
          HivorrChip(
            label: industry.name,
            isSelected: industry.id == selectedId,
            onSelected: (_) => onSelected?.call(industry),
            variant: HivorrChipVariant.primary,
          ),
      ],
    );
  }
}
