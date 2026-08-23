# TASK IMPLEMENTATION PLAN: EP-01-11

## Local Storage & Cache Management System

| Field | Value |
|---|---|
| Task ID | EP-01-11 |
| Task Name | Local Storage & Cache Management System |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-02 (Dependency Integration & Package Configuration — completed). Transitively relies on EP-01-03 (`EnvironmentConfig` contract) for env-sourced settings. Consumed downstream by EP-01-08 (local-datasource seam), EP-01-12 (Offline Sync Engine action queue persistence), and EP-02+. |
| Priority | High |
| Planning Reasoning | High (approved EP-01 matrix) |
| Coding Reasoning | High (approved EP-01 matrix) |

---

## 1. Task Objective

Implement the client-side local persistence and transient caching foundation in two ARCHITECTURE.md-mandated directories:

- `lib/core/database/` — **local storage drivers** providing a persistent, typed, crash-safe store (selected from SQLite / Hive / Isar per D1), fully **abstracted** behind a `StorageEngine` interface so the data layer (EP-01-08) and the sync engine (EP-01-12) depend only on the abstraction (vendor-lock-in mitigation, consistent with EP-01-08).
- `lib/core/cache/` — **transient in-memory cache manager** with **LRU eviction**, **TTL expiration**, typed accessors, and a prefix-based invalidation API.

Deliverables:
- A selected, configured, **abstracted** persistent storage engine with typed object/JSON accessors, atomic writes, and named "box" (collection) isolation.
- A bounded LRU+TTL in-memory cache manager observable via stats and invalidation events.
- An `initializeDatabase()` / `initializeCache()` bootstrap hook for EP-01-15 (no `main.dart` modification).
- A clearly documented integration seam so EP-01-08's `EntityLocalDataSource` and EP-01-12's action queue can be backed by this engine without later refactor.
- Unit tests (no live backend) proving persistence round-trips, TTL expiry, LRU eviction, and atomicity.

**Dependency note:** EP-01-11 depends only on EP-01-02 per the approved matrix. EP-01-12 (sync) and the data layer (EP-01-08) are **downstream consumers**, not modified by this task.

---

## 2. Business Problem Being Solved

Without a unified local storage + cache foundation:

- The app cannot support **offline readability** or **cache-first reads** — every screen would block on the network, failing the Nigeria-market unreliable-connectivity requirement.
- The **Offline Sync Engine (EP-01-12)** would have no durable surface to persist its action queue; pending mutations would be lost on app restart/crash.
- EP-01-08's `EntityLocalDataSource` abstract (already defined) would have no concrete, non-in-memory backend, leaving cache-first data flow non-functional.
- Each future feature (EP-02+) would hand-roll `shared_preferences`/`sqlite`/`hive` calls, scattering persistence logic and fracturing the architectural boundary (ARCHITECTURE.md `lib/core/database/` vs `lib/core/cache/`).
- Cache memory would grow unbounded without LRU/TTL, risking OOM on low-end devices.

This is the **persistence bedrock** — it turns the client into a resilient, offline-capable presentation layer (AGENT.md Rule 4, zero-trust) without moving any business logic client-side.

---

## 3. Scope

### In Scope
- `lib/core/database/` module (§5.2): `database_config.dart`, `storage_engine.dart` (abstract), `adapters/<driver>_storage_engine.dart` (concrete), `boxes/app_boxes.dart` (named-box registry), `local_store.dart` (typed high-level accessor), `database.dart` barrel + `initializeDatabase()`.
- `lib/core/cache/`-equivalent `lib/core/cache/` module (§5.2): `cache_config.dart`, `cache_entry.dart`, `lru_cache.dart`, `cache_manager.dart`, `cache.dart` barrel + `initializeCache()`.
- **Storage technology selection** via D1 decision — one driver chosen and abstracted (Hive recommended; see §15).
- Persistent store with: typed `put/get/delete/clear/keys`, JSON + object (via `toJson/fromJson`) support, **atomic write** semantics, and named-box isolation (`cache`, `sync_queue`, `entity_cache`, `misc`).
- Transient in-memory `CacheManager`: `get/put/remove/clear`, prefix invalidation (`invalidatePrefix`), bounded entry count, per-entry + default TTL, LRU eviction, hit/miss stats.
- Environment-driven config sourced **only** from `EnvironmentConfig` (EP-01-03): storage driver type, base path, max cache entries, default TTL, encryption-at-rest flag. No `String.fromEnvironment`.
- A documented **integration contract**: `StorageEngine` is the backend EP-01-08's `EntityLocalDataSource` and EP-01-12's queue will implement against (no EP-01-08/12 code written here).
- Unit tests (`test/unit/core/database/`, `test/unit/core/cache/`): round-trip, TTL expiry, LRU eviction order, atomicity, typed accessors, invalidation.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope
- Building repositories, DTOs, mappers, or remote datasources — EP-01-08.
- **Implementing** `EntityLocalDataSource` concrete binding (that is EP-01-08's domain; this task only supplies the engine it binds to).
- Offline sync engine, action queue, conflict resolution — EP-01-12.
- Connectivity monitoring — EP-01-13.
- Secure storage of secrets/tokens (refresh tokens, access tokens, device secrets) — EP-01-10 (`SecureStorage`). This task's persistent store is for **non-secret operational/offline cache data only**; sensitive material must never be written here (see §12).
- AES-at-rest crypto implementation — EP-01-10; this task may *consume* an optional encryption wrapper hook but does not implement crypto.
- Supabase migrations, RPC, RLS — EP-01-05/06.
- Auth framework, API layer, security infrastructure, monitoring, UI, bootstrap routing — EP-01-07/09/10/14/15/16.
- Native platform configuration changes.
- Modification of the approved EP-01 phase document, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No proprietary/business rule, pricing, matching, escrow, or verification logic is permitted. This layer **persists and caches data**; it does not authorize, compute, or decide. It must never store secrets or tokens (those belong to EP-01-10 `SecureStorage`). The persistent store and cache operate purely as an unprivileged client-side buffer for server-sourced/queued data (AGENT.md Rule 4).

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Abstraction over implementation (vendor lock-in mitigation) | EP-01-08 §5.2/DoD (local-datasource seam) |
| Secrets belong to `SecureStorage` (EP-01-10) | EP-01-10 contract |
| Separation: persistent store (`database/`) vs transient cache (`cache/`) | ARCHITECTURE.md `lib/core/` mapping |
| No business logic in client | AGENT.md Rules 1, 4 |

### 5.2 Proposed Structure

```text
lib/core/database/
├── database_config.dart                 # driver type, path, box registry, enc-at-rest flag (from EnvironmentConfig)
├── storage_engine.dart                  # abstract StorageEngine interface
├── adapters/
│   └── hive_storage_engine.dart         # concrete impl (Hive) — or sqlite/drift per D1
├── boxes/
│   └── app_boxes.dart                   # named-box registry (cache|sync_queue|entity_cache|misc)
├── local_store.dart                     # typed high-level accessor (object <-> JSON via mapper fns)
└── database.dart                        # barrel + initializeDatabase()

lib/core/cache/
├── cache_config.dart                    # maxEntries, defaultTtl, evictionPolicy
├── cache_entry.dart                     # entry wrapper (value, expiresAt, lastAccessedAt)
├── lru_cache.dart                       # bounded LRU + TTL in-memory cache
├── cache_manager.dart                   # get/put/remove/clear/invalidatePrefix/stats
└── cache.dart                           # barrel + initializeCache()
```

### 5.3 Storage Engine (`database/`)

- `StorageEngine` (abstract): `Future<void> put(String box, String key, Map<String, dynamic> value)`, `Future<Map<String, dynamic>?> get(String box, String key)`, `Future<void> delete(String box, String key)`, `Future<void> clearBox(String box)`, `Future<List<String>> keys(String box)`, plus a **best-effort atomic batch** `Future<void> writeBatch(String box, List<WriteOp> ops)` for queue-safe multi-writes. Errors normalized to a typed `StorageException` (no raw driver exceptions surfaced).
- `HiveStorageEngine` (concrete, if D1 = Hive): initializes `Hive` with a `path_provider` base path (env-sourced), opens lazily per registered box, stores `Map<String,dynamic>` (JSON-compatible) values. `local_store.dart` adds typed `read<T>`/`write<T>` helpers taking `T Function(Map) fromJson` / `Map Function(T) toJson` — keeping entity/DTO serialization in the data layer (EP-01-08), not here.
- **Atomicity for the sync queue:** `writeBatch` writes all ops within a single box transaction (Hive supports box put batches; for SQLite, a transaction). This guarantees the EP-01-12 action queue cannot be left half-written on crash.
- **Box isolation:** pre-registered boxes (`sync_queue`, `entity_cache`, `misc`) prevent key collisions across features and keep the sensitive-vs-operational boundary explicit.

### 5.4 Cache Manager (`cache/`)

- `CacheEntry<T>`: holds `value`, `expiresAt`, `lastAccessedAt`.
- `LruCache<T>`: doubly-linked-list or `LinkedHashMap`-based LRU; on `get`, refresh `lastAccessedAt`; on insert beyond `maxEntries`, evict LRU; on `get`, treat expired entries as miss and evict.
- `CacheManager`: process-wide singleton (constructed via `initialize()`). API: `get<T>(key)`, `put<T>(key, value, {ttl})`, `remove(key)`, `clear()`, `invalidatePrefix(prefix)` (e.g., `entity:*` on profile update), `stats()` (size, hits, misses, evictions). All operations O(1) amortized; TTL evaluated lazily.
- Transient by design: **never persisted**; survives only for process lifetime. This satisfies the "transient memory cache" mandate and avoids PII-at-rest concerns.

### 5.5 Integration Contract (for downstream tasks)

- `StorageEngine` is the **sole** persistence backend EP-01-12 uses for its action queue (`sync_queue` box) — EP-01-12 depends on this interface, not on any driver.
- EP-01-08's `EntityLocalDataSource` abstract can be backed by `local_store.dart` + `StorageEngine` (`entity_cache` box) with a trivial adapter. This task **documents** the binding; the concrete `EntityLocalDataSource` impl remains EP-01-08's (this task does not modify EP-01-08 files).
- Encryption hook: `database_config` exposes `encryptAtRest` flag; if enabled, `local_store` may wrap values through an injected `Cipher` (EP-01-10 `AesCipher`) — **consumed, not implemented**, here.

### 5.6 Extensibility Hooks
- `StorageEngine` abstract → EP-01-12 (queue), EP-01-08 (entity cache), EP-02+ (offline reads).
- `CacheManager.invalidatePrefix` → EP-01-08/EP-02 cache coherence on writes.
- Optional `Cipher` injection → EP-01-10 at-rest encryption for sensitive cached fields.
- `database.dart` / `cache.dart` barrels → EP-01-15 bootstrap.

### 5.7 Initialization Wiring
`initializeDatabase(EnvironmentConfig)` + `initializeCache(EnvironmentConfig)` build the singletons. `lib/app/` (EP-01-15) calls these at bootstrap — **this task does not modify `main.dart` or bootstrap**; it exports the initializers only.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` | `lib/config/environments/` (EP-01-03) | Source of path, driver type, cache limits, enc flag |
| `StorageEngine` (abstract) + concrete adapter | `lib/core/database/` | Persistent typed store |
| `app_boxes.dart` | `lib/core/database/boxes/` | Named-box registry |
| `local_store.dart` | `lib/core/database/` | Typed object<->JSON accessor |
| `CacheManager` / `LruCache` | `lib/core/cache/` | Transient LRU+TTL cache |
| `EntityLocalDataSource` (abstract) | `lib/data/datasources/local/` (EP-01-08) | Consumer seam (not modified) |
| `SecureStorage` | `lib/core/storage/` (EP-01-10) | Secrets boundary (not used for operational cache) |
| Test suites | `test/unit/core/database/`, `test/unit/core/cache/` | Round-trip, TTL, LRU, atomicity |

**New dependency (D1):** one local-storage package added to `pubspec.yaml` (e.g., `hive` + `hive_flutter` + `path_provider`). Selection requires lead approval (§15).

---

## 7. Data Requirements

- Persisted data is **server-sourced or client-queued operational data only**: cached entity/profile DTOs, sync action records, misc UI/preference state. **No tokens, secrets, or credentials** (those → EP-01-10).
- Values stored as JSON-compatible `Map<String,dynamic>`; typed mapping (`T` ↔ `Map`) lives in the consumer (EP-01-08 mappers), preserving the "no business logic here" boundary.
- Cache holds only in-memory transient copies; nothing sensitive is persisted by the cache.
- No business, user-seeded, or domain data is created by this task beyond caching what upstream layers already provide.

---

## 8. Database Considerations

**Not applicable** to Supabase/PostgreSQL. This task defines **client-local** persistence only. All server-side schema, RPC, and RLS remain owned by EP-01-05/06. The local store is a cache/offline buffer of server data — enforcement (auth scoping, validation) stays server-side (AGENT.md Rule 4). No migrations; the local engine self-initializes its boxes.

---

## 9. API Requirements

- **No new network endpoints/RPCs.** This is a pure client-local subsystem.
- Exposes a **client-side persistence contract** (`StorageEngine`, `CacheManager`) consumed by EP-01-08/12 and EP-02+, not by any remote API.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, or routing. Initializers are exported for EP-01-15; `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `initializeDatabase(config)` / `initializeCache(config)` yields fully wired persistence + cache.
- A single `StorageEngine` abstraction means EP-01-12 and EP-01-08 never touch a concrete driver — swap-in/swap-out without ripple effects.
- `CacheManager.invalidatePrefix` gives features a clean coherence primitive (no stale-cache bugs).
- Bounded LRU+TTL prevents silent memory growth on low-end devices.
- Documented seam lets EP-01-08 back its `EntityLocalDataSource` with zero refactor.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Secret/token leakage into local store | **Hard boundary:** only operational/queued non-secret data here; tokens/credentials go to EP-01-10 `SecureStorage`. `StorageException`/logs never embed values. |
| Sensitive PII cached at rest | Cache is transient (memory only). For persistent sensitive fields, enable `encryptAtRest` via EP-01-10 `AesCipher` (consumed hook, not implemented). Default `entity_cache` holds only non-sensitive profile fields. |
| Hardcoded paths / env-specific flags | All path/driver/TTL/enc values sourced exclusively from `EnvironmentConfig` (EP-01-03); never literals or `String.fromEnvironment`. |
| Raw driver exceptions to consumers | `StorageException` normalizes failures; no SQL/driver internals surfaced. |
| Business logic in client | Layer persists/caches only; no role/verification/pricing decisions (AGENT.md Rule 4). |
| Unauthorized env access | Client cannot switch environments at runtime (ENV-003/EP-01-03 invariant). |
| Cache poisoning across features | Named-box isolation + `invalidatePrefix` scoping prevent cross-feature key collisions. |

**R1 (data sensitivity classification):** confirm which cached entity fields are non-sensitive enough for the default (unencrypted) `entity_cache` box vs. requiring the `encryptAtRest` hook. Flagged for lead.

---

## 13. Performance Considerations

- **Cache:** O(1) get/put via `LinkedHashMap` LRU; lazy TTL check; bounded size prevents OOM; no disk I/O (transient).
- **Storage:** async reads/writes; box-open lazily cached; `writeBatch` minimizes round-trips for queue writes; no synchronous blocking on UI path.
- **Startup:** `initializeDatabase` opens only registered boxes on first access (lazy), keeping the lightweight installer fast; negligible impact on the 15–20 MB target (Hive is pure-Dart/small; SQLite/drift adds native libs — D1 weighs this).
- **Memory:** LRU cap + TTL reclamation keeps footprint predictable on low-end Android devices common in the Nigeria market.
- No new heavy assets; only one storage package (D1).

---

## 14. Testing Strategy

### 14.1 Unit — Storage Engine (mocked/real driver in temp dir)
- Round-trip: `put` → `get` returns equal `Map`; missing key → `null`.
- `clearBox` / `delete` behave; `keys` returns correct set.
- `writeBatch` is atomic: simulated failure mid-batch leaves box unchanged (queue-safe).
- Typed `local_store` `read<T>`/`write<T>` round-trips via provided mapper fns.
- Box isolation: same key in different boxes independent.

### 14.2 Unit — Cache Manager
- `put` then `get` returns value; after TTL elapses, `get` → `null` (miss).
- LRU: fill beyond `maxEntries`; oldest-accessed evicted; recently-used retained.
- `invalidatePrefix('entity:')` clears only matching keys.
- `stats()` reflects hits/misses/evictions correctly.

### 14.3 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new tests pass.
- Available platform smoke build (no native changes; web path validated if Hive chosen).

### 14.4 Scope Validation
- Diff review: only `lib/core/database/` + `lib/core/cache/` + `test/unit/core/{database,cache}/` (+ `pubspec.yaml` if D1 adds a package). No bootstrap/UI/DB/auth/security/sync/monitoring implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-02/03 deliverables; confirm `lib/core/database/` and `lib/core/cache/` contain only `.gitkeep`.
2. **Decision D1:** pin the chosen local-storage package in `pubspec.yaml` (per lead approval; Hive recommended for web-readiness + small footprint; SQLite/drift alternative for relational offline data; Isar excluded — no stable Web support).
3. Extend `EnvironmentConfig` (EP-01-03) usage with `databaseConfig`/`cacheConfig` values — no `String.fromEnvironment`.
4. Implement `lib/core/cache/cache_config.dart` + `cache_entry.dart` + `lru_cache.dart` + `cache_manager.dart` + `cache.dart`.
5. Implement `lib/core/database/database_config.dart` + `storage_engine.dart` (abstract) + `boxes/app_boxes.dart`.
6. Implement the concrete adapter (`adapters/hive_storage_engine.dart` per D1) + `local_store.dart` + `database.dart`.
7. Add `test/unit/core/cache/` + `test/unit/core/database/` unit tests.
8. Run `flutter analyze` and `flutter test`.
9. Available platform smoke builds (no native changes; verify web storage path if Hive).
10. Review final diff for strict EP-01-11 scope containment and phase-document integrity.
11. **Stop at the approval gate** — do not implement EP-01-08's `EntityLocalDataSource` binding, EP-01-12 queue, or downstream tasks.

---

## Approval-Required Decisions (flagged for the lead)

- **D1 — Local storage technology:** `Hive` (recommended: pure-Dart, small footprint, Web/IndexedDB support, satisfies 15–20 MB + cross-platform constraints) vs `SQLite`/`drift` (relational, mirrors server schema, better for complex offline queries, but larger native libs + web WASM overhead) vs `Isar` (excluded — no stable Web support, violating cross-platform readiness). Selected package is pinned in `pubspec.yaml` before code.
- **R1 — Cached-data sensitivity:** confirm default `entity_cache` holds only non-sensitive profile fields; sensitive fields require the `encryptAtRest` hook (EP-01-10). Behavior is config-driven; no code-path change.

---

## 16. Expected Outcome

- A reusable **persistence + cache foundation**: an abstracted `StorageEngine` (selected driver, typed accessors, atomic batch, named-box isolation) in `lib/core/database/` and a bounded LRU+TTL `CacheManager` in `lib/core/cache/`.
- A documented, stable integration seam so EP-01-08's `EntityLocalDataSource` and EP-01-12's action queue bind to `StorageEngine` with **no later refactor**.
- All persistence config sourced only from `EnvironmentConfig`; secrets excluded (EP-01-10 boundary); no business logic present.
- Unit tests proving round-trip, TTL, LRU eviction, and atomic batching without a live backend.
- Clean extensibility hooks for EP-01-08 (entity cache), EP-01-12 (sync queue), and EP-01-10 (at-rest encryption).

---

## 17. Definition of Done (DoD)

**Structure & Code**
- [ ] `lib/core/database/` and the `lib/core/cache/` module contain the §5.2 structure; all files implemented and importing correctly.
- [ ] `StorageEngine` abstract exposes `put/get/delete/clearBox/keys` + atomic `writeBatch`; concrete adapter implemented and **abstracted** (consumer depends on interface only).
- [ ] `app_boxes.dart` registers isolated boxes (`cache|sync_queue|entity_cache|misc`); no cross-box key collisions.
- [ ] `local_store.dart` provides typed `read<T>`/`write<T>` via injected mapper fns (no entity/DTO logic hardcoded here).
- [ ] `CacheManager` provides `get/put/remove/clear/invalidatePrefix/stats`; LRU eviction + TTL expiry verified.
- [ ] `database.dart` + `cache.dart` barrels export public API; `initializeDatabase()`/`initializeCache()` wired for EP-01-15 (no `main.dart` change).
- [ ] All config (path, driver, TTL, maxEntries, enc flag) sourced only from `EnvironmentConfig`; no `String.fromEnvironment`, no hardcoded values.
- [ ] No tokens/secrets persisted here (EP-01-10 boundary honored); `StorageException` never embeds values.
- [ ] No business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/auth/security/sync/monitoring/migration code included.
- [ ] `flutter_analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (storage round-trip, atomic batch, TTL, LRU, invalidation unit tests).
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] Approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-11 changes (+ `pubspec.yaml` if D1 adds a package).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **High**

### Reasoning Level Justification

- **Technical complexity:** Medium-high — designing a correct abstracted storage engine with atomic batching for a crash-safe queue, plus a correct LRU+TTL cache (eviction order, lazy expiry, prefix invalidation) requires careful reasoning; mistakes cause data loss, stale cache, or memory leaks. Complexity is bounded by the absence of conflict-resolution/business logic.
- **Business impact:** High — every EP-02+ offline/cache-first feature and the EP-01-12 sync engine sit on this foundation; flaws degrade reliability platform-wide but do not directly authorize capability.
- **Security risk:** Medium — primarily a data-at-rest boundary concern (keep secrets out, optional at-rest encryption hook); no auth/RLS decisions here, mitigating severity versus EP-01-09/10.
- **Performance sensitivity:** Medium — LRU/TTL bounds and async I/O matter on low-end devices, but there is no hot network path or real-time constraint.
- **Data complexity:** Medium — JSON-compatible operational/queued data with typed mapping delegated to consumers; no relational joins or schema design.
- **Integration complexity:** High — must expose a stable `StorageEngine` seam consumed exactly by EP-01-08 (`EntityLocalDataSource`) and EP-01-12 (action queue), and respect the EP-01-10 secret boundary, without coupling them to the concrete driver.

High reasoning matches the approved EP-01 matrix (EP-01-11 = High) and the foundational-yet-bounded nature of the task.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Specifically, the lead's confirmation is requested on the **Approval-Required Decisions** (§15 follow-up): **D1** (local storage technology selection — Hive recommended; SQLite/drift alternative; Isar excluded for Web) and **R1** (cached-data sensitivity classification for the default `entity_cache` box).

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-11-Local Storage & Cache Management System.md` (matching the established task-plan format; a separate `the EP-01-11-Definition-of-Done.md` will be produced at completion per established practice). Implementation will begin only after a separate implementation approval. No production code is written during planning.
