import 'package:flutter/material.dart';

import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Standard screen wrapper: applies [SafeArea], horizontal padding, and an
/// optional [AppBar] / [FloatingActionButton]. Defaults its background to
/// the app background token so white [HivorrCard] surfaces stay visible
/// (VISUAL-IDENTITY.md §5.3).
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
    return Scaffold(
      appBar: appBar,
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
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
