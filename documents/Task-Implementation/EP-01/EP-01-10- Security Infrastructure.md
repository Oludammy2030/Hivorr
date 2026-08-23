# TASK IMPLEMENTATION PLAN: EP-01-10

## Security Infrastructure

| Field | Value |
|---|---|
| Task ID | EP-01-10 |
| Task Name | Security Infrastructure |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Not Started (plan for approval) |
| Dependencies | EP-01-07 (Core API Layer — completed), EP-01-09 (Authentication & Authorization Framework — **Not Started**; consumed as an integration contract only, not modified). Transitively relies on EP-01-03 (EnvironmentConfig) and EP-01-05/06 (server envelope). |
| Priority | High |
| Planning Reasoning | Extremely High (approved EP-01 matrix) |
| Coding Reasoning | Extremely High (approved EP-01 matrix) |

> **Sequencing flag (see §15):** EP-01-09 is currently *Not Started*. This plan treats EP-01-09 only as a **downstream consumer** of the hardening utilities built here. EP-01-10 must not modify EP-01-09. Recommended order: implement EP-01-09 first (or in parallel) so the secure-token-store adapter can be wired at auth bootstrap; EP-01-10 itself remains independently deliverable against the EP-01-07 `AccessTokenProvider` seam.

---

## 1. Task Objective

Build the client-side **Security Infrastructure** across two directories defined in ARCHITECTURE.md:

- `lib/core/security/` — **encryption utilities**, **SSL pinning**, and **token rotation**.
- `lib/core/storage/` — **secure storage wrappers** over `flutter_secure_storage` (already pinned in EP-01-02) with typed accessors.

Deliverables:

- **AES-GCM encryption utilities** for at-rest protection of sensitive blobs (defense-in-depth on platforms where `flutter_secure_storage` is not OS-encrypted — notably Web/localStorage).
- **SSL certificate pinning** wired into the EP-01-07 Dio channel via a security adapter/interceptor (registry hook from EP-01-07 §5.7), using environment-sourced SPKI hashes. Graceful no-op on Web (browser-mediated TLS).
- **Token rotation helper** that consolidates proactive/expiry-driven refresh (reusing the EP-01-07 `AccessTokenProvider.refresh()` seam) and persists rotated tokens through the secure store.
- **Secure storage wrapper** (`SecureStorage`) with a platform-agnostic abstract interface, typed accessors (string/bool/int/json), and a high-level `SecureTokenStore` for access/refresh tokens.
- A **`LocalStorage` adapter** (implementing `supabase_flutter`'s `LocalStorage` interface backed by `SecureStorage`) as the integration point EP-01-09 will adopt to harden session persistence — defined here, **wired by EP-01-09**, not by this task.

---

## 2. Business Problem Being Solved

Without a security infrastructure layer:

- Sensitive client-held material (refresh tokens, device-bound secrets, cached PII fragments) is stored only via default OS storage; on Web `flutter_secure_storage` degrades to plaintext `localStorage`, exposing tokens to XSS/local extraction. AES-at-rest closes that gap.
- The app is vulnerable to **MITM / forged-certificate** interception on compromised networks (a real risk in the Nigeria market), silently defeating HTTPS confidentiality. SSL pinning binds the client to Hivorr's genuine certificates.
- Token refresh/persistence is scattered and inconsistent; without a rotation helper, expired sessions cause silent logout loops on unreliable connections (AGENT.md zero-trust + EP-01-07 retry contract).
- Future systems (finance, KYC, verification) would each hand-roll secure storage and crypto, fracturing the zero-trust client discipline and risking secret leakage.

This is the **client-side hardening foundation** that turns the unprivileged-presentation-layer principle (AGENT.md Rule 4) into enforced practice.

---

## 3. Scope

### In Scope
- `lib/core/security/` module (§5.2): `security_config.dart`, `crypto/aes_cipher.dart`, `crypto/key_derivation.dart`, `pinning/certificate_pinner.dart`, `pinning/ssl_security_adapter.dart`, `token/token_rotation_helper.dart`, `security.dart` barrel.
- `lib/core/storage/` module (§5.2): `secure_storage_config.dart`, `secure_storage.dart` (abstract + `flutter_secure_storage` impl), `secure_token_store.dart`, `supabase_secure_local_storage.dart` (LocalStorage adapter impl), `storage.dart` barrel.
- Integration with EP-01-07: SSL adapter inserted into the Dio channel via the established interceptor/adapter **registry** (no modification of EP-01-07 core logic); token rotation reuses `AccessTokenProvider.refresh()`.
- Environment-driven config sourced **only** from `EnvironmentConfig` (EP-01-03): pinning-enabled flag, SPKI SHA-256 hashes per env, key-derivation params. No `String.fromEnvironment`.
- AES round-trip utilities + a `SecureTokenStore` providing typed `writeToken/readToken/clear` for access + refresh tokens.
- The `supabase_secure_local_storage` adapter implemented but **not wired** into `Supabase.initialize` (wiring belongs to EP-01-09 boot).
- Unit tests (mocked `flutter_secure_storage`, mock `AccessTokenProvider`, fake `SecureStorage`): AES round-trip, pinning accept/reject, rotation+persist, typed store accessors.
- `flutter analyze` (strict lints) + `flutter test` must pass.

### Out of Scope
- Building the auth framework, session ownership, route guarding — EP-01-09 (this task only supplies the storage/rotation tools it will consume).
- RLS policies, RPC, migrations, Edge Functions — EP-01-05/06 (consumed only).
- Data-access repositories/DTOs — EP-01-08.
- Local storage drivers (SQLite/Hive/Isar) / cache / offline sync — EP-01-11, EP-01-12.
- Connectivity monitoring — EP-01-13.
- Sentry/logger concrete wiring — EP-01-14.
- App bootstrap, GoRouter, design system, localization, notifications — EP-01-15/16/17/18.
- **Wiring** the secure adapter into Supabase init (belongs to EP-01-09).
- Native platform config changes (Android network security config / iOS Info.plist pinning entries) — see §12 Risk R2; flagged for approval, not implemented here.
- Any proprietary/business/pricing/matching/escrow logic — strictly forbidden (AGENT.md Rule 4).
- Modification of the approved EP-01 phase doc, ARCHITECTURE.md, AGENT.md.

---

## 4. Out of Scope (explicit boundary reaffirmation)

No business logic, financial rules, or authorization decisions are permitted. This layer **protects secrets and transport**; it does not authorize capabilities (server RLS+RPC owns that, AGENT.md Rule 4). The `SecureTokenStore` stores opaque tokens only — it never interprets or applies them.

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer | AGENT.md Rule 4, ARCHITECTURE.md |
| Config via `EnvironmentConfig` only | EP-01-03; never `String.fromEnvironment` |
| Token injection + 401-refresh already owned by API layer | EP-01-07 `AccessTokenProvider` |
| Single Dio channel, extensible via registry | EP-01-07 §5.7 |
| No secrets in logs | EP-01-07 `ApiLogSink` redaction; mirrored here |
| Only anon key client-side | EP-01-03/07 invariant |

### 5.2 Proposed Structure

```text
lib/core/security/
├── security_config.dart                 # pinning-enabled, SPKI hashes/env, KDF params
├── crypto/
│   ├── aes_cipher.dart                  # AES-GCM encrypt/decrypt (key + IV + tag)
│   └── key_derivation.dart              # derive symmetric key (PBKDF2/Argon2 via crypto pkg)
├── pinning/
│   ├── certificate_pinner.dart          # holds expected SPKI SHA-256 per env; verify()
│   └── ssl_security_adapter.dart        # custom HttpClient/SecureContext → Dio adapter
├── token/
│   └── token_rotation_helper.dart       # refresh via AccessTokenProvider + persist to store
└── security.dart                        # barrel

lib/core/storage/
├── secure_storage_config.dart           # namespace, accessibility, web fallback flag
├── secure_storage.dart                  # abstract SecureStorage + FlutterSecureStorageImpl
├── secure_token_store.dart              # typed access/refresh token store
├── supabase_secure_local_storage.dart   # LocalStorage adapter impl (for EP-01-09 wiring)
└── storage.dart                         # barrel
```

### 5.3 Encryption Utilities (`crypto/`)

- `AesCipher`: `encrypt(plaintext, key)` → `{iv, ciphertext, tag}`; `decrypt(...)` with constant-time comparison of tag (AES-GCM). Key sourced from `KeyDerivation` (derived from a device-bound secret + optional passphrase) or from a random key persisted in `SecureStorage`. **No hardcoded key.**
- `KeyDerivation`: PBKDF2 (or `cryptography` Argon2 if package chosen) with env-provided salt/iterations from `security_config.dart`. On Web, key material still derived in-memory (no secure enclave).
- Purpose: encrypt refresh tokens / sensitive cache blobs **before** handing to `SecureStorage` (defense-in-depth, especially Web).

> **Approval decision D1:** crypto package selection — `encrypt` (simple, AES-CBC/GCM) vs `cryptography` (native AES-GCM, stronger, recommended). EP-01-10 will pin the chosen package (new addition to `pubspec.yaml`, §15 D1).

### 5.4 SSL Pinning (`pinning/`)

- `CertificatePinner`: holds expected **SPKI SHA-256** hashes per environment (from `security_config` ← `EnvironmentConfig`). `verify(certificate)` returns true only if the presented cert chain's SPKI hash matches.
- `SslSecurityAdapter`: builds a `dart:io` `HttpClient`/`SecurityContext` with `setTrustedCertificates` + `badCertificateCallback` enforcing the pin; exposed as a Dio `HttpClientAdapter` inserted into the EP-01-07 adapter registry.
- **Web constraint:** Dart `dart:io` TLS customization is unavailable on Web; the adapter detects platform and **no-ops safely** (pinning enforced by browser TLS). Documented as accepted residual risk (§12 R3).
- No extra pinning package required (native `dart:io` approach keeps deps minimal).

### 5.5 Token Rotation Helper (`token/`)

- `TokenRotationHelper`: constructor-injected `AccessTokenProvider` (EP-01-07 seam) + `SecureTokenStore`.
  - `rotateIfNeeded(sessionExpiry)`: proactive refresh when token within buffer; persists new access/refresh via store.
  - `onRefresh()` (called by EP-01-07 401 path or EP-01-09): refreshes, persists, returns new token.
- Reuses EP-01-07's existing refresh mechanism — **does not reimplement** auth refresh. Avoids refresh storms (single refresh, lock-guarded).

### 5.6 Secure Storage (`storage/`)

- `SecureStorage` (abstract): `writeString/readString/writeJson/readJson/writeBool/readBool/writeInt/readInt/delete/clear` + namespacing.
- `FlutterSecureStorageImpl`: wraps `flutter_secure_storage` (pinned EP-01-02) with `AndroidOptions` (encrypted shared prefs) + `IOSOptions` (Keychain); `WebOptions` with `initializationVector`/base64 (still plaintext — AES layer compensates).
- `SecureTokenStore`: high-level typed API for access token, refresh token, session id, device secret.
- `SupabaseSecureLocalStorage`: implements `supabase_flutter`'s `LocalStorage` (async `init/accessToken/write/remove/hasItem`) over `SecureStorage`. **Defined here; EP-01-09 passes it to `Supabase.initialize(localStorage:)` — not wired in this task.**

### 5.7 Extensibility Hooks
- `SecureStorage` abstract interface → EP-01-11/12 may back caches with the same contract.
- `SslSecurityAdapter` → inserted via EP-01-07 registry; EP-01-19 builds mock factories.
- `SupabaseSecureLocalStorage` → EP-01-09 bootstrap seam for hardened session persistence.
- `TokenRotationHelper` → consumed by EP-01-09 provider + EP-01-13 (connectivity-aware refresh) + EP-01-15 lifecycle.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| `EnvironmentConfig` (incl. `supabaseConfig`, new `securityConfig`) | `lib/config/environments/` (EP-01-03) | Source of pinning hashes, flags |
| `AccessTokenProvider` + Dio registry | `lib/core/api/` (EP-01-07) | Refresh seam + pinning insertion point |
| `crypto/*`, `pinning/*`, `token/*`, `security.dart` | `lib/core/security/` | This task |
| `secure_storage*`, `supabase_secure_local_storage`, `storage.dart` | `lib/core/storage/` | This task |
| `flutter_secure_storage` 11.0.0 | EP-01-02 (pinned) | OS-backed secure storage |
| (new) crypto package (`encrypt`/`cryptography`) | `pubspec.yaml` | AES-GCM (D1) |

No service-role key, no server logic.

---

## 7. Data Requirements

- Only **opaque secret material** is handled: access/refresh tokens, device secret, encrypted blobs. Never logs tokens, keys, or plaintext PII.
- `AesCipher` inputs/outputs are byte/string buffers held transiently; keys persisted only inside `SecureStorage` (never in `ApiException`, logs, or crash reports).
- `SecureTokenStore` stores tokens **only**; it does not read/interpret business claims.

---

## 8. Database Considerations

**Not applicable.** This is a pure client security layer. No migrations, RPC, or RLS. The `SupabaseSecureLocalStorage` adapter only changes *where* Supabase's session JSON is persisted client-side — server enforcement (EP-01-05/06) is untouched.

---

## 9. API Requirements

- **No new endpoints/RPCs.** SSL pinning only constrains the existing Dio/Supabase transport (EP-01-07). `TokenRotationHelper` calls the existing `AccessTokenProvider.refresh()` (which ultimately uses Supabase Auth refresh).
- Exposes a **client-side security contract**: pinned transport + encrypted-at-rest secrets for every future feature.

---

## 10. User Interface Requirements

**Not applicable.** No widgets/screens. Utilities are exported for EP-01-09/13/15 consumption. `main.dart`/bootstrap unchanged.

---

## 11. User Experience Considerations

Developer/operator experience only:
- One-call `TokenRotationHelper` + `SecureStorage` give every future system a vetted secret-handling pattern.
- Pinning prevents silent MITM; users are protected transparently (fail-closed: pinned mismatch → connection refused, no silent fallback).
- Rotation helper eliminates silent logout loops on unreliable networks by proactively refreshing before expiry.
- Typed `SecureStorage` accessors prevent key-collision and serialization bugs across features.
- The `SupabaseSecureLocalStorage` adapter gives EP-01-09 a drop-in hardened persistence with zero auth-logic changes.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Secret leakage in logs | Tokens/keys never logged; mirror EP-01-07 `ApiLogSink` redaction; `ApiException` never embeds secrets |
| Hardcoded cert hashes / endpoints | All pinning hashes + flags sourced exclusively from `EnvironmentConfig` (EP-01-03), never literals |
| Service-role key in client | Only anon-key client used (EP-01-03/07 invariant preserved) |
| MITM / forged certificate | `SslSecurityAdapter` enforces SPKI pin (fail-closed); Web relies on browser TLS (R3) |
| Token extraction from storage | `flutter_secure_storage` (Keychain/encrypted prefs) + AES-at-rest layer for blobs; Web mitigated by AES (no OS enclave) |
| Key material compromise | No hardcoded keys; keys derived (PBKDF2/Argon2) + persisted only in `SecureStorage` |
| Refresh storm / race | `TokenRotationHelper` lock-guarded single refresh; reuses EP-01-07 single-retry contract |
| Unauthorized env access | Client cannot switch environments at runtime (EP-01-03 invariant) |
| Business logic in client | Layer protects secrets/transport only; no role/verification authorization (AGENT.md Rule 4) |
| Native pinning drift | **R2:** Android `network_security_config.xml` / iOS pinning entries are NOT added in this task (flagged); relies on Dio adapter. Native hardening deferred to a platform task. |

**R1 (crypto package — D1):** choose `encrypt` vs `cryptography` (recommended) before implementation.
**R2 (native pinning):** Web/desktop rely on the Dio adapter; OS-native pinning config is out of scope here, flagged for a later platform task.
**R3 (Web pinning gap):** accepted residual risk — browser-mediated TLS; AES-at-rest still protects stored secrets on Web.

---

## 13. Performance Considerations

- Crypto/AES ops are low-frequency (token encrypt/decrypt at rotation/persist only); AES-GCM is cheap and runs off the UI-critical path.
- SSL pinning verification is a single SHA-256 compare per TLS handshake — negligible.
- `TokenRotationHelper` proactive refresh is event/timer-driven (near-expiry), not polling; lock-guarded to avoid duplicate work.
- `SecureStorage` access is async but infrequent (session/secret read at boot, write at rotation); no hot-path concern.
- No new heavy assets; only one new crypto package (D1) — negligible impact on the 15–20 MB installer.
- No synchronous blocking I/O in interceptors/adapters.

---

## 14. Testing Strategy

### 14.1 Unit — Encryption (`crypto/`)
- `AesCipher` round-trip: encrypt → decrypt returns original; tampered tag → decrypt fails (constant-time reject).
- `KeyDerivation`: same inputs → same key; different salt → different key; no hardcoded key path.

### 14.2 Unit — SSL Pinning (`pinning/`)
- `CertificatePinner.verify()` accepts a cert whose SPKI hash matches the env config; rejects mismatch.
- `SslSecurityAdapter` builds a Dio adapter; on non-Web it enforces the pin via `badCertificateCallback`; on Web it no-ops safely (assertion on platform branch).

### 14.3 Unit — Token Rotation (`token/`)
- `rotateIfNeeded()` calls `AccessTokenProvider.refresh()` once when within buffer; persists new tokens to `SecureTokenStore` (mocked provider + fake store).
- Concurrent calls result in a single refresh (lock guard); persistent refresh failure surfaces typed `ApiException`.

### 14.4 Unit — Secure Storage (`storage/`)
- `SecureStorage` abstract contract validated via a fake in-memory impl: typed accessors round-trip; `delete`/`clear` behave; namespacing prevents collisions.
- `SecureTokenStore` write/read/clear of access + refresh tokens.
- `SupabaseSecureLocalStorage` satisfies `supabase_flutter` `LocalStorage` interface contract (init/accessToken/write/remove/hasItem) over the fake store — no wiring into `Supabase.initialize`.

### 14.5 Project Validation
- `flutter analyze` (strict lints; no `print`; no `implicit_dynamic`).
- `flutter test` — all new unit tests pass.
- Available platform smoke build (no native changes).

### 14.6 Scope Validation
- Diff review: only `lib/core/security/` + `lib/core/storage/` + `test/unit/core/security/` + `test/unit/core/storage/` (+ `pubspec.yaml` if D1 adds a package). No bootstrap/UI/DB/auth-framework/monitoring implementation leaked. No phase-document edits.

---

## 15. Recommended Implementation Sequence

1. Inspect EP-01-03/05/06/07 deliverables; confirm `lib/core/security/` and `lib/core/storage/` contain only `.gitkeep`.
2. **Decision D1:** pin the chosen crypto package in `pubspec.yaml` (per lead approval).
3. Extend `EnvironmentConfig` (EP-01-03) with `securityConfig` (pinning-enabled, SPKI hashes per env, KDF salt/iterations) — no `String.fromEnvironment`.
4. Implement `lib/core/storage/secure_storage_config.dart` + `secure_storage.dart` (abstract + `FlutterSecureStorageImpl`) + `secure_token_store.dart`.
5. Implement `lib/core/storage/supabase_secure_local_storage.dart` (LocalStorage adapter impl; **not** wired).
6. Implement `lib/core/security/security_config.dart` + `crypto/aes_cipher.dart` + `crypto/key_derivation.dart`.
7. Implement `lib/core/security/pinning/certificate_pinner.dart` + `pinning/ssl_security_adapter.dart` (Dio adapter; Web no-op).
8. Implement `lib/core/security/token/token_rotation_helper.dart` (injected `AccessTokenProvider` + `SecureTokenStore`).
9. Implement `security.dart` + `storage.dart` barrels.
10. Add `test/unit/core/security/` + `test/unit/core/storage/` unit tests (fake store, mock provider, mock pinner).
11. Run `flutter analyze` and `flutter test`.
12. Available platform smoke builds (no native changes).
13. Review final diff for strict EP-01-10 scope containment and phase-document integrity.
14. **Stop at the approval gate** — do not wire `Supabase.initialize` (EP-01-09), build routes, or implement downstream tasks.

---

## Approval-Required Decisions (flagged for the lead)

- **D1 — Crypto package:** `encrypt` (simple) vs `cryptography` (native AES-GCM, recommended). Selected package is pinned in `pubspec.yaml` before code.
- **R2 — Native pinning:** This task implements pinning only via the Dio adapter (covers Android/iOS/desktop at the Dart TLS layer). OS-native pinning config (`network_security_config.xml`, iOS `Info.plist`) is deferred to a platform task and not added here.
- **R3 — Web pinning gap:** Accepted residual risk; browser-mediated TLS on Web. AES-at-rest still protects stored secrets on Web.

---

## 16. Expected Outcome

- A reusable **security toolkit** in `lib/core/security/` + `lib/core/storage/`: AES-GCM cipher, SPKI certificate pinner wired into the EP-01-07 Dio channel, lock-guarded token rotation reusing the EP-01-07 refresh seam, and a typed secure-storage wrapper over `flutter_secure_storage`.
- A `SupabaseSecureLocalStorage` adapter (implementing `supabase_flutter`'s `LocalStorage`) ready for EP-01-09 to harden session persistence — defined here, wired by EP-01-09.
- All secret material encrypted-at-rest and never logged; pinning fail-closed; config sourced only from `EnvironmentConfig`.
- Unit tests proving crypto, pinning, rotation, and storage behavior without a live backend.
- Clean extensibility seams for EP-01-09 (auth persistence), EP-01-11/12 (cache backing), EP-01-13 (connectivity-aware refresh), EP-01-15 (lifecycle), and EP-01-19 (mock factories).

---

## 17. Definition of Done (DoD)

**Structure & Code**
- [ ] `lib/core/security/` and `lib/core/storage/` contain the §5.2 structure; all files implemented and importing correctly.
- [ ] `AesCipher` provides AES-GCM encrypt/decrypt with constant-time tag rejection; no hardcoded key.
- [ ] `KeyDerivation` derives keys from env-provided salt/iterations; no hardcoded key path.
- [ ] `CertificatePinner` holds SPKI SHA-256 per env from `securityConfig`; `verify()` fails closed on mismatch.
- [ ] `SslSecurityAdapter` inserts into the EP-01-07 Dio adapter/registry; enforces pin on non-Web; no-ops safely on Web.
- [ ] `TokenRotationHelper` is constructor-injected with `AccessTokenProvider` + `SecureTokenStore`; reuses EP-01-07 refresh; lock-guarded single refresh; persists rotated tokens.
- [ ] `SecureStorage` abstract + `FlutterSecureStorageImpl` with typed accessors (string/bool/int/json) + namespacing.
- [ ] `SecureTokenStore` provides typed access/refresh token store.
- [ ] `SupabaseSecureLocalStorage` implements `supabase_flutter` `LocalStorage` over `SecureStorage`; **not** wired into `Supabase.initialize`.
- [ ] `security.dart` + `storage.dart` barrels export public API.
- [ ] Config (`securityConfig`) sourced only from `EnvironmentConfig`; no `String.fromEnvironment`, no hardcoded hashes/endpoints/keys.
- [ ] No service-role key, no business/pricing/matching/verification logic (AGENT.md Rule 4).
- [ ] No bootstrap/UI/migration/RPC/auth-framework/monitoring/sync code included.
- [ ] `flutter_analyze` passes cleanly (strict lints; no `print`; no `implicit_dynamic`).
- [ ] `flutter test` passes (crypto, pinning, rotation, storage unit tests).
- [ ] Available platform smoke builds pass (no native config changed).
- [ ] The approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Final diff contains only approved EP-01-10 changes (plus `pubspec.yaml` if D1 adds a package).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

- **Technical complexity:** Very high–Extremely high — designing correct AES-GCM (IV/tag handling, constant-time reject), SPKI pinning via a Dio `HttpClientAdapter` with safe Web no-op, lock-guarded token rotation that reuses (not duplicates) the EP-01-07 refresh seam, and a `supabase_flutter` `LocalStorage` adapter requires precise reasoning; mistakes leak secrets, break TLS, or cause refresh storms.
- **Business impact:** High–Critical — every EP-02+ sensitive flow (finance, KYC, verification) depends on this hardening; flaws propagate platform-wide.
- **Security risk:** Extremely high — this layer is the client-side secret/transport protection; incorrect pinning (fail-open), weak key handling, or logged tokens directly enable MITM or credential extraction (AGENT.md Rule 4).
- **Performance sensitivity:** Low-medium — crypto/rotation are low-frequency; but rotation timing and lock behavior affect reliability on unreliable Nigerian networks.
- **Data complexity:** Medium — opaque secret material must be handled without ever surfacing tokens/keys in logs, exceptions, or crash reports.
- **Integration complexity:** Extremely high — must consume EP-01-03 config contract, EP-01-07 Dio registry + `AccessTokenProvider` exactly, and expose stable seams for EP-01-09 (auth persistence), EP-01-11/12 (cache), EP-01-13 (refresh), EP-01-15 (lifecycle), and EP-01-19 (mocks) without coupling them to implementation.

Extremely High reasoning matches the approved EP-01 matrix (EP-01-10 = Extremely High) and the security-critical, foundational nature of the infrastructure.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Specifically, the lead's confirmation is requested on the **Approval-Required Decisions** (§15 follow-up): **D1** (crypto package selection — `encrypt` vs `cryptography` recommended), **R2** (native pinning deferred to a platform task), and **R3** (Web pinning gap accepted). The **sequencing flag** (EP-01-09 Not Started) is also noted: EP-01-10 is independently deliverable, but the `SupabaseSecureLocalStorage` adapter is wired by EP-01-09 at auth bootstrap.

Upon approval, the plan will be saved to `documents/Task-Implementation/EP-01/EP-01-10- Security Infrastructure.md` (matching the established task-plan format; a separate `EP-01-10-Definition-of-Done.md` will be produced at completion per established practice). Implementation will begin only after a separate implementation approval. No production code is written during planning.
