import 'dart:math';

import 'package:flutter/material.dart';

import 'package:hivorr/app/theme/app_colors.dart';

/// Monochrome Hivorr loading indicator.
///
/// Renders the Universal-Entity node network in a single stroke/fill color
/// (no background). Nodes are **filled** to match the brand mark (logo.svg);
/// connectors are strokes. The three outer nodes play a subtle, organic
/// breathing pulse staggered in a smooth wave (no 360° spin).
///
/// The breathing is driven by a Flutter [AnimationController]; for a
/// standalone web/HTML SVG that uses CSS `@keyframes` instead, see
/// `assets/images/hivorr_loader.svg`.
class HivorrLoader extends StatefulWidget {
  const HivorrLoader({
    super.key,
    this.size = 48,
    this.color = AppColors.brandPrimary,
    this.duration = const Duration(milliseconds: 1800),
    this.strokeWidth,
  });

  /// Rendered box size (square).
  final double size;

  /// Single color for the whole network (monochrome). Defaults to the brand
  /// primary so it reads as "Hivorr" out of the box; pass e.g.
  /// `Theme.of(context).colorScheme.onSurface` for a neutral variant.
  final Color color;

  /// One full breathing wave cycle.
  final Duration duration;

  /// Outline thickness; defaults to ~6% of [size].
  final double? strokeWidth;

  @override
  State<HivorrLoader> createState() => _HivorrLoaderState();
}

class _HivorrLoaderState extends State<HivorrLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant HivorrLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _HivorrLoaderPainter(
            progress: _controller.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth ?? widget.size * 12 / 256,
          ),
        ),
      ),
    );
  }
}

class _HivorrLoaderPainter extends CustomPainter {
  const _HivorrLoaderPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  // Relative node positions (fraction of the box), mirroring the brand mark
  // (logo.svg: outer r=17, center r=24, stroke=12 in a 256 box).
  static const List<Offset> _outer = <Offset>[
    Offset(0.5, 0.242),
    Offset(0.258, 0.703),
    Offset(0.742, 0.703),
  ];
  static const Offset _center = Offset(0.5, 0.5);

  static const double _outerR = 17 / 256;
  static const double _centerR = 24 / 256;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    Offset toPx(Offset o) => Offset(o.dx * w, o.dy * h);

    final Offset center = toPx(_center);
    final List<Offset> outer = _outer.map(toPx).toList();

    final Paint linkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Connectors — constant, full opacity.
    for (final Offset o in outer) {
      canvas.drawLine(center, o, linkPaint);
    }

    // Central node — steady, un-staggered breathing (filled, like the mark).
    final double centerWave = 0.5 - 0.5 * cos(2 * pi * progress);
    _drawNode(
      canvas,
      center,
      w * _centerR * (0.9 + 0.2 * centerWave),
      color.withValues(alpha: 0.55 + 0.45 * centerWave),
    );

    // Outer nodes — staggered wave (smooth sequential pulse).
    for (int i = 0; i < outer.length; i++) {
      final double phase = i / outer.length;
      final double wave = 0.5 - 0.5 * cos(2 * pi * (progress + phase));
      _drawNode(
        canvas,
        outer[i],
        w * _outerR * (0.82 + 0.30 * wave),
        color.withValues(alpha: 0.30 + 0.70 * wave),
      );
    }
  }

  void _drawNode(Canvas canvas, Offset c, double r, Color nodeColor) {
    final Paint p = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, r, p);
  }

  @override
  bool shouldRepaint(covariant _HivorrLoaderPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
