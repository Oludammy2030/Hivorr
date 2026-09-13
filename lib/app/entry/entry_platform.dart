// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

/// Device/platform context for entry routing (entry architecture §4).
///
/// Pure (no BuildContext, no go_router) so the same decision logic drives both
/// the widget layer and the guard layer:
///
/// * Web builds land on the public `/welcome` landing.
/// * Native builds route through `/intro` on first launch, then to `/login`
///   for returning visitors.
abstract final class EntryPlatform {
  const EntryPlatform._();

  /// Whether this build is the Flutter-Web landing experience.
  static bool get isWeb => kIsWeb;
}