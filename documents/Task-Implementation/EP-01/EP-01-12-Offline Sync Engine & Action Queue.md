# TASK IMPLEMENTATION PLAN: EP-01-12

## Offline Sync Engine & Action Queue

| Field | Value |
|---|---|
| Task ID | EP-01-12 |
| Task Name | Offline Sync Engine & Action Queue |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-07 (Core API Layer & HTTP Client Architecture — completed), EP-01-11 (Local Storage & Cache Management System — completed). Parallel with EP-01-13 (Network Management). Consumed downstream by EP-01-20 (phase integration validation) and EP-02+ (all offline-capable features). |
| Priority | High |
| Planning Reasoning | Very High (approved EP-01 matrix) |
| Coding Reasoning | Very High (approved EP-01 matrix) |

---

## 1. Task Objective

Implement the client-side offline sync engine and action queue in the ARCHITECTURE.md-mandated directory `lib/core/sync/`:

- **Action Queue** — a FIFO + priority queue of pending offline mutations (create, update, delete), persisted durably in the `sync_queue` box of EP-01-11's `StorageEngine` via atomic `writeBatch`, surviving app restart and crash.
- **Sync Engine** — an orchestrator that drains the queue on connectivity restoration, replays each action through the EP-01-07 API layer (Dio with full interceptor chain), handles success/failure, and manages retry with exponential backoff + jitter.
- **Connectivity Abstraction** — a `ConnectivityProvider` interface with a basic `connectivity_plus`-backed implementation, enabling connectivity-triggered replay. EP-01-13 may later replace this with a richer provider.
- **Basic Conflict Detection** — version/timestamp comparison on server 409 responses, flagging conflicted actions without attempting automated resolution (complex resolution deferred).
- **Observable Sync Status** — a `ChangeNotifier`-based status provider exposing `idle | syncing | offline | error` states and queue depth for downstream UI consumption (EP-01-15+).

Deliverables:
- A persistent, crash-safe action queue backed by `StorageEngine` (`sync_queue` box).
- A replay engine that drains the queue through the API layer with retry, backoff, and jitter.
- A connectivity abstraction with a basic default implementation.
- Basic conflict detection (flag, not resolve).
- An observable sync status provider.
- A sync configuration class sourced from `EnvironmentConfig`.
- Unit tests proving enqueue/dequeue persistence, replay ordering, retry backoff, conflict flagging, and status transitions.
- `flutter analyze` (strict lints) + `flutter test` must pass.

**Dependency note:** EP-01-12 depends on EP-01-07 (API layer) and EP-01-11 (storage engine) per the approved matrix. EP-01-13 (Network Management) is a parallel task — this task defines its own minimal connectivity interface and does not consume EP-01-13 code.

---

## 2. Business Problem Being Solved

Without an offline sync engine:

- Users in the Nigeria market (unreliable connectivity) would lose every mutation attempted while offline — form submissions, status updates, message drafts, booking requests.
- The platform would be unusable during network interruptions, directly contradicting the "platform usability with unreliable connectivity" requirement (EP-01-12 engineering purpose).
- The `sync_queue` box reserved in EP-01-11's `AppBoxes` would remain empty, and the `StorageEngine.writeBatch` atomic primitive would have no consumer.
- Every future feature (EP-02+) would need to hand-roll offline handling, scattering retry/conflict logic across the codebase and fracturing the architectural boundary.
- No observable sync status means no offline indicators in the UI, leaving users unaware of pending actions.

This is the **offline resilience backbone** — it turns the client into a resilient, offline-capable presentation layer that queues mutations and replays them reliably when connectivity returns (AGENT.md Rule 4, zero-trust client).

---

## 3. Scope

### In Scope

- `lib/core/sync/` module (§5.2): `sync_config.dart`, `sync_action.dart`, `sync_action_status.dart`, `action_queue.dart`, `sync_engine.dart`, `sync_status.dart`, `sync_status_provider.dart`, `connectivity_provider.dart`, `connectivity_plus_provider.dart`, `conflict_detector.dart`, `sync_exception.dart`, `sync.dart` barrel + `initializeSyncEngine()`.
- **Action queue** with FIFO + priority ordering, persistent storage via `StorageEngine` (`sync_queue` box), atomic enqueue/dequeue via `writeBatch`, and queue depth tracking.
- **Sync engine orchestrator** that drains the queue on connectivity restoration, replays actions through `Dio` (EP-01-07 API layer), handles success (dequeue) and failure (retry with backoff + jitter), and respects max retry limits (dead-letter on exhaustion).
- **Connectivity abstraction** (`ConnectivityProvider` interface) with a basic `connectivity_plus`-backed default implementation and a `ManualConnectivityProvider` for testing.
- **Basic conflict detection** — on server 409 Conflict response, compare action's `lastKnownVersion` with server state, flag the action as conflicted, and move to dead-letter. No automated resolution.
- **Observable sync status** — `SyncStatusProvider` (ChangeNotifier) exposing `SyncStatus` enum (`idle`, `syncing`, `offline`, `error`) and `pendingCount`.
- **Sync configuration** sourced from `EnvironmentConfig` (retry policy, max queue depth, backoff parameters, feature gate via `FeatureFlags.enableOfflineSync`).
- **New dependencies** (D1): `connectivity_plus` (connectivity detection), `uuid` (action ID generation) — added to `pubspec.yaml`.
- Unit tests (`test/unit/core/sync/`): queue persistence, replay ordering, retry backoff timing, conflict flagging, status transitions, dead-letter on max retries.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Complex conflict resolution strategies (merge, server-wins, client-wins, user-prompted) — deferred to a future phase.
- Network type detection (WiFi/mobile/ethernet), payload optimization utilities — EP-01-13.
- Building repositories, DTOs, mappers, or remote datasources — EP-01-08.
- Background sync (workmanager/platform channels for sync when app is killed) — deferred.
- UI widgets (offline banners, sync indicators, retry buttons) — EP-01-15/16+.
- Auth framework, token refresh during replay — EP-01-09 (the API layer's `RetryInterceptor` already handles 401 refresh transparently).
- Secure storage of secrets/tokens — EP-01-10.
- Supabase migrations, RPC, RLS — EP-01-05/06.
- Monitoring/logging integration — EP-01-14 (the sync engine emits events; EP-01-14 wires them to Sentry).
- Modification of EP-01-07, EP-01-08, EP-01-11, or EP-01-13 files.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification logic is permitted. This layer **queues and replays mutations**; it does not authorize, compute, or decide outcomes. It must never store secrets or tokens (those belong to EP-01-10 `SecureStorage`). The sync engine operates purely as an unprivileged client-side replay buffer — all server-side enforcement (RLS, RPC validation, conflict authority) remains authoritative (AGENT.md Rule 4).

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Persistence via `StorageEngine` abstraction only | EP-01-11; no direct Hive/driver calls |
| Replay via EP-01-07 API layer (Dio + interceptors) | EP-01-07; auth/retry/error handled by interceptor chain |
| Feature-gated via `FeatureFlags.enableOfflineSync` | EP-01-03 |
| No business logic in client | AGENT.md Rules 1, 4 |
| Server is the conflict authority | AGENT.md Rule 4; client flags, never resolves |

### 5.2 Proposed Structure

```text
lib/core/sync/
├── sync_config.dart                  # retry policy, backoff params, max queue depth, batch size
├── sync_action.dart                  # action record model (id, type, endpoint, payload, priority, etc.)
├── sync_action_status.dart           # enum: pending, inFlight, failed, deadLettered, conflicted
├── action_queue.dart                 # FIFO + priority queue backed by StorageEngine (sync_queue box)
├── sync_engine.dart                  # orchestrator: drain, replay, retry, conflict detect, status emit
├── sync_status.dart                  # enum: idle, syncing, offline, error
├── sync_status_provider.dart         # ChangeNotifier exposing SyncStatus + pendingCount
├── connectivity_provider.dart        # abstract interface: Stream<ConnectivityStatus> + isConnected
├── connectivity_plus_provider.dart   # basic default impl using connectivity_plus
├── conflict_detector.dart            # basic version/timestamp comparison on 409 responses
├── sync_exception.dart               # typed exception for sync operations
└── sync.dart                         # barrel + initializeSyncEngine()
```

### 5.3 Sync Action Model (`sync_action.dart`)

Each queued action is a serializable record:

| Field | Type | Purpose |
|---|---|---|
| `id` | `String` | Unique action ID (UUID v4) |
| `type` | `SyncActionType` | Enum: `create`, `update`, `delete` |
| `endpoint` | `String` | API endpoint path (e.g., `/rpc/update_entity_profile`) |
| `method` | `String` | HTTP method (`POST`, `PUT`, `PATCH`, `DELETE`) |
| `payload` | `Map<String, dynamic>?` | Request body (JSON-compatible) |
| `headers` | `Map<String, String>?` | Optional per-action headers |
| `priority` | `int` | Lower = higher priority (0 = critical, 10 = default) |
| `status` | `SyncActionStatus` | Current state |
| `retryCount` | `int` | Number of replay attempts |
| `maxRetries` | `int` | Ceiling before dead-letter |
| `lastKnownVersion` | `int?` | Optimistic concurrency version (for conflict detection) |
| `createdAt` | `DateTime` | Enqueue timestamp |
| `lastAttemptAt` | `DateTime?` | Last replay attempt timestamp |
| `errorMessage` | `String?` | Last failure reason |

Serialization: `toJson()` / `fromJson(Map<String, dynamic>)` — stored as `Map<String, dynamic>` in `StorageEngine`.

### 5.4 Action Queue (`action_queue.dart`)

- **Backed by `StorageEngine`** using the `sync_queue` box (pre-registered in `AppBoxes.syncQueue`).
- **Enqueue:** `writeBatch` with a `PutOp` — atomic, crash-safe. Assigns UUID, sets `status = pending`, `createdAt = now`.
- **Dequeue (on success):** `delete(box, key)` — removes the action from persistent storage.
- **Peek/Drain:** `keys(box)` + `get(box, key)` for each — loads all actions, sorts by `(priority ASC, createdAt ASC)` for FIFO + priority ordering.
- **Update (on retry):** `put(box, key, updatedAction)` — increments `retryCount`, updates `lastAttemptAt`, `errorMessage`.
- **Dead-letter:** on max retry exhaustion, action status set to `deadLettered`, retained in queue for diagnostics (not replayed).
- **Queue depth:** `keys(box).length` — exposed via `SyncStatusProvider.pendingCount`.
- **Atomicity guarantee:** `writeBatch` ensures enqueue cannot be half-written on crash (EP-01-11's snapshot-rollback semantics).

### 5.5 Sync Engine Orchestrator (`sync_engine.dart`)

The core replay loop:

1. **Trigger:** connectivity change (offline → online) via `ConnectivityProvider` stream, or manual `drain()` call.
2. **Guard:** if `FeatureFlags.enableOfflineSync` is `false`, the engine is a no-op (all `enqueue` calls throw `SyncException('Offline sync disabled')`).
3. **Drain:** load all pending actions from `ActionQueue`, sort by `(priority ASC, createdAt ASC)`.
4. **Replay loop:** for each action:
   - Set status to `inFlight`, update in queue.
   - Execute via `Dio` (from EP-01-07 `ApiLayer`): `dio.request(action.endpoint, data: action.payload, options: Options(method: action.method, headers: action.headers))`.
   - **On success (2xx):** dequeue action from queue. Emit `SyncStatus.idle` when queue empty.
   - **On 409 Conflict:** pass to `ConflictDetector`. Flag action as `conflicted`, move to dead-letter. Continue with next action.
   - **On transient failure (network error, 5xx, timeout):** increment `retryCount`, apply exponential backoff + jitter, schedule retry. If `retryCount >= maxRetries`, set `deadLettered`.
   - **On auth failure (401):** the API layer's `RetryInterceptor` handles token refresh + single retry transparently. If it still fails, treat as transient.
   - **On client error (4xx except 401/409):** do not retry (server rejected the mutation). Set `deadLettered` with error message.
5. **Status emission:** update `SyncStatusProvider` throughout (syncing → idle/error).
6. **Concurrency:** actions replayed sequentially (one at a time) to preserve ordering and avoid race conditions. No parallel replay.

### 5.6 Retry with Exponential Backoff + Jitter

```
delay = min(baseDelay * 2^retryCount + random(0, jitterMax), maxDelay)
```

| Parameter | Default | Source |
|---|---|---|
| `baseDelay` | 1 second | `SyncConfig` |
| `maxDelay` | 60 seconds | `SyncConfig` |
| `jitterMax` | 1 second | `SyncConfig` |
| `maxRetries` | 5 | `SyncConfig` |

All values sourced from `EnvironmentConfig` via `SyncConfig`. The backoff delay is applied via `Future.delayed` — no `Timer` or `workmanager` dependency.

### 5.7 Connectivity Abstraction (`connectivity_provider.dart`)

```dart
abstract class ConnectivityProvider {
  Stream<ConnectivityStatus> get onConnectivityChanged;
  Future<bool> get isConnected;
  void dispose();
}

enum ConnectivityStatus { online, offline }
```

- **`ConnectivityPlusProvider`** (default): wraps `connectivity_plus` package, maps `ConnectivityResult` to `ConnectivityStatus`.
- **`ManualConnectivityProvider`** (test): allows manual `setOnline()`/`setOffline()` for deterministic testing.
- EP-01-13 may later provide a richer implementation (network type detection, payload optimization hooks) that replaces the default.

### 5.8 Conflict Detection (`conflict_detector.dart`)

- **Basic detection only:** on HTTP 409 response, extract server version from response body (if present) and compare with action's `lastKnownVersion`.
- **Outcome:** flag the action as `conflicted`, store server version in `errorMessage` for diagnostics, move to dead-letter.
- **No resolution:** the engine does not attempt merge, server-wins, or client-wins strategies. Conflicted actions are retained for future resolution (EP-02+ or manual admin intervention).
- **Server is authority:** per AGENT.md Rule 4, the client never overrides server conflict decisions.

### 5.9 Sync Status Provider (`sync_status_provider.dart`)

A `ChangeNotifier` exposing:

| Property | Type | Purpose |
|---|---|---|
| `status` | `SyncStatus` | Current engine state: `idle`, `syncing`, `offline`, `error` |
| `pendingCount` | `int` | Number of actions in queue (pending + inFlight) |
| `lastError` | `SyncException?` | Most recent error (cleared on successful drain) |
| `deadLetterCount` | `int` | Number of dead-lettered actions |

Downstream consumers (EP-01-15 router, EP-01-16 UI) listen to this provider for offline banners and sync indicators. This task does not build any UI.

### 5.10 Sync Configuration (`sync_config.dart`)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `maxQueueDepth` | `int` | 500 | Maximum pending actions before rejection |
| `defaultMaxRetries` | `int` | 5 | Per-action retry ceiling |
| `baseDelay` | `Duration` | 1s | Backoff base |
| `maxDelay` | `Duration` | 60s | Backoff ceiling |
| `jitterMax` | `Duration` | 1s | Random jitter upper bound |
| `defaultPriority` | `int` | 10 | Default action priority |
| `drainBatchSize` | `int` | 50 | Max actions per drain cycle |

Sourced from `EnvironmentConfig` via compile-time defines (`HIVORR_SYNC_*`). If not provided, defaults apply.

### 5.11 Initialization Wiring

`initializeSyncEngine(EnvironmentConfig, StorageEngine, Dio)` builds the `SyncEngine` singleton. It:
1. Reads `FeatureFlags.enableOfflineSync` — if `false`, returns a no-op engine.
2. Constructs `SyncConfig` from environment values.
3. Constructs `ActionQueue` with the provided `StorageEngine`.
4. Constructs `ConnectivityPlusProvider` (or injected provider).
5. Constructs `ConflictDetector`.
6. Constructs `SyncStatusProvider`.
7. Wires the connectivity stream to trigger `drain()` on `online` events.
8. Returns the wired `SyncEngine`.

`lib/app/` (EP-01-15) calls this at bootstrap — **this task does not modify `main.dart` or bootstrap**; it exports the initializer only.

### 5.12 Extensibility Hooks

- `ConnectivityProvider` abstract → EP-01-13 can replace with richer implementation.
- `ConflictDetector` → future phases can add resolution strategies.
- `SyncStatusProvider` → EP-01-15/16 UI consumes for offline indicators.
- `SyncAction.priority` → EP-02+ features can assign domain-specific priorities (e.g., payment actions = priority 0).
- Dead-letter queue → future admin/debug tooling can inspect and retry.
- `sync.dart` barrel → EP-01-15 bootstrap.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Source of sync config values, feature gate |
| `StorageEngine` | `lib/core/database/` (EP-01-11) | Persistent action queue storage (`sync_queue` box) |
| `Dio` / `ApiLayer` | `lib/core/api/` (EP-01-07) | HTTP replay channel with auth/retry/error interceptors |
| `ActionQueue` | `lib/core/sync/` | FIFO + priority queue with atomic persistence |
| `SyncEngine` | `lib/core/sync/` | Orchestrator: drain, replay, retry, conflict detect |
| `ConnectivityProvider` | `lib/core/sync/` | Connectivity detection abstraction |
| `SyncStatusProvider` | `lib/core/sync/` | Observable sync state for downstream consumers |
| `ConflictDetector` | `lib/core/sync/` | Basic 409 conflict flagging |
| Test suites | `test/unit/core/sync/` | Queue, replay, retry, conflict, status tests |

**New dependencies (D1):**
- `connectivity_plus` — cross-platform connectivity detection.
- `uuid` — RFC 4122 v4 action ID generation.

---

## 7. Data Requirements

- **Action records** are client-generated mutation descriptors (endpoint, method, payload). They contain no business logic — only the intent to mutate server state.
- Payloads are JSON-compatible `Map<String, dynamic>` — the sync engine does not inspect, validate, or transform payloads. Validation is the server's responsibility (RLS + RPC).
- Action records are stored in the `sync_queue` box of `StorageEngine` — isolated from `entity_cache`, `cache`, and `misc` boxes.
- Dead-lettered actions are retained in the same box with `status = deadLettered` for diagnostics.
- No tokens, secrets, or credentials are stored in action records. Auth is injected by the API layer's `AuthInterceptor` during replay.
- No business, financial, or domain data is created by this task beyond queuing what upstream layers submit.

---

## 8. Database Considerations

**Not applicable** to Supabase/PostgreSQL. This task defines **client-local** queue persistence only. All server-side schema, RPC, and RLS remain owned by EP-01-05/06. The sync queue is a client-side buffer of pending mutations — the server remains the authoritative state (AGENT.md Rule 4). No migrations; the queue self-initializes via `StorageEngine`.

---

## 9. API Requirements

- **No new network endpoints/RPCs.** The sync engine replays existing API calls through the EP-01-07 `Dio` instance.
- The engine uses `dio.request(action.endpoint, data: action.payload, options: Options(method: action.method, headers: action.headers))` — the full interceptor chain (auth, retry, error normalization, logging) applies transparently.
- **409 Conflict** responses are intercepted by the sync engine for conflict detection.
- **401 Unauthorized** is handled by the API layer's `RetryInterceptor` (token refresh + single retry) before reaching the sync engine.
- The sync engine does not bypass or duplicate any interceptor logic.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing. The `SyncStatusProvider` is exported for EP-01-15/16+ to build offline indicators. `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `initializeSyncEngine(config, storageEngine, dio)` yields a fully wired sync engine.
- `SyncEngine.enqueue(action)` is the single entry point for all offline-capable mutations.
- `SyncStatusProvider` gives UI layers a clean observable for offline banners and pending counts.
- Actions are automatically replayed on connectivity restoration — no manual intervention required.
- Dead-lettered actions are inspectable for debugging (future tooling).
- Feature gate (`enableOfflineSync`) allows disabling the engine entirely without code changes.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Secrets/tokens in action payloads | **Hard boundary:** action payloads must not contain tokens or credentials. Auth is injected by `AuthInterceptor` during replay. `SyncException`/logs never embed payload values. |
| Replay of stale/unauthorized actions | Server-side RLS + RPC validation is authoritative. The client queues intent; the server decides authorization at replay time. Expired sessions cause 401 → token refresh → retry. If refresh fails, action remains queued. |
| Queue tampering (rooted device) | Queue is stored via `StorageEngine` (Hive). If `encryptAtRest` is enabled (EP-01-10), the `sync_queue` box benefits from at-rest encryption. The sync engine does not implement crypto — it consumes the `StorageEngine` which may be wrapped. |
| Replay attack (duplicate actions) | Each action has a unique UUID. Server-side idempotency keys (if implemented in EP-02+) prevent duplicate execution. The sync engine does not enforce idempotency — that is a server concern. |
| Hardcoded config values | All sync parameters sourced exclusively from `EnvironmentConfig`; no `String.fromEnvironment`, no literals. |
| Business logic in client | Layer queues and replays only; no role/verification/pricing decisions (AGENT.md Rule 4). |
| Conflict override | Client never overrides server conflict decisions. 409 → flag + dead-letter. |

---

## 13. Performance Considerations

- **Sequential replay:** actions replay one at a time to preserve ordering and avoid server overload. No parallel replay.
- **Bounded queue:** `maxQueueDepth` (default 500) prevents unbounded growth. Enqueue beyond limit throws `SyncException`.
- **Drain batch size:** `drainBatchSize` (default 50) caps actions per drain cycle, preventing UI thread starvation on large queues.
- **Backoff + jitter:** prevents thundering herd on connectivity restoration. Exponential backoff with random jitter spreads retry attempts.
- **Lazy queue loading:** `ActionQueue` loads actions from `StorageEngine` only when `drain()` is called, not at initialization.
- **No synchronous I/O:** all `StorageEngine` operations are async; no blocking on the UI thread.
- **Minimal dependency footprint:** `connectivity_plus` and `uuid` are lightweight packages. No impact on the 15–20 MB installer target.
- **Memory:** `SyncStatusProvider` holds only status + counts (negligible). Action records are loaded from disk during drain, not held in memory permanently.

---

## 14. Testing Strategy

### 14.1 Unit — Action Queue
- Enqueue → action persisted in `sync_queue` box with correct fields.
- Dequeue (on success) → action removed from box.
- Drain ordering: actions sorted by `(priority ASC, createdAt ASC)`.
- Atomic enqueue: simulated `writeBatch` failure leaves queue unchanged.
- Queue depth limit: enqueue beyond `maxQueueDepth` throws `SyncException`.
- Update on retry: `retryCount` incremented, `lastAttemptAt` updated.

### 14.2 Unit — Sync Engine (with fake Dio + fake ConnectivityProvider)
- Replay success: action dequeued after 2xx response.
- Replay transient failure: `retryCount` incremented, backoff delay applied.
- Max retries exhausted: action set to `deadLettered`.
- 409 Conflict: action flagged as `conflicted`, moved to dead-letter.
- 4xx client error (non-401/409): action dead-lettered without retry.
- Sequential replay: actions processed in order, one at a time.
- Feature gate disabled: `enqueue` throws `SyncException`.
- Drain batch size respected: only `drainBatchSize` actions per cycle.

### 14.3 Unit — Connectivity Provider
- `ManualConnectivityProvider`: `setOnline()` emits `online`, `setOffline()` emits `offline`.
- Stream emits initial status on listen.

### 14.4 Unit — Conflict Detector
- 409 response with version mismatch → `conflicted` result.
- 409 response without version info → `conflicted` result (conservative).
- Non-409 response → no conflict.

### 14.5 Unit — Sync Status Provider
- Status transitions: `idle` → `syncing` → `idle` on successful drain.
- Status transitions: `idle` → `syncing` → `error` on failure.
- `pendingCount` reflects queue depth.
- `deadLetterCount` increments on dead-letter.

### 14.6 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new tests pass.
- Available platform smoke build (no native changes required for `connectivity_plus`/`uuid` on Windows).

### 14.7 Scope Validation
- Diff review: only `lib/core/sync/` + `test/unit/core/sync/` + `pubspec.yaml` (D1 dependencies). No modifications to EP-01-07, EP-01-08, EP-01-11, EP-01-13 files. No bootstrap/UI/DB/auth/security/monitoring implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-07 and EP-01-11 deliverables; confirm `lib/core/sync/` contains only `.gitkeep`.
2. **Decision D1:** add `connectivity_plus` and `uuid` to `pubspec.yaml` (per lead approval).
3. Implement `lib/core/sync/sync_config.dart` — configuration class sourced from `EnvironmentConfig`.
4. Implement `lib/core/sync/sync_action.dart` + `sync_action_status.dart` — action record model and status enum.
5. Implement `lib/core/sync/sync_exception.dart` — typed exception.
6. Implement `lib/core/sync/connectivity_provider.dart` + `connectivity_plus_provider.dart` — connectivity abstraction and default implementation.
7. Implement `lib/core/sync/action_queue.dart` — persistent FIFO + priority queue backed by `StorageEngine`.
8. Implement `lib/core/sync/conflict_detector.dart` — basic 409 conflict flagging.
9. Implement `lib/core/sync/sync_status.dart` + `sync_status_provider.dart` — observable status.
10. Implement `lib/core/sync/sync_engine.dart` — orchestrator: drain, replay, retry, backoff, conflict detect.
11. Implement `lib/core/sync/sync.dart` — barrel + `initializeSyncEngine()`.
12. Add `test/unit/core/sync/` unit tests (queue, engine, connectivity, conflict, status).
13. Run `flutter analyze` and `flutter test`.
14. Available platform smoke builds.
15. Review final diff for strict EP-01-12 scope containment and phase-document integrity.
16. **Stop at the approval gate** — do not implement EP-01-13 network management, EP-01-15 bootstrap, or downstream tasks.

---

## Approval-Required Decisions (flagged for the lead)

- **D1 — New dependencies:** `connectivity_plus` (cross-platform connectivity detection; required for connectivity-triggered replay) and `uuid` (RFC 4122 v4 action ID generation; lightweight, standard). Both are well-maintained, widely-used Flutter ecosystem packages. Confirm approval to add to `pubspec.yaml`.
- **D2 — Sequential vs. parallel replay:** This plan recommends **sequential** replay (one action at a time) to preserve ordering, simplify conflict detection, and avoid server overload. Parallel replay would increase throughput but introduces ordering guarantees complexity and race conditions. Confirm sequential is acceptable for EP-01 (parallel can be added in a future phase if needed).
- **D3 — Dead-letter retention policy:** Dead-lettered actions are retained indefinitely in the `sync_queue` box for diagnostics. No automatic purge. Confirm this is acceptable for EP-01 (a TTL-based purge can be added later).

---

## 16. Expected Outcome

- A fully functional **offline sync engine** with a persistent, crash-safe action queue in `lib/core/sync/`.
- Actions enqueued while offline are durably persisted and automatically replayed when connectivity returns.
- Retry with exponential backoff + jitter prevents thundering herd and respects server capacity.
- Basic conflict detection flags 409 responses without attempting resolution (server is authority).
- Observable sync status enables downstream UI to show offline indicators and pending counts.
- Feature-gated via `FeatureFlags.enableOfflineSync` — can be disabled without code changes.
- Clean extensibility hooks for EP-01-13 (connectivity), EP-01-15 (bootstrap), EP-01-16 (UI), and EP-02+ (domain-specific action priorities).
- Unit tests proving queue persistence, replay ordering, retry backoff, conflict flagging, and status transitions without a live backend.

---

## 17. Definition of Done (DoD)

**Structure & Code**
- [ ] `lib/core/sync/` contains the §5.2 structure; all files implemented and importing correctly.
- [ ] `SyncAction` model with `toJson()`/`fromJson()` round-trips correctly; all fields present.
- [ ] `ActionQueue` provides `enqueue`, `dequeue`, `peek`, `drain`, `update`, `depth`; backed by `StorageEngine` (`sync_queue` box) with atomic `writeBatch`.
- [ ] `SyncEngine` provides `enqueue(action)`, `drain()`, `dispose()`; replays through `Dio` with retry, backoff, and conflict detection.
- [ ] `ConnectivityProvider` abstract interface defined; `ConnectivityPlusProvider` default implementation functional.
- [ ] `ConflictDetector` flags 409 responses as `conflicted` and moves to dead-letter.
- [ ] `SyncStatusProvider` exposes `status`, `pendingCount`, `deadLetterCount`, `lastError`; emits changes via `ChangeNotifier`.
- [ ] `SyncConfig` sourced from `EnvironmentConfig`; no `String.fromEnvironment`, no hardcoded values.
- [ ] `sync.dart` barrel exports public API; `initializeSyncEngine()` wired for EP-01-15 (no `main.dart` change).
- [ ] Feature gate (`FeatureFlags.enableOfflineSync`) respected — engine is no-op when disabled.
- [ ] No tokens/secrets in action payloads; auth injected by `AuthInterceptor` during replay.
- [ ] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/auth/security/monitoring/migration code included.
- [ ] No modifications to EP-01-07, EP-01-08, EP-01-11, or EP-01-13 files.
- [ ] New dependencies (D1: `connectivity_plus`, `uuid`) added to `pubspec.yaml`.
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (queue persistence, replay ordering, retry backoff, conflict flagging, status transition unit tests).
- [ ] Available platform smoke builds pass.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-12 changes (+ `pubspec.yaml` for D1).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Very High**

### Reasoning Level Justification

- **Technical complexity:** High — designing a correct persistent action queue with atomic operations, a replay orchestrator with exponential backoff + jitter, sequential drain with status transitions, and conflict detection on 409 responses requires careful concurrent reasoning. Mistakes cause lost mutations, duplicate replays, or corrupted queue state.
- **Business impact:** High — the Nigeria market's unreliable connectivity makes offline resilience a core platform differentiator. Every EP-02+ feature that supports offline mutations depends on this engine. Flaws cause user data loss.
- **Security risk:** Medium — the engine must not store secrets, must respect server authority on conflicts, and must not bypass auth interceptors. Risk is mitigated by the API layer's interceptor chain and server-side RLS.
- **Performance sensitivity:** Medium-high — sequential replay with backoff must not starve the UI thread; bounded queue and drain batch size prevent resource exhaustion on low-end devices. Incorrect backoff timing causes thundering herd.
- **Data complexity:** Medium — action records are JSON-compatible maps with ordering semantics; no relational joins or schema design. Complexity lies in the queue discipline (FIFO + priority) and atomic persistence.
- **Integration complexity:** High — must integrate correctly with three completed subsystems (`StorageEngine` for persistence, `Dio` + interceptors for replay, `EnvironmentConfig` for configuration) and expose a clean interface for two parallel/downstream tasks (EP-01-13 connectivity, EP-01-15 bootstrap). Incorrect integration breaks the entire offline pipeline.

Very High reasoning matches the approved EP-01 matrix (EP-01-12 = Very High) and the orchestration-heavy nature of the task.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Specifically, the lead's confirmation is requested on the **Approval-Required Decisions**: **D1** (new dependencies: `connectivity_plus` + `uuid`), **D2** (sequential replay confirmed for EP-01), and **D3** (dead-letter retention policy — indefinite, no auto-purge).

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-12-Offline Sync Engine & Action Queue.md`. Implementation will begin only after a separate implementation approval. No production code is written during planning.
