# EP-01-05 / EP-01-06 — Supabase Server-Side Enforcement Architecture: Runbook

Operational runbook for the Database-First Zero-Trust enforcement layer
(RPC + RLS). Approved implementation plans:
`documents/Task-Implementation/EP-01/EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md`
and `documents/Task-Implementation/EP-01/EP-01-06-Universal Entity Data Model & Core Schema Design.md`.

## 1. Overview

| Item | Value |
|---|---|
| Enforcement model | PostgreSQL RPC + Row-Level Security (default-deny) |
| Client posture | Unprivileged presentation layer (zero-trust) |
| Environment isolation | Dev / Staging / Prod — separate Supabase projects (ENV-001–ENV-008) |
| Migration strategy | Versioned SQL migrations in `supabase/migrations/` |
| Test strategy | pgTAP suite in `supabase/tests/database/` (local + CI) |
| CI workflow | `.github/workflows/database-rls-tests.yml` (additive; EP-01-04 files untouched) |

## 2. Environment Mapping

| Environment | Supabase Project | Project Ref / Region | Config Source (EP-01-03) | Tooling Access |
|---|---|---|---|---|
| Development | local `supabase start` (Docker); cloud `hivorr-dev` NOT provisioned (2-project free-plan limit — mapping decision pending lead) | — | Dev URL/anon key | Local CLI + dev DB password |
| Staging | `hivorr-staging` | `cgxkiczmwzydhoroclvf` / eu-west-2 | Staging URL/anon key | CLI via secret-env (lead approval) |
| Production | `hivorr-prod` | `fxpcgtetvzlexbptqiwp` / eu-west-1 | Prod URL/anon key | CLI via secret-env (lead approval) |

Migrated 2026-08-19 (both; see Section 6). Staging and Prod are verified at the
post-migration reference state: 10 `platform_*` functions, 0 demo rows, 0 audit
rows, no test extensions.

Credentials (project refs, database passwords, `SUPABASE_ACCESS_TOKEN`) must
exist **only** in environment variables / secret stores. They are never
committed. The service-role key is used exclusively by server-side tooling and
operators, never by client artifacts. Rotate the two project Postgres passwords
if they were ever surfaced in a chat/session (they were during the 2026-08-19
promotion).

## 3. Repository Layout

```text
supabase/
├── config.toml                 # Local dev instance config (no secrets)
├── migrations/                 # Versioned SQL migrations (append-only)
│   ├── 20260819090001_enforcement_foundation.sql
│   ├── 20260819090002_reference_tables_rls.sql
│   ├── 20260819090003_foundational_rpcs.sql
│   ├── 20260821090001_entity_taxonomy_tables.sql   # EP-01-06: industries, professions
│   ├── 20260821090002_entity_core_tables.sql       # EP-01-06: 7 entity tables
│   ├── 20260821090003_entity_model_rls_policies.sql# EP-01-06: RLS + grants + realtime
│   ├── 20260821090004_entity_model_rpcs.sql        # EP-01-06: 5 enforcement RPCs
│   ├── 20260821090005_entity_owner_defaults.sql    # EP-01-06 correction: child entity_id default auth.uid()
│   └── 20260821090006_entity_profile_legal_name_guard.sql # EP-01-06 correction: legal_name mutation gate
├── tests/
│   └── database/               # pgTAP suite
│       ├── 001_rls_leakage_matrix.sql
│       ├── 002_rpc_auth_enforcement.sql
│       ├── 003_rpc_validation_errors.sql
│       ├── 004_security_posture_audit.sql
│       ├── 005_entity_rls_leakage_matrix.sql       # EP-01-06: zero cross-entity leakage (7 tables)
│       ├── 006_taxonomy_integrity.sql              # EP-01-06: FK/CHECK/vocabulary/cascade
│       ├── 007_entity_rpc_enforcement.sql          # EP-01-06: 5 RPCs, error contract, audit
│       └── 008_full_schema_posture_audit.sql       # EP-01-06: grants/RLS/definer posture
└── README.md                   # This runbook
```

## 4. Prerequisites

- Supabase CLI (version pinned in `.github/workflows/database-rls-tests.yml`; install:
  https://supabase.com/docs/guides/cli/getting-started)
- Docker (required for the local instance: `supabase start`)
- No secrets required for local development or tests

## 5. Local Development

```powershell
supabase start        # Boot the local Supabase stack (Docker)
supabase db reset     # Rebuild a clean database from migrations
supabase test db      # Run the pgTAP RLS/RPC suite
```

`supabase db reset` rebuilds the schema from zero — this is the reproducibility
check for the migration set.

## 6. Migration Promotion (Dev → Staging → Prod)

Migrations are append-only. Never edit an applied migration; ship corrections
as new timestamped files. Strictly follow ENV-007 with a project-lead approval
gate before every non-local environment.

```powershell
# Development (after local verification)
supabase start
supabase db reset
supabase test db

# Staging — requires lead approval. Used 2026-08-19:
supabase db push --db-url "postgresql://postgres.<staging-ref>:<pw>@aws-0-eu-west-2.pooler.supabase.com:6543/postgres" --dry-run   # gate: review summary
supabase db push --db-url "postgresql://postgres.<staging-ref>:<pw>@aws-0-eu-west-2.pooler.supabase.com:6543/postgres"         # gate: lead approval

# Production — requires lead approval. Used 2026-08-19:
supabase db push --db-url "postgresql://postgres.<prod-ref>:<pw>@aws-1-eu-west-1.pooler.supabase.com:6543/postgres" --dry-run   # gate: review summary
supabase db push --db-url "postgresql://postgres.<prod-ref>:<pw>@aws-1-eu-west-1.pooler.supabase.com:6543/postgres"           # gate: lead approval
```

Notes on the pooler path:

- Always use the **session pooler (port 6543)** for `db push` and tests — the
  transaction pooler (5432) can break multi-statement operations.
- `supabase link` / `projects list` require Management-API scopes
  (Projects/Databases) on `SUPABASE_ACCESS_TOKEN`; with a scoped-down token use
  `--db-url` as above.
- Verify application with a follow-up `supabase db push --db-url ... --dry-run`
  → expected output `Remote database is up to date.`

If a push fails midway, do not hand-edit the database. Re-run `supabase db push`
after fixing forward (new migration), or rebuild via a fresh branch as approved.

## 7. Connectivity Verification

No Dart code is involved (client integration is EP-01-07).

```powershell
supabase db push --db-url "<session pooler>" --dry-run     # per project: none/up-to-date
```

Health probe per environment (PostgREST, anon key from the EP-01-03 contract):

```powershell
curl -X POST "https://<project-ref>.supabase.co/rest/v1/rpc/platform_health" `
  -H "apikey: <anon-key>" -H "Authorization: Bearer <anon-key>" `
  -H "Content-Type: application/json" -d "{}"
```

Database-level probe (no anon key needed; callable via pooler directly):

```powershell
psql "<session pooler url>" -c "select * from public.platform_health()"
```

Expected: `{"success": true, "code": "PLT000", "message": "Platform connected.", "data": {...}}`.
Each environment must respond only through its own project.

**Running the pgTAP suite against a Cloud project** (verified 2026-08-19 on
Staging, 69/69 for the EP-01-05 baseline; the EP-01-06 files `005`–`008` are
local-only and not yet promoted — see Section 6 promotion gate): execute each
test file statement-by-statement (as `psql` does)
through the session pooler, after `discard all` per file. Two Cloud-only
pitfalls: (1) the pooler recycles backends without dropping temp state, so
pgTAP's per-backend `tap` state leaks between sessions — `discard all` is
mandatory; (2) `commit; begin;` sent within a single multi-statement message
reuses one transaction timestamp, making the 002 trigger assertion fail — send
statements individually. Never run the suite against Production (002's mid-file
commit persists one fixture row; clean it with a `delete` afterwards if run) —
the suite's authority is CI.

## 8. RPC Surface & Error Contract

| RPC | Auth | Security | Purpose |
|---|---|---|---|
| `platform_health()` | anon | invoker | Connectivity/version probe |
| `platform_demo_records_get(p_id uuid)` | authenticated | invoker + RLS | Authenticated read pattern |
| `platform_demo_records_create(p_title text, p_payload jsonb)` | authenticated | invoker + RLS | Validated write pattern |
| `platform_demo_records_update(p_id uuid, p_payload jsonb)` | authenticated | invoker + RLS | Owner-guarded update pattern |
| `platform_audit_log_add(p_action text, p_entity text, p_details jsonb)` | authenticated | **security definer** (pinned `search_path`) | Insert-only audit path |

Envelope: `{success, code, message, data}`.

| Code | Meaning |
|---|---|
| `PLT000` | Success |
| `PLT001` | Authentication required |
| `PLT002` | Forbidden |
| `PLT003` | Validation failed |
| `PLT004` | Not found |
| `PLT005` | Conflict |
| `PLT999` | Internal |

Error messages are static and never contain data values or credentials. The
message format is `"<PLT-code>: <message>"`; the SQLSTATE is `P0001`.

## 8b. EP-01-06 — Universal Entity Data Model

Adds the universal entity surface on top of the EP-01-05 enforcement layer.
Approved plan:
`documents/Task-Implementation/EP-01/EP-01-06-Universal Entity Data Model & Core Schema Design.md`.

### Tables

| Table | Purpose |
|---|---|
| `industries` | Taxonomy root (slug/name). anon-readable. |
| `professions` | Taxonomy leaf (industry_id FK, RESTRICT). anon-readable. |
| `entities` | Anchor row; `id = auth.users.id` (PK, ON DELETE CASCADE, DEFAULT `auth.uid()`). `status` CHECK vocabulary. |
| `entity_profiles` | 1:1 profile. `legal_name` anchor frozen except via `entity_profile_update` RPC (trigger gate). |
| `entity_roles` | Fluid multi-role (consumer/professional/merchant/rider). Activated/deactivated via RPC. |
| `entity_professions` | Profession bindings. `trade_verification_status` starts `unverified`, client-unwritable. |
| `entity_credentials` | Immutable submissions. `verification_status` starts `pending`, client-unwritable. |
| `entity_settings` | Per-entity JSON settings (owner-scoped). |
| `entity_devices` | Per-entity device tokens (owner-scoped). |

No seed data is shipped (decision D7). Verification columns are client-unwritable
via column-level grants (D5); transitions are reserved for the EP-02 admin gate.

### Enforcement RPCs (all `security invoker`, authenticated-only, audit-logged)

| RPC | Purpose |
|---|---|
| `entity_profile_update(p_legal_name, p_display_name, p_bio)` | Validated anchor/display update. Sets `platform.rpc_invocation` GUC so the `entity_profiles_guard_legal_name` trigger permits the `legal_name` change. |
| `entity_roles_activate(p_role)` / `entity_roles_deactivate(p_role)` | Validate vocabulary (`consumer`/`professional`/`merchant`/`rider`) and upsert/flip `is_active`. History preserved (no DELETE). |
| `entity_profession_bind(p_profession_id)` | Validate existence + active; insert binding as `trade_verification_status = 'unverified'`; reject duplicates (`PLT005`). |
| `entity_credentials_submit(p_kind, p_title, p_profession_id, p_document_path, p_expires_at)` | Validate kind vocabulary + title; insert immutable `pending` submission (zero client UPDATE grant). |

All RPCs return the `{success, code, message, data}` envelope and raise `P0001`
with static `PLT###` messages (PLT001 auth, PLT003 validation, PLT004 not found,
PLT005 conflict). Failures are asserted with `throws_ok`/`P0001` in the suite.

### Access Model

| Surface | anon | authenticated | service_role |
|---|---|---|---|
| `industries`, `professions` | SELECT | SELECT | SELECT (bypass) |
| `entities`, `entity_profiles`, `entity_roles`, `entity_professions`, `entity_credentials`, `entity_settings`, `entity_devices` | no grants | SELECT/INSERT/UPDATE owner-scoped (`entity_id = auth.uid()`); verification columns + `entity_id` column writes denied | bypasses RLS |
| 5 entity RPCs | denied (no execute grant) | execute | execute |

`legal_name` is the one writable-but-guarded column: authenticated holds the
UPDATE grant, but the `entity_profiles_guard_legal_name_update` BEFORE UPDATE
trigger raises `PLT002` unless `current_setting('platform.rpc_invocation') = 'on'`
(set only by `entity_profile_update`). This enforces AGENT.md Rule 3 anchor
discipline without introducing a `SECURITY DEFINER` RPC.

### Test coverage (EP-01-06 adds 4 pgTAP files)

| File | Assertions | Focus |
|---|---|---|
| `005_entity_rls_leakage_matrix.sql` | 20 | Zero cross-entity leakage across all 7 private tables; anon denied; verification-column write denial |
| `006_taxonomy_integrity.sql` | 15 | FK RESTRICT, CHECK vocabularies (23514), cascade on entity delete |
| `007_entity_rpc_enforcement.sql` | 24 | 5 RPCs, anon no-execute, error contract (P0001), audit writes |
| `008_full_schema_posture_audit.sql` | 20 | Default-deny RLS, column grants, realtime exclusion, no `SECURITY DEFINER` entity function |

Full suite after EP-01-06: **148 tests across 8 files, all green** after
`supabase db reset` (CI resets before testing).

## 9. Access Model

| Surface | anon | authenticated | service_role |
|---|---|---|---|
| `platform_health` | execute | execute | execute |
| Demo RPCs | denied | execute | execute |
| Helpers (`platform_*`) | denied | execute | execute |
| `platform_demo_records` (table) | no grants | SELECT, INSERT, UPDATE (RLS owner-scoped) | bypasses RLS |
| `platform_audit_log` (table) | no grants | no grants (RPC-only) | bypasses RLS |

Policy naming convention: `<table>_<role>_<op>`.

## 10. Security Notes

- RLS is enabled and default-deny on every table this task creates.
- `SECURITY DEFINER` is limited to `platform_audit_log_add` with
  `SET search_path = pg_catalog, public` and narrowed execute grants.
- No dynamic SQL is built from user input; all functions are parameterized.
- Realtime does not publish the reference tables.
- Static scans must confirm no service-role keys, passwords, or real URLs in
  the repository.

## 11. CI

`.github/workflows/database-rls-tests.yml` runs on PR and push to `master`:

1. Pinned Supabase CLI.
2. `supabase start` (Docker on the runner).
3. `supabase db reset` (clean migration rebuild).
4. `supabase test db` (pgTAP suite).
5. Secret pattern scan of `supabase/migrations/` and `supabase/config.toml`.

If CI Docker support is unavailable, the documented fallback is local execution
(`supabase start` → `supabase db reset` → `supabase test db`) reviewed by the
project lead.

## 12. Explicitly Deferred

- Universal Entity data model (EP-01-06) — **implemented** (this runbook,
  Section 8b). Verification-state transitions for `entity_professions` /
  `entity_credentials` are reserved for the EP-02 admin gate (no client path).
- Dart client integration, API layer, data access layer, authentication
  framework (EP-01-07, EP-01-08, EP-01-09).
- Edge Functions, Realtime subscriptions (entity tables excluded from the
  `realtime` publication per EP-01-06), Storage configuration.
- Modifications to existing EP-01-04 workflows or branch protection.