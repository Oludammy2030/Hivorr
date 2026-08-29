# Task Implementation Plan — EP-02-02: Taxonomy Management RPCs & Server-Side Registry

---

## 1. Task Objective

Build server-side PostgreSQL RPC functions for taxonomy administration: public read RPCs (`taxonomy_industries_list`, `taxonomy_professions_list`) accessible to anon and authenticated users, and service-role-only write RPCs (`taxonomy_industry_create`, `taxonomy_industry_update`, `taxonomy_profession_create`, `taxonomy_profession_update`, `taxonomy_profession_move`) for taxonomy CRUD management. All write RPCs enforce input validation, slug uniqueness, referential integrity, and audit logging. Include a pgTAP enforcement test suite validating authorization, validation, and data integrity.

---

## 2. Business Problem Being Solved

The taxonomy registry (8 industries, 46 professions) was seeded in EP-02-01, but no server-side management layer exists. Currently:

- Clients read taxonomy tables directly via PostgREST under RLS — no consistent response envelope, no pagination, no server-side filtering
- No RPC path exists to create, update, activate/deactivate, or re-parent taxonomy records
- Future admin tooling (EP-02-10, EP-02-11 admin review interfaces) has no taxonomy management API
- The client-side taxonomy engine (EP-02-07) needs a stable, envelope-consistent read API
- Slug uniqueness is enforced only by table-level CHECK constraints, not by RPC-level pre-validation with meaningful error messages
- There is no audit trail for taxonomy mutations

This task creates the server-side management layer that all downstream taxonomy consumers depend on.

---

## 3. Scope

| In Scope | Detail |
|---|---|
| Read RPC: `taxonomy_industries_list` | Returns all active industries ordered by `sort_order`, with optional `p_include_inactive` flag (service-role only) |
| Read RPC: `taxonomy_professions_list` | Returns professions filtered by `p_industry_id`, ordered by `sort_order`, with optional `p_include_inactive` flag |
| Write RPC: `taxonomy_industry_create` | Creates a new industry with validated slug, name, description, sort_order |
| Write RPC: `taxonomy_industry_update` | Updates an existing industry's name, description, sort_order, and/or is_active (activate/deactivate) |
| Write RPC: `taxonomy_profession_create` | Creates a new profession linked to a valid industry, with validated slug, name, description, sort_order |
| Write RPC: `taxonomy_profession_update` | Updates an existing profession's name, description, sort_order, and/or is_active (activate/deactivate) |
| Write RPC: `taxonomy_profession_move` | Re-parents a profession to a different industry (changes `industry_id`) |
| EXECUTE grants | Read RPCs: `anon, authenticated, service_role`. Write RPCs: `service_role` only |
| pgTAP enforcement test | New test file validating authorization gates, input validation, slug uniqueness, FK integrity, audit logging, and envelope contract |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| Taxonomy DELETE RPCs | No DELETE grant exists on taxonomy tables; deactivation via `is_active = false` is the archival mechanism |
| Client-side taxonomy engine | EP-02-07 |
| Client-side Dart code (models, repositories, providers) | EP-02-07 |
| Admin UI for taxonomy management | Future task (post EP-02) |
| Schema modifications to `industries`/`professions` tables | Tables are finalized in EP-01-06 |
| RLS policy changes on `industries`/`professions` | Already configured in EP-01-06 (migration 090003); service_role bypasses RLS inherently |
| Taxonomy seed data modifications | EP-02-01 (completed) |
| Bulk import/export RPCs | Future task |
| Taxonomy search/fuzzy matching | Client-side concern (EP-02-07) |

---

## 5. Recommended Technical Approach

### 5.1 Single SQL Migration

Create one new migration file following the established naming convention:

```
supabase/migrations/<YYYYMMDD><HHMMSS>_taxonomy_management_rpcs.sql
```

The migration will contain all 7 RPC function definitions, EXECUTE grants, and function comments. No DDL changes, no RLS policy changes, no table modifications.

### 5.2 Execution Model: SECURITY INVOKER

All 7 RPCs will be `SECURITY INVOKER` — consistent with the established pattern from `20260821090004_entity_model_rpcs.sql` and `20260819090003_foundational_rpcs.sql`. RLS applies inside the function body.

- **Read RPCs**: `anon` and `authenticated` roles can call them. The existing `SELECT` RLS policies (`using (true)`) allow full read access.
- **Write RPCs**: Only `service_role` receives EXECUTE grants. Since `service_role` bypasses RLS inherently, the RPCs can INSERT/UPDATE taxonomy tables directly. The EXECUTE grant restriction is the authorization gate — no `anon` or `authenticated` role can invoke write RPCs.

### 5.3 Response Envelope Contract

All RPCs return `jsonb` following the established envelope:

```json
{
  "success": true,
  "code": "PLT000",
  "message": "Descriptive success message.",
  "data": { ... }
}
```

Error codes reused from the existing contract:
- `PLT003` — Validation error (empty name, invalid slug format, missing required field)
- `PLT004` — Not found (industry/profession ID does not exist)
- `PLT005` — Conflict (duplicate slug)

### 5.4 Read RPC Design

**`taxonomy_industries_list(p_include_inactive boolean default false)`**
- Returns `jsonb` with `data` containing a JSON array of industry objects
- Default: only `is_active = true` industries, ordered by `sort_order`
- `p_include_inactive = true`: returns all industries (for admin views)
- Language: `sql` (pure SELECT, no procedural logic needed) — or `plpgsql` if input validation is added
- Volatility: `STABLE`

**`taxonomy_professions_list(p_industry_id uuid default null, p_include_inactive boolean default false)`**
- Returns `jsonb` with `data` containing a JSON array of profession objects
- `p_industry_id` filters by industry; `null` returns all professions
- Default: only `is_active = true` professions, ordered by `sort_order`
- Language: `plpgsql` (conditional WHERE clause construction)
- Volatility: `STABLE`

### 5.5 Write RPC Design

All write RPCs follow the established pattern:
1. Input validation (null checks, empty string checks, length constraints)
2. Slug format pre-validation (regex match before INSERT to produce PLT003 instead of raw 23514)
3. Existence checks for referenced records (PLT004)
4. Uniqueness pre-checks for slugs (PLT005 with meaningful message instead of raw 23505)
5. Perform the mutation
6. Audit log via `platform_audit_log_add()`
7. Return envelope with the mutated row

**`taxonomy_industry_create(p_slug text, p_name text, p_description text default null, p_sort_order integer default 0)`**
- Validates slug format (regex, length ≤140, lowercase)
- Validates name (non-empty, trimmed, ≤255 chars)
- Pre-checks slug uniqueness
- Inserts with `created_by = null` (admin/system-authored, not user-authored)
- Audit logs the creation

**`taxonomy_industry_update(p_industry_id uuid, p_name text default null, p_description text default null, p_sort_order integer default null, p_is_active boolean default null)`**
- Validates industry exists (PLT004)
- Validates each provided field (non-empty name, length constraints)
- Performs partial update (only provided fields are changed, using COALESCE pattern from `entity_profile_update`)
- Audit logs the mutation

**`taxonomy_profession_create(p_industry_id uuid, p_slug text, p_name text, p_description text default null, p_sort_order integer default 0)`**
- Validates industry exists and is active (PLT004)
- Validates slug format and uniqueness
- Validates name constraints
- Inserts with `created_by = null`
- Audit logs

**`taxonomy_profession_update(p_profession_id uuid, p_name text default null, p_description text default null, p_sort_order integer default null, p_is_active boolean default null)`**
- Validates profession exists (PLT004)
- Validates each provided field
- Partial update pattern
- Audit logs

**`taxonomy_profession_move(p_profession_id uuid, p_new_industry_id uuid)`**
- Validates profession exists (PLT004)
- Validates target industry exists and is active (PLT004)
- Prevents move to same industry (PLT003 — no-op detection)
- Updates `industry_id`
- Audit logs with old and new industry IDs

### 5.6 No Hardcoded Authentication Checks on Write RPCs

Write RPCs are `SECURITY INVOKER` with EXECUTE grants restricted to `service_role` only. The `service_role` bypasses RLS and is inherently trusted (Supabase admin/server-side context). An explicit `platform_is_authenticated()` check is unnecessary because:
- `anon` and `authenticated` roles have zero EXECUTE grant on these functions
- Any call from a non-service-role context fails with `42501` (insufficient privilege) before the function body executes

Read RPCs will also omit the authentication check since they are granted to `anon` (unauthenticated) — the RLS `using (true)` policies already permit public read.

### 5.7 EXECUTE Grant Strategy

```sql
-- Read RPCs: public access
grant execute on function public.taxonomy_industries_list(boolean) to anon, authenticated, service_role;
grant execute on function public.taxonomy_professions_list(uuid, boolean) to anon, authenticated, service_role;

-- Write RPCs: service-role only
grant execute on function public.taxonomy_industry_create(text, text, text, integer) to service_role;
grant execute on function public.taxonomy_industry_update(uuid, text, text, integer, boolean) to service_role;
grant execute on function public.taxonomy_profession_create(uuid, text, text, text, integer) to service_role;
grant execute on function public.taxonomy_profession_update(uuid, text, text, integer, boolean) to service_role;
grant execute on function public.taxonomy_profession_move(uuid, uuid) to service_role;
```

### 5.8 Reuse of Platform Helpers

All write RPCs reuse:
- `platform_raise_error(code, message)` — standardized error raising
- `platform_audit_log_add(action, entity, details)` — immutable audit trail (SECURITY DEFINER with pinned search_path)

Read RPCs reuse:
- Standard `jsonb_build_object()` envelope construction

---

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Taxonomy management RPCs migration | `supabase/migrations/<timestamp>_taxonomy_management_rpcs.sql` | **Create** — new SQL migration |
| pgTAP RPC enforcement test | `supabase/tests/database/010_taxonomy_rpc_enforcement.sql` | **Create** — new test file |

No client-side modules, Dart files, or Flutter components are created in this task.

---

## 7. Data Requirements

### 7.1 No New Tables

This task creates RPC functions only. No new tables, columns, indexes, or constraints are introduced.

### 7.2 Data Read Patterns

| RPC | Data Accessed | Filter Criteria | Ordering |
|---|---|---|---|
| `taxonomy_industries_list` | `industries` table | `is_active = true` (default) or all | `sort_order ASC` |
| `taxonomy_professions_list` | `professions` table | `industry_id` (optional), `is_active = true` (default) or all | `sort_order ASC` |

### 7.3 Data Write Patterns

| RPC | Mutation | Audit Action |
|---|---|---|
| `taxonomy_industry_create` | INSERT into `industries` | `taxonomy_industry_create` |
| `taxonomy_industry_update` | UPDATE `industries` | `taxonomy_industry_update` |
| `taxonomy_profession_create` | INSERT into `professions` | `taxonomy_profession_create` |
| `taxonomy_profession_update` | UPDATE `professions` | `taxonomy_profession_update` |
| `taxonomy_profession_move` | UPDATE `professions.industry_id` | `taxonomy_profession_move` |

---

## 8. Database Considerations

### 8.1 Existing Schema (No Modifications)

This task creates functions only. No DDL changes (CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE INDEX) are performed. The existing `industries` and `professions` tables, constraints, indexes, triggers, and RLS policies remain untouched.

### 8.2 Constraint Compliance via RPC Pre-Validation

Write RPCs pre-validate inputs before executing DML to produce meaningful PLT### error codes instead of raw PostgreSQL constraint violations:

| Constraint | RPC Pre-Validation | Error Code |
|---|---|---|
| `industries_slug_format` / `professions_slug_format` | Regex match `^[a-z0-9]+(-[a-z0-9]+)*$`, length ≤140, lowercase check | PLT003 |
| `industries_name_length` / `professions_name_length` | `char_length(btrim(name)) between 1 and 255` | PLT003 |
| `industries_slug_key` / `professions_slug_key` (UNIQUE) | Pre-check `EXISTS (SELECT 1 FROM ... WHERE slug = p_slug)` | PLT005 |
| `professions.industry_id` FK (ON DELETE RESTRICT) | Pre-check `EXISTS (SELECT 1 FROM industries WHERE id = p_industry_id)` | PLT004 |

### 8.3 Exception Handling for Race Conditions

Despite pre-validation, concurrent inserts could still produce constraint violations. Write RPCs wrap the DML in a `BEGIN...EXCEPTION` block to catch `unique_violation` (23505) and re-raise as PLT005, and `foreign_key_violation` (23503) and re-raise as PLT004.

### 8.4 Trigger Compatibility

The existing `industries_set_updated_at` and `professions_set_updated_at` triggers fire automatically on UPDATE. No trigger modifications needed. The `updated_at` column is managed by the trigger, not by the RPC.

### 8.5 Audit Log Integration

All write RPCs call `platform_audit_log_add()` which is SECURITY DEFINER with pinned `search_path = pg_catalog, public`. The audit details JSON includes:
- For create: the slug, name, and industry_id (for professions)
- For update: the record ID and changed fields
- For move: the profession_id, old industry_id, and new industry_id

### 8.6 `created_by` for Admin-Created Records

Write RPCs set `created_by = null` for new records (consistent with seed data convention — system/admin-authored, not user-authored). This is appropriate because taxonomy management is a service-role administrative operation.

---

## 9. API Requirements

### 9.1 RPC API Surface

| RPC | HTTP Method (PostgREST) | Access | Returns |
|---|---|---|---|
| `taxonomy_industries_list` | POST `/rest/v1/rpc/taxonomy_industries_list` | anon, authenticated, service_role | `jsonb` envelope with array of industries |
| `taxonomy_professions_list` | POST `/rest/v1/rpc/taxonomy_professions_list` | anon, authenticated, service_role | `jsonb` envelope with array of professions |
| `taxonomy_industry_create` | POST `/rest/v1/rpc/taxonomy_industry_create` | service_role only | `jsonb` envelope with created industry |
| `taxonomy_industry_update` | POST `/rest/v1/rpc/taxonomy_industry_update` | service_role only | `jsonb` envelope with updated industry |
| `taxonomy_profession_create` | POST `/rest/v1/rpc/taxonomy_profession_create` | service_role only | `jsonb` envelope with created profession |
| `taxonomy_profession_update` | POST `/rest/v1/rpc/taxonomy_profession_update` | service_role only | `jsonb` envelope with updated profession |
| `taxonomy_profession_move` | POST `/rest/v1/rpc/taxonomy_profession_move` | service_role only | `jsonb` envelope with moved profession |

### 9.2 No REST Endpoints

All access is via Supabase RPC invocation (PostgREST `/rpc/` path). No custom REST endpoints, Edge Functions, or API routes are created.

---

## 10. User Interface Requirements

None. This task produces no UI components. The taxonomy browsing UI is EP-02-07. Admin taxonomy management UI is a future task.

---

## 11. User Experience Considerations

While this task has no direct UI, the RPCs directly impact UX:

- **Consistent envelope**: Client-side taxonomy engine (EP-02-07) receives the same `{success, code, message, data}` envelope as all other RPCs, simplifying error handling and data extraction
- **Ordered results**: `sort_order` ordering ensures industries and professions display in a logical, curated sequence during onboarding
- **Active filtering**: Default `is_active = true` filtering ensures deactivated taxonomy entries don't appear in user-facing pickers
- **Meaningful errors**: PLT003/PLT004/PLT005 error codes with descriptive messages enable the client to display actionable feedback

---

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Write authorization | EXECUTE grants restricted to `service_role` only. `anon` and `authenticated` receive `42501` (insufficient privilege) on any write RPC call attempt |
| Read authorization | Read RPCs granted to `anon, authenticated, service_role`. Data is public classification (names, slugs, descriptions) — no sensitive information |
| RLS posture unchanged | No new RLS policies, GRANT, or REVOKE on `industries`/`professions` tables. Existing public-read + service-role-write posture preserved |
| No SECURITY DEFINER | All 7 RPCs are SECURITY INVOKER. No new SECURITY DEFINER functions introduced (consistent with `008_full_schema_posture_audit.sql` assertion) |
| Audit trail | All write mutations logged via `platform_audit_log_add()` with action, entity, and details |
| Input validation | All inputs validated server-side before DML execution. SQL injection prevented by parameterized queries (PL/pgSQL `USING` clause or direct variable references) |
| Slug pre-validation | Regex and uniqueness checked before INSERT to produce meaningful PLT### errors, not raw constraint violations |
| No secrets exposure | No credentials, keys, or PII in taxonomy data or RPC logic |
| `revoke execute` discipline | Migration begins with `revoke execute on all functions in schema public from public` (consistent with existing pattern) before granting specific EXECUTE rights |

---

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Read query optimization | `taxonomy_industries_list` uses `industries_is_active_sort_idx` index. `taxonomy_professions_list` uses `professions_is_active_industry_idx` composite index |
| Result set size | Initial dataset: 8 industries, 46 professions. Negligible payload size. Future growth to hundreds of records remains well within performance bounds |
| Volatility marking | Read RPCs marked `STABLE` (consistent results within a transaction, allows query planner optimization). Write RPCs marked `VOLATILE` |
| No N+1 queries | `taxonomy_professions_list` returns all professions for an industry in a single query. No nested lookups |
| Audit log writes | `platform_audit_log_add()` is SECURITY DEFINER with pinned search_path — minimal overhead per mutation |
| No locking concerns | Write RPCs operate on individual rows. No table-level locks. Concurrent writes to different taxonomy records do not block each other |

---

## 14. Testing Strategy

### 14.1 pgTAP RPC Enforcement Test

Create `supabase/tests/database/010_taxonomy_rpc_enforcement.sql` validating:

**Authorization Tests:**

| Test | Assertion |
|---|---|
| anon can call `taxonomy_industries_list` | `lives_ok` |
| anon can call `taxonomy_professions_list` | `lives_ok` |
| authenticated can call `taxonomy_industries_list` | `lives_ok` |
| authenticated can call `taxonomy_professions_list` | `lives_ok` |
| anon cannot call `taxonomy_industry_create` | `throws_ok` with `42501` |
| anon cannot call `taxonomy_industry_update` | `throws_ok` with `42501` |
| anon cannot call `taxonomy_profession_create` | `throws_ok` with `42501` |
| anon cannot call `taxonomy_profession_update` | `throws_ok` with `42501` |
| anon cannot call `taxonomy_profession_move` | `throws_ok` with `42501` |
| authenticated cannot call `taxonomy_industry_create` | `throws_ok` with `42501` |
| authenticated cannot call `taxonomy_industry_update` | `throws_ok` with `42501` |
| authenticated cannot call `taxonomy_profession_create` | `throws_ok` with `42501` |
| authenticated cannot call `taxonomy_profession_update` | `throws_ok` with `42501` |
| authenticated cannot call `taxonomy_profession_move` | `throws_ok` with `42501` |
| service_role can call all write RPCs | `lives_ok` |

**Validation Tests (service_role context):**

| Test | Assertion |
|---|---|
| `taxonomy_industry_create` with empty slug | Raises PLT003 |
| `taxonomy_industry_create` with invalid slug format (uppercase, spaces) | Raises PLT003 |
| `taxonomy_industry_create` with empty name | Raises PLT003 |
| `taxonomy_industry_create` with duplicate slug | Raises PLT005 |
| `taxonomy_industry_update` with non-existent ID | Raises PLT004 |
| `taxonomy_profession_create` with non-existent industry_id | Raises PLT004 |
| `taxonomy_profession_create` with inactive industry | Raises PLT004 |
| `taxonomy_profession_create` with duplicate slug | Raises PLT005 |
| `taxonomy_profession_update` with non-existent ID | Raises PLT004 |
| `taxonomy_profession_move` with non-existent profession | Raises PLT004 |
| `taxonomy_profession_move` with non-existent target industry | Raises PLT004 |
| `taxonomy_profession_move` to same industry (no-op) | Raises PLT003 |

**Functional Tests (service_role context):**

| Test | Assertion |
|---|---|
| `taxonomy_industries_list` returns seeded industries | Result count = 8, envelope `success = true` |
| `taxonomy_professions_list` with industry filter | Returns correct count for filtered industry |
| `taxonomy_professions_list` without filter | Returns all 46 professions |
| `taxonomy_industry_create` creates valid industry | Envelope `success = true`, returned row has correct slug/name |
| `taxonomy_industry_update` updates name | Returned row reflects new name |
| `taxonomy_industry_update` deactivates (is_active = false) | Returned row has `is_active = false` |
| `taxonomy_profession_create` creates valid profession | Envelope `success = true`, FK valid |
| `taxonomy_profession_update` updates name | Returned row reflects new name |
| `taxonomy_profession_move` changes industry_id | Returned row has new `industry_id` |

**Envelope Contract Tests:**

| Test | Assertion |
|---|---|
| All RPCs return `jsonb` with `success`, `code`, `message`, `data` keys | Structural assertion on return type |
| Success responses have `code = 'PLT000'` | Envelope compliance |
| Error responses have appropriate PLT### codes | Envelope compliance |

**Security Posture Tests:**

| Test | Assertion |
|---|---|
| No new SECURITY DEFINER functions with `taxonomy_` prefix | Consistent with `008` posture audit |
| All `taxonomy_` functions exist | Function existence assertions |

### 14.2 Test Execution

The test follows the established pgTAP pattern: `begin; set search_path to extensions, public; select plan(N); ... select * from finish(); rollback;`

### 14.3 Regression Testing

After implementation, the full test suite must pass without regression:
- `006_taxonomy_integrity.sql` — 15 assertions
- `008_full_schema_posture_audit.sql` — 20 assertions (specifically the "no entity_* SECURITY DEFINER" assertion must still pass; taxonomy_ functions are not entity_ prefixed)
- `009_taxonomy_seed_verification.sql` — all assertions
- All other existing tests (001–009)

---

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Create migration file with correct timestamp naming: `supabase/migrations/<timestamp>_taxonomy_management_rpcs.sql` | Migration file scaffolded |
| 2 | Add migration header comment block documenting purpose (EP-02-02), execution model, envelope contract, and grant strategy | Documentation |
| 3 | Implement `taxonomy_industries_list` read RPC (SQL or PL/pgSQL, STABLE) | Read RPC |
| 4 | Implement `taxonomy_professions_list` read RPC (PL/pgSQL, STABLE, with optional industry filter) | Read RPC |
| 5 | Implement `taxonomy_industry_create` write RPC with full validation and audit logging | Write RPC |
| 6 | Implement `taxonomy_industry_update` write RPC with partial update pattern and audit logging | Write RPC |
| 7 | Implement `taxonomy_profession_create` write RPC with FK validation, slug uniqueness, and audit logging | Write RPC |
| 8 | Implement `taxonomy_profession_update` write RPC with partial update pattern and audit logging | Write RPC |
| 9 | Implement `taxonomy_profession_move` write RPC with dual existence checks and no-op detection | Write RPC |
| 10 | Add `revoke execute on all functions in schema public from public` and specific EXECUTE grants | Authorization |
| 11 | Add `comment on function` documentation for all 7 RPCs | Documentation |
| 12 | Create pgTAP test file `010_taxonomy_rpc_enforcement.sql` with full authorization, validation, functional, and envelope tests | Test file |
| 13 | Run migration via `supabase db push` (or local `supabase db reset`) | Migration applied |
| 14 | Run pgTAP test suite (`supabase db test`) to verify all new tests pass | All tests pass |
| 15 | Run existing test suite (001–009) to confirm no regressions | No regressions |

---

## 16. Expected Outcome

- 7 taxonomy management RPCs deployed: 2 public read + 5 service-role-only write
- All RPCs return the standard `{success, code, message, data}` envelope
- Write RPCs enforce input validation (PLT003), existence checks (PLT004), and uniqueness constraints (PLT005) server-side with meaningful error messages
- All write mutations are audit-logged via `platform_audit_log_add()`
- EXECUTE grants correctly restrict write RPCs to `service_role` only; `anon` and `authenticated` receive `42501` on write attempts
- Read RPCs accessible to `anon`, `authenticated`, and `service_role`
- No new SECURITY DEFINER functions introduced
- No schema DDL, RLS policy, or grant changes on existing tables
- pgTAP test `010_taxonomy_rpc_enforcement.sql` passes all authorization, validation, functional, and envelope assertions
- Existing pgTAP tests (001–009) pass without regression
- EP-02-03 (Verification & Admin Review Schema) and EP-02-07 (Client-Side Taxonomy Engine) unblocked

---

## 17. Definition of Done (DoD)

| # | Criterion | Verification Method |
|---|---|---|
| 1 | Migration file exists at `supabase/migrations/<timestamp>_taxonomy_management_rpcs.sql` with correct naming and timestamp ordering | File inspection |
| 2 | 7 RPC functions created: `taxonomy_industries_list`, `taxonomy_professions_list`, `taxonomy_industry_create`, `taxonomy_industry_update`, `taxonomy_profession_create`, `taxonomy_profession_update`, `taxonomy_profession_move` | `SELECT proname FROM pg_proc WHERE proname LIKE 'taxonomy_%'` = 7 rows |
| 3 | All 7 RPCs are SECURITY INVOKER (none are SECURITY DEFINER) | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'taxonomy_%' AND prosecdef` = 0 |
| 4 | Read RPCs granted to `anon, authenticated, service_role` | Grant inspection query |
| 5 | Write RPCs granted to `service_role` only | Grant inspection query |
| 6 | `anon` cannot invoke any write RPC (throws 42501) | pgTAP `throws_ok` |
| 7 | `authenticated` cannot invoke any write RPC (throws 42501) | pgTAP `throws_ok` |
| 8 | `taxonomy_industries_list` returns seeded 8 industries with correct envelope | pgTAP assertion |
| 9 | `taxonomy_professions_list` returns correct filtered/unfiltered results with correct envelope | pgTAP assertion |
| 10 | `taxonomy_industry_create` validates slug format (PLT003), uniqueness (PLT005), and name constraints (PLT003) | pgTAP `throws_ok` |
| 11 | `taxonomy_industry_update` validates existence (PLT004) and performs partial update | pgTAP assertion |
| 12 | `taxonomy_profession_create` validates industry FK (PLT004), slug uniqueness (PLT005), and name constraints (PLT003) | pgTAP `throws_ok` |
| 13 | `taxonomy_profession_update` validates existence (PLT004) and performs partial update | pgTAP assertion |
| 14 | `taxonomy_profession_move` validates both profession and target industry existence (PLT004), rejects no-op (PLT003) | pgTAP `throws_ok` |
| 15 | All write RPCs produce audit log entries | Audit log count assertion post-mutation |
| 16 | All RPCs return `{success, code, message, data}` envelope | Envelope structure assertion |
| 17 | No DDL statements in migration (no CREATE/ALTER/DROP TABLE) | Migration file review |
| 18 | No RLS policy changes, table GRANT/REVOKE statements in migration | Migration file review |
| 19 | No client-side code created — no files added under `lib/` | File inspection |
| 20 | pgTAP test `010_taxonomy_rpc_enforcement.sql` exists and passes all assertions | `supabase db test` |
| 21 | Existing pgTAP tests (001–009) pass without regression | `supabase db test` — full suite zero failures |
| 22 | Migration header comment block documents purpose, EP reference, execution model, and grant strategy | Code review |
| 23 | All 7 RPCs have `comment on function` documentation | `SELECT obj_description(oid) FROM pg_proc WHERE proname LIKE 'taxonomy_%'` — all non-null |
| 24 | EP-02-03 and EP-02-07 unblocked | Dependency check |

---

## 18. Implementation AI Execution Profile

| Attribute | Recommendation |
|---|---|
| **Recommended Coding Reasoning Level** | **Very High** |
| **Reasoning Level Justification** | This task requires Very High reasoning due to the convergence of multiple complexity factors: (1) **Security risk** — write RPC authorization gates must be airtight; any EXECUTE grant misconfiguration exposes taxonomy mutation to unauthenticated or authenticated users, violating the service-role-only constraint. (2) **Integration complexity** — 7 RPCs must interoperate with existing platform helpers (`platform_raise_error`, `platform_audit_log_add`), respect the established envelope contract, and maintain consistency with 5 existing entity RPCs. (3) **Validation complexity** — each write RPC requires multi-layer input validation (format, length, existence, uniqueness) with correct PLT### error code mapping and race-condition exception handling. (4) **Test complexity** — the pgTAP test must cover 3 authorization roles × 7 RPCs × multiple validation paths, requiring careful role-switching, fixture management, and assertion counting. (5) **Business impact** — taxonomy is the universal classification backbone; incorrect CRUD behavior propagates to onboarding, verification, and marketplace discovery. The EP-02 Phase Plan assigns this task a Coding Reasoning of **Very High**, which aligns with the task's characteristics: security-sensitive server-side RPC development with multi-role authorization, comprehensive validation, and exhaustive test coverage requirements. |
