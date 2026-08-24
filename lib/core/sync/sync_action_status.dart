/// The lifecycle state of a queued sync action.
///
/// Actions progress through these states as the sync engine enqueues, replays,
/// retries, or dead-letters them (EP-01-12 §5.3).
enum SyncActionStatus {
  /// Waiting in the queue for the next drain cycle.
  pending,

  /// Currently being replayed to the server via the API layer.
  inFlight,

  /// Last replay attempt failed; will be retried with backoff.
  failed,

  /// Exhausted all retries or rejected by the server; retained for
  /// diagnostics, not replayed.
  deadLettered,

  /// Server returned 409 Conflict; flagged for future resolution.
  ///
  /// The server is the conflict authority; the client never resolves
  /// conflicts automatically (AGENT.md Rule 4).
  conflicted,
}
