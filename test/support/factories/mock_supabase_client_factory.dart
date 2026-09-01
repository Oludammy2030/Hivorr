import 'package:supabase_flutter/supabase_flutter.dart';

import '../fakes/fake_network.dart';
import '../fakes/fake_supabase.dart';

/// Scriptable [SupabaseClient] used by [MockSupabaseClientFactory].
///
/// Data/RPC paths are served by an in-memory [ScriptedHttpClient] (no network);
/// auth state is exposed through [goTrue] for assertions and is seeded from
/// [MockSupabaseClientFactory.create]'s `currentUser`/`currentSession` args.
class ScriptedSupabaseClient extends SupabaseClient {
  ScriptedSupabaseClient({
    required this.goTrue,
    this.rpcHandlers,
    this.queryResults,
    this.queryError,
  }) : super(
          'https://example.supabase.co',
          'public-anon-key',
          httpClient: ScriptedHttpClient(
            queryResults: queryResults,
            queryError: queryError,
            rpcHandlers: rpcHandlers,
          ),
        );

  /// Controllable auth client for state assertions.
  ///
  /// This is surfaced through [auth] so repository code that reads
  /// `supabase.auth.currentUser` observes the seeded session.
  final FakeGoTrueClient goTrue;

  @override
  GoTrueClient get auth => goTrue;

  /// Scripted RPC handlers keyed by function name.
  final Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers;

  /// Scripted REST query rows keyed by table name.
  final Map<String, List<Map<String, dynamic>>>? queryResults;

  /// When non-null, thrown on every REST query attempt.
  final Object? queryError;
}

/// One-call factory for a fully configured, network-free [SupabaseClient].
///
/// Usage:
/// ```dart
/// final client = MockSupabaseClientFactory.create(
///   currentUser: fakeUser('u1'),
///   rpcHandlers: {'get_listing': (p) => <String, dynamic>{}},
/// );
/// ```
class MockSupabaseClientFactory {
  MockSupabaseClientFactory._();

  /// Creates a [SupabaseClient] in signed-out state by default.
  ///
  /// - [currentUser]/[currentSession] seed the [ScriptedSupabaseClient.goTrue]
  ///   auth state (signed-in when provided).
  /// - [rpcHandlers] script RPC functions by name.
  /// - [queryResults]/[queryError] script REST table queries.
  static SupabaseClient create({
    User? currentUser,
    Session? currentSession,
    Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers,
    Map<String, List<Map<String, dynamic>>>? queryResults,
    Object? queryError,
  }) {
    final FakeGoTrueClient goTrue = FakeGoTrueClient();
    if (currentSession != null) {
      goTrue.seedSession(currentSession);
    } else if (currentUser != null) {
      goTrue.seedSession(fakeSession(currentUser.id));
    }
    final ScriptedSupabaseClient supabaseClient = ScriptedSupabaseClient(
      goTrue: goTrue,
      rpcHandlers: rpcHandlers,
      queryResults: queryResults,
      queryError: queryError,
    );
    // SupabaseClient starts a background auto-refresh ticker on construction;
    // cancel it so tests under fake_async don't leak pending timers.
    supabaseClient.auth.stopAutoRefresh();
    return supabaseClient;
  }
}
