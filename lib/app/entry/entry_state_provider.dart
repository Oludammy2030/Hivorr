// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'package:hivorr/data/local/entry_state_store.dart';

/// Provider exposing the entry-state rows to the widget tree and the guard
/// (entry architecture §5).
///
/// A thin state mirror over [EntryStateStore] — it owns no transport and hides
/// storage failures behind sensible defaults so the entry flow is never blocked
/// by local I/O. The site of the "one-time intro" flag and the deep-link
/// destination preserved across registration (pending redirect).
class EntryStateProvider extends ChangeNotifier {
  /// Creates the provider bound to [store].
  EntryStateProvider({required EntryStateStore store}) : _store = store;

  final EntryStateStore _store;

  bool _hydrated = false;
  bool _introSeen = false;
  String? _pendingRedirect;

  /// Whether [hydrate] has completed at least once.
  bool get isHydrated => _hydrated;

  /// Whether the one-time native intro has been shown on this device.
  bool get introSeen => _introSeen;

  /// The deep-link destination preserved across registration, if any.
  String? get pendingRedirect => _pendingRedirect;

  /// Whether a pending redirect is waiting to be honored.
  bool get hasPendingRedirect => _pendingRedirect != null;

  /// Loads [introSeen] and [pendingRedirect] from the store.
  Future<void> hydrate() async {
    _introSeen = await _store.readIntroSeen() ?? false;
    _pendingRedirect = await _store.readPendingRedirect();
    _hydrated = true;
    notifyListeners();
  }

  /// Persists the one-time "intro seen" flag.
  Future<void> markIntroSeen() async {
    _introSeen = true;
    await _store.writeIntroSeen(true);
    notifyListeners();
  }

  /// Persists [redirect]; `null` clears any stored pending redirect.
  Future<void> setPendingRedirect(String? redirect) async {
    _pendingRedirect = redirect;
    await _store.writePendingRedirect(redirect);
    notifyListeners();
  }

  /// Clears only the pending redirect and returns what was stored.
  Future<String?> consumePendingRedirect() async {
    final String? next = _pendingRedirect;
    await setPendingRedirect(null);
    return next;
  }
}
