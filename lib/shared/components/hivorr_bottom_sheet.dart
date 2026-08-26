import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_divider.dart';

/// Themed modal bottom-sheet scaffold with a rounded top edge and an optional
/// title. Present it with [HivorrBottomSheet.show] or as the builder result of
/// [showModalBottomSheet].
class HivorrBottomSheet extends StatelessWidget {
  const HivorrBottomSheet({
    super.key,
    this.title,
    required this.child,
  });

  /// Optional header title.
  final String? title;

  /// Sheet body.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ext.radiusLg),
        ),
      ),
      padding: EdgeInsets.only(
        top: HivorrSpacing.md,
        left: HivorrSpacing.md,
        right: HivorrSpacing.md,
        bottom: HivorrSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HivorrSpacing.sm),
            const HivorrDivider(),
            const SizedBox(height: HivorrSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }

  /// Presents this sheet as a modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: true,
      builder: (_) => HivorrBottomSheet(title: title, child: child),
    );
  }
}
