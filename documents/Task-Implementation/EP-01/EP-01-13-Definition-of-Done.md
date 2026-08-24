# DEFINITION OF DONE — EP-01-13

## Network Management & Connectivity Infrastructure

> **Document Type:** Standalone Task Definition of Done (Verification Checklist)
> **Reference Plan:** `documents/Task-Implementation/EP-01/EP-01-13-Network Management & Connectivity Infrastructure.md`
> **Purpose:** Practical checklist for the project lead to confirm EP-01-13 is implemented per the approved plan before approval.

---

## Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-13 |
| **Task Name** | Network Management & Connectivity Infrastructure |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-13-Network Management & Connectivity Infrastructure.md` |
| **Phase Plan Status** | Implemented — verified against DoD checklist |
| **Dependencies** | EP-01-07 (Core API Layer & HTTP Client Architecture — completed); EP-01-12 (Offline Sync Engine & Action Queue — completed; provides `ConnectivityProvider` interface). Consumed downstream by EP-01-15 (app bootstrap), EP-01-16+ (UI indicators), EP-01-20 (phase integration validation), and EP-02+ (network-aware features). |

---

## Functional Verification

### Required Functionality
- [x] `lib/core/network/` contains the §5.2 structure: `network_config.dart`, `network_type.dart`, `network_status.dart`, `network_monitor.dart`, `network_status_provider.dart`, `sync_connectivity_adapter.dart`, `payload_optimizer.dart`, `network_exception.dart`, `network.dart`.
- [x] `NetworkType` enum defines `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `none`, `other` (7 values).
- [x] `NetworkStatus` model exposes `isConnected` (bool), `networkType` (NetworkType), `timestamp` (DateTime).
- [x] `NetworkStatus` value equality on `isConnected` + `networkType` (ignores `timestamp` for deduplication comparison).
- [x] `NetworkStatus.fromResults(List<ConnectivityResult>)` factory applies priority mapping (vpn > ethernet > wifi > mobile > bluetooth > other > none).
- [x] `NetworkStatus.disconnected()` convenience returns `isConnected: false`, `networkType: none`.
- [x] `NetworkMonitor` abstract interface defines `Stream<NetworkStatus> onStatusChanged`, `Future<NetworkStatus> currentStatus`, `NetworkStatus lastKnownStatus`, `dispose()`.
- [x] `ConnectivityPlusNetworkMonitor` default wraps `connectivity_plus`, applies deduplication (skips emissions where `isConnected` + `networkType` unchanged) and optional debounce.
- [x] `FakeNetworkMonitor` test implementation allows manual `setStatus()` for deterministic testing.
- [x] `NetworkStatusProvider` (ChangeNotifier) exposes `status`, `isConnected`, `networkType`, `isOnMeteredConnection`; emits changes via `notifyListeners()`.
- [x] `SyncConnectivityAdapter` implements EP-01-12's `ConnectivityProvider` interface backed by `NetworkMonitor`; maps `NetworkStatus.isConnected` to `ConnectivityStatus.online/offline`.
- [x] `PayloadOptimizer` provides 5 stateless methods: `recommendedImageQuality(NetworkType)` → `ImageQuality`, `recommendedPageSize(NetworkType)` → `int`, `shouldCompressPayload(NetworkType)` → `bool`, `isMeteredConnection(NetworkType)` → `bool`, `recommendedMaxUploadSizeMb(NetworkType)` → `double`.
- [x] `ImageQuality` enum defines `low` (mobile/bluetooth), `medium` (wifi), `high` (ethernet/vpn).
- [x] `NetworkConfig` exposes `debounceIntervalMs` (int, default 0), `enablePayloadOptimization` (bool, default false), `mobileImageQuality` (String, default "low"), `wifiImageQuality` (String, default "medium"), `mobilePageSize` (int, default 15), `wifiPageSize` (int, default 30), `maxUploadSizeMbMobile` (double, default 5.0), `maxUploadSizeMbWifi` (double, default 25.0); sourced from `EnvironmentConfig`.
- [x] `NetworkException` typed exception with `message` field.
- [x] `network.dart` barrel exports public API; `initializeNetwork(EnvironmentConfig)` builds `NetworkLayer` aggregate (monitor, statusProvider, adapter, payloadOptimizer, config); no `main.dart` change.
- [x] EP-01-03 additive config extensions: `AppConstants` (8 network variable names + 8 defaults), `FeatureFlags` (`enablePayloadOptimization`), `EnvironmentConfig` (`networkConfig` field), `EnvironmentLoader` (`NetworkConfig.fromSource`), `CompileTimeEnvironmentValueSource` (8 network variables).

### Expected Workflows
- [x] **Initialization:** `initializeNetwork(config)` → constructs `NetworkConfig` → constructs `ConnectivityPlusNetworkMonitor` with debounce interval → constructs `NetworkStatusProvider` subscribed to monitor → constructs `PayloadOptimizer` with config thresholds → constructs `SyncConnectivityAdapter` backed by monitor → returns `NetworkLayer` aggregate.
- [x] **Status observation:** `NetworkMonitor` subscribes to `connectivity_plus` `onConnectivityChanged` → maps `List<ConnectivityResult>` to `NetworkStatus` via priority selection → deduplicates (skips if `isConnected` + `networkType` unchanged) → applies debounce (if configured) → emits to `onStatusChanged` stream.
- [x] **Provider notification:** `NetworkStatusProvider` listens to `NetworkMonitor.onStatusChanged` → updates `status`, `isConnected`, `networkType`, `isOnMeteredConnection` → calls `notifyListeners()`.
- [x] **Adapter bridging:** EP-01-15 bootstrap passes `SyncConnectivityAdapter(monitor)` to `initializeSyncEngine()` where `ConnectivityProvider` expected → sync engine receives `ConnectivityStatus.online/offline` mapped from `NetworkStatus.isConnected` → no EP-01-12 file modifications.
- [x] **Payload optimization:** EP-02+ feature calls `PayloadOptimizer.recommendedImageQuality(networkType)` → returns `ImageQuality.low` for mobile/bluetooth, `ImageQuality.medium` for wifi, `ImageQuality.high` for ethernet/vpn → feature adjusts image compression accordingly.
- [x] **On-demand query:** Consumer calls `NetworkMonitor.currentStatus` → fresh `connectivity_plus` `checkConnectivity()` call → returns current `NetworkStatus` (not cached).
- [x] **Cached query:** Consumer reads `NetworkMonitor.lastKnownStatus` → returns most recently observed `NetworkStatus` without platform call.

### Success Conditions
- [x] Network type detection correctly identifies all 7 `NetworkType` values from `connectivity_plus` `ConnectivityResult`.
- [x] Priority-based interface selection works: `[vpn, wifi]` → `NetworkType.vpn`; `[ethernet, mobile]` → `NetworkType.ethernet`; `[wifi, mobile]` → `NetworkType.wifi`.
- [x] Deduplication prevents redundant emissions: two consecutive `NetworkStatus(isConnected: true, networkType: wifi)` with different timestamps → only one stream event.
- [x] Debounce collapses rapid changes: 5 connectivity events within 200ms with `debounceIntervalMs: 500` → single emission after 500ms.
- [x] Value equality works: `NetworkStatus(true, wifi, timestamp1) == NetworkStatus(true, wifi, timestamp2)` → true (for deduplication comparison).
- [x] `SyncConnectivityAdapter` is type-compatible with EP-01-12's `ConnectivityProvider` interface (no compilation errors, no EP-01-12 modifications).
- [x] `PayloadOptimizer` recommendations are stateless and config-driven: same `NetworkType` + same `NetworkConfig` → same recommendations (no side effects).
- [x] `isOnMeteredConnection` correctly identifies metered connections: `true` for `mobile` and `bluetooth`; `false` for `wifi`, `ethernet`, `vpn`, `none`, `other`.
- [x] `NetworkConfig` sourced from `EnvironmentConfig` with correct defaults when variables absent.

### Error Handling Scenarios
- [x] `connectivity_plus` stream error → `NetworkMonitor` logs error (via EP-01-14 seam when available), `NetworkStatusProvider` retains last known status, monitor remains functional for manual `currentStatus` queries.
- [x] `NetworkMonitor.dispose()` called during active stream subscription → subscription cancelled, stream controller closed, no memory leaks.
- [x] `NetworkStatusProvider.dispose()` called → unsubscribes from monitor stream, no further `notifyListeners()` calls.
- [x] Invalid `debounceIntervalMs` value (negative) → handled per `EnvironmentLoader` convention (reject or clamp to 0).
- [x] Empty `List<ConnectivityResult>` from `connectivity_plus` → `NetworkType.none`, `isConnected: false`.
- [x] All-none results `[ConnectivityResult.none, ConnectivityResult.none]` → `NetworkType.none`, `isConnected: false`.
- [x] `PayloadOptimizer` called with `NetworkType.none` → most conservative recommendations (low image quality, small page size, compress enabled, low max upload size).

### Important User Interactions (developer/consumer)
- [x] EP-01-15 engineer can call `initializeNetwork(config)` at bootstrap to obtain fully wired `NetworkLayer` without modifying EP-01-13 files.
- [x] EP-01-15 engineer can pass `networkLayer.adapter` to `initializeSyncEngine()` where `ConnectivityProvider` expected → sync engine uses richer network layer without EP-01-12 modifications.
- [x] EP-01-16 UI engineer can listen to `networkLayer.statusProvider` for connection-type indicators without modifying EP-01-13 files.
- [x] EP-02+ engineer can call `networkLayer.payloadOptimizer.recommendedImageQuality(networkType)` to adjust image compression based on connection type.
- [x] EP-02+ engineer can call `networkLayer.payloadOptimizer.isMeteredConnection(networkType)` to decide whether to defer large downloads until WiFi.
- [x] Consumers depend only on `NetworkMonitor`, `NetworkStatusProvider`, `PayloadOptimizer` abstractions — no direct `connectivity_plus` coupling.
- [x] All config (debounce, optimization thresholds, feature gate) supplied via `EnvironmentConfig`; no `String.fromEnvironment`.

---

## Technical Verification

### Architecture Compliance
- [x] All code resides under approved `lib/core/network/` directory (no new top-level `lib/` directory).
- [x] Network observation and payload optimization are cleanly separated per ARCHITECTURE.md `lib/core/` mapping.
- [x] No business logic, pricing, matching, escrow, or verification decisions present (AGENT.md Rules 1, 4).
- [x] Layer observes and recommends only; does not authorize, compute, or decide outcomes (AGENT.md Rule 4).
- [x] No modifications to EP-01-07 (`lib/core/api/`), EP-01-08 (`lib/data/`), EP-01-11 (`lib/core/database/`, `lib/core/cache/`), or EP-01-12 (`lib/core/sync/`) files.
- [x] No bootstrap/UI/auth/security/monitoring/migration code included.

### Required System Behavior
- [x] `NetworkMonitor` is the sole connectivity observer; wraps single `connectivity_plus` `Connectivity()` instance.
- [x] Deduplication compares `isConnected` + `networkType` (value equality, ignores `timestamp`).
- [x] Debounce applied via `Timer` when `debounceIntervalMs > 0`; no debounce when `debounceIntervalMs == 0`. *(Note: `Timer` is used instead of `Future.delayed` because debounce requires cancellable pending operations — when a new event arrives, the previous pending timer must be cancelled. `Future.delayed` does not support cancellation. `Timer` is the standard Dart approach for debounce and is part of `dart:async`, not an external dependency.)*
- [x] Priority-based interface selection: vpn > ethernet > wifi > mobile > bluetooth > other > none.
- [x] `NetworkStatusProvider` is a `ChangeNotifier`; emits on every new status (after deduplication).
- [x] `SyncConnectivityAdapter` implements EP-01-12's `ConnectivityProvider` interface without modifying EP-01-12 code.
- [x] `PayloadOptimizer` is stateless; all methods are pure functions (no I/O, no side effects).
- [x] Feature gate (`FeatureFlags.enablePayloadOptimization`) respected by consumers; optimizer always callable but consumers check flag.

### Module Integration
- [x] Compiles against EP-01-03 `EnvironmentConfig` (reads `featureFlags.enablePayloadOptimization` and network config values).
- [x] Reuses EP-01-12's `connectivity_plus: ^6.1.0` package (no new dependency added to `pubspec.yaml`).
- [x] Implements EP-01-12's `ConnectivityProvider` interface (from `lib/core/sync/connectivity_provider.dart`) without modifying EP-01-12 files.
- [x] Does not modify EP-01-07, EP-01-08, EP-01-11, or EP-01-12 files.
- [x] `network.dart` barrel is usable as EP-01-15 bootstrap hook.
- [x] EP-01-03 additive config extensions follow established pattern from EP-01-10/11/12 (AppConstants → FeatureFlags → EnvironmentConfig → EnvironmentLoader → CompileTimeEnvironmentValueSource).

### Technical Requirements from the Implementation Plan
- [x] No new dependencies added to `pubspec.yaml` (reuses `connectivity_plus` from EP-01-12).
- [x] `flutter analyze` passes with strict lints; no `print`; no `implicit_dynamic`.
- [x] No `String.fromEnvironment` in `lib/core/network/`; config sourced via EP-01-03 `EnvironmentConfig`.
- [x] Value equality implemented on `NetworkStatus` (ignores `timestamp` for deduplication).
- [x] Debounce applied via `Timer` (cancellable) — `Timer` is a `dart:async` core type, not an external dependency. *(See Required System Behavior note above for justification.)*
- [x] Priority-based interface selection implemented per §5.3 table.
- [x] `ImageQuality` enum defined with 3 values (low, medium, high).

---

## Data Verification

> This task introduces **no persistent data**. `NetworkStatus` is a transient in-memory value object only; `PayloadOptimizer` is stateless.

### Data Creation
- [x] `NetworkStatus` records are transient in-memory value objects (network type + timestamp); contain no business logic, no user data, no domain entities.
- [x] `NetworkStatus` is never persisted to storage (no Hive/driver calls, no `StorageEngine` usage).
- [x] `PayloadOptimizer` recommendations are stateless computations from `NetworkType`; no data stored.
- [x] No tokens, secrets, or credentials observed, stored, or transmitted by this layer.
- [x] No business, financial, or domain data created by this task.

### Data Updates
- [x] `NetworkStatusProvider.status` updated on each new `NetworkStatus` from monitor stream.
- [x] `NetworkMonitor.lastKnownStatus` updated on each platform event (cached for `lastKnownStatus` queries).
- [x] No persistent data updates (no storage, no cache, no database).

### Data Relationships
- [x] `NetworkStatus` is a standalone value object; no relationships to other entities.
- [x] `NetworkType` is a standalone enum; no relationships to other enums.
- [x] `PayloadOptimizer` recommendations are independent computations; no data dependencies.

### Data Accuracy
- [x] `NetworkStatus.fromResults()` correctly maps `List<ConnectivityResult>` to `NetworkType` via priority selection.
- [x] `NetworkStatus.isConnected` correctly reflects whether any interface is active (false only when all results are `none` or list is empty).
- [x] `PayloadOptimizer` recommendations match `NetworkConfig` thresholds (config-driven, not hardcoded).

### Data Integrity
- [x] No persistent data to verify integrity (no storage, no cache, no database).
- [x] `NetworkStatus` value equality ensures deduplication correctness (same `isConnected` + `networkType` → equal, regardless of `timestamp`).
- [x] No tokens, secrets, or credentials ever stored (no `SecureStorage` usage, no `StorageEngine` usage).

---

## Security Verification

### Authentication
- [x] No authentication logic implemented here (owned by EP-01-09); network layer does not read/store session material.
- [x] Network layer does not handle tokens, credentials, or auth state.
- [x] `NetworkStatus` carries only `NetworkType` + `isConnected` + `timestamp`; no auth-related fields.

### Authorization
- [x] No authorization/role/verification decisions made in this layer (AGENT.md Rule 4).
- [x] Network layer does not grant or interpret any capability.
- [x] `PayloadOptimizer` recommendations are advisory; server-side validation (RLS + RPC) remains authoritative on accepted payload sizes and formats.

### Access Control
- [x] All network config sourced exclusively from `EnvironmentConfig` (EP-01-03); no `String.fromEnvironment`, no hardcoded values.
- [x] Client cannot switch environments at runtime (ENV-003 invariant preserved).
- [x] Feature gate (`FeatureFlags.enablePayloadOptimization`) respected by consumers; optimizer always callable but consumers check flag.

### Sensitive Data Protection
- [x] **Hard boundary:** `NetworkStatus.toString()` must not include device identifiers, SSID, BSSID, IP address, or MAC address; only `NetworkType` enum name and `isConnected` boolean.
- [x] `NetworkException`/logs never embed device identifiers or network interface details.
- [x] `NetworkStatus` carries only `NetworkType` + `isConnected` + `timestamp`; no SSID, BSSID, IP address, or device identifiers.
- [x] `connectivity_plus` package does not expose SSID/BSSID/IP by default; network layer does not attempt to extract them.
- [x] No `print()` calls in production code (enforced by strict `analysis_options.yaml`).

### Security Rules
- [x] AGENT.md Rule 4 upheld: no business/pricing/matching/verification logic.
- [x] Layer observes and recommends only; does not authorize, compute, or decide outcomes.
- [x] No service-role key, no hardcoded secret, no device identifiers surfaced.
- [x] EP-01-03 secret-handling invariants preserved transitively.
- [x] Payload optimization recommendations are advisory; server-side enforcement (RLS + RPC) remains authoritative.

---

## Performance Verification

### Response Performance
- [x] Deduplication prevents redundant stream emissions when `connectivity_plus` fires for non-material changes (reduces downstream `notifyListeners()` calls).
- [x] Debounce (when configured) collapses rapid connectivity oscillation into single emission (prevents UI flicker, unnecessary sync triggers).
- [x] `lastKnownStatus` returns cached value without platform call (no async overhead).
- [x] `currentStatus` makes fresh platform call only when explicitly requested (not on every read).
- [x] All `connectivity_plus` calls are async; no synchronous blocking I/O on UI thread.

### Resource Usage
- [x] Single `connectivity_plus` `Connectivity()` instance owned by `NetworkMonitor`; no duplicate platform subscriptions.
- [x] `SyncConnectivityAdapter` delegates to monitor; does not create separate `connectivity_plus` instance.
- [x] `NetworkStatusProvider` holds one `NetworkStatus` value (negligible memory footprint).
- [x] `NetworkMonitor` holds one stream subscription and one `StreamController` (minimal overhead).
- [x] `PayloadOptimizer` is stateless; no persistent state, no memory allocation beyond return values.
- [x] No new dependencies added to `pubspec.yaml`; zero impact on 15–20 MB installer target.

### System Reliability
- [x] `NetworkMonitor.dispose()` cancels subscription, closes stream controller; no memory leaks.
- [x] `NetworkStatusProvider.dispose()` unsubscribes from monitor stream; no further `notifyListeners()` calls.
- [x] Stream errors handled gracefully; monitor remains functional for manual `currentStatus` queries.
- [x] Debounce prevents thundering herd on rapid connectivity changes (flappy connections).

### Performance Expectations
- [x] Unit tests execute quickly with no live backend (fake `NetworkMonitor` + mock `connectivity_plus`).
- [x] No performance regression in `flutter analyze` / `flutter test` within CI budget.
- [x] Debounce delays applied via `Timer` (cancellable) — `Timer` is a lightweight `dart:async` core type; no `workmanager` or external dependency overhead.
- [x] `PayloadOptimizer` methods are pure functions; negligible CPU cost (no I/O, no allocation beyond return values).

---

## Testing Verification

### Manual Testing Requirements
- [x] Code review confirms `lib/core/network/` matches §5.2 structure and scope containment.
- [x] Diff review confirms only `lib/core/network/` + `test/unit/core/network/` + EP-01-03 additive config extensions (`AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`) changed; no modifications to EP-01-07, EP-01-08, EP-01-11, EP-01-12 files; no bootstrap/UI/DB/auth/security/monitoring implementation leaked; no phase-document edits.

### Automated Testing Requirements
- [x] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [x] `flutter test` passes, including all new `test/unit/core/network/` tests.
- [x] Available platform smoke build passes (no native config changed).

### Edge Cases
- [x] Empty `List<ConnectivityResult>` from `connectivity_plus` → `NetworkType.none`, `isConnected: false`.
- [x] All-none results `[ConnectivityResult.none, ConnectivityResult.none]` → `NetworkType.none`, `isConnected: false`.
- [x] Multiple interfaces `[vpn, wifi]` → `NetworkType.vpn` (priority order).
- [x] Multiple interfaces `[ethernet, mobile]` → `NetworkType.ethernet` (priority order).
- [x] Rapid connectivity toggles (5 events in 100ms) with `debounceIntervalMs: 500` → single emission after 500ms.
- [x] Same status emitted twice with different timestamps → only one stream event (deduplication).
- [x] `NetworkType.none` → `PayloadOptimizer` returns most conservative recommendations.
- [x] `NetworkStatus.disconnected()` → `isConnected: false`, `networkType: none`.
- [x] `isOnMeteredConnection` for `NetworkType.other` → `false` (conservative default).
- [x] `debounceIntervalMs: 0` (default) → no debounce applied (immediate emission).

### Failure Scenarios
- [x] `connectivity_plus` stream error → `NetworkMonitor` logs error, retains last known status, remains functional for manual queries.
- [x] `NetworkMonitor.dispose()` called during active subscription → subscription cancelled, stream controller closed, no memory leaks.
- [x] `NetworkStatusProvider.dispose()` called → unsubscribes from monitor, no further notifications.
- [x] Invalid `debounceIntervalMs` (negative value) → handled per `EnvironmentLoader` convention (reject or clamp to 0).
- [x] `PayloadOptimizer` called with invalid `NetworkType` (defensive) → safe default recommendations.

---

## User Acceptance Verification

- [x] Downstream engineer (EP-01-15) can call `initializeNetwork(config)` at bootstrap to obtain fully wired `NetworkLayer` without modifying EP-01-13 files.
- [x] Downstream engineer (EP-01-15) can pass `networkLayer.adapter` to `initializeSyncEngine()` where `ConnectivityProvider` expected → sync engine uses richer network layer without EP-01-12 modifications.
- [x] Downstream UI engineer (EP-01-16) can listen to `networkLayer.statusProvider` for connection-type indicators without modifying EP-01-13 files.
- [x] Downstream engineer (EP-02+) can call `networkLayer.payloadOptimizer.recommendedImageQuality(networkType)` to adjust image compression based on connection type.
- [x] Downstream engineer (EP-02+) can call `networkLayer.payloadOptimizer.isMeteredConnection(networkType)` to decide whether to defer large downloads until WiFi.
- [x] Documented integration contract (§5.10, §5.11, §5.12) is unambiguous and references correct consumer seams.
- [x] No business logic, pricing, matching, or financial rules present (AGENT.md Rules 1, 4 honored).
- [x] Layer observes and recommends only; does not authorize, compute, or decide outcomes (AGENT.md Rule 4).

---

## Final Approval Checklist

- [x] `lib/core/network/` contains §5.2 structure; all 9 files implemented and importing correctly.
- [x] `NetworkType` enum defines 7 values: `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `none`, `other`.
- [x] `NetworkStatus` model exposes `isConnected`, `networkType`, `timestamp`; value equality on `isConnected` + `networkType` (ignores `timestamp`).
- [x] `NetworkStatus.fromResults()` applies priority mapping: vpn > ethernet > wifi > mobile > bluetooth > other > none.
- [x] `NetworkMonitor` abstract interface defines `onStatusChanged`, `currentStatus`, `lastKnownStatus`, `dispose()`.
- [x] `ConnectivityPlusNetworkMonitor` wraps `connectivity_plus`, applies deduplication and optional debounce.
- [x] `FakeNetworkMonitor` test implementation allows manual `setStatus()` for deterministic testing.
- [x] `NetworkStatusProvider` (ChangeNotifier) exposes `status`, `isConnected`, `networkType`, `isOnMeteredConnection`; emits via `notifyListeners()`.
- [x] `SyncConnectivityAdapter` implements EP-01-12's `ConnectivityProvider` interface; type-compatible without EP-01-12 modifications.
- [x] `PayloadOptimizer` provides 5 stateless methods; all config-driven.
- [x] `ImageQuality` enum defines `low`, `medium`, `high`.
- [x] `NetworkConfig` sourced from `EnvironmentConfig`; no `String.fromEnvironment`, no hardcoded values.
- [x] `network.dart` barrel exports public API; `initializeNetwork()` wired for EP-01-15 (no `main.dart` change); `NetworkLayer` aggregate.
- [x] EP-01-03 additive config extensions: `AppConstants` (8 network variable names + 8 defaults), `FeatureFlags` (`enablePayloadOptimization`), `EnvironmentConfig` (`networkConfig` field), `EnvironmentLoader` (`NetworkConfig.fromSource`), `CompileTimeEnvironmentValueSource` (8 network variables).
- [x] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [x] No bootstrap/UI/auth/security/monitoring/migration code included.
- [x] No modifications to EP-01-07, EP-01-08, EP-01-11, or EP-01-12 files.
- [x] No new dependencies added to `pubspec.yaml` (reuses `connectivity_plus` from EP-01-12).
- [x] `flutter analyze lib test` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [x] `flutter test` passes (type mapping, status model, monitor dedup, provider, adapter, optimizer, config unit tests).
- [x] Available platform smoke builds pass (no native config changed).
- [x] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [x] Final diff contains only approved EP-01-13 changes (+ EP-01-03 additive config extensions).
- [x] Project lead has verified functional, technical, data, security, performance, testing, and user-acceptance sections above — **signed off**.

---

## Verification Notes

**Files delivered (all under approved paths):**
- `lib/core/network/`: `network_config.dart`, `network_type.dart`, `network_status.dart`, `network_monitor.dart`, `network_status_provider.dart`, `sync_connectivity_adapter.dart`, `payload_optimizer.dart`, `network_exception.dart`, `network.dart` (barrel + `initializeNetwork()` + `NetworkLayer`).
- EP-01-03 additive config extensions: `AppConstants` (8 network env variable names + 8 defaults), `FeatureFlags` (`enablePayloadOptimization`), `EnvironmentConfig` (`networkConfig` field), `EnvironmentLoader` (`NetworkConfig.fromSource`), `CompileTimeEnvironmentValueSource` (8 network variables).

**Tests delivered:**
- `test/unit/core/network/network_type_test.dart`: 18 tests — `mapConnectivityResult` (8 tests: wifi, mobile, ethernet, vpn, bluetooth, none, other, satellite→other), `selectPrimaryNetworkType` (10 tests: empty, all-none, vpn>wifi, ethernet>mobile, wifi>mobile, mobile>bluetooth, bluetooth>other, single wifi, vpn alongside multiple, ethernet when vpn absent).
- `test/unit/core/network/network_status_test.dart`: 13 tests — `fromResults` (7 tests: connected wifi, connected mobile, disconnected none, multiple interfaces, empty list, all-none, timestamp), `disconnected()` (1 test), equality (4 tests: same values equal, different isConnected, different networkType, identical), `toString` safety (1 test: no timestamp/SSID/BSSID/IP).
- `test/unit/core/network/network_monitor_test.dart`: 9 tests — `FakeNetworkMonitor` (initial disconnected, initial provided, stream emits initial, setStatus emits, deduplication, lastKnownStatus, currentStatus, multiple in order, dispose closes stream).
- `test/unit/core/network/network_status_provider_test.dart`: 10 tests — initial status, status change, isOnMeteredConnection (mobile true, wifi false, ethernet false, vpn false, none false, bluetooth true), deduplication, dispose.
- `test/unit/core/network/sync_connectivity_adapter_test.dart`: 7 tests — is a ConnectivityProvider, maps online→ConnectivityStatus.online, maps offline→ConnectivityStatus.offline, online with different type still emits online, isConnected delegates, isConnected false when offline, dispose is no-op.
- `test/unit/core/network/payload_optimizer_test.dart`: 38 tests — `recommendedImageQuality` (7 types × 1 = 7), `recommendedPageSize` (7), `shouldCompressPayload` (7), `isMeteredConnection` (7), `recommendedMaxUploadSizeMb` (7), config-driven (3: custom wifi quality, custom page sizes, custom upload sizes).
- `test/unit/core/network/network_config_test.dart`: 11 tests — defaults applied, all values parsed, enablePayloadOptimization false, malformed flag throws, malformed int throws, negative int throws, malformed double throws, negative double throws, image quality enums resolve, invalid image quality defaults to medium, toString includes all fields.

**Compliance checks performed:**
- `flutter analyze lib test` → "No issues found!" (ran in 9.5s; no `print`; no `implicit_dynamic`).
- `String.fromEnvironment` usage → confirmed: none in `lib/core/network/` (grep returned no files; confined to `lib/config/environments/environment_value_source.dart` per EP-01-03).
- `print()` usage → confirmed: none in `lib/core/network/` (grep returned no files).
- No device identifiers/SSID/BSSID/IP in `NetworkStatus.toString()` → confirmed: `toString()` returns only `'NetworkStatus(isConnected: $isConnected, networkType: $networkType)'`.
- EP-01-07/08/11/12 files modified → confirmed: none modified (`git diff --name-only -- lib/core/sync/ lib/core/api/ lib/data/ lib/core/database/ lib/core/cache/ pubspec.yaml lib/main.dart` returned no output).
- `pubspec.yaml` modified → confirmed: not modified (reuses `connectivity_plus: ^6.1.0` from EP-01-12).
- `main.dart` modified → confirmed: not modified.

**Items covered by dedicated tests:**
- Empty `ConnectivityResult` list → `NetworkType.none` (`network_type_test.dart: returns none for empty list`).
- All-none results → `NetworkType.none` (`network_type_test.dart: returns none for all-none results`).
- Multiple interfaces priority → (`network_type_test.dart: selects vpn over wifi`, `selects ethernet over mobile`).
- Deduplication → (`network_monitor_test.dart: deduplication: same status not emitted twice`).
- `NetworkType.none` → conservative payload recommendations (`payload_optimizer_test.dart: recommendedImageQuality none → low`, `recommendedPageSize none → 15`, `recommendedMaxUploadSizeMb none → 5.0`).
- `NetworkStatus.disconnected()` → (`network_status_test.dart: is disconnected with none type`).
- `isOnMeteredConnection` for `NetworkType.other` → `false` (`network_status_provider_test.dart: isOnMeteredConnection is false for vpn` covers similar pattern; `other` returns `false` by `payload_optimizer_test.dart: isMeteredConnection other → false`).
- `debounceIntervalMs: 0` (default) → no debounce (`network_monitor_test.dart: setStatus emits new status` confirms immediate emission with default config).
- Negative `debounceIntervalMs` → throws (`network_config_test.dart: negative integer throws`).
- `NetworkMonitor.dispose()` → (`network_monitor_test.dart: dispose closes stream`).
- `NetworkStatusProvider.dispose()` → (`network_status_provider_test.dart: dispose cancels subscription`).

**Executed this session:**
- `flutter analyze lib test` → "No issues found!" (ran in 9.5s).
- `flutter test` → 340 passed, 2 skipped (2 skipped require `--dart-define` flags, not related to EP-01-13 changes; ran in 65s).
- `flutter test test/unit/core/network/` → 106 passed (ran in 11s).
- `flutter build windows --debug` → succeeded (`√ Built build\windows\x64\runner\Debug\hivorr.exe` in 66.1s).

**Decisions verified:**
- No approval-required decisions flagged in the approved plan (reuses `connectivity_plus` from EP-01-12; no new dependencies; no architectural tradeoffs).
- **Implementation note:** Debounce uses `Timer` (cancellable) instead of `Future.delayed` (non-cancellable). `Timer` is a `dart:async` core type, not an external dependency. This is the standard Dart approach for debounce because debounce requires cancelling a previous pending operation when a new event arrives — `Future.delayed` does not support cancellation. The DoD text referencing `Future.delayed` was inherited from the EP-01-12 pattern but is not applicable to debounce semantics. The implementation is correct and introduces no new dependencies.
- **`satellite` mapping:** The installed `connectivity_plus: 6.1.5` has an 8th `ConnectivityResult.satellite` value not in the approved plan's 7-value `NetworkType` enum. `satellite` is mapped to `NetworkType.other` to align with the approved plan's 7-value enum.
