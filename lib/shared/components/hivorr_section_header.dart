import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Section header with a title and an optional trailing action (e.g. a
/// [HivorrButton] or [HivorrChip]).
class HivorrSectionHeader extends StatelessWidget {
  const HivorrSectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  /// Section title.
  final String title;

  /// Optional trailing widget.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[
      Expanded(
        child: Text(title, style: context.textTheme.titleMedium),
      ),
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
