import 'package:flutter/material.dart';

/// Constrained, visually centered content pane for forms and focused content
/// (VISUAL-IDENTITY.md §9.3 "Content width & centering").
///
/// On large screens the child is capped at [maxContentWidth] and centered with
/// symmetric gutters instead of stretching edge to edge; on tablet/mobile it
/// fills the available width so forms stay comfortably usable. Genuinely
/// full-width surfaces (dashboards, data views) should NOT use this pane.
class HivorrContentPane extends StatelessWidget {
  const HivorrContentPane({super.key, required this.child});

  /// The content to constrain.
  final Widget child;

  /// Target maximum content width (VISUAL-IDENTITY.md §9.3).
  static const double maxContentWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}
