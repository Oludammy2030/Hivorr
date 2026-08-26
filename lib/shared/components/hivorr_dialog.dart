import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// Themed alert dialog wrapper around [AlertDialog] that applies the
/// [AppThemeExtension] corner radius.
class HivorrDialog extends StatelessWidget {
  const HivorrDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
  });

  /// Dialog title text.
  final String? title;

  /// Dialog body.
  final Widget? content;

  /// Action buttons (typically [HivorrButton]s).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    return AlertDialog(
      title: title != null ? Text(title!, style: context.textTheme.titleLarge) : null,
      content: content,
      actions: actions,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
    );
  }
}
