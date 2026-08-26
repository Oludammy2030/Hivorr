import 'package:flutter/widgets.dart';

/// Callback invoked on application lifecycle state changes.
typedef LifecycleCallback = void Function(AppLifecycleState state);

/// Thin, testable wrapper around [WidgetsBindingObserver].
///
/// Decouples lifecycle observation from the widget tree so it can be unit
/// tested without a live Flutter engine (EP-01-15 §5.4). All registration is
/// via an extensible callback list rather than hard-coded logic.
class AppLifecycleObserver with WidgetsBindingObserver {
  final List<LifecycleCallback> _callbacks = <LifecycleCallback>[];

  /// Registers a [LifecycleCallback] to receive lifecycle transitions.
  ///
  /// Returns a disposer that removes the callback when invoked.
  void Function() register(LifecycleCallback callback) {
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }

  void _notify(AppLifecycleState state) {
    for (final LifecycleCallback callback
        in List<LifecycleCallback>.of(_callbacks)) {
      callback(state);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _notify(state);

  /// Removes all callbacks and detaches from the binding.
  void dispose() {
    _callbacks.clear();
    WidgetsBinding.instance.removeObserver(this);
  }
}
