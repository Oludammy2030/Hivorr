import 'package:hivorr/core/sync/sync_action_status.dart';

/// The type of mutation a sync action represents.
///
/// Used for diagnostics and dead-letter inspection; the sync engine itself
/// does not branch on the type — it replays all actions the same way through
/// the API layer (EP-01-12 §5.3).
enum SyncActionType { create, update, delete }

/// A serializable record describing a pending offline mutation.
///
/// Each action carries the full information needed to replay a single API
/// request: the HTTP method, endpoint path, optional payload, and metadata for
/// retry, priority, and conflict detection.
///
/// The sync engine does not inspect, validate, or transform the [payload] —
/// validation is the server's responsibility (RLS + RPC). No tokens, secrets,
/// or credentials are stored in action records; auth is injected by the API
/// layer's `AuthInterceptor` during replay (AGENT.md Rule 4).
class SyncAction {
  const SyncAction({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    required this.priority,
    required this.status,
    required this.retryCount,
    required this.maxRetries,
    required this.createdAt,
    this.payload,
    this.headers,
    this.lastKnownVersion,
    this.lastAttemptAt,
    this.errorMessage,
  });

  /// Unique action ID (UUID v4).
  final String id;

  /// Mutation type (for diagnostics only; engine does not branch on this).
  final SyncActionType type;

  /// API endpoint path (e.g., `/rpc/update_entity_profile`).
  final String endpoint;

  /// HTTP method (`POST`, `PUT`, `PATCH`, `DELETE`).
  final String method;

  /// Request body (JSON-compatible). `null` for `DELETE` requests.
  final Map<String, dynamic>? payload;

  /// Optional per-action headers.
  final Map<String, String>? headers;

  /// Priority (lower = higher priority; 0 = critical, 10 = default).
  final int priority;

  /// Current lifecycle state.
  final SyncActionStatus status;

  /// Number of replay attempts so far.
  final int retryCount;

  /// Ceiling before dead-lettering.
  final int maxRetries;

  /// Optimistic concurrency version (for conflict detection on 409).
  final int? lastKnownVersion;

  /// Enqueue timestamp.
  final DateTime createdAt;

  /// Last replay attempt timestamp.
  final DateTime? lastAttemptAt;

  /// Last failure reason.
  final String? errorMessage;

  /// Returns a copy of this action with the specified fields updated.
  SyncAction copyWith({
    SyncActionStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) {
    return SyncAction(
      id: id,
      type: type,
      endpoint: endpoint,
      method: method,
      payload: payload,
      headers: headers,
      priority: priority,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      lastKnownVersion: lastKnownVersion,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Serializes this action to a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'headers': headers,
      'priority': priority,
      'status': status.name,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'lastKnownVersion': lastKnownVersion,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// Deserializes an action from a JSON-compatible map.
  factory SyncAction.fromJson(Map<String, dynamic> json) {
    return SyncAction(
      id: json['id'] as String,
      type: SyncActionType.values.byName(json['type'] as String),
      endpoint: json['endpoint'] as String,
      method: json['method'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
      headers: (json['headers'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      priority: json['priority'] as int,
      status: SyncActionStatus.values.byName(json['status'] as String),
      retryCount: json['retryCount'] as int,
      maxRetries: json['maxRetries'] as int,
      lastKnownVersion: json['lastKnownVersion'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
