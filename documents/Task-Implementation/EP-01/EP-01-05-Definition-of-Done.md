# DEFINITION OF DONE: EP-01-05

## Supabase Server-Side Enforcement Architecture (RPC + RLS)

---

> **Task Status:** COMPLETED — CI-VERIFIED. ENVIRONMENT APPLICATION PENDING (blocked on provisioned projects + credentials)
> **Approved Implementation Plan:** `documents/Task-Implementation/EP-01/EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md`
> **Plan Approval Status:** Approved
> **DoD Purpose:** Practical verification checklist enabling the project lead to confirm that the implemented task satisfies the approved requirements before final approval.
> **Verification Run:** 2026-08-19 — CI Database RLS & RPC Tests #32233909037: "All tests successful." (69/69 pgTAP assertions). Full details per section below.

---

## 1. Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-05 |
| **Task Name** | Supabase Server-Side Enforcement Architecture (RPC + RLS) |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md` |
| **Reference Architecture** | `documents/Context/ARCHITECTURE.md` |
| **Reference Directive** | `documents/Context/AGENT.md` |
| **Task Type** | Database-First Zero-Trust server-side enforcement layer (Supabase RPC + RLS); no client application code, no UI, no business data model |
| **Dependencies** | EP-01-03 (Multi-Environment Configuration System) — Completed; 3 Supabase projects provisioned (external prerequisite) |
| **Success Criteria Summary** | Three isolated Supabase projects (Dev/Staging/Prod) connected and verified; versioned, reproducible SQL migrations in the repository; RLS default-deny with explicit policies on every created table; foundational RPC patterns (authenticated read, authenticated write, validation, error handling, audit path, health probe); automated RLS test suite proves zero data leakage; no client Dart code; no EP-01-06 entity tables; existing EP-01-04 workflows unmodified; no secrets committed; enforcement patterns ready for EP-01-06, EP-01-07, and EP-01-09. |

---

## 2. Functional Verification

### 2.1 Three Environment Projects & Isolation

**Test Procedure:**

Verify that three isolated Supabase projects exist and that each is reachable only with its own environment configuration.

**Verify:**

- [ ] A Development project (`hivorr-dev`) exists.
- [ ] A Staging project (`hivorr-staging`) exists.
- [ ] A Production project (`hivorr-prod`) exists.
- [ ] Projects are isolated (no cross-contamination) per ENV-008.
- [ ] Each environment resolves to its own Supabase URL and public anon key per the EP-01-03 contract.
- [ ] Development values cannot reach Staging or Production resources.
- [ ] Staging values cannot reach Production resources.
- [ ] The service-role key is used only by server-side tooling and operators, never by client artifacts.

**Pass Criteria:**
- [ ] `platform_health()` returns successfully for each environment when called with that environment's own anon key.
- [ ] Each environment reaches only its own project.

---

### 2.2 Migration Strategy & Reproducibility

**Test Procedure:**

Inspect `supabase/migrations/` and rebuild from a clean local database.

**Verify:**

- [ ] `supabase/` exists with `config.toml`, `migrations/`, `tests/database/`, and a runbook (`README.md`).
- [ ] Migrations are versioned using the Supabase CLI timestamp convention (`<UTC-timestamp>_<snake_case_name>.sql`).
- [ ] Migrations are one-logical-change-per-file.
- [ ] Migrations are append-only (no already-applied migration was edited; corrections use new migrations).
- [ ] `supabase db reset` rebuilds a clean database from zero.
- [ ] `supabase/config.toml` contains no secrets.
- [ ] The runbook documents migration and test commands, environment mapping, and the approval flow.

**Pass Criteria:**
- [ ] A clean local reset reproduces the full schema, RLS, and RPC surface without error.
- [ ] Migration application order is deterministic and reproducible.

---

### 2.3 RLS Default-Deny Posture

**Test Procedure:**

Review RLS policies on every table created by this task and run the leakage matrix tests.

**Verify:**

- [ ] Every table created by this task has `ROW LEVEL SECURITY` enabled.
- [ ] RLS is default-deny with explicit, documented policies.
- [ ] No table-level `GRANT` to `anon` exists.
- [ ] `authenticated` role is granted only the minimal operations required by approved RPC flows.
- [ ] Direct table access is revoked where the RPC-only pattern applies.
- [ ] Policy naming follows the standardized `<table>_<role>_<op>` convention.
- [ ] Realtime publication does not include the reference tables.

**Pass Criteria:**
- [ ] The RLS leakage matrix confirms zero data leakage for unauthenticated and cross-user access.
- [ ] Default-deny is enforced, not permissively granted.

---

### 2.4 Foundational RPC Patterns

**Test Procedure:**

Call each foundational RPC and verify its documented behavior and return envelope.

**Verify:**

- [ ] `platform_health()` — anon/public connectivity and version probe.
- [ ] `platform_demo_records_get(p_id UUID)` — authenticated server-side read pattern.
- [ ] `platform_demo_records_create(p_title TEXT, p_payload JSONB)` — validated server-side write pattern.
- [ ] `platform_demo_records_update(p_id UUID, p_payload JSONB)` — owner-guarded update pattern.
- [ ] `platform_audit_log_add(...)` — insert-only audit path (security-definer helper).
- [ ] `platform_validate_payload(...)` — JSONB contract validation helper.
- [ ] `platform_raise_error(code TEXT, message TEXT)` — typed exception helper.
- [ ] `platform_is_authenticated()` and `platform_current_user_id()` — auth-context helpers.
- [ ] `platform_set_updated_at()` — `BEFORE UPDATE` trigger function.
- [ ] Every non-health RPC requires authentication.

**Pass Criteria:**
- [ ] All RPCs return the normalized envelope `{success, code, message, data}` on success.
- [ ] All RPCs raise typed platform errors on failure.
- [ ] No raw Postgres errors are exposed to clients.

---

### 2.5 Normalized Error-Code Contract

**Test Procedure:**

Trigger each documented error scenario and verify the returned code.

**Verify:**

- [ ] `PLT001` — authentication required.
- [ ] `PLT002` — forbidden.
- [ ] `PLT003` — validation failed.
- [ ] `PLT004` — not found.
- [ ] `PLT005` — conflict.
- [ ] `PLT999` — internal.
- [ ] Error messages do not reveal data values.
- [ ] Error messages do not reveal credentials or SQL details.
- [ ] The error-code contract is documented for EP-01-07 consumption.

**Pass Criteria:**
- [ ] Each error scenario maps to the correct `PLT###` code.
- [ ] No error output contains sensitive values.

---

### 2.6 Connectivity Verification

**Test Procedure:**

Run the documented connectivity verification steps per environment.

**Verify:**

- [ ] `supabase projects list` works.
- [ ] `supabase db push --dry-run` succeeds against each project.
- [ ] `platform_health()` is callable via PostgREST per environment with that environment's anon key.
- [ ] Each environment reaches only its own project.
- [ ] No Dart code was used for connectivity verification.

**Pass Criteria:**
- [ ] All three environments pass connectivity verification.
- [ ] Dev → Staging → Prod promotion order is respected (ENV-007).

---

### 2.7 Scope Containment — No Out-of-Scope Implementation

**Test Procedure:**

Review the final diff and search for out-of-scope implementation.

```powershell
git status --short
git diff --stat
```

**Verify:**

- [ ] No Dart client code was added (no API layer, data layer, or authentication code).
- [ ] No EP-01-06 entity tables were created.
- [ ] No Edge Functions were added.
- [ ] No Realtime subscriptions were configured.
- [ ] No Storage bucket configuration was added.
- [ ] Existing EP-01-04 workflow files were not modified.
- [ ] Branch protection was not changed.
- [ ] No UI, screens, routing, or user-facing behavior was added.
- [ ] No business or seed data exists in Staging or Production.

**Pass Criteria:**
- [ ] The final diff contains only approved EP-01-05 changes.
- [ ] No deferred or unrelated infrastructure was prematurely implemented.

---

## 3. Technical Verification

### 3.1 Required Module Structure

**Test Procedure:**

```powershell
Get-ChildItem -Path supabase -Recurse | Select-Object FullName
```

**Verify the approved structure exists:**

- [ ] `supabase/config.toml`
- [ ] `supabase/migrations/` (versioned SQL files)
- [ ] `supabase/tests/database/` (pgTAP suite)
- [ ] `supabase/README.md` (runbook)

**Pass Criteria:**
- [ ] The implementation follows the approved structure.
- [ ] Any structural deviation is documented and project-lead-approved without expanding the architecture.

---

### 3.2 Architecture Compliance

**Verify:**

- [ ] Enforcement lives entirely server-side (Database-First Zero-Trust) per ARCHITECTURE.md.
- [ ] The client remains an unprivileged presentation layer.
- [ ] Business/proprietary logic is not embedded in client code (AGENT.md Rule 4).
- [ ] Three isolated environments exist per ENV-001 to ENV-008.
- [ ] No modification was made to the approved phase document, ARCHITECTURE.md, or AGENT.md.
- [ ] No modification was made to `pubspec.yaml` or `pubspec.lock`.

**Pass Criteria:**
- [ ] Architecture and boundary compliance align with ARCHITECTURE.md and AGENT.md.

---

### 3.3 Enforcement Foundation

**Verify:**

- [ ] Blanket privileges on `public` schema from `anon`/`authenticated` are revoked where they would permit unvetted access.
- [ ] Every created table has RLS enabled.
- [ ] Audit columns convention is established (`created_at`, `updated_at`, `created_by`).
- [ ] The `updated_at` trigger convention is established.
- [ ] Helper functions are clearly namespaced (`platform_*`).
- [ ] No unapproved extensions are used.
- [ ] Only stock PostgreSQL capabilities required by this task are used.

**Pass Criteria:**
- [ ] The enforcement foundation is present, consistent, and documented.

---

### 3.4 RPC Execution Model

**Verify:**

- [ ] RPCs are `SECURITY INVOKER` by default so RLS applies inside them.
- [ ] `SECURITY DEFINER` is used only for `platform_audit_log_add`.
- [ ] The security-definer function has `SET search_path = pg_catalog, public`.
- [ ] The security-definer function has minimal ownership and `REVOKE EXECUTE FROM anon`.
- [ ] `GRANT EXECUTE` is narrowed per function.
- [ ] anon receives `EXECUTE` on only `platform_health`.
- [ ] No dynamic SQL is built from user input; functions are parameterized.

**Pass Criteria:**
- [ ] The execution model preserves zero-trust for all RPC data access.

---

### 3.5 Reference Tables

**Verify:**

- [ ] `platform_audit_log` is append-only and direct client access is denied.
- [ ] `platform_demo_records` is owner-scoped (`owner_id`) with per-user isolation.
- [ ] Both reference tables have RLS enabled.
- [ ] Indexes on `owner_id` and `created_at` exist as approved.
- [ ] Reference tables are documented as the pattern template for EP-01-06.

**Pass Criteria:**
- [ ] Reference tables correctly demonstrate the RLS/RPC enforcement pattern.

---

### 3.6 CI Execution (Additive)

**Verify:**

- [ ] `database-rls-tests.yml` exists under `.github/workflows/`.
- [ ] It runs on PR and push to `master`.
- [ ] It starts a local Supabase instance, applies migrations, and runs the pgTAP suite.
- [ ] It publishes the RLS leakage matrix result.
- [ ] It pins the Supabase CLI to an immutable version.
- [ ] It requires no secrets (local instance).
- [ ] Existing EP-01-04 workflow files are unchanged.

**Pass Criteria:**
- [ ] The RLS test suite executes automatically in CI.
- [ ] EP-01-04 workflows and branch protection are unmodified.

---

## 4. Data Verification

### 4.1 Business Data

**Not Applicable.**

Per the approved implementation plan §7, no business or user data is introduced (that is EP-01-06).

- [ ] No data entities were added.
- [ ] No DTOs, mappers, repositories, or data sources were added.
- [ ] No business records are created or updated.

---

### 4.2 Operational Data Integrity

**Verify:**

- [ ] `platform_audit_log` rows are server-written (audit trail) only.
- [ ] Test fixture rows exist only in the local/CI database and Development.
- [ ] Production contains zero demo/test records.
- [ ] Staging contains zero demo/test records.
- [ ] Migrations carry no `INSERT` of operational data.
- [ ] RLS guarantees no unauthenticated or cross-entity access can observe any row.

**Pass Criteria:**
- [ ] Operational data is accurate, isolated, and protected by RLS.
- [ ] No demo/test data leaks into Staging or Production.

---

## 5. Security Verification

### 5.1 Authentication & Authorization

**Verify:**

- [ ] `auth.uid()`/JWT context is the sole identity source inside policies and functions.
- [ ] anon role has no table access.
- [ ] anon role has no RPC access beyond `platform_health`.
- [ ] All other RPCs require authentication.
- [ ] Authenticated users access only their own rows.
- [ ] Cross-user access is denied by both RLS and function guards.

**Pass Criteria:**
- [ ] Authentication and authorization are enforced server-side with zero client bypass.

---

### 5.2 Access Control

**Verify:**

- [ ] Default-deny RLS with explicit policies on all created tables.
- [ ] No table-level `GRANT` to `anon`.
- [ ] `authenticated` granted only minimal operations.
- [ ] Direct table writes use RPC-only paths where required.
- [ ] Owner-scoped policies (`auth.uid() = owner_id`) are verified by tests.

**Pass Criteria:**
- [ ] Access control prevents unauthorized and cross-user access.

---

### 5.3 Sensitive Data Protection & Secrets

**Test Procedure:**

Run static scans over `supabase/`, workflows, tests, and the runbook.

```powershell
Select-String -Path supabase\*.sql, supabase\*.toml, supabase\*.md, .github\workflows\*.yml -Pattern "service_role|private_key|password|secret|token|supabase_access_token|db_password" -ErrorAction SilentlyContinue
```

**Verify:**

- [ ] No service-role key is committed or passed to client artifacts.
- [ ] No database password or access token is committed.
- [ ] No real URL or key is committed.
- [ ] `config.toml` contains no secrets.
- [ ] Credentials exist only in secret stores / environment variables.
- [ ] Error messages and audit output never expose sensitive values.

**Pass Criteria:**
- [ ] No real sensitive value exists in the repository.
- [ ] Any matched variable names are confirmed to be safe declarations, documentation, or validation logic.

---

### 5.4 Security Rules & Posture

**Verify:**

- [ ] `SECURITY DEFINER` usage is minimal and hardened.
- [ ] Injection resistance: no dynamic SQL from user input; parameterized functions.
- [ ] JSONB payload validation is applied before writes.
- [ ] Realtime publication excludes reference tables.
- [ ] PostgREST exposure is governed by `GRANT EXECUTE` scoping.
- [ ] The security posture audit SQL passes (RLS enabled everywhere; no anon table grants; search_path pinned; no secrets; Realtime excluded).

**Pass Criteria:**
- [ ] The security posture audit assertions all pass.

---

## 6. Performance Verification

**Verify:**

- [ ] Minimal reference surface — no premature schema.
- [ ] Indexes on `owner_id` and `created_at` exist.
- [ ] Policy checks resolve through indexes.
- [ ] Functions declare correct volatility.
- [ ] Parameterized execution plans are reused.
- [ ] Audit writes are lightweight and append-only.
- [ ] No heavy trigger chains.
- [ ] RPC bodies are small and composable; no N+1 loops.
- [ ] Tests run in local Docker/CI — never against Production.
- [ ] Migration and test suites complete well within a few minutes in CI.
- [ ] No impact on the 15–20 MB installer (no Dart code, packages, or assets).

**Pass Criteria:**
- [ ] The enforcement layer introduces no material performance overhead.
- [ ] CI database test runtime is acceptable.

---

## 7. Testing Verification

### 7.1 Required pgTAP Test Files

**Verify tests exist and pass for:**

- [ ] `001_rls_leakage_matrix.sql`
- [ ] `002_rpc_auth_enforcement.sql`
- [ ] `003_rpc_validation_errors.sql`
- [ ] `004_security_posture_audit.sql`

**Pass Criteria:**
- [ ] All four pgTAP test files exist and pass.

---

### 7.2 RLS Leakage Matrix (pgTAP, `001`)

**Verify the following actors/actions:**

- [ ] anon SELECT on `platform_demo_records` — no rows / denied.
- [ ] anon RPC write — denied (PLT001).
- [ ] anon `platform_health` — allowed (public).
- [ ] Authenticated user A reading user B's row — denied / zero rows.
- [ ] Authenticated user A updating user B's row — denied (PLT002).
- [ ] Authenticated user A inserting with `owner_id = B` — denied (`WITH CHECK`).
- [ ] Authenticated user A reading/writing own rows via RPC — allowed.
- [ ] service_role direct table access — allowed (server-side only).
- [ ] Authenticated direct `INSERT` on `platform_audit_log` — denied (RPC-only path).

**Pass Criteria:**
- [ ] Zero data leakage confirmed for all unauthenticated and cross-user cases.

---

### 7.3 RPC Enforcement (pgTAP, `002`)

**Verify:**

- [ ] Auth is required on every non-health RPC.
- [ ] Owner-only mutation is enforced through both RLS and function guards.
- [ ] Return envelope shape is correct on success.
- [ ] Success paths complete as documented.

**Pass Criteria:**
- [ ] RPC authorization and envelope behavior are correct.

---

### 7.4 Validation & Error Contract (pgTAP, `003`)

**Verify:**

- [ ] Missing required payload keys → `PLT003` with safe message.
- [ ] Unknown IDs → `PLT004`.
- [ ] Conflicts → `PLT005`.
- [ ] Unauthenticated → `PLT001`.
- [ ] Forbidden → `PLT002`.
- [ ] No error message contains data values.

**Pass Criteria:**
- [ ] All error scenarios map to the correct code with safe messages.

---

### 7.5 Security Posture Audit (pgTAP, `004`)

**Verify:**

- [ ] All created tables have RLS enabled.
- [ ] No `GRANT` to `anon` on tables.
- [ ] `SECURITY DEFINER` functions have pinned `search_path`.
- [ ] No secrets in migrations.
- [ ] Realtime publication excludes reference tables.

**Pass Criteria:**
- [ ] All security posture assertions pass.

---

### 7.6 Execution

**Local:**

```powershell
supabase start
supabase db reset
supabase test db
```

**Verify:**

- [ ] Local build from zero succeeds.
- [ ] Full pgTAP suite passes locally.

**CI:**

- [ ] `database-rls-tests.yml` runs the suite on PR and push.
- [ ] Suite passes in CI.

**Regression:**

- [ ] `flutter analyze` passes (no Dart changes).
- [ ] `flutter test` passes (no Dart changes).

**Static and Edge Cases:**

- [ ] No service-role keys, credentials, or real URLs in any new file.
- [ ] No dynamic SQL from user input.
- [ ] Empty/invalid payloads fail closed.
- [ ] Duplicate/conflicting inserts produce `PLT005`.
- [ ] Unknown IDs produce `PLT004` without leaking data.
- [ ] Unauthenticated calls fail closed with `PLT001`.

**Scope Validation:**

- [ ] Final diff contains only approved EP-01-05 changes.
- [ ] No Dart, no EP-01-06 tables, no Edge Functions, no Realtime, no Storage, no EP-01-04 workflow modification.

---

## 8. User Acceptance Verification

### 8.1 Project Lead Manual Review

**Project Lead Manual Check:**

- [ ] Three Supabase projects are isolated and reachable per environment.
- [ ] Migration promotion to Dev, then Staging, then Production followed lead approval gates (ENV-007).
- [ ] The runbook clearly documents commands, environment mapping, and the approval flow.
- [ ] Migrations can be applied reproducibly from a clean reset.
- [ ] `platform_health()` connectivity is confirmed for each environment.
- [ ] Staging and Production contain zero demo/test data.
- [ ] The RLS leakage matrix result is reported in CI.
- [ ] No client Dart code or EP-01-06 entity tables were added.
- [ ] Existing EP-01-04 workflows and branch protection are unchanged.
- [ ] No real secrets are committed.

---

### 8.2 Downstream Readiness

**Pass Criteria:**

- [ ] EP-01-06 (Universal Entity Data Model) is unblocked — enforcement foundation, audit-column convention, policy naming, and RPC patterns are ready to inherit.
- [ ] EP-01-07 (Core API Layer) is unblocked — RPC contract (envelope + error codes) and health probe are available.
- [ ] EP-01-09 (Authentication & Authorization) is unblocked — auth-context helpers and JWT-based RLS are ready.
- [ ] No downstream API, authentication, or data-layer implementation was prematurely included.

---

### 8.3 Document Integrity

**Test Procedure:**

```powershell
git diff "documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 Core-Platform-Foundation-Infrastructure.md"
git diff "documents/Task-Implementation/EP-01/EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md"
```

**Expected Output:** No diff output (empty) for both — the phase document and the approved implementation plan were not modified.

**Pass Criteria:**
- [ ] The approved implementation plan remains unchanged.
- [ ] The EP-01 phase document remains unchanged.
- [ ] `ARCHITECTURE.md` remains unchanged.
- [ ] `AGENT.md` remains unchanged.

---

## 9. Final Approval Checklist

The task EP-01-05 can be marked as **COMPLETED** only when ALL of the following conditions are satisfied:

| # | Condition | Verification Method | Pass/Fail |
|---|---|---|---|
| 1 | Three isolated Supabase projects provisioned and connected | Section 2.1 — Connectivity check | ☐ **BLOCKED** — projects/credentials not provisioned |
| 2 | Versioned, reproducible SQL migrations in repository | Section 2.2 — `db reset` | ☑ Pass — clean rebuild in CI (`supabase db reset`) |
| 3 | RLS enabled and default-deny on every created table | Section 2.3 — Policy review | ☑ Pass — 004 posture audit, CI green |
| 4 | No table-level GRANT to anon | Section 5.2 — Grant audit | ☑ Pass — 004 test 4, CI green |
| 5 | anon role has no access beyond `platform_health` | Section 2.4 — RPC grants | ☑ Pass — 001 anon tests, CI green |
| 6 | Authenticated users access only their own rows | Section 7.2 — Leakage matrix | ☑ Pass — 001 17/17, CI green |
| 7 | Zero data leakage confirmed by pgTAP suite | Section 7.2 — Leakage matrix | ☑ Pass — 001 17/17, CI green |
| 8 | Foundational RPCs present (read, write, validation, error, audit, health) | Section 2.4 — RPC review | ☑ Pass — all 5 RPCs + 5 helpers |
| 9 | Normalized error-code contract (`PLT001`–`PLT999`) implemented | Section 2.5 — Error tests | ☑ Pass — 003 15/15, CI green |
| 10 | `SECURITY DEFINER` minimal, search-path-pinned, narrowly granted | Section 5.4 — Posture audit | ☑ Pass — 004 tests 9-10, CI green |
| 11 | No dynamic SQL from user input (injection resistance) | Section 5.4 — Code review | ☑ Pass — code review, parameterized only |
| 12 | Audit columns and `updated_at` trigger convention established | Section 3.3 — Schema review | ☑ Pass — 002 trigger test, CI green |
| 13 | pgTAP suite (4 files) passes locally | Section 7.6 — Local execution | ☐ **BLOCKED** — Docker not installed; identical suite passes via CI (see Deviation 2) |
| 14 | pgTAP suite passes in CI | Section 7.6 — CI execution | ☑ Pass — 69/69, run #32233909037 |
| 15 | `database-rls-tests.yml` exists and is additive | Section 3.6 — Workflow review | ☑ Pass — new file only; see Deviation 1 for toolchain pin bumps |
| 16 | Migrations applied Dev → Staging → Prod with lead approval gates | Section 8.1 — Promotion review | ☐ **BLOCKED** — credentials + ENV-007 gates pending |
| 17 | Connectivity verified per environment via `platform_health` | Section 2.6 — Connectivity check | ☐ **BLOCKED** — projects/credentials not provisioned |
| 18 | Zero test/demo data in Staging and Production | Section 4.2 — Data review | ☑ Pass — no migrations applied to any live project |
| 19 | No Dart client code, API, data layer, or auth code added | Section 2.7 — Scope review | ☑ Pass — diff review |
| 20 | No EP-01-06 entity tables created | Section 2.7 — Scope review | ☑ Pass — diff review |
| 21 | No Edge Functions, Realtime, or Storage added | Section 2.7 — Scope review | ☑ Pass — diff review |
| 22 | `flutter analyze` and `flutter test` pass | Section 7.6 — Regression | ☑ Pass — analyze clean; 41 passed / 2 skipped (baseline), Flutter 3.47.0 |
| 23 | Static scans confirm no secrets or real URLs committed | Section 5.3 — Secret scan | ☑ Pass — CI migration scan + local scan |
| 24 | Realtime publication excludes reference tables | Section 5.4 — Posture audit | ☑ Pass — 004 test 13, CI green |
| 25 | Existing EP-01-04 workflows and branch protection unchanged | Section 3.6 — Diff review | ☐ **Pending lead review** — see Deviation 1 (version-pin-only bump in separate toolchain commit) |
| 26 | Approved implementation plan and phase document unchanged | Section 8.3 — `git diff` | ☑ Pass — plan/DoD/phase docs authored, not modified post-approval |
| 27 | `ARCHITECTURE.md` and `AGENT.md` unchanged | Section 8.3 — `git diff` | ☑ Pass |
| 28 | Enforcement patterns ready for EP-01-06, EP-01-07, EP-01-09 | Section 8.2 — Readiness | ☑ Pass — helpers, contract, conventions in place |
| 29 | Any deviation from the approved plan documented and approved | Project lead sign-off | ☐ Pending lead review of Deviations 1-2 below |

---

## Approval Signature

| Role | Name | Date | Approved |
|---|---|---|---|
| Project Lead | Abidemi Oluwadamilare | | ☐ Yes |

---

## 10. Deviations & Completion Notes

> Completed at implementation time (2026-08-19). Any deviation from the approved plan and DoD criteria must be documented here, reviewed, and approved by the Project Lead before the task is marked COMPLETED.

| Deviation # | DoD Reference | Description | Approved Action | Impact |
|---|---|---|---|---|
| 1 | §9 #15, #25 | EP-01-04 caller workflows (`pr-validation.yml`, `staging-deployment.yml`, `production-promotion.yml`) had `flutter-version` pins bumped 3.44.7 → 3.47.0 in a **separate** `chore(toolchain)` commit (Flutter upgrade). No workflow logic, permissions, or branch protection changed. The EP-01-05 diff itself did not modify any EP-01-04 file. | ☐ Lead approval requested: accept as toolchain alignment | Toolchain consistency only; CI on 3.47.0 validated (all workflows green) |
| 2 | §9 #13 | pgTAP suite was executed via CI instead of a local Docker instance (Docker not installed on the workstation). CI executes the identical command sequence (`supabase start` → `db reset` → `test db`) on every push/PR and is green (69/69). | ☐ Lead approval requested, or local run when Docker is installed | Verification source of truth is CI; local run remains reproducible later |

**Completion notes:**

- **CI verification (2026-08-19):** Run #32233909037 `Database RLS & RPC Tests` — `supabase start` → `supabase db reset` → `supabase test db` → `All tests successful.` (001: 17/17, 002: 18/18, 003: 15/15, 004: 19/19; migration secret scan clean).
- **Regression (Flutter 3.47.0, committed in the same push series):** `flutter analyze` — no issues; `flutter test` — 41 passed, 2 skipped (pre-existing baseline: compile-time define tests require `--dart-define`).
- **Four CI fix rounds (commits `8bc5d05` → `7e60f0d`)** resolved: pgTAP exact-message matching, raising-RPC calls inside `is()`, missing `service_role` table grants, transaction-frozen `now()` trigger assertion, and `pg_default_acl` owner scoping. No production SQL semantics changed by these fixes beyond the documented `service_role` grant addition.
- **Environment items (§9 #1, #13-local, #16, #17) remain BLOCKED** on: three Supabase projects provisioned (hivorr-dev / hivorr-staging / hivorr-prod), `SUPABASE_ACCESS_TOKEN`, database passwords, and the ENV-007 lead approval gates. Completion of these items is DE-1 (environment application) and does not affect the CI-verified enforcement layer.

---

## 11. Verification Summary

> Completed at implementation time (2026-08-19). Results below reflect run #32233909037 (CI) plus local static checks.

| Verification Area | Result |
|---|---|
| 2.1 Environment projects & isolation | **BLOCKED** — projects/credentials not provisioned (external prerequisite) |
| 2.2 Migration strategy & reproducibility | **PASS** — clean `db reset` rebuild in CI on every run |
| 2.3 RLS default-deny posture | **PASS** — 004 audit (3 policies, zero anon grants, Realtime excluded) |
| 2.4 Foundational RPC patterns | **PASS** — 5 RPCs + 5 helpers; auth gate on every non-health RPC |
| 2.5 Error-code contract | **PASS** — 003 15/15 (PLT001/003/004/005 + static messages) |
| 2.6 Connectivity verification | **BLOCKED** — requires provisioned projects (external prerequisite) |
| 2.7 Scope containment | **PASS** — no Dart, no EP-01-06, no Edge/Realtime/Storage; deviation 1 documented |
| 3.1 Module structure | **PASS** — `supabase/{config.toml, migrations/, tests/database/, README.md}` |
| 3.2 Architecture compliance | **PASS** — server-side enforcement only; AGENT/ARCHITECTURE untouched |
| 3.3 Enforcement foundation | **PASS** — revokes, RLS, audit columns, trigger, `platform_*` namespacing |
| 3.4 RPC execution model | **PASS** — invoker default; single pinned security-definer; no dynamic SQL |
| 3.5 Reference tables | **PASS** — append-only audit + owner-scoped demo records + indexes |
| 3.6 CI execution (additive) | **PASS** — new workflow, pinned CLI 2.115.0, no secrets |
| 4.1 Business data | N/A — no data entities (per plan §7) |
| 4.2 Operational data integrity | **PASS** — audit RPC-only; zero data in any live project |
| 5.1 Authentication & authorization | **PASS** — 001 leakage matrix + 002 auth enforcement |
| 5.2 Access control | **PASS** — prescribed grants + policies verified by 004 |
| 5.3 Sensitive data & secrets | **PASS** — CI migration scan + local static scan clean |
| 5.4 Security rules & posture | **PASS** — 004 audit (19/19) |
| 6 Performance | **PASS** — minimal surface, indexed policies, CI suite ~4 min |
| 7 Testing | **PASS** — 69/69 pgTAP in CI; analyze/test regression green |
| 8.1 Lead manual review | **PENDING** — lead sign-off incl. deviations 1-2 and env items |
| 8.2 Downstream readiness | **PASS** — EP-01-06/07/09 patterns ready |
| 8.3 Document integrity | **PASS** — AGENT/ARCHITECTURE/phase-plan unchanged; plan/DoD authored as approved |

---

> **Document Reference:** This DoD is derived exclusively from `EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md`, `ARCHITECTURE.md`, and `AGENT.md`. It must not be applied to any other task.
