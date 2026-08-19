# EP-01-05 — Supabase Server-Side Enforcement Architecture: Runbook

Operational runbook for the Database-First Zero-Trust enforcement layer
(RPC + RLS). Approved implementation plan:
`documents/Task-Implementation/EP-01/EP-01-05-Supabase-Server-Side-Enforcement-Architecture.md`.

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

| Environment | Supabase Project | Config Source (EP-01-03) | Tooling Access |
|---|---|---|---|
| Development | `hivorr-dev` (+ local `supabase start`) | Dev URL/anon key | Local CLI + dev DB password |
| Staging | `hivorr-staging` | Staging URL/anon key | CLI via secret-env (lead approval) |
| Production | `hivorr-prod` | Prod URL/anon key | CLI via secret-env (lead approval) |

Credentials (project refs, database passwords, `SUPABASE_ACCESS_TOKEN`) must
exist **only** in environment variables / secret stores. They are never
committed. The service-role key is used exclusively by server-side tooling and
operators, never by client artifacts.

## 3. Repository Layout

```text
supabase/
├── config.toml                 # Local dev instance config (no secrets)
├── migrations/                 # Versioned SQL migrations (append-only)
│   ├── 20260819090001_enforcement_foundation.sql
│   ├── 20260819090002_reference_tables_rls.sql
│   └── 20260819090003_foundational_rpcs.sql
├── tests/
│   └── database/               # pgTAP suite
│       ├── 001_rls_leakage_matrix.sql
│       ├── 002_rpc_auth_enforcement.sql
│       ├── 003_rpc_validation_errors.sql
│       └── 004_security_posture_audit.sql
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
supabase link --project-ref <hivorr-dev-ref>
supabase db push

# Staging — requires lead approval
supabase link --project-ref <hivorr-staging-ref>
supabase db push

# Production — requires lead approval
supabase link --project-ref <hivorr-prod-ref>
supabase db push
```

If a push fails midway, do not hand-edit the database. Re-run `supabase db push`
after fixing forward (new migration), or rebuild via a fresh branch as approved.

## 7. Connectivity Verification

No Dart code is involved (client integration is EP-01-07).

```powershell
supabase projects list                         # CLI can reach the account
supabase db push --dry-run                     # per linked project
```

Health probe per environment (PostgREST, anon key from the EP-01-03 contract):

```powershell
curl -X POST "https://<project-ref>.supabase.co/rest/v1/rpc/platform_health" `
  -H "apikey: <anon-key>" -H "Authorization: Bearer <anon-key>" `
  -H "Content-Type: application/json" -d "{}"
```

Expected: `{"success": true, "code": "PLT000", "message": "Platform connected.", "data": {...}}`.
Each environment must respond only through its own project.

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

- Universal Entity data model (EP-01-06) — the reference tables here are the
  pattern template, not the entity model.
- Dart client integration, API layer, data access layer, authentication
  framework (EP-01-07, EP-01-08, EP-01-09).
- Edge Functions, Realtime subscriptions, Storage configuration.
- Modifications to existing EP-01-04 workflows or branch protection.