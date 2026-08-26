import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// Themed horizontal divider built from the [ColorScheme.outline] token.
class HivorrDivider extends StatelessWidget {
  const HivorrDivider({
    super.key,
    this.thickness = 1,
    this.indent,
    this.endIndent,
  });

  /// Stroke thickness in logical pixels.
  final double thickness;

  /// Leading inset.
  final double? indent;

  /// Trailing inset.
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: thickness,
      indent: indent,
      endIndent: endIndent,
      color: context.colorScheme.outline,
    );
  }
}
