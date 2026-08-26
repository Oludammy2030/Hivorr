import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Standard screen wrapper: applies [SafeArea], horizontal padding, and an
/// optional [AppBar] / [FloatingActionButton]. Defaults its background to
/// [ColorScheme.surface] so nested cards can use the scaffold background for
/// contrast.
class HivorrScreenScaffold extends StatelessWidget {
  const HivorrScreenScaffold({
    super.key,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    required this.body,
  });

  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor ?? colors.surface,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HivorrSpacing.md),
          child: body,
        ),
      ),
    );
  }
}
