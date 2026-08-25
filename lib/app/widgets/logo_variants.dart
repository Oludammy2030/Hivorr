import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable Hivorr logo variants.
///
/// All variants render the brand mark consistently (hub-and-spoke network of
/// silver nodes + cerulean tile where applicable). See
/// `documents/Context/VISUAL-IDENTITY.md` §5 for the canonical artwork and the
/// guidance on when to use each variant.
///
/// Sizing follows the [height]-first convention used across the app: pass the
/// desired height and the width is derived from the asset's intrinsic aspect
/// ratio.
class LogoIcon extends StatelessWidget {
  const LogoIcon({super.key, this.size = 48, this.fit = BoxFit.contain});

  /// Rendered square size (the asset is 1:1).
  final double size;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/logo_icon.svg',
    width: size,
    height: size,
    fit: fit,
  );
}

/// Horizontal lockup: emblem to the left of the "Hivorr" wordmark.
class LogoHorizontal extends StatelessWidget {
  const LogoHorizontal({
    super.key,
    this.height = 40,
    this.fit = BoxFit.contain,
  });

  /// Rendered height; width derives from the 256:80 (3.2:1) aspect ratio.
  final double height;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/logo_horizontal.svg',
    height: height,
    fit: fit,
  );
}

/// Stacked lockup: emblem above the "Hivorr" wordmark.
class LogoStacked extends StatelessWidget {
  const LogoStacked({super.key, this.height = 120, this.fit = BoxFit.contain});

  /// Rendered height; width derives from the 256:300 aspect ratio.
  final double height;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/logo_stacked.svg',
    height: height,
    fit: fit,
  );
}

/// Monochrome lockup: single-color wordmark + emblem (no tile, no cerulean),
/// tinted via [color]. Defaults to white for dark headers/footers.
class LogoMonochrome extends StatelessWidget {
  const LogoMonochrome({
    super.key,
    this.height = 40,
    this.color = Colors.white,
    this.fit = BoxFit.contain,
  });

  /// Rendered height; width derives from the 320:80 (4:1) aspect ratio.
  final double height;

  /// Tint for the whole lockup. The underlying SVG is white, so any color
  /// applied via [ColorFilter] replaces it directly.
  final Color color;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/logo_monochrome.svg',
    height: height,
    fit: fit,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}
