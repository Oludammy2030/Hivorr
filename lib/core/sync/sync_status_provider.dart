import 'package:flutter/foundation.dart';

import 'package:hivorr/core/sync/sync_exception.dart';
import 'package:hivorr/core/sync/sync_status.dart';

/// Observable sync engine state for downstream consumers.
///
/// Exposes the current [SyncStatus], pending action count, dead-letter count,
/// and last error. Implemented as a [ChangeNotifier] so EP-01-15/16 UI layers
/// can listen for offline banners and sync indicators (EP-01-12 §5.9).
///
/// This class does not build any UI; it is purely a state container.
class SyncStatusProvider extends ChangeNotifier {
  SyncStatus _status = SyncStatus.idle;
  int _pendingCount = 0;
  int _deadLetterCount = 0;
  SyncException? _lastError;
  bool _isDisposed = false;

  /// The current engine state.
  SyncStatus get status => _status;

  /// Number of actions in the queue (pending + inFlight).
  int get pendingCount => _pendingCount;

  /// Number of dead-lettered actions (exhausted retries or conflicts).
  int get deadLetterCount => _deadLetterCount;

  /// The most recent error, or `null` if the last drain succeeded.
  SyncException? get lastError => _lastError;

  /// Sets the status and notifies listeners.
  void setStatus(SyncStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  /// Sets the pending count and notifies listeners.
  void setPendingCount(int value) {
    if (_pendingCount == value) return;
    _pendingCount = value;
    notifyListeners();
  }

  /// Sets the dead-letter count and notifies listeners.
  void setDeadLetterCount(int value) {
    if (_deadLetterCount == value) return;
    _deadLetterCount = value;
    notifyListeners();
  }

  /// Sets the last error, switches status to [SyncStatus.error], and
  /// notifies listeners.
  void setError(SyncException error) {
    _lastError = error;
    _status = SyncStatus.error;
    notifyListeners();
  }

  /// Clears the last error (called on successful drain).
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Resets all fields to their initial values (test helper).
  ///
  /// Idempotent: calling multiple times is safe.
  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _status = SyncStatus.idle;
    _pendingCount = 0;
    _deadLetterCount = 0;
    _lastError = null;
    super.dispose();
  }
}
