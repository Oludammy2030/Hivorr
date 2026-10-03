import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Section header with a title and an optional trailing action (e.g. a
/// [HivorrButton] or [HivorrChip]).
///
/// Functional screens use the compact `titleMedium` style; marketing surfaces
/// opt into `titleLarge` via [large] (VISUAL-IDENTITY.md §6a).
class HivorrSectionHeader extends StatelessWidget {
  const HivorrSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.large = false,
  });

  /// Section title.
  final String title;

  /// Optional trailing widget.
  final Widget? action;

  /// Marketing-tier large title (`titleLarge`). Defaults to the compact
  /// functional style (`titleMedium` semibold).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final TextStyle? titleStyle = large
        ? context.textTheme.titleLarge
        : context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          );
    final List<Widget> children = <Widget>[
      Expanded(child: Text(title, style: titleStyle)),
    ];
    if (action != null) {
      children.add(action!);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: HivorrSpacing.sm,
        horizontal: HivorrSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ),
    );
  }
}
