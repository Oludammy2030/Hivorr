import 'package:hivorr/core/sync/sync_action.dart';
import 'package:hivorr/core/sync/sync_action_status.dart';

/// Basic conflict detection on HTTP 409 Conflict responses.
///
/// On a 409, the detector flags the action as [conflicted] and stores the
/// server version (if present in the response body) in the action's
/// `errorMessage` for diagnostics. The action is then moved to dead-letter.
///
/// **No resolution:** the engine does not attempt merge, server-wins, or
/// client-wins strategies. The server is the conflict authority (AGENT.md
/// Rule 4). Complex resolution is deferred to a future phase (EP-01-12 §5.8).
class ConflictDetector {
  const ConflictDetector();

  /// Returns a copy of [action] with status `conflicted` and an error message
  /// containing the server version (if available in [responseData]).
  ///
  /// Conservative: if [responseData] is `null` or does not contain a version,
  /// the action is still flagged as conflicted — the server's 409 is
  /// authoritative regardless of whether version info is present.
  SyncAction detect(
    SyncAction action,
    Map<String, dynamic>? responseData,
  ) {
    final int? serverVersion = _extractVersion(responseData);
    final int? clientVersion = action.lastKnownVersion;

    final StringBuffer message = StringBuffer('Conflict detected (HTTP 409).');
    if (clientVersion != null) {
      message.write(' Client version: $clientVersion.');
    }
    if (serverVersion != null) {
      message.write(' Server version: $serverVersion.');
    }

    return action.copyWith(
      status: SyncActionStatus.conflicted,
      errorMessage: message.toString(),
    );
  }

  /// Attempts to extract a version field from the 409 response body.
  ///
  /// Checks common field names: `version`, `server_version`,
  /// `current_version`. Returns `null` if no version is found.
  static int? _extractVersion(Map<String, dynamic>? responseData) {
    if (responseData == null) {
      return null;
    }

    const List<String> versionKeys = <String>[
      'version',
      'server_version',
      'current_version',
    ];

    for (final String key in versionKeys) {
      final dynamic value = responseData[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final int? parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
