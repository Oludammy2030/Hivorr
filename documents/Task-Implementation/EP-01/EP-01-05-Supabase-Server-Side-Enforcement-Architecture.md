# TASK IMPLEMENTATION PLAN: EP-01-05

## Supabase Server-Side Enforcement Architecture (RPC + RLS)

## Task Identification

| Field | Value |
|---|---|
| Task ID | EP-01-05 |
| Task Name | Supabase Server-Side Enforcement Architecture (RPC + RLS) |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Ready for Approval |
| Dependencies | EP-01-03 completed (environment configuration contract); 3 Supabase projects provisioned (external prerequisite) |
| Repository State | No `supabase/` directory exists; EP-01-01 through EP-01-04 completed and committed; CI/CD workflows present under `.github/workflows/`; `supabase_flutter: 2.17.2` pinned in `pubspec.yaml` |
| Current Branch | `master` (protected) |

---

## 1. Task Objective

Establish the **Database-First Zero-Trust Architecture** that every future phase operates under:

- Provision and connect three isolated Supabase projects (Development, Staging, Production) per ENV-001 to ENV-008.
- Establish a versioned, reproducible SQL migration strategy stored in the repository.
- Configure **Row-Level Security (RLS)** with **default-deny** on every table created, with explicit per-operation grants.
- Create **foundational RPC (stored procedure) patterns** demonstrating server-side enforcement: authenticated read, authenticated write, validation, and error handling.
- Deliver an **RLS test suite** proving zero data leakage (unauthenticated and cross-user access yields no data).
- Enforce AGENT.md Rule 4: sensitive logic, validation, and state changes execute server-side — never in client code.

**Dependency:** EP-01-03 configuration contract (Supabase URL + public anon key per environment) is consumed for verification only; client-side Supabase initialization belongs to EP-01-07.

---

## 2. Business Problem Being Solved

Without a server-side enforcement layer:

- Proprietary business logic embedded in the client can be decompiled, reverse-engineered, and tampered with — violating AGENT.md Proprietary Logic Protection.
- Direct client access to tables allows data forgery, cross-user data reads, and financial manipulation (AGENT.md Rule 4 violation).
- RLS configured permissively or inconsistently causes data leakage between entities — a catastrophic, reputation-destroying failure for a multi-role marketplace (consumer, professional, merchant, rider).
- Unversioned or hand-edited databases create unreproducible environments, schema drift, and broken deployments across Dev/Staging/Prod.
- Without standardized RPC patterns, every future phase (EP-01-06 onward, then EP-02 through EP-08) invents its own security approach — inconsistent, unreviewable, and unmaintainable.
- Without an automated RLS test suite, security regressions go undetected until production.

This task is the **most architecturally significant item in EP-01**: it fixes the security model, migration discipline, and server-side enforcement patterns that all subsequent phases inherit.

---

## 3. Scope

### In Scope

- Coordination and connection of 3 Supabase projects (Dev/Staging/Prod) with strict isolation.
- Supabase CLI setup (pinned version), local development instance configuration.
- Versioned SQL migrations under `supabase/migrations/`:
  - Enforcement foundation (default-deny posture, schema privilege revocation, auth-context helpers, audit-column trigger, error-raising helper).
  - Reference tables (minimal, non-entity): `platform_audit_log` and `platform_demo_records` — the RLS/RPC pattern template that EP-01-06 entities will follow.
  - RLS policies with default-deny and explicit grants on all created tables.
  - Foundational RPC functions (authenticated read, authenticated write, validation helper, error handling, audit-log helper, health probe).
- Normalized server-side error-code contract and error envelope.
- pgTAP-based RLS/RPC test suite under `supabase/tests/database/`.
- Additive CI workflow (`database-rls-tests.yml`) executing the RLS test suite — **new file only; existing EP-01-04 workflows must not be modified**.
- Migration application and verification runbook (`supabase/README.md`) covering Dev → Staging → Prod with approval gates (ENV-007).
- Environment connectivity verification (no Dart code) using the EP-01-03 configuration contract.
- Security audit SQL checks (no anon table grants, no `security definer` without hardening, no secrets in migrations).
- Regression run of `flutter analyze` and `flutter test` (no Dart changes expected).

---

## 4. Out of Scope

- The Universal Entity data model (entities, profiles, roles, industries, professions, etc.) — EP-01-06.
- Any Dart client code: Supabase client initialization, API layer, data access layer, repositories — EP-01-07, EP-01-08.
- Authentication & authorization framework on the client — EP-01-09.
- Supabase Auth configuration beyond what is required for RLS context (JWT claims) verification.
- Edge Functions (webhooks, external API adapters) — deferred by the approved architecture.
- Supabase Realtime subscriptions and Storage bucket configuration.
- Modification of existing EP-01-04 CI/CD workflow files or branch protection.
- Service-role key exposure to any client artifact or committed file.
- Business data, seed data in Production, or demo records in Staging/Production.
- UI, screens, routing, or any user-facing behavior.
- Changes to the approved EP-01 phase document, ARCHITECTURE.md, or AGENT.md.
- Final feature documentation (a Definition-of-Done document is produced at completion, per established practice).

---

## 5. Recommended Technical Approach

### 5.1 Project Provisioning & Environment Mapping

- Three isolated Supabase projects: `hivorr-dev`, `hivorr-staging`, `hivorr-prod` (ENV-008 — no cross-contamination).
- Credentials (project refs, database passwords, `SUPABASE_ACCESS_TOKEN`) are supplied by the project lead through secure channels and exist **only** in environment variables / secret stores — never committed.
- The EP-01-03 contract supplies each environment's Supabase URL and public anon key; these are used for connectivity verification only in this task. The service-role key is used exclusively by server-side tooling and operators.
- Environment mapping:

| Environment | Supabase Project | Config Source (EP-01-03) | Tooling Access |
|---|---|---|---|
| Development | hivorr-dev (+ local `supabase start` for tests) | Dev URL/anon key | Local CLI + dev DB password |
| Staging | hivorr-staging | Staging URL/anon key | CLI via secret-env (lead approval) |
| Production | hivorr-prod | Prod URL/anon key | CLI via secret-env (lead approval) |

### 5.2 Migration Strategy

- Migrations stored as versioned SQL files in `supabase/migrations/` using Supabase CLI timestamp convention: `<UTC-timestamp>_<snake_case_name>.sql`.
- One logical change per migration; append-only — an applied migration is never edited; corrections come as new migrations.
- Local development: `supabase start` (Docker) with `supabase/config.toml`; `supabase db reset` for clean rebuilds.
- Promotion: `supabase link --project-ref <ref>` + `supabase db push` per environment, strictly Dev → Staging → Prod with a project-lead approval gate before each non-local environment.
- `supabase/config.toml` contains no secrets.

### 5.3 Proposed Repository Structure

```text
supabase/
├── config.toml                 # Local dev instance config (no secrets)
├── migrations/
│   ├── <ts>_enforcement_foundation.sql     # Helpers, default-deny posture
│   ├── <ts>_reference_tables_rls.sql       # platform_audit_log, platform_demo_records + RLS
│   └── <ts>_foundational_rpcs.sql          # RPC pattern set + grants
├── tests/
│   └── database/               # pgTAP suite
│       ├── 001_rls_leakage_matrix.sql
│       ├── 002_rpc_auth_enforcement.sql
│       ├── 003_rpc_validation_errors.sql
│       └── 004_security_posture_audit.sql
└── README.md                   # Runbook: migration + test commands, env mapping, approval flow
```

### 5.4 Enforcement Foundation (Migration 1)

- **Default-deny posture:**
  - Revoke blanket privileges on `public` schema from `anon`/`authenticated` where they would permit unvetted access; grant only what explicit patterns require.
  - Every created table: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
  - No table-level `GRANT` to `anon`; `authenticated` granted only the minimal operations needed by approved RPC flows; direct table access revoked where the RPC-only pattern applies.
- **Helpers (all in `public`, clearly namespaced):**
  - `platform_is_authenticated()` — returns `auth.uid() IS NOT NULL`.
  - `platform_current_user_id()` — returns `auth.uid()`.
  - `platform_set_updated_at()` — `BEFORE UPDATE` trigger function.
  - `platform_raise_error(code TEXT, message TEXT)` — raises typed exceptions via `RAISE EXCEPTION USING ERRCODE, MESSAGE`.
  - `platform_validate_payload(p_payload JSONB, p_required_keys TEXT[])` — JSONB contract validation with safe errors.
- **Audit columns convention:** `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `created_by UUID DEFAULT auth.uid()` — the convention EP-01-06 inherits.
- No unapproved extensions; only stock PostgreSQL capabilities required by this task.

### 5.5 Reference Tables & RLS (Migration 2)

Minimal, clearly-documented reference surface — **not** the EP-01-06 entity model:

- `platform_audit_log` — append-only (id, action, entity, entity_id, details JSONB, actor_id, created_at). Direct client access denied; writes occur only via the security-definer helper. Demonstrates the "client never touches the table" pattern.
- `platform_demo_records` — owner-scoped reference table (id, owner_id, title, payload JSONB, audit columns). Demonstrates per-user isolation. Documented as the pattern template that EP-01-06 entities replace.

RLS policy pattern (standardized naming `<table>_<role>_<op>`):

| Policy Pattern | Table | Semantics |
|---|---|---|
| `authenticated` select — `platform_demo_records` | owner `auth.uid() = owner_id` | Users read only their own rows |
| `authenticated` insert — `platform_demo_records` | `WITH CHECK (owner_id = auth.uid())` | Users create only their own rows |
| `authenticated` update — `platform_demo_records` | `USING` + `WITH CHECK` owner-guarded | Owner-only mutation |
| `service_role` select/insert on `platform_audit_log` | policy-free, service-role only | Audit trail write path |

Realtime publication must not include these tables (Realtime stays disabled for them).

### 5.6 Foundational RPC Set (Migration 3)

| RPC | Auth Required | Purpose |
|---|---|---|
| `platform_health()` | anon (public) | Connectivity/version probe per environment |
| `platform_demo_records_get(p_id UUID)` | authenticated | Server-side authenticated read pattern |
| `platform_demo_records_create(p_title TEXT, p_payload JSONB)` | authenticated | Validated server-side write pattern |
| `platform_demo_records_update(p_id UUID, p_payload JSONB)` | authenticated | Owner-guarded update pattern |
| `platform_audit_log_add(p_action TEXT, p_entity TEXT, p_details JSONB)` | security-definer helper | Insert-only audit path (service-side) |

Execution model:

- **SECURITY INVOKER by default** so RLS applies to every data access inside RPCs (zero-trust preserved).
- **SECURITY DEFINER only** for `platform_audit_log_add`, hardened with `SET search_path = pg_catalog, public`, minimal function ownership, and `REVOKE EXECUTE FROM anon`.
- `GRANT EXECUTE` narrowed per function; anon receives only `platform_health`.
- All RPCs return normalized envelopes and raise typed platform errors (no raw Postgres errors exposed to clients).
- Normalized error-code contract: `PLT001` authentication required, `PLT002` forbidden, `PLT003` validation failed, `PLT004` not found, `PLT005` conflict, `PLT999` internal — documented for EP-01-07 consumption.

### 5.7 Connectivity Verification (no Dart code)

- `supabase projects list` and `supabase db push --dry-run` against each project.
- Call `platform_health()` via PostgREST with each environment's anon key (from the EP-01-03 contract) to prove each environment reaches only its own project.
- Verification commands documented in the runbook.

### 5.8 CI Execution (additive only)

- New `database-rls-tests.yml`: on PR and push to `master` — start local Supabase (Docker) via the CLI, apply migrations, run the pgTAP suite, publish results as a required check.
- Pins the Supabase CLI to an immutable version; no secrets required (local instance).
- If CI Docker support is unavailable, the fallback (documented local execution) is recorded and the lead approves the effective testing path.
- **Existing EP-01-04 workflow files, environments, and branch protection are not modified.**

---

## 6. Required Systems, Modules, and Components

| Component | Location or System | Responsibility |
|---|---|---|
| 3 Supabase projects | Supabase Cloud | Isolated per-environment databases (ENV-008) |
| Supabase CLI (pinned) | Tooling | Local dev, migrations, linking, pgTAP tests |
| `supabase/config.toml` | `supabase/` | Local development instance config |
| Versioned migrations | `supabase/migrations/` | Reproducible schema and enforcement layer |
| Enforcement helpers | Migrations | Auth context, timestamps, typed errors, validation |
| Reference tables + RLS | Migrations | Default-deny + explicit policy pattern surface |
| Foundational RPCs | Migrations | Server-side enforcement pattern set |
| pgTAP test suite | `supabase/tests/database/` | Zero-leakage and RPC behavior verification |
| RLS test workflow | `.github/workflows/database-rls-tests.yml` | CI execution of the security suite (new file) |
| EP-01-03 configuration contract | `lib/config/environments/` | Per-env URL/anon key for verification |
| Migration/verification runbook | `supabase/README.md` | Commands, env mapping, approval flow |
| Secret store / environment variables | Operator tooling | Access token + DB passwords (never committed) |

No new Dart package or module is required. No modification to `pubspec.yaml`.

---

## 7. Data Requirements

- **No business or user data** is introduced (that is EP-01-06).
- Only operational data is produced:
  - `platform_audit_log` rows (server-written audit trail).
  - Test fixture rows in the local/CI database and Development only.
- **Production must receive zero demo/test records.** Migrations may carry no `INSERT` of operational data; test data exists only inside the pgTAP suite (which runs against local/CI instances).
- RLS must guarantee that no unauthenticated or cross-entity access can observe any row.

---

## 8. Database Considerations

This is the central deliverable of the task. Requirements:

- RLS **enabled and default-deny** on every table this task creates.
- All enforcement via PostgreSQL native mechanisms (RLS policies, RPC functions, grants) — no client-side enforcement.
- `auth.uid()`/JWT context as the sole identity source inside policies and functions.
- `SECURITY DEFINER` limited, hardened (`search_path` pinned, ownership minimal, execute grants narrowed, `REVOKE` from `anon` where not public).
- No dynamic SQL built from user input (injection resistance); parameterized functions only.
- Tables, functions, and policies named consistently and documented via `COMMENT ON`.
- Audit columns + `updated_at` trigger convention established for EP-01-06.
- Migrations versioned, append-only, reproducible from a clean `db reset` in local/CI.
- No unapproved extensions; no Realtime exposure of reference tables.
- Connection pooling, indexes (`owner_id`, `created_at`), and function volatility declared appropriately for performance.

---

## 9. API Requirements

- **No client API code** is written (EP-01-07).
- The task defines the server-side **RPC contract** for future consumers: function names, parameter types, return envelope `{success, code, message, data}`, auth requirements, and error codes (`PLT001`–`PLT999`).
- RPCs become callable via PostgREST (`/rest/v1/rpc/<fn>`); exposure is controlled through `GRANT EXECUTE` scoping.
- The health probe provides the first environment-to-client connectivity contract for EP-01-07.

---

## 10. User Interface Requirements

**Not applicable.**

No widgets, screens, routes, or user-facing behavior. `lib/` Dart code must remain untouched except for any lead-approved regression verification. `lib/main.dart` behavior is unchanged.

---

## 11. User Experience Considerations

Developer and operator experience only:

- One-command local rebuild: `supabase start` → `supabase db reset` → `supabase test db`.
- Deterministic migration promotion commands per environment with explicit lead approval gates.
- Safe, actionable error messages that never reveal data values or credentials.
- A runbook that maps each environment to its Supabase project, config values, and verification steps.
- CI output clearly reports the RLS leakage matrix result on every PR.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Data leakage via permissive RLS | Default-deny; every table RLS-enabled; explicit `USING`/`WITH CHECK` policies; leakage matrix test |
| Client-side business logic extraction | All enforcement server-side; zero sensitive logic in Dart |
| Direct table tampering by clients | Narrow grants; RPC-only write patterns; direct table access revoked |
| `SECURITY DEFINER` privilege escalation | Minimal usage; `search_path` pinned; narrow `EXECUTE` grants; audit review |
| Cross-user data access | Owner-scoped policies (`auth.uid() = owner_id`) verified by tests |
| Unauthenticated access | Anon gets only `platform_health`; all other RPCs require auth; RLS denies anon |
| Service-role key exposure | Never committed, never passed to client artifacts, never in config.toml |
| Secrets in repository | Static scan of migrations, tests, workflows, and runbook |
| Injection attacks | Parameterized functions; no dynamic SQL from user input; JSONB validation |
| Error-message data leakage | Typed platform errors; no raw values or SQL details surfaced |
| Environment contamination | Isolated projects per ENV-008; per-environment credentials; Dev → Staging → Prod flow (ENV-007) |
| Realtime/PostgREST accidental exposure | Realtime disabled for reference tables; exposure governed by grants |
| Supply chain | Pinned Supabase CLI version; immutable action refs in the new workflow |
| Audit integrity | Append-only audit log; direct client modification denied |

---

## 13. Performance Considerations

- Minimal reference surface — no premature schema; EP-01-06 owns the real model.
- Indexes on `owner_id` and `created_at`; policy checks resolve through indexes.
- Functions declared with correct volatility; parameterized execution plans reused.
- Append-only audit writes are lightweight; no heavy trigger chains.
- Tests run in local Docker/CI instances — never against Production.
- RPC bodies kept small and composable; no N+1 loops inside functions.
- Migration and test suites are fast enough for CI (target well under a few minutes).
- No impact on the 15–20 MB installer: no Dart code, no packages, no assets.

---

## 14. Testing Strategy

### 14.1 RLS Leakage Matrix (pgTAP, `001`)

| Actor | Action | Expected Result |
|---|---|---|
| anon (unauthenticated) | SELECT on `platform_demo_records` | No rows / denied |
| anon | RPC write | Denied (PLT001) |
| anon | `platform_health` | Allowed (public) |
| authenticated user A | Read user B's row | Denied / zero rows |
| authenticated user A | Update user B's row | Denied (PLT002) |
| authenticated user A | Insert with `owner_id = B` | Denied (`WITH CHECK`) |
| authenticated user A | Read/write own rows via RPC | Allowed |
| service_role | Direct table access | Allowed (server-side only) |
| authenticated | Direct `INSERT` on `platform_audit_log` | Denied (RPC-only path) |

### 14.2 RPC Enforcement (`002`)

- Auth required on every non-health RPC.
- Owner-only mutation enforced through both RLS and function guards.
- Return envelope shape and success paths verified.

### 14.3 Validation & Error Contract (`003`)

- Missing required payload keys → `PLT003` with safe message.
- Unknown IDs → `PLT004`; conflicts → `PLT005`; unauthenticated → `PLT001`; forbidden → `PLT002`.
- No error message contains data values.

### 14.4 Security Posture Audit (`004`)

- SQL audit assertions: all created tables have RLS enabled; no `GRANT` to `anon` on tables; `SECURITY DEFINER` functions have pinned `search_path`; no secrets in migrations; Realtime publication excludes reference tables.

### 14.5 Execution

- Local: `supabase start` → `supabase db reset` → `supabase test db`.
- CI: new `database-rls-tests.yml` runs the same suite on PR and push.
- Regression: `flutter analyze` and `flutter test` pass (no Dart changes expected).
- Static scan: no service-role keys, credentials, or real URLs in any new file.
- Scope validation: review the final diff — no Dart, no EP-01-04 workflow modification, no phase-document change.

---

## 15. Recommended Implementation Sequence

1. Confirm EP-01-03 deliverables intact and the 3 Supabase projects provisioned (lead-provided refs/credentials via secrets).
2. Initialize `supabase/` with `config.toml` (no secrets) and pin the Supabase CLI version.
3. Write migration 1 — enforcement foundation (default-deny posture, helpers, audit convention).
4. Write migration 2 — reference tables + RLS policies.
5. Write migration 3 — foundational RPC set + grants + error contract.
6. `supabase start` locally; `supabase db reset`; verify clean build from zero.
7. Author the pgTAP suite (4 files); run locally until green.
8. Add `database-rls-tests.yml` (additive); verify in CI on a controlled PR.
9. Link and push migrations to the Development project; run connectivity verification (`platform_health` + dry-run).
10. Approval gate — apply to Staging; verify connectivity and zero test data.
11. Approval gate — apply to Production; verify connectivity and zero test data.
12. Run the security posture audit SQL and static secret scans.
13. Write the runbook (`supabase/README.md`): commands, env mapping, approval flow, error-code contract.
14. Run `flutter analyze` and `flutter test` as regression (no Dart changes expected).
15. Review final diff for strict EP-01-05 scope containment and phase-document integrity.
16. Stop at the implementation approval gate — no downstream EP-01-06/07/09 implementation.

---

## 16. Expected Outcome

- Three isolated Supabase projects connected, each verified reachable with its own EP-01-03 configuration values.
- Versioned, reproducible SQL migrations in the repository; clean rebuild verified locally and in CI.
- RLS default-deny with explicit policies; automated leakage matrix proves **zero data leakage** (unauthenticated and cross-user access yields nothing).
- Foundational RPC patterns established (authenticated read, authenticated write, validation, error handling, audit path) with a documented error-code contract.
- CI executes the RLS test suite on every PR without modifying existing EP-01-04 workflows.
- EP-01-06 (Universal Entity schema), EP-01-07 (API layer), and EP-01-09 (Auth) inherit a proven, documented enforcement pattern and runbook.

---

## 17. Definition of Done (DoD)

- [ ] Three Supabase projects (Dev/Staging/Prod) are provisioned, isolated, and connected.
- [ ] Environment credentials exist only in secret stores / environment variables — never committed.
- [ ] `supabase/` exists with `config.toml`, versioned migrations, pgTAP tests, and runbook.
- [ ] Migrations are versioned, append-only, and reproducible from a clean local reset.
- [ ] Every table created by this task has RLS enabled.
- [ ] RLS is default-deny with explicit, documented policies.
- [ ] Anon role has no table access and no RPC access beyond `platform_health`.
- [ ] Authenticated users access only their own rows (verified by tests).
- [ ] `SECURITY DEFINER` usage is minimal, search-path-pinned, and execute-granted narrowly.
- [ ] Foundational RPCs exist: authenticated read, authenticated write, validation helper, error handler, audit-log helper, health probe.
- [ ] Normalized error-code contract (`PLT001`–`PLT999`) is implemented and documented.
- [ ] Audit columns and `updated_at` trigger convention are established.
- [ ] pgTAP suite covers the leakage matrix, RPC auth enforcement, validation/error contract, and security posture.
- [ ] The full pgTAP suite passes locally and in CI.
- [ ] `database-rls-tests.yml` exists and runs on PR/push (additive; EP-01-04 files unmodified).
- [ ] Migrations applied to Dev, then Staging, then Production with lead approval gates (ENV-007).
- [ ] Connectivity verified per environment via `platform_health` using EP-01-03 values.
- [ ] Zero test/demo data exists in Staging and Production.
- [ ] No Dart code, API layer, data layer, or authentication code was added.
- [ ] No EP-01-06 entity tables were created.
- [ ] No Edge Functions, Realtime subscriptions, or Storage configuration were added.
- [ ] `flutter analyze` and `flutter test` pass (no Dart changes).
- [ ] Static scans confirm no secrets, service-role keys, or real URLs in the repository.
- [ ] No Realtime publication includes the reference tables.
- [ ] The approved EP-01 phase document, ARCHITECTURE.md, and AGENT.md remain unchanged.
- [ ] Existing EP-01-04 workflows and branch protection remain unchanged.
- [ ] The final diff contains only approved EP-01-05 changes.

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

- **Technical complexity:** Extremely high — RLS policy semantics, security-definer hardening, PostgREST exposure, JWT auth context, versioned migration discipline, pgTAP test authoring, and multi-environment promotion sequencing demand precise, security-critical SQL reasoning where a single misconfiguration creates exploitable data exposure.
- **Business impact:** Critical — this is the most architecturally significant item in EP-01. Every future phase and business system (marketplace, finance, logistics, verification) operates under the enforcement patterns established here; errors propagate to the entire platform.
- **Security risk:** Extremely high — the task *is* the security boundary: zero-trust enforcement, data-leakage prevention, privilege escalation resistance, and secret handling. RLS/RPC misconfiguration is a direct data-breach vector.
- **Performance sensitivity:** Medium-high — policy design, indexes, function volatility, and audit write paths set the performance ceiling for all future server-side logic; the pattern must not institutionalize slow or N+1 patterns.
- **Data complexity:** High — the task defines the enforcement foundation and reference tables that EP-01-06's Universal Entity model will build on; conventions established here (audit columns, triggers, policy naming) become permanent schema decisions.
- **Integration complexity:** Extremely high — coordinates three Supabase projects, CLI tooling, CI, the EP-01-03 configuration contract, and must remain cleanly consumable by EP-01-06, EP-01-07, and EP-01-09 without coupling or scope creep.

Extremely High reasoning is required because this task is a security-critical architectural keystone whose decisions are irreversible in practice and inherited by the entire platform.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Upon approval, the plan document will be saved to `documents/Task-Implementation/EP-01/EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md` (matching the established task-plan format), and implementation will begin only after a separate implementation approval. No production code is written during planning.
