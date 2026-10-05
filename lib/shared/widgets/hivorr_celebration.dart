import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// One-shot success celebration (§16a): the mark scales 0.6→1 and fades in
/// while a deterministic confetti burst arcs out and settles by 600ms.
///
/// Exactly one celebration per completed flow (order placed, contract signed,
/// payout received, verification approved, listing published, onboarding
/// done). Never on errors, never on amounts, never looping. Reduced motion
/// (`disableAnimations`) renders the resting end frame with no controller.
class HivorrCelebration extends StatefulWidget {
  const HivorrCelebration({
    super.key,
    required this.child,
    this.size = 144,
    this.particles = 22,
  });

  /// The success mark shown at rest (typically the success icon).
  final Widget child;

  /// Square celebration canvas.
  final double size;

  final int particles;

  @override
  State<HivorrCelebration> createState() => _HivorrCelebrationState();
}

class _HivorrCelebrationState extends State<HivorrCelebration>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _mark;
  Timer? _starter;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.disableAnimations) {
      return;
    }
    final AnimationController controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _controller = controller;
    _mark = CurvedAnimation(
      parent: controller,
      // Mark settles in the first 350ms; confetti owns the tail.
      curve: const Interval(0, 0.58, curve: HivorrMotion.emphasized),
    );
    // Start on the next frame so the resting layout paints first.
    _starter = Timer(Duration.zero, () {
      if (mounted) controller.forward();
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
    final Animation<double>? mark = _mark;
    if (controller == null || mark == null) {
      return widget.child;
    }
    final AppThemeExtension ext = context.appExtension;
    final ColorScheme colors = context.colorScheme;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, _) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _ConfettiPainter(
                progress: controller.value,
                colors: <Color>[
                  colors.primary,
                  colors.secondary,
                  ext.success,
                ],
              ),
            ),
          ),
          ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(mark),
            child: FadeTransition(opacity: mark, child: widget.child),
          ),
        ],
      ),
    );
  }
}

/// Deterministic confetti: pseudo-random from the particle index (no `Random`
/// in build), arcing outward with gravity, fading through the tail.
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  double _hash(int i, double salt) {
    final double x = sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    const int count = 22;
    for (int i = 0; i < count; i++) {
      final double angle = _hash(i, 1) * 2 * pi;
      final double speed = 0.30 + _hash(i, 2) * 0.22;
      final double dist = size.width * speed * progress;
      final Offset pos = center +
          Offset(
            cos(angle) * dist,
            sin(angle) * dist + size.height * 0.18 * progress * progress,
          );
      final double fade = (1 - progress).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        1.5 + _hash(i, 3) * 2.5,
        Paint()..color = colors[i % colors.length].withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.colors != colors;
}
