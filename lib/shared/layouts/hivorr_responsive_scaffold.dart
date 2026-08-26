import 'package:flutter/material.dart';

import 'package:hivorr/shared/layouts/breakpoints.dart';

/// Responsive application scaffold that adapts to the current width using
/// [LayoutBuilder] (not a top-level [MediaQuery] lookup).
///
/// - Mobile (< 600dp): single-column [Scaffold] with optional bottom nav.
/// - Tablet / Desktop (≥ 600dp): [Scaffold] with a fixed [sidebar] rail and
///   expanded [mobileBody] content.
///
/// When [sidebar] is `null`, the tablet/desktop branch gracefully falls back to
/// the mobile layout (single column).
class HivorrResponsiveScaffold extends StatelessWidget {
  const HivorrResponsiveScaffold({
    super.key,
    required this.mobileBody,
    this.sidebar,
    this.appBar,
    this.bottomNavigationBar,
  });

  /// Content shown in both layouts.
  final Widget mobileBody;

  /// Sidebar shown on tablet/desktop when provided. Typically a
  /// [NavigationRail] (see plan §5.4); the desktop layout places it in a fixed
  /// 280dp rail beside the expanded [mobileBody].
  final Widget? sidebar;

  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Breakpoint bp = Breakpoints.fromWidth(constraints.maxWidth);
        if (bp == Breakpoint.mobile || sidebar == null) {
          return Scaffold(
            appBar: appBar,
            bottomNavigationBar: bottomNavigationBar,
            body: SafeArea(child: mobileBody),
          );
        }
        return Scaffold(
          appBar: appBar,
          body: SafeArea(
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: sidebar!,
                ),
                Expanded(child: mobileBody),
              ],
            ),
          ),
        );
      },
    );
  }
}
