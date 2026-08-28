/// Notification delivery priority.
///
/// Maps onto platform importance/presentation semantics without carrying any
/// business meaning. The client is an unprivileged delivery layer (AGENT.md
/// Rules 1 & 4) — priority only influences rendering, never business logic.
enum NotificationPriority {
  /// Lowest priority: no sound, banner-only (Android `IMPORTANCE_LOW`).
  low(0),

  /// Default priority: sound + banner (Android `IMPORTANCE_DEFAULT`).
  normal(1),

  /// High priority: heads-up display (Android `IMPORTANCE_HIGH`).
  high(2),

  /// Highest priority: persistent heads-up (Android `IMPORTANCE_MAX`).
  urgent(3);

  const NotificationPriority(this.value);

  /// Numeric weight used for ordering and platform mapping.
  final int value;
}
