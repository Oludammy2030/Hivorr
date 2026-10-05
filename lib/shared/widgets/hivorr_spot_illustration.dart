import 'dart:math';

import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// Spot-illustration variant: rotates the constellation and moves the
/// highlighted node so nearby empty states don't look stamped out.
enum HivorrSpotVariant { general, search, messages, orders }

/// Static brand spot illustration in the node-network language.
///
/// A soft tinted disc, one thin orbit ring, and a small constellation —
/// monochrome primary, layered alphas. Deliberately static (no controller):
/// correct under reduced motion with no extra path, and cheap enough for
/// lists of empty states. This is decoration with a job (§16a): it warms
/// empty/error/success surfaces while echoing the loader and logo mark.
class HivorrSpotIllustration extends StatelessWidget {
  const HivorrSpotIllustration({
    super.key,
    this.variant = HivorrSpotVariant.general,
    this.size = 96,
    this.foreground,
    this.background,
  });

  final HivorrSpotVariant variant;
  final double size;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpotPainter(
          variant: variant,
          foreground: foreground ?? colors.primary,
          background: background ?? colors.primaryContainer,
        ),
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  const _SpotPainter({
    required this.variant,
    required this.foreground,
    required this.background,
  });

  final HivorrSpotVariant variant;
  final Color foreground;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final Offset center = Offset(w / 2, w / 2);

    // Soft disc.
    canvas.drawCircle(
      center,
      w * 0.48,
      Paint()..color = background,
    );

    // Thin orbit ring.
    canvas.drawCircle(
      center,
      w * 0.36,
      Paint()
        ..color = foreground.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, w * 0.008),
    );

    // Constellation: center + 4 orbiters; the variant rotates the ring and
    // picks which node carries the full-strength highlight.
    final double rotation = variant.index * pi / 6;
    final List<Offset> outer = <Offset>[
      for (int i = 0; i < 4; i++)
        center +
            Offset(
              cos(rotation + i * pi / 2) * w * 0.26,
              sin(rotation + i * pi / 2) * w * 0.26,
            ),
    ];

    final Paint linkPaint = Paint()
      ..color = foreground.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, w * 0.012)
      ..strokeCap = StrokeCap.round;
    for (final Offset o in outer) {
      canvas.drawLine(center, o, linkPaint);
    }

    final int highlight = variant.index % 4;
    for (int i = 0; i < outer.length; i++) {
      final bool hot = i == highlight;
      canvas.drawCircle(
        outer[i],
        w * (hot ? 0.052 : 0.038),
        Paint()
          ..color = foreground.withValues(alpha: hot ? 1.0 : 0.45),
      );
    }
    canvas.drawCircle(
      center,
      w * 0.068,
      Paint()..color = foreground.withValues(alpha: 0.85),
    );
    // Pin the center with a paper dot so the mark reads at small sizes.
    canvas.drawCircle(
      center,
      w * 0.026,
      Paint()..color = background,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotPainter old) =>
      old.variant != variant ||
      old.foreground != foreground ||
      old.background != background;
}
