import 'package:flutter/widgets.dart';

import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:provider/provider.dart';

/// Signs out and evicts the device-local messaging cache (EP-03-13).
///
/// Thread windows + composer drafts are warm-then-refresh cache only; they
/// must not survive into the next session on a shared device. Eviction runs
/// before sign-out while the widget tree (and its providers) is still
/// mounted. An absent messaging slice is tolerated (admin shell, isolated
/// widget tests) so sign-out itself never fails because of cache cleanup.
Future<void> signOutAndEvictMessagingCache(BuildContext context) async {
  // Capture providers before any await — the tree may unmount mid-sign-out.
  final AuthProvider auth = context.read<AuthProvider>();
  MessagingProvider? messaging;
  try {
    messaging = context.read<MessagingProvider>();
  } on Object {
    messaging = null;
  }
  try {
    await messaging?.clearCache();
  } on Object {
    // Cache cleanup is best-effort — sign-out still proceeds.
  }
  await auth.signOut();
}
