/// Unified-account activity launcher (Explore with Hivorr / Earn with Hivorr).
///
/// Barrel re-exporting the activity catalogue + launcher screen. Activities are
/// intent entry points, not permissions: one `entities` account can activate
/// many activities over time. Server RPCs + RLS stay authoritative (AGENT.md
/// Rule 4). UI uses only [AppTheme] tokens (AGENT.md Rule 5).
library;

export 'package:hivorr/systems/activities/models/hivorr_activity.dart';
export 'package:hivorr/systems/activities/screens/activities_screen.dart';
