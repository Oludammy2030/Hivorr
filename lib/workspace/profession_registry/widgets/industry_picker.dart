import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';

/// Horizontal (mobile) / wrapped (web) selection of industries, ordered by
/// [Industry.sortOrder], used to drive the profession list.
///
/// Selection emits the chosen [Industry.id] via [onSelected]. Built entirely
/// from [ColorScheme] / [AppThemeExtension] tokens (AGENT.md Rule 5).
class IndustryPicker extends StatelessWidget {
  const IndustryPicker({
    super.key,
    required this.industries,
    required this.selectedId,
    required this.onSelected,
  });

  /// The industries to display (expected in `sortOrder`).
  final List<Industry> industries;

  /// The currently selected industry id.
  final String? selectedId;

  /// Emits the newly selected industry id.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final Breakpoint bp = Breakpoints.current(context);
    final bool wrap = bp != Breakpoint.mobile;
    final List<Widget> chips = industries
        .map(
          (Industry i) => Padding(
            padding: const EdgeInsets.only(
              right: HivorrSpacing.xs,
              bottom: HivorrSpacing.xs,
            ),
            child: HivorrChip(
              label: i.name,
              isSelected: i.id == selectedId,
              variant: HivorrChipVariant.surface,
              onSelected: (_) => onSelected(i.id),
            ),
          ),
        )
        .toList();

    final Widget body = wrap
        ? Wrap(children: chips)
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
      child: body,
    );
  }
}
