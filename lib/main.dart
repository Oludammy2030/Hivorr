import 'dart:async';

import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:hivorr/app/app_bootstrap.dart';

/// Application entrypoint.
///
/// [usePathUrlStrategy] opts the web build into clean, SEO-friendly path URLs
/// (e.g. `hivorr.com/welcome`, `hivorr.com/p/electrician/abc-123`) instead of
/// hash URLs. It is a no-op on non-web platforms, so the same entrypoint is
/// safe for Android/iOS/desktop. Supabase email-confirmation redirect URLs
/// must be configured against path-based links (entry architecture §8).
void main() {
  usePathUrlStrategy();
  unawaited(AppBootstrap.run());
}
