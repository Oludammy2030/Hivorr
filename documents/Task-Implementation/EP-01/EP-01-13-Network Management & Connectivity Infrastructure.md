# TASK IMPLEMENTATION PLAN: EP-01-13

## Network Management & Connectivity Infrastructure

| Field | Value |
|---|---|
| Task ID | EP-01-13 |
| Task Name | Network Management & Connectivity Infrastructure |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-07 (Core API Layer & HTTP Client Architecture — completed). Parallel with EP-01-12 (Offline Sync Engine — completed; provides `ConnectivityProvider` seam). Consumed downstream by EP-01-15 (app bootstrap), EP-01-16+ (UI offline indicators), EP-01-20 (phase integration validation), and EP-02+ (all network-aware features). |
| Priority | Medium |
| Planning Reasoning | High (approved EP-01 matrix) |
| Coding Reasoning | High (approved EP-01 matrix) |

---

## 1. Task Objective

Implement the client-side network management and connectivity infrastructure in the ARCHITECTURE.md-mandated directory `lib/core/network/`:

- **Network Monitor** — a service wrapping `connectivity_plus` with richer semantics than EP-01-12's basic `ConnectivityPlusProvider`: detects network type (WiFi, mobile, ethernet, VPN, none), exposes a typed `NetworkStatus` model carrying both connectivity state and connection type, and emits a deduplicated status stream.
- **Network Status Provider** — a `ChangeNotifier`-based state container exposing current `NetworkStatus` (online/offline + network type) for app-wide consumption by EP-01-15 (bootstrap), EP-01-16+ (UI offline/connection-type indicators), and EP-02+ (network-aware features).
- **Sync Engine Adapter** — a `ConnectivityProvider` implementation (EP-01-12 interface) backed by the `NetworkMonitor`, enabling the sync engine to optionally consume the richer network layer without modifying `SyncEngine` or `ConnectivityProvider` abstraction.
- **Payload Optimization Utilities** — stateless helpers recommending image quality, pagination page size, and compression preference based on current network type, enabling EP-02+ features to reduce data costs on metered connections (critical for Nigeria market).
- **Network Configuration** — a `NetworkConfig` class sourced from `EnvironmentConfig` (feature gate, debounce interval, payload optimization defaults).
- **Unit tests** proving network type detection, status stream deduplication, adapter compatibility, payload optimization recommendations, and configuration sourcing.

Deliverables:
- A `NetworkMonitor` service with network type detection and deduplicated status stream.
- A `NetworkStatusProvider` (ChangeNotifier) for app-wide network state observation.
- A `SyncConnectivityAdapter` bridging `NetworkMonitor` to EP-01-12's `ConnectivityProvider` interface.
- Payload optimization utilities (`PayloadOptimizer`).
- A `NetworkConfig` class sourced from `EnvironmentConfig`.
- Unit tests for all components.
- `flutter analyze` (strict lints) + `flutter test` must pass.

**Dependency note:** EP-01-13 depends on EP-01-07 (API layer) per the approved matrix. EP-01-12 (Sync Engine) is completed and provides the `ConnectivityProvider` abstraction that EP-01-13 can adapt to. This task does not modify EP-01-12 files.

---

## 2. Business Problem Being Solved

Without a network management layer:

- The platform cannot distinguish between WiFi and metered mobile connections, preventing data-cost optimization for the Nigeria market where mobile data is expensive and users are cost-sensitive.
- EP-01-12's `ConnectivityPlusProvider` provides only binary online/offline detection — no network type awareness. EP-02+ features (image uploads, catalog browsing, video previews) cannot adapt behavior to connection quality.
- No app-wide network status observable exists for EP-01-15/16 UI to render connection-type indicators (e.g., "You're on mobile data" banners, "WiFi recommended for large downloads").
- Payload sizes remain constant regardless of connection type, wasting data on metered connections and degrading perceived performance on slow networks.
- The sync engine's connectivity trigger is binary; it cannot prioritize or throttle replay based on connection type (e.g., defer large payloads until WiFi).

This is the **network awareness backbone** — it turns the client into a network-intelligent presentation layer that adapts behavior to connection conditions and reduces data costs (AGENT.md Rule 4, zero-trust client).

---

## 3. Scope

### In Scope

- `lib/core/network/` module (§5.2): `network_config.dart`, `network_type.dart`, `network_status.dart`, `network_monitor.dart`, `network_status_provider.dart`, `sync_connectivity_adapter.dart`, `payload_optimizer.dart`, `network_exception.dart`, `network.dart` barrel + `initializeNetwork()`.
- **Network type detection** using `connectivity_plus` (already in `pubspec.yaml` via EP-01-12) — maps `ConnectivityResult` to a typed `NetworkType` enum (`wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `none`, `other`).
- **Network status model** (`NetworkStatus`) carrying `isConnected`, `networkType`, and `timestamp` — richer than EP-01-12's binary `ConnectivityStatus`.
- **Network monitor service** (`NetworkMonitor`) wrapping `connectivity_plus` with deduplicated status stream (no duplicate emissions for same network type), configurable debounce interval, and on-demand `currentStatus` query.
- **Network status provider** (`NetworkStatusProvider`, ChangeNotifier) exposing `NetworkStatus` for app-wide consumption.
- **Sync engine adapter** (`SyncConnectivityAdapter`) implementing EP-01-12's `ConnectivityProvider` interface, backed by `NetworkMonitor` — allows EP-01-15 bootstrap to wire the richer network layer into the sync engine without modifying EP-01-12 code.
- **Payload optimization utilities** (`PayloadOptimizer`) — stateless helpers recommending image quality, pagination page size, and compression preference based on `NetworkType`.
- **Network configuration** (`NetworkConfig`) sourced from `EnvironmentConfig` — debounce interval, feature gate (`FeatureFlags.enablePayloadOptimization`), default optimization thresholds.
- **EP-01-03 config extensions**: additive changes to `AppConstants` (network env variable names + defaults), `EnvironmentConfig` (networkConfig field), `EnvironmentLoader` (NetworkConfig.fromSource wiring), `FeatureFlags` (enablePayloadOptimization flag), `CompileTimeEnvironmentValueSource` (network variables).
- Unit tests (`test/unit/core/network/`): network type mapping, status stream deduplication, adapter compatibility, payload optimization recommendations, configuration sourcing.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope

- Modifying EP-01-12 files (`lib/core/sync/`) — the adapter implements the existing `ConnectivityProvider` interface without changing it.
- Modifying EP-01-07 files (`lib/core/api/`) — network awareness is consumed by downstream layers, not injected into the API interceptor chain at this stage.
- Actual internet reachability probing (ping/DNS checks) — `connectivity_plus` detects interface availability, not true internet access. True reachability probing is deferred.
- Bandwidth estimation or throughput measurement — deferred to a future phase.
- Network request interception or Dio interceptor modifications — EP-01-07.
- UI widgets (offline banners, connection-type indicators, data-saver toggles) — EP-01-15/16+.
- Background connectivity monitoring (platform channels for connectivity when app is killed) — deferred.
- SSL pinning, encryption, or security infrastructure — EP-01-10.
- Auth framework, token handling — EP-01-09.
- Monitoring/logging integration — EP-01-14 (the network layer emits events; EP-01-14 wires them to Sentry).
- Supabase migrations, RPC, RLS — EP-01-05/06.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification logic is permitted. This layer **detects network conditions and recommends payload adaptations**; it does not authorize, compute, or decide outcomes. It must never store secrets or tokens. The network monitor operates purely as an unprivileged client-side observation layer — all server-side enforcement (RLS, RPC validation) remains authoritative (AGENT.md Rule 4). Payload optimization utilities are advisory only; downstream consumers decide whether to act on recommendations.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Reuse existing `connectivity_plus` package | EP-01-12 already added it to `pubspec.yaml` |
| No modification of EP-01-12 files | Adapter pattern implements existing interface |
| Feature-gated via `FeatureFlags` | EP-01-03 |
| No business logic in client | AGENT.md Rules 1, 4 |
| Advisory-only payload optimization | Layer recommends; consumers decide |

### 5.2 Proposed Structure

```text
lib/core/network/
├── network_config.dart              # debounce interval, feature gate, optimization thresholds
├── network_type.dart                # enum: wifi, mobile, ethernet, vpn, bluetooth, none, other
├── network_status.dart              # model: isConnected, networkType, timestamp
├── network_monitor.dart             # service: wraps connectivity_plus, deduplicated stream, debounce
├── network_status_provider.dart     # ChangeNotifier exposing NetworkStatus app-wide
├── sync_connectivity_adapter.dart   # implements EP-01-12 ConnectivityProvider via NetworkMonitor
├── payload_optimizer.dart           # stateless helpers: image quality, page size, compression
├── network_exception.dart           # typed exception for network operations
└── network.dart                     # barrel + initializeNetwork() + NetworkLayer aggregate
```

### 5.3 Network Type (`network_type.dart`)

```dart
enum NetworkType {
  wifi,
  mobile,
  ethernet,
  vpn,
  bluetooth,
  none,
  other,
}
```

Mapping from `connectivity_plus` `ConnectivityResult`:

| `ConnectivityResult` | `NetworkType` |
|---|---|
| `wifi` | `wifi` |
| `mobile` | `mobile` |
| `ethernet` | `ethernet` |
| `vpn` | `vpn` |
| `bluetooth` | `bluetooth` |
| `none` | `none` |
| `other` | `other` |

When `connectivity_plus` returns a `List<ConnectivityResult>` (multiple active interfaces), the monitor selects the **primary** interface using priority order: `vpn` > `ethernet` > `wifi` > `mobile` > `bluetooth` > `other` > `none`. This reflects the interface most likely carrying traffic.

### 5.4 Network Status Model (`network_status.dart`)

| Field | Type | Purpose |
|---|---|---|
| `isConnected` | `bool` | `true` if any network interface is active |
| `networkType` | `NetworkType` | The primary active network interface |
| `timestamp` | `DateTime` | When this status was observed |

Factory: `NetworkStatus.fromResults(List<ConnectivityResult>)` applies the priority mapping. `NetworkStatus.disconnected()` convenience for `none`.

Equality: value-based on `isConnected` + `networkType` (ignores `timestamp` for deduplication comparison).

### 5.5 Network Monitor (`network_monitor.dart`)

The core service:

1. **Wraps `connectivity_plus`** `Connectivity` instance.
2. **Initial status:** calls `checkConnectivity()` at construction, maps to `NetworkStatus`.
3. **Stream:** subscribes to `onConnectivityChanged`, maps each `List<ConnectivityResult>` to `NetworkStatus`.
4. **Deduplication:** compares new `NetworkStatus` against last emitted status using value equality (`isConnected` + `networkType`). Skips emission if unchanged (prevents duplicate events when `connectivity_plus` fires for non-material changes).
5. **Debounce:** optional configurable debounce interval (`NetworkConfig.debounceIntervalMs`) — when set, rapid connectivity changes are collapsed into a single emission after the interval. Default: 0 (no debounce). Useful for environments with flappy connections.
6. **On-demand query:** `Future<NetworkStatus> get currentStatus` calls `checkConnectivity()` for a fresh check (not cached).
7. **Cached status:** `NetworkStatus get lastKnownStatus` returns the most recently observed status without a platform call.
8. **Dispose:** cancels subscription, closes stream controller.

```dart
abstract class NetworkMonitor {
  Stream<NetworkStatus> get onStatusChanged;
  Future<NetworkStatus> get currentStatus;
  NetworkStatus get lastKnownStatus;
  void dispose();
}
```

Default implementation: `ConnectivityPlusNetworkMonitor` (wraps `connectivity_plus`, applies dedup + debounce).
Test implementation: `FakeNetworkMonitor` (manual `setStatus()` for deterministic testing).

### 5.6 Network Status Provider (`network_status_provider.dart`)

A `ChangeNotifier` exposing:

| Property | Type | Purpose |
|---|---|---|
| `status` | `NetworkStatus` | Current network status (last observed) |
| `isConnected` | `bool` | Convenience: `status.isConnected` |
| `networkType` | `NetworkType` | Convenience: `status.networkType` |
| `isOnMeteredConnection` | `bool` | `true` if `mobile` or `bluetooth` |

Subscribes to `NetworkMonitor.onStatusChanged` at construction. Calls `notifyListeners()` on each new status.

Downstream consumers (EP-01-15 router, EP-01-16 UI, EP-02+ features) listen to this provider for connection-type indicators and data-saver logic. This task does not build any UI.

### 5.7 Sync Engine Adapter (`sync_connectivity_adapter.dart`)

Implements EP-01-12's `ConnectivityProvider` interface, backed by `NetworkMonitor`:

```dart
class SyncConnectivityAdapter implements ConnectivityProvider {
  SyncConnectivityAdapter(this._monitor);

  final NetworkMonitor _monitor;

  @override
  Stream<ConnectivityStatus> get onConnectivityChanged =>
      _monitor.onStatusChanged.map(
        (NetworkStatus s) => s.isConnected
            ? ConnectivityStatus.online
            : ConnectivityStatus.offline,
      );

  @override
  Future<bool> get isConnected async =>
      (await _monitor.currentStatus).isConnected;

  @override
  void dispose() { /* monitor lifecycle owned by NetworkLayer */ }
}
```

This adapter allows EP-01-15 bootstrap to wire the richer `NetworkMonitor` into the sync engine by passing `SyncConnectivityAdapter(monitor)` where `ConnectivityProvider` is expected — without modifying any EP-01-12 file.

### 5.8 Payload Optimizer (`payload_optimizer.dart`)

Stateless utility class providing advisory recommendations based on `NetworkType`:

| Method | Input | Output | Purpose |
|---|---|---|---|
| `recommendedImageQuality(NetworkType)` | network type | `ImageQuality` enum (`low`, `medium`, `high`) | Image compression level for uploads/downloads |
| `recommendedPageSize(NetworkType)` | network type | `int` (10–50) | Pagination page size for list queries |
| `shouldCompressPayload(NetworkType)` | network type | `bool` | Whether to enable request/response compression |
| `isMeteredConnection(NetworkType)` | network type | `bool` | Whether the connection is metered (mobile, bluetooth) |
| `recommendedMaxUploadSizeMb(NetworkType)` | network type | `double` | Advisory max upload size in MB |

`ImageQuality` enum:

| Value | Typical use |
|---|---|
| `low` | Mobile/bluetooth — compressed thumbnails, low-res previews |
| `medium` | WiFi default — balanced quality |
| `high` | Ethernet/VPN — full resolution |

Defaults are sourced from `NetworkConfig`. The optimizer is stateless and can be called from any layer without holding a reference to the monitor.

### 5.9 Network Configuration (`network_config.dart`)

| Field | Type | Default | Purpose |
|---|---|---|---|
| `debounceIntervalMs` | `int` | 0 | Connectivity change debounce (ms). 0 = no debounce |
| `enablePayloadOptimization` | `bool` | `false` | Feature gate for payload optimization advisories |
| `mobileImageQuality` | `String` | `low` | Default image quality on mobile |
| `wifiImageQuality` | `String` | `medium` | Default image quality on WiFi |
| `mobilePageSize` | `int` | 15 | Default pagination page size on mobile |
| `wifiPageSize` | `int` | 30 | Default pagination page size on WiFi |
| `maxUploadSizeMbMobile` | `double` | 5.0 | Advisory max upload size on mobile (MB) |
| `maxUploadSizeMbWifi` | `double` | 25.0 | Advisory max upload size on WiFi (MB) |

Sourced from `EnvironmentConfig` via compile-time defines (`HIVORR_NETWORK_*`). If not provided, defaults apply.

### 5.10 Initialization Wiring

`initializeNetwork(EnvironmentConfig)` builds the `NetworkLayer` aggregate. It:
1. Reads `FeatureFlags` — if payload optimization is disabled, `PayloadOptimizer` still exists but consumers can check the flag.
2. Constructs `NetworkConfig` from environment values.
3. Constructs `ConnectivityPlusNetworkMonitor` with config (debounce interval).
4. Constructs `NetworkStatusProvider` subscribed to the monitor.
5. Constructs `PayloadOptimizer` with config thresholds.
6. Constructs `SyncConnectivityAdapter` backed by the monitor.
7. Returns the wired `NetworkLayer`.

`NetworkLayer` aggregate:

| Field | Type | Purpose |
|---|---|---|
| `monitor` | `NetworkMonitor` | Core network detection service |
| `statusProvider` | `NetworkStatusProvider` | App-wide observable |
| `adapter` | `SyncConnectivityAdapter` | EP-01-12 bridge |
| `payloadOptimizer` | `PayloadOptimizer` | Advisory optimization |
| `config` | `NetworkConfig` | Active configuration |

`lib/app/` (EP-01-15) calls `initializeNetwork()` at bootstrap — **this task does not modify `main.dart` or bootstrap**; it exports the initializer only.

### 5.11 EP-01-03 Configuration Extensions (additive)

Following the established pattern from EP-01-10, EP-01-11, EP-01-12:

**`AppConstants` additions:**
- `envNetworkDebounceIntervalMs` = `'HIVORR_NETWORK_DEBOUNCE_MS'`
- `envNetworkMobileImageQuality` = `'HIVORR_NETWORK_MOBILE_IMAGE_QUALITY'`
- `envNetworkWifiImageQuality` = `'HIVORR_NETWORK_WIFI_IMAGE_QUALITY'`
- `envNetworkMobilePageSize` = `'HIVORR_NETWORK_MOBILE_PAGE_SIZE'`
- `envNetworkWifiPageSize` = `'HIVORR_NETWORK_WIFI_PAGE_SIZE'`
- `envNetworkMaxUploadMbMobile` = `'HIVORR_NETWORK_MAX_UPLOAD_MB_MOBILE'`
- `envNetworkMaxUploadMbWifi` = `'HIVORR_NETWORK_MAX_UPLOAD_MB_WIFI'`
- `featureEnablePayloadOptimization` = `'HIVORR_FEATURE_ENABLE_PAYLOAD_OPTIMIZATION'`
- Corresponding `default*` constants for each.

**`FeatureFlags` addition:**
- `enablePayloadOptimization` (bool, default `false`).

**`EnvironmentConfig` addition:**
- `networkConfig` field (`NetworkConfig`).

**`EnvironmentLoader` addition:**
- `NetworkConfig.fromSource(source)` wiring.

**`CompileTimeEnvironmentValueSource` addition:**
- Network variable mappings.

### 5.12 Extensibility Hooks

- `NetworkMonitor` abstract → future phases can replace with richer implementation (bandwidth estimation, true reachability probing).
- `NetworkStatusProvider` → EP-01-15/16 UI consumes for connection-type indicators and data-saver toggles.
- `PayloadOptimizer` → EP-02+ features call for advisory recommendations per network type.
- `SyncConnectivityAdapter` → EP-01-15 bootstrap wires into sync engine without modifying EP-01-12.
- `NetworkConfig` → environment-specific tuning without code changes.
- `network.dart` barrel → EP-01-15 bootstrap.
- `NetworkType` → EP-02+ features can branch on connection type (e.g., defer video preload on mobile).

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Source of network config values, feature gate |
| `connectivity_plus` | `pubspec.yaml` (EP-01-12) | Platform connectivity detection (already integrated) |
| `NetworkMonitor` | `lib/core/network/` | Network type detection, deduplicated status stream |
| `NetworkStatusProvider` | `lib/core/network/` | App-wide ChangeNotifier observable |
| `SyncConnectivityAdapter` | `lib/core/network/` | EP-01-12 `ConnectivityProvider` bridge |
| `PayloadOptimizer` | `lib/core/network/` | Advisory payload optimization recommendations |
| `NetworkConfig` | `lib/core/network/` | Configuration sourced from `EnvironmentConfig` |
| EP-01-03 config extensions | `lib/config/` | Additive `AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource` |
| Test suites | `test/unit/core/network/` | Type mapping, dedup, adapter, optimizer, config tests |

**No new dependencies required.** `connectivity_plus: ^6.1.0` is already in `pubspec.yaml` (added by EP-01-12). The payload optimizer is pure Dart with no external dependencies.

---

## 7. Data Requirements

- **Network status records** are transient observation models (network type + timestamp). They contain no business logic, no user data, no domain entities.
- `NetworkStatus` is an in-memory value object — never persisted to storage.
- `PayloadOptimizer` recommendations are stateless computations from `NetworkType` — no data stored.
- No tokens, secrets, or credentials are observed, stored, or transmitted by this layer.
- No business, financial, or domain data is created by this task.

---

## 8. Database Considerations

**Not applicable** to Supabase/PostgreSQL. This task defines **client-local** network observation only. All server-side schema, RPC, and RLS remain owned by EP-01-05/06. No migrations; no persistent storage.

---

## 9. API Requirements

- **No new network endpoints/RPCs.** The network monitor observes connectivity; it does not make API calls.
- The `PayloadOptimizer` provides advisory recommendations that downstream API consumers (EP-02+ repositories, datasources) may use to adjust request parameters (page size, image quality query params, compression headers).
- The `SyncConnectivityAdapter` bridges to EP-01-12's `ConnectivityProvider` — the sync engine continues to replay through EP-01-07 `Dio` with the full interceptor chain.
- No interceptor modifications to EP-01-07.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing. The `NetworkStatusProvider` is exported for EP-01-15/16+ to build connection-type indicators. `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `initializeNetwork(config)` yields a fully wired `NetworkLayer`.
- `NetworkStatusProvider` gives UI layers a clean observable for connection-type indicators and metered-connection warnings.
- `PayloadOptimizer` gives EP-02+ features a simple, stateless API for network-adaptive behavior.
- `SyncConnectivityAdapter` allows EP-01-15 bootstrap to wire the richer network layer into the sync engine with a single line.
- Feature gate (`enablePayloadOptimization`) allows disabling optimization advisories without code changes.
- Debounce interval prevents UI flicker from rapid connectivity oscillation.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Network type leaking to logs | `NetworkStatus.toString()` must not include device identifiers or SSID. Only `NetworkType` enum name and `isConnected` boolean. |
| Hardcoded config values | All network parameters sourced exclusively from `EnvironmentConfig`; no `String.fromEnvironment`, no literals. |
| Business logic in client | Layer observes and recommends only; no role/verification/pricing decisions (AGENT.md Rule 4). |
| Payload optimization bypassing server authority | Recommendations are advisory; server-side validation (RLS + RPC) remains authoritative on accepted payload sizes and formats. |
| Secrets in network status | `NetworkStatus` carries only `NetworkType` + `isConnected` + `timestamp`. No SSID, BSSID, IP address, or device identifiers. |
| Feature gate bypass | `FeatureFlags.enablePayloadOptimization` checked by consumers; the optimizer itself is stateless and always callable, but consumers respect the gate. |

---

## 13. Performance Considerations

- **Deduplication:** prevents redundant stream emissions when `connectivity_plus` fires for non-material changes (e.g., interface re-scan with same result). Reduces downstream `notifyListeners()` calls.
- **Debounce:** configurable interval collapses rapid connectivity oscillation (flappy connections) into a single emission, preventing UI flicker and unnecessary sync engine triggers.
- **Lazy platform calls:** `lastKnownStatus` returns cached value without a platform call. `currentStatus` makes a fresh call only when explicitly requested.
- **Stateless optimizer:** `PayloadOptimizer` methods are pure functions — no I/O, no allocation beyond return values. Negligible CPU cost.
- **Single `connectivity_plus` instance:** the `NetworkMonitor` owns the single `Connectivity()` instance. The `SyncConnectivityAdapter` delegates to the monitor — no duplicate platform subscriptions.
- **No synchronous I/O:** all `connectivity_plus` calls are async; no blocking on the UI thread.
- **No new dependencies:** reuses `connectivity_plus` already in `pubspec.yaml`. Zero impact on the 15–20 MB installer target.
- **Memory:** `NetworkStatusProvider` holds one `NetworkStatus` value (negligible). `NetworkMonitor` holds one stream subscription and one `StreamController`.

---

## 14. Testing Strategy

### 14.1 Unit — Network Type Mapping
- `ConnectivityResult.wifi` → `NetworkType.wifi`.
- `ConnectivityResult.mobile` → `NetworkType.mobile`.
- `ConnectivityResult.ethernet` → `NetworkType.ethernet`.
- `ConnectivityResult.vpn` → `NetworkType.vpn`.
- `ConnectivityResult.bluetooth` → `NetworkType.bluetooth`.
- `ConnectivityResult.none` → `NetworkType.none`.
- `ConnectivityResult.other` → `NetworkType.other`.
- Multiple results: `[vpn, wifi]` → `NetworkType.vpn` (priority order).
- Empty results list → `NetworkType.none`.
- All-none results → `NetworkType.none`.

### 14.2 Unit — Network Status
- `NetworkStatus.fromResults([wifi])` → `isConnected: true`, `networkType: wifi`.
- `NetworkStatus.fromResults([none])` → `isConnected: false`, `networkType: none`.
- Value equality: two `NetworkStatus` with same `isConnected` + `networkType` but different `timestamp` are equal (for deduplication).
- `NetworkStatus.disconnected()` → `isConnected: false`, `networkType: none`.

### 14.3 Unit — Network Monitor (with `FakeNetworkMonitor`)
- Initial status emitted on stream listen.
- Status change emits new value.
- Deduplication: same status emitted twice → only one stream event.
- `lastKnownStatus` returns most recent without platform call.
- `currentStatus` returns fresh check.
- Dispose cancels subscription and closes controller.

### 14.4 Unit — Network Status Provider
- Initial status reflects monitor's initial status.
- Status change updates `status`, `isConnected`, `networkType`, `isOnMeteredConnection`.
- `notifyListeners()` called on status change.
- `isOnMeteredConnection`: `true` for `mobile` and `bluetooth`; `false` for `wifi`, `ethernet`, `vpn`, `none`.

### 14.5 Unit — Sync Connectivity Adapter
- `onConnectivityChanged` maps `NetworkStatus(online)` → `ConnectivityStatus.online`.
- `onConnectivityChanged` maps `NetworkStatus(offline)` → `ConnectivityStatus.offline`.
- `isConnected` delegates to `NetworkMonitor.currentStatus`.
- Adapter is compatible with EP-01-12's `ConnectivityProvider` interface (type check passes).

### 14.6 Unit — Payload Optimizer
- `recommendedImageQuality(mobile)` → `ImageQuality.low`.
- `recommendedImageQuality(wifi)` → `ImageQuality.medium`.
- `recommendedImageQuality(ethernet)` → `ImageQuality.high`.
- `recommendedPageSize(mobile)` → config value (default 15).
- `recommendedPageSize(wifi)` → config value (default 30).
- `shouldCompressPayload(mobile)` → `true`.
- `shouldCompressPayload(wifi)` → `false` (or configurable).
- `isMeteredConnection(mobile)` → `true`.
- `isMeteredConnection(wifi)` → `false`.
- `recommendedMaxUploadSizeMb(mobile)` → config value (default 5.0).
- `none` type → most conservative recommendations.

### 14.7 Unit — Network Configuration
- `NetworkConfig.fromSource()` with all values present → correct parsing.
- `NetworkConfig.fromSource()` with no values → defaults applied.
- Invalid debounce value → handled per `EnvironmentLoader` convention.

### 14.8 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new tests pass.
- Available platform smoke build (no native changes required).

### 14.9 Scope Validation
- Diff review: only `lib/core/network/` + `test/unit/core/network/` + EP-01-03 additive config extensions (`AppConstants`, `FeatureFlags`, `EnvironmentConfig`, `EnvironmentLoader`, `CompileTimeEnvironmentValueSource`). No modifications to EP-01-07, EP-01-08, EP-01-11, or EP-01-12 files. No bootstrap/UI/DB/auth/security/monitoring implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-07 and EP-01-12 deliverables; confirm `lib/core/network/` contains only `.gitkeep`.
2. Implement EP-01-03 additive config extensions: `AppConstants` (network variable names + defaults), `FeatureFlags` (`enablePayloadOptimization`), `NetworkConfig` class, `EnvironmentConfig` (`networkConfig` field), `EnvironmentLoader` (NetworkConfig.fromSource wiring), `CompileTimeEnvironmentValueSource` (network variables).
3. Implement `lib/core/network/network_type.dart` — `NetworkType` enum.
4. Implement `lib/core/network/network_status.dart` — `NetworkStatus` model with value equality, `fromResults()` factory, `disconnected()` convenience.
5. Implement `lib/core/network/network_exception.dart` — typed exception.
6. Implement `lib/core/network/network_config.dart` — configuration class sourced from `EnvironmentConfig`.
7. Implement `lib/core/network/network_monitor.dart` — `NetworkMonitor` abstract + `ConnectivityPlusNetworkMonitor` default + `FakeNetworkMonitor` test implementation. Deduplication + debounce.
8. Implement `lib/core/network/network_status_provider.dart` — ChangeNotifier wrapping `NetworkMonitor`.
9. Implement `lib/core/network/sync_connectivity_adapter.dart` — EP-01-12 `ConnectivityProvider` bridge.
10. Implement `lib/core/network/payload_optimizer.dart` — stateless advisory helpers.
11. Implement `lib/core/network/network.dart` — barrel + `initializeNetwork()` + `NetworkLayer` aggregate.
12. Add `test/unit/core/network/` unit tests (type mapping, status model, monitor dedup, provider, adapter, optimizer, config).
13. Run `flutter analyze` and `flutter test`.
14. Available platform smoke builds.
15. Review final diff for strict EP-01-13 scope containment and phase-document integrity.
16. **Stop at the approval gate** — do not implement EP-01-15 bootstrap, EP-01-16 UI, or downstream tasks.

---

## 16. Expected Outcome

- A fully functional **network management layer** in `lib/core/network/` providing network type detection, deduplicated status streaming, and app-wide observability.
- `NetworkMonitor` wraps `connectivity_plus` with richer semantics (network type, priority-based interface selection, deduplication, optional debounce) than EP-01-12's basic `ConnectivityPlusProvider`.
- `NetworkStatusProvider` enables EP-01-15/16+ UI to render connection-type indicators and metered-connection warnings.
- `SyncConnectivityAdapter` bridges the richer network layer into EP-01-12's `ConnectivityProvider` interface without modifying any EP-01-12 file.
- `PayloadOptimizer` provides advisory, stateless recommendations for image quality, pagination, and compression based on network type — enabling data-cost reduction on metered connections (Nigeria market).
- `NetworkConfig` sourced from `EnvironmentConfig` — environment-tunable without code changes.
- Unit tests proving type mapping, deduplication, adapter compatibility, optimization recommendations, and configuration sourcing — all without a live backend.

---

## 17. Definition of Done (DoD)

**Structure & Code**
- [ ] `lib/core/network/` contains the §5.2 structure; all files implemented and importing correctly.
- [ ] `NetworkType` enum defines `wifi`, `mobile`, `ethernet`, `vpn`, `bluetooth`, `none`, `other`.
- [ ] `NetworkStatus` model exposes `isConnected`, `networkType`, `timestamp`; value equality on `isConnected` + `networkType`; `fromResults()` factory applies priority mapping; `disconnected()` convenience.
- [ ] `NetworkMonitor` abstract interface defines `onStatusChanged`, `currentStatus`, `lastKnownStatus`, `dispose()`.
- [ ] `ConnectivityPlusNetworkMonitor` default implementation wraps `connectivity_plus`, applies deduplication and optional debounce.
- [ ] `FakeNetworkMonitor` test implementation allows manual `setStatus()` for deterministic testing.
- [ ] `NetworkStatusProvider` (ChangeNotifier) exposes `status`, `isConnected`, `networkType`, `isOnMeteredConnection`; emits changes via `notifyListeners()`.
- [ ] `SyncConnectivityAdapter` implements EP-01-12's `ConnectivityProvider` interface backed by `NetworkMonitor`; type-compatible without EP-01-12 modifications.
- [ ] `PayloadOptimizer` provides `recommendedImageQuality()`, `recommendedPageSize()`, `shouldCompressPayload()`, `isMeteredConnection()`, `recommendedMaxUploadSizeMb()` — all stateless, config-driven.
- [ ] `NetworkConfig` sourced from `EnvironmentConfig`; no `String.fromEnvironment`, no hardcoded values.
- [ ] `network.dart` barrel exports public API; `initializeNetwork()` wired for EP-01-15 (no `main.dart` change); `NetworkLayer` aggregate.
- [ ] EP-01-03 additive config extensions: `AppConstants` (8 network variable names + defaults), `FeatureFlags` (`enablePayloadOptimization`), `EnvironmentConfig` (`networkConfig` field), `EnvironmentLoader` (NetworkConfig.fromSource), `CompileTimeEnvironmentValueSource` (network variables).
- [ ] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/auth/security/monitoring/migration code included.
- [ ] No modifications to EP-01-07, EP-01-08, EP-01-11, or EP-01-12 files.
- [ ] No new dependencies added to `pubspec.yaml` (reuses `connectivity_plus` from EP-01-12).
- [ ] `flutter analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (type mapping, status model, monitor dedup, provider, adapter, optimizer, config unit tests).
- [ ] Available platform smoke builds pass.
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-13 changes (+ EP-01-03 additive config extensions).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** Medium-high — designing a correct deduplicated connectivity stream with priority-based interface selection, debounce logic, and a clean adapter to EP-01-12's `ConnectivityProvider` requires careful reasoning about stream semantics and edge cases (rapid toggles, multiple interfaces, dispose ordering). Mistakes cause duplicate emissions, missed transitions, or adapter incompatibility.
- **Business impact:** Medium — the Nigeria market's data-cost sensitivity makes payload optimization valuable, but the layer is advisory-only. Core platform functionality (auth, sync, API) works without it. However, every EP-02+ feature that adapts to network conditions depends on this layer.
- **Security risk:** Low — the layer observes network type only; no secrets, tokens, or business data. Risk is limited to accidental information leakage in logs (mitigated by safe `toString()`).
- **Performance sensitivity:** Medium — deduplication and debounce prevent UI flicker and unnecessary sync triggers. Incorrect implementation causes redundant `notifyListeners()` calls or missed transitions. The payload optimizer is pure computation with negligible cost.
- **Data complexity:** Low — `NetworkStatus` is a simple value object (3 fields). `NetworkType` is a 7-value enum. No relational data, no persistence, no schema design.
- **Integration complexity:** High — must integrate correctly with two completed subsystems (`connectivity_plus` via EP-01-12's existing package, `EnvironmentConfig` via EP-01-03's established pattern) and expose a clean adapter for EP-01-12's `ConnectivityProvider` interface without modifying EP-01-12 files. The EP-01-03 config extension pattern must be followed precisely (8 new variable names, FeatureFlags addition, EnvironmentConfig field, EnvironmentLoader wiring, CompileTimeEnvironmentValueSource mapping).

High reasoning matches the approved EP-01 matrix (EP-01-13 = High) and the integration-heavy nature of the task — the complexity lies in correct stream semantics, adapter compatibility, and precise config pattern adherence rather than algorithmic depth.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

No approval-required decisions are flagged — this task introduces no new dependencies (reuses `connectivity_plus` from EP-01-12), no architectural tradeoffs, and no scope ambiguities. The plan follows established patterns from EP-01-10, EP-01-11, and EP-01-12.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-13-Network Management & Connectivity Infrastructure.md`. Implementation will begin only after a separate implementation approval. No production code is written during planning.
