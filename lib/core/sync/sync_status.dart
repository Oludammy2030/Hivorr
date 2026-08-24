/// The high-level state of the offline sync engine.
///
/// Downstream consumers (EP-01-15 router, EP-01-16 UI) listen to
/// [SyncStatusProvider] for offline banners and sync indicators
/// (EP-01-12 §5.9).
enum SyncStatus {
  /// No pending actions; engine is idle.
  idle,

  /// Actively draining and replaying the action queue.
  syncing,

  /// Device is offline; actions are being queued but not replayed.
  offline,

  /// An error occurred during the last drain cycle.
  error,
}
