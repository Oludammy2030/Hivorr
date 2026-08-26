import 'package:flutter/foundation.dart';

/// Loading / error state management for stateful widgets and controllers.
///
/// Mix into any [ChangeNotifier] to expose a consistent `isLoading` /
/// `hasError` / `errorMessage` contract and a [runWithLoading] helper that
/// wraps an async action with safe state transitions.
mixin LoadingStateMixin on ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  /// Whether an action is currently in flight.
  bool get isLoading => _isLoading;

  /// Whether the last action produced an error.
  bool get hasError => _errorMessage != null;

  /// The captured error message, or `null` when there is no error.
  String? get errorMessage => _errorMessage;

  /// Runs [action], surfacing loading and error state to listeners.
  ///
  /// Sets [isLoading] to `true` and clears any prior error, executes [action],
  /// captures any thrown exception into [errorMessage], and finally resets
  /// [isLoading] to `false`. Listeners are notified on every state change.
  Future<void> runWithLoading(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
