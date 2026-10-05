import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/app/theme/app_theme.dart';

/// One-shot list entrance: fade + 8dp rise, staggered by [index].
///
/// Wrap cards in lazy lists so first paint settles gracefully instead of
/// popping in. Each keyed instance plays exactly once (state persists per
/// `ValueKey`), so scrolling back never replays. Stagger caps at
/// [maxStagger] items — late items share the final delay.
///
/// Reduced motion (`MediaQuery.disableAnimations`) renders [child] directly
/// with no controller, timer, or transition.
class HivorrEntrance extends StatefulWidget {
  const HivorrEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxStagger = 8,
  });

  final int index;
  final Widget child;
  final int maxStagger;

  @override
  State<HivorrEntrance> createState() => _HivorrEntranceState();
}

class _HivorrEntranceState extends State<HivorrEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<Offset>? _slide;
  Timer? _starter;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.disableAnimations) {
      return;
    }
    final AnimationController controller = AnimationController(
      duration: HivorrMotion.short,
      vsync: this,
    );
    final CurvedAnimation curve = CurvedAnimation(
      parent: controller,
      curve: HivorrMotion.standard,
    );
    _controller = controller;
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
    final int step = widget.index.clamp(0, widget.maxStagger);
    _starter = Timer(Duration(milliseconds: step * 40), () {
      if (!mounted) return;
      setState(() => _ready = true);
      controller.forward();
    });
  }

  @override
  void dispose() {
    _starter?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AnimationController? controller = _controller;
    final Animation<double>? fade = _fade;
    final Animation<Offset>? slide = _slide;
    if (controller == null || fade == null || slide == null || !_ready) {
      if (controller == null) {
        // Reduced motion: render directly, no transition at all.
        return widget.child;
      }
      // Pre-start: hold invisible to avoid a flash before the delay elapses.
      return Opacity(opacity: 0, child: widget.child);
    }
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}
