// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// In-memory [http.Client] that returns scripted REST/RPC responses without
/// any network access, for [MockSupabaseClientFactory].
///
/// - REST queries (`/rest/v1/<table>...`) resolve to [queryResults].
/// - RPC calls (`/rest/v1/rpc/<fn>`) resolve to the matching [rpcHandlers]
///   entry (the handler receives the decoded request body).
/// - When [queryError] is set, any REST query throws it, simulating a backend
///   failure surfaced by PostgREST.
class ScriptedHttpClient extends http.BaseClient {
  ScriptedHttpClient({
    this.queryResults,
    this.queryError,
    this.rpcHandlers,
  });

  /// Scripted rows keyed by table name.
  final Map<String, List<Map<String, dynamic>>>? queryResults;

  /// When non-null, thrown on every REST query attempt.
  final Object? queryError;

  /// Scripted RPC handlers keyed by function name.
  final Map<String, Object? Function(Map<String, dynamic>)>? rpcHandlers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final Uri uri = request.url;
    final String path = uri.path;

    if (path.contains('/rest/v1/rpc/')) {
      final String fn = path.split('/rest/v1/rpc/').last;
      final handler = rpcHandlers?[fn];
      final Map<String, dynamic> body = _decodeBody(request);
      final Object result = handler == null
          ? <String, dynamic>{}
          : handler(body) as Object;
      return _jsonResponse(200, result, request);
    }

    if (queryError != null) {
      if (queryError is Exception || queryError is Error) {
        // ignore: only_throw_errors
        throw queryError!;
      }
      throw Exception(queryError.toString());
    }

    final String table = path.contains('/rest/v1/')
        ? path.split('/rest/v1/').last.split('?').first
        : path;
    final List<Map<String, dynamic>> data =
        queryResults?[table] ?? <Map<String, dynamic>>[];
    return _jsonResponse(200, data, request);
  }

  Map<String, dynamic> _decodeBody(http.BaseRequest request) {
    if (request is http.Request && request.body.isNotEmpty) {
      try {
        return jsonDecode(request.body) as Map<String, dynamic>;
      } on Object {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  http.StreamedResponse _jsonResponse(
    int statusCode,
    Object body,
    http.BaseRequest request,
  ) {
    final List<int> bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      request: request,
      headers: <String, String>{
        'content-type': 'application/json',
      },
    );
  }
}

/// Controllable connectivity monitor for network-dependent tests.
class FakeConnectivityMonitor {
  FakeConnectivityMonitor({this.isOnline = true});

  bool isOnline;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  /// Emits connectivity transitions.
  Stream<bool> get onStatusChanged => _controller.stream;

  /// Updates the simulated connectivity and notifies listeners.
  void setOnline(bool value) {
    isOnline = value;
    _controller.add(value);
  }

  /// Snapshot check used by consumers that poll rather than stream.
  Future<bool> check() async => isOnline;

  /// Closes the broadcast stream.
  Future<void> dispose() async => _controller.close();
}

/// Controllable network status provider for network-dependent tests.
class FakeNetworkStatusProvider {
  FakeNetworkStatusProvider({this.isOnline = true});

  bool isOnline;

  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  /// Emits network status transitions.
  Stream<bool> get status => _controller.stream;

  /// Simulates the device coming online.
  void goOnline() {
    isOnline = true;
    _controller.add(true);
  }

  /// Simulates the device going offline.
  void goOffline() {
    isOnline = false;
    _controller.add(false);
  }

  /// Closes the broadcast stream.
  Future<void> dispose() async => _controller.close();
}
