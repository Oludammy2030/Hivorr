# Definition of Done — EP-02-03: Verification & Admin Review Schema Extension

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-03 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-03-Verification & Admin Review Schema Extension.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-03 |
| **Task Name** | Verification & Admin Review Schema Extension |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 2 — Extended Server-Side Schema |
| **Priority** | Critical |
| **Dependencies** | EP-02-02 (Taxonomy Management RPCs & Server-Side Registry — completed) |
| **Blocks** | EP-02-04 (Financial Integrity Schema), EP-02-10 (Identity Verification), EP-02-11 (Trade Verification), EP-02-12 (KYC Framework), EP-02-16 (Payout & Deposit Verification) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-03-Verification & Admin Review Schema Extension.md` |

---

## 2. Functional Verification

This task creates 5 database tables, 4 tiers of seed data, and 6 server-side PostgreSQL RPC functions for verification workflow and admin review. There are no user-facing workflows or UI components. Functional verification confirms the schema and RPCs behave correctly under all authorized and unauthorized invocation scenarios.

### 2.1 Required Functionality — Table DDL (5 Tables)

- [ ] **FV-01:** `kyc_tiers` table exists with correct columns (`tier_code` PK, `name`, `description`, `daily_limit`, `weekly_limit`, `monthly_limit`, `cashout_limit`, `is_active`, `sort_order`, audit cols)
- [ ] **FV-02:** `kyc_tiers` has CHECK constraint enforcing `tier_code ~ '^tier_[0-9]+$'` and non-negative limits, plus `is_active_sort_idx` index and `platform_set_updated_at` trigger
- [ ] **FV-03:** `entity_kyc_levels` table exists with correct columns (`id`, `entity_id`, `tier_code`, `status`, `assigned_at`, `assigned_by`, `expires_at`, audit cols)
- [ ] **FV-04:** `entity_kyc_levels` has UNIQUE `(entity_id)` and FK references to `entities(id)` (CASCADE) and `kyc_tiers(tier_code)`, plus `platform_set_updated_at` trigger
- [ ] **FV-05:** `verification_submissions` table exists with correct columns (`id`, `entity_id`, `credential_id`, `submission_type`, `status`, `priority`, `assigned_reviewer`, `submitted_at`, `reviewed_at`, `reviewed_by`, `decision_notes`, audit cols)
- [ ] **FV-06:** `verification_submissions` has FK references to `entities(id)` (CASCADE) and `entity_credentials(id)` (RESTRICT), the `verification_submissions_review_consistency` CHECK, all 5 indexes, and `platform_set_updated_at` trigger
- [ ] **FV-07:** `verification_reviews` table exists with correct columns (`id`, `submission_id`, `entity_id`, `reviewer_id`, `decision`, `decision_notes`, `created_at`, `created_by`) — no `updated_at` column
- [ ] **FV-08:** `verification_reviews` has FK references to `verification_submissions(id)` (CASCADE) and `entities(id)` (CASCADE), plus `submission_id_idx` and `entity_idx` indexes
- [ ] **FV-09:** `verification_audit_trail` table exists with correct columns (`id`, `entity_id`, `event_type`, `subject_type`, `subject_id`, `from_state`, `to_state`, `actor_id`, `details`, `created_at`) — no `updated_at` column
- [ ] **FV-10:** `verification_audit_trail` has FK reference to `entities(id)` (SET NULL), plus `entity_idx` and `created_at_idx` indexes

### 2.2 Required Functionality — Seed Data

- [ ] **FV-11:** `kyc_tiers` seeded with exactly 4 rows (`tier_0`, `tier_1`, `tier_2`, `tier_3`)
- [ ] **FV-12:** Seed limits match approved values: `tier_0` all 0; `tier_1` (50k/200k/800k/100k); `tier_2` (200k/800k/3M/500k); `tier_3` (1M/4M/15M/2M)
- [ ] **FV-13:** Seed is idempotent — uses `INSERT ... ON CONFLICT (tier_code) DO NOTHING`

### 2.3 Required Functionality — RPCs (6 Functions)

- [ ] **FV-14:** `verification_submit(p_credential_id uuid, p_submission_type text default null)` function exists and queues a credential for review
- [ ] **FV-15:** `verification_review_approve(p_submission_id uuid, p_notes text default null)` function exists and approves + propagates status
- [ ] **FV-16:** `verification_review_reject(p_submission_id uuid, p_notes text default null)` function exists and rejects without propagation
- [ ] **FV-17:** `verification_status_get(p_entity_id uuid default null)` function exists and returns aggregated verification status
- [ ] **FV-18:** `verification_kyc_level_get()` function exists and returns current KYC tier + limits
- [ ] **FV-19:** `verification_limits_get()` function exists and returns applicable transaction/cashout limits

### 2.4 Expected Workflows

- [ ] **FV-20:** Full identity verification lifecycle: submit identity credential → status `pending` → admin approve → `entity_kyc_levels` upserted to `tier_1` active
- [ ] **FV-21:** Full trade verification lifecycle: submit trade proof → status `pending` → admin approve → `entity_professions.trade_verification_status = 'approved'` (Rule 2 gate flipped)
- [ ] **FV-22:** Rejection lifecycle: submit → admin reject → submission status `rejected`, no KYC tier change, no trade gate flip
- [ ] **FV-23:** Limit query: entity at `tier_1` → `verification_limits_get` returns `tier_1` limits matching seed data
- [ ] **FV-24:** Status aggregation: entity with multiple submissions → `verification_status_get` returns correct aggregate of identity/trade/KYC state
- [ ] **FV-25:** Audit trail completeness: every submission, approval, rejection, KYC assignment, and trade propagation produces `verification_audit_trail` rows
- [ ] **FV-26:** Decision immutability: every review produces a `verification_reviews` row that cannot be updated or deleted

### 2.5 Success Conditions

- [ ] **FV-27:** All 6 RPCs return `jsonb` with `success = true` and `code = 'PLT000'` on successful operations
- [ ] **FV-28:** `verification_submit` returns the created submission row within the `data` field of the envelope
- [ ] **FV-29:** `verification_review_approve` returns the updated submission row with propagated state within the `data` field
- [ ] **FV-30:** `verification_review_reject` returns the updated submission row within the `data` field
- [ ] **FV-31:** Read RPCs (`verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`) return structured status/limit data in the `data` field

### 2.6 Error Handling Scenarios — Authentication (PLT001)

- [ ] **FV-32:** `verification_submit` without authentication raises PLT001
- [ ] **FV-33:** `verification_status_get` without authentication raises PLT001
- [ ] **FV-34:** `verification_kyc_level_get` without authentication raises PLT001
- [ ] **FV-35:** `verification_limits_get` without authentication raises PLT001

### 2.7 Error Handling Scenarios — Validation (PLT003)

- [ ] **FV-36:** `verification_submit` with NULL `p_credential_id` raises PLT003
- [ ] **FV-37:** `verification_submit` with invalid `p_submission_type` value raises PLT003
- [ ] **FV-38:** `verification_review_approve` with NULL `p_submission_id` raises PLT003
- [ ] **FV-39:** `verification_review_reject` with NULL `p_submission_id` raises PLT003

### 2.8 Error Handling Scenarios — Not Found (PLT004)

- [ ] **FV-40:** `verification_submit` with non-existent credential raises PLT004
- [ ] **FV-41:** `verification_submit` with credential not owned by caller raises PLT004
- [ ] **FV-42:** `verification_review_approve` with non-existent submission raises PLT004
- [ ] **FV-43:** `verification_review_reject` with non-existent submission raises PLT004
- [ ] **FV-44:** `verification_status_get` with another entity's ID (authenticated) returns empty or PLT004

### 2.9 Error Handling Scenarios — Conflict (PLT005)

- [ ] **FV-45:** `verification_submit` for a credential that already has an active (pending/in_review) submission raises PLT005
- [ ] **FV-46:** `verification_review_approve` on an already-decided submission raises PLT005 or is a guarded no-op

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Migration file is located in `supabase/migrations/` with naming pattern `<YYYYMMDD><HHMMSS>_verification_admin_review_schema.sql`
- [ ] **TV-02:** Migration timestamp places it after `20260829090002_taxonomy_management_rpcs.sql`
- [ ] **TV-03:** No DDL changes to any EP-01 table (`entities`, `entity_profiles`, `entity_roles`, `entity_credentials`, `entity_professions`, `entity_settings`, `entity_devices`, `industries`, `professions`)
- [ ] **TV-04:** No modifications to any existing RPC function
- [ ] **TV-05:** No client-side Dart code created — no files added under `lib/`
- [ ] **TV-06:** Migration header comment block documents purpose (EP-02-03), execution model (SECURITY INVOKER), envelope contract (`{success, code, message, data}`), and grant strategy

### 3.2 Required System Behavior — Function Properties

- [ ] **TV-07:** Exactly 6 functions exist with `verification_` prefix:
  ```sql
  SELECT proname FROM pg_proc WHERE proname LIKE 'verification_%';
  -- Expected: 6 rows
  ```
- [ ] **TV-08:** All 6 `verification_` functions are SECURITY INVOKER (none are SECURITY DEFINER):
  ```sql
  SELECT count(*) FROM pg_proc WHERE proname LIKE 'verification_%' AND prosecdef;
  -- Expected: 0
  ```
- [ ] **TV-09:** Read RPCs (`verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`) are marked `STABLE`
- [ ] **TV-10:** Write RPCs (`verification_submit`, `verification_review_approve`, `verification_review_reject`) are marked `VOLATILE`
- [ ] **TV-11:** All 6 RPCs return `jsonb` type
- [ ] **TV-12:** All 6 RPCs have `comment on function` documentation (non-null `obj_description`):
  ```sql
  SELECT proname, obj_description(oid) FROM pg_proc WHERE proname LIKE 'verification_%';
  -- All obj_description values non-null
  ```

### 3.3 Required System Behavior — Envelope Contract

- [ ] **TV-13:** Every successful RPC response contains exactly 4 top-level keys: `success`, `code`, `message`, `data`
- [ ] **TV-14:** Every successful response has `success = true` and `code = 'PLT000'`
- [ ] **TV-15:** Every error response raises a PostgreSQL exception with a message containing the PLT### code (PLT001/PLT003/PLT004/PLT005)
- [ ] **TV-16:** Write RPC `data` field contains the full mutated row as a JSON object
- [ ] **TV-17:** Read RPC `data` field contains structured status/limit data

### 3.4 Required System Behavior — Platform Helper Integration

- [ ] **TV-18:** Entity-facing write RPC (`verification_submit`) calls `platform_is_authenticated()` for auth gate
- [ ] **TV-19:** All RPCs use `platform_raise_error()` for validation failures (not raw `RAISE EXCEPTION`)
- [ ] **TV-20:** `verification_submit` may call `platform_audit_log_add()` for general mutation auditing
- [ ] **TV-21:** `verification_review_approve` and `verification_review_reject` write directly to `verification_audit_trail` (not `platform_audit_log_add`) due to service-role auth-context caveat
- [ ] **TV-22:** `platform_set_updated_at()` trigger attached to the 3 mutable tables (`kyc_tiers`, `entity_kyc_levels`, `verification_submissions`)

### 3.5 Required System Behavior — Status Propagation

- [ ] **TV-23:** `verification_review_approve` on identity/certification submission upserts `entity_kyc_levels` to assigned tier with `status = 'active'`
- [ ] **TV-24:** `verification_review_approve` on trade proof submission sets `entity_professions.trade_verification_status = 'approved'`, `verified_at = now()`, `verified_by = <reviewer>` for the linked profession binding
- [ ] **TV-25:** `verification_review_reject` does NOT modify `entity_kyc_levels` or `entity_professions`
- [ ] **TV-26:** Status propagation is the only authorized path that advances the Rule 2 trade gate (client grants exclude `trade_verification_status`, `verified_at`, `verified_by`)

### 3.6 Module Integration

- [ ] **TV-27:** Migration does not modify or conflict with any existing migration files (`20260819090001` through `20260829090002`)
- [ ] **TV-28:** `verification_submissions.credential_id` FK correctly references `entity_credentials(id)`
- [ ] **TV-29:** `entity_kyc_levels.entity_id` FK correctly references `entities(id)`
- [ ] **TV-30:** `entity_kyc_levels.tier_code` FK correctly references `kyc_tiers(tier_code)`
- [ ] **TV-31:** `verification_reviews.submission_id` FK correctly references `verification_submissions(id)`

---

## 4. Data Verification

### 4.1 Data Creation — Tables

- [ ] **DV-01:** `kyc_tiers` table has correct column types, constraints, and defaults
- [ ] **DV-02:** `entity_kyc_levels` table has correct column types, constraints, UNIQUE on `entity_id`, and defaults
- [ ] **DV-03:** `verification_submissions` table has correct column types, constraints, review-consistency CHECK, and defaults
- [ ] **DV-04:** `verification_reviews` table has correct column types, constraints, and defaults (no `updated_at`)
- [ ] **DV-05:** `verification_audit_trail` table has correct column types, constraints, and defaults (no `updated_at`)

### 4.2 Data Creation — Seed Data

- [ ] **DV-06:** `kyc_tiers` contains exactly 4 rows after migration
- [ ] **DV-07:** `tier_0` has all limits = 0
- [ ] **DV-08:** `tier_1` limits: daily 50,000 / weekly 200,000 / monthly 800,000 / cashout 100,000
- [ ] **DV-09:** `tier_2` limits: daily 200,000 / weekly 800,000 / monthly 3,000,000 / cashout 500,000
- [ ] **DV-10:** `tier_3` limits: daily 1,000,000 / weekly 4,000,000 / monthly 15,000,000 / cashout 2,000,000
- [ ] **DV-11:** All seed rows have `is_active = true`
- [ ] **DV-12:** Seed is idempotent — re-running does not create duplicate `tier_code` rows

### 4.3 Data Creation via RPCs

- [ ] **DV-13:** `verification_submit` inserts a row into `verification_submissions` with `status = 'pending'`, correct `entity_id`, `credential_id`, `submission_type`
- [ ] **DV-14:** `verification_submit` produces a `verification_audit_trail` row with `event_type = 'submission_created'`
- [ ] **DV-15:** `verification_review_approve` updates `verification_submissions.status` to `'approved'`, sets `reviewed_at` and `reviewed_by`
- [ ] **DV-16:** `verification_review_approve` inserts a `verification_reviews` row with `decision = 'approved'`
- [ ] **DV-17:** `verification_review_approve` inserts `verification_audit_trail` rows for `review_approved` and any propagation events (`kyc_level_assigned`, `trade_status_propagated`)
- [ ] **DV-18:** `verification_review_reject` updates `verification_submissions.status` to `'rejected'`, sets `reviewed_at` and `reviewed_by`
- [ ] **DV-19:** `verification_review_reject` inserts a `verification_reviews` row with `decision = 'rejected'`
- [ ] **DV-20:** `verification_review_reject` inserts a `verification_audit_trail` row for `review_rejected`

### 4.4 Data Relationships

- [ ] **DV-21:** `verification_submissions.credential_id` references a valid `entity_credentials(id)` — zero orphaned submissions
- [ ] **DV-22:** `verification_submissions.entity_id` references a valid `entities(id)` — zero orphaned submissions
- [ ] **DV-23:** `entity_kyc_levels.entity_id` references a valid `entities(id)` — zero orphaned KYC assignments
- [ ] **DV-24:** `entity_kyc_levels.tier_code` references a valid `kyc_tiers(tier_code)` — zero invalid tier assignments
- [ ] **DV-25:** `verification_reviews.submission_id` references a valid `verification_submissions(id)` — zero orphaned reviews
- [ ] **DV-26:** `verification_audit_trail.entity_id` references `entities(id)` with ON DELETE SET NULL — nullable FK

### 4.5 Data Accuracy

- [ ] **DV-27:** `verification_submissions` review-consistency CHECK enforced: pending/in_review rows have `reviewed_at IS NULL AND reviewed_by IS NULL`; decided rows have `reviewed_at IS NOT NULL`
- [ ] **DV-28:** `kyc_tiers.tier_code` CHECK enforced: matches `^tier_[0-9]+$`
- [ ] **DV-29:** All limit columns in `kyc_tiers` are non-negative (CHECK constraint)
- [ ] **DV-30:** `verification_submissions.submission_type` restricted to `identity_document | trade_proof | certification`
- [ ] **DV-31:** `verification_submissions.status` restricted to `pending | in_review | approved | rejected | requires_resubmission`
- [ ] **DV-32:** `verification_reviews.decision` restricted to `approved | rejected | requires_resubmission`
- [ ] **DV-33:** `verification_audit_trail.event_type` restricted to defined vocabulary

### 4.6 Data Integrity

- [ ] **DV-34:** `entity_kyc_levels` UNIQUE(entity_id) enforced — one current tier per entity
- [ ] **DV-35:** `verification_reviews` has no `updated_at` column and no UPDATE/DELETE grants — immutability enforced
- [ ] **DV-36:** `verification_audit_trail` has no `updated_at` column and no UPDATE/DELETE grants — append-only enforced
- [ ] **DV-37:** `updated_at` is automatically set by the `platform_set_updated_at()` trigger on all 3 mutable tables
- [ ] **DV-38:** FK ON DELETE CASCADE on `entity_kyc_levels`, `verification_submissions`, `verification_reviews` — cascading cleanup on entity deletion
- [ ] **DV-39:** FK ON DELETE RESTRICT on `verification_submissions.credential_id` — prevents credential deletion while submission exists
- [ ] **DV-40:** Race condition handling: concurrent `verification_submit` for same credential results in one success (PLT000) and one conflict error (PLT005)
- [ ] **DV-41:** Existing EP-01 seed data and taxonomy seed data unchanged after migration

---

## 5. Security Verification

### 5.1 Authentication

- [ ] **SV-01:** Migration does not alter any authentication configuration or `auth.*` tables
- [ ] **SV-02:** Entity-facing RPCs (`verification_submit`, `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`) enforce `platform_is_authenticated()` — unauthenticated calls raise PLT001

### 5.2 Authorization & Access Control — EXECUTE Grants

- [ ] **SV-03:** `verification_submit` EXECUTE granted to `authenticated` and `service_role`
- [ ] **SV-04:** `verification_status_get` EXECUTE granted to `authenticated` and `service_role`
- [ ] **SV-05:** `verification_kyc_level_get` EXECUTE granted to `authenticated` and `service_role`
- [ ] **SV-06:** `verification_limits_get` EXECUTE granted to `authenticated` and `service_role`
- [ ] **SV-07:** `verification_review_approve` EXECUTE granted to `service_role` only
- [ ] **SV-08:** `verification_review_reject` EXECUTE granted to `service_role` only
- [ ] **SV-09:** No EXECUTE grants to `anon` on any of the 6 RPCs
- [ ] **SV-10:** No EXECUTE grants to `authenticated` on `verification_review_approve` or `verification_review_reject`:
  ```sql
  SELECT grantee, routine_name
  FROM information_schema.routine_privileges
  WHERE routine_schema = 'public'
    AND routine_name LIKE 'verification_%'
    AND grantee IN ('anon', 'authenticated')
    AND routine_name NOT IN ('verification_submit', 'verification_status_get', 'verification_kyc_level_get', 'verification_limits_get');
  -- Expected: 0 rows
  ```

### 5.3 Authorization & Access Control — Enforcement

- [ ] **SV-11:** `anon` role calling `verification_submit` throws `42501`
- [ ] **SV-12:** `anon` role calling `verification_review_approve` throws `42501`
- [ ] **SV-13:** `anon` role calling `verification_review_reject` throws `42501`
- [ ] **SV-14:** `anon` role calling `verification_status_get` throws `42501`
- [ ] **SV-15:** `anon` role calling `verification_kyc_level_get` throws `42501`
- [ ] **SV-16:** `anon` role calling `verification_limits_get` throws `42501`
- [ ] **SV-17:** `authenticated` role calling `verification_review_approve` throws `42501`
- [ ] **SV-18:** `authenticated` role calling `verification_review_reject` throws `42501`
- [ ] **SV-19:** `service_role` can successfully invoke all 6 RPCs without authorization errors

### 5.4 RLS & Table-Level Grants

- [ ] **SV-20:** All 5 new tables have RLS enabled (`relrowsecurity = true`)
- [ ] **SV-21:** `anon` has zero grants on all 5 new tables
- [ ] **SV-22:** `authenticated` has SELECT only on `kyc_tiers`
- [ ] **SV-23:** `authenticated` has SELECT (self-scoped) on `entity_kyc_levels`, `verification_submissions`, `verification_reviews`, `verification_audit_trail`
- [ ] **SV-24:** `authenticated` has INSERT (limited columns) on `verification_submissions` — columns `entity_id, credential_id, submission_type, priority` only; `status`, `reviewed_at`, `reviewed_by` excluded
- [ ] **SV-25:** `authenticated` has INSERT (self-scoped) on `verification_audit_trail`
- [ ] **SV-26:** `authenticated` has zero INSERT/UPDATE on `entity_kyc_levels`
- [ ] **SV-27:** `verification_reviews` has no UPDATE/DELETE grant to any role
- [ ] **SV-28:** `verification_audit_trail` has no UPDATE/DELETE grant to any role

### 5.5 RLS Policies

- [ ] **SV-29:** `verification_submissions_authenticated_select` policy exists (using `entity_id = auth.uid()`)
- [ ] **SV-30:** `verification_submissions_authenticated_insert` policy exists (with check `entity_id = auth.uid()`; column-restricted)
- [ ] **SV-31:** `entity_kyc_levels_authenticated_select` policy exists
- [ ] **SV-32:** `verification_reviews_authenticated_select` policy exists
- [ ] **SV-33:** `verification_audit_trail_authenticated_select` policy exists
- [ ] **SV-34:** `verification_audit_trail_authenticated_insert` policy exists (with check `entity_id = auth.uid()`)

### 5.6 Security Posture

- [ ] **SV-35:** No new SECURITY DEFINER functions introduced with `verification_` prefix:
  ```sql
  SELECT count(*) FROM pg_proc
  WHERE proname LIKE 'verification_%' AND prosecdef;
  -- Expected: 0
  ```
- [ ] **SV-36:** No SQL injection vectors — all RPCs use parameterized PL/pgSQL variable references
- [ ] **SV-37:** No secrets, credentials, API keys, or PII in any RPC function body or comment
- [ ] **SV-38:** `decision_notes` fields are admin-authored free text with length constraints
- [ ] **SV-39:** Realtime excludes all 5 new tables from `supabase_realtime` publication

### 5.7 Trade Gate Integrity

- [ ] **SV-40:** `trade_verification_status` on `entity_professions` is advanced only inside `verification_review_approve` — no other authorized path exists
- [ ] **SV-41:** Client grants on `entity_professions` continue to exclude `trade_verification_status`, `verified_at`, `verified_by` columns
- [ ] **SV-42:** No client-side bypass of the Rule 2 trade gate is possible

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] **PV-01:** `verification_status_get` uses indexed lookups on `entity_id` — no sequential scans on default query
- [ ] **PV-02:** `verification_kyc_level_get` uses `entity_kyc_levels_entity_id_key` unique index
- [ ] **PV-03:** `verification_limits_get` joins `entity_kyc_levels` with `kyc_tiers` via indexed FK — single query, no N+1
- [ ] **PV-04:** `verification_submit` performs indexed existence checks before insert — no table scans
- [ ] **PV-05:** Read RPCs marked `STABLE` allow PostgreSQL query planner optimization

### 6.2 Resource Usage

- [ ] **PV-06:** Migration creates exactly 6 functions — no duplicate or orphaned definitions
- [ ] **PV-07:** Write RPCs operate on individual rows — no table-level locks acquired during mutation
- [ ] **PV-08:** Audit trail inserts are append-only with indexed `created_at`/`entity_id` — negligible overhead
- [ ] **PV-09:** 9 indexes created across 5 tables — appropriate for query patterns

### 6.3 System Reliability

- [ ] **PV-10:** `platform_set_updated_at()` triggers fire correctly on all 3 mutable tables
- [ ] **PV-11:** `verification_audit_trail` direct inserts from review RPCs do not cause transaction failures
- [ ] **PV-12:** Status propagation UPDATEs on `entity_professions` and UPSERTs on `entity_kyc_levels` are single-row operations — no deadlock risk
- [ ] **PV-13:** All FK references are valid — zero constraint violation risk under normal operation

---

## 7. Testing Verification

### 7.1 Automated Testing — pgTAP Schema Posture

- [ ] **TT-01:** Test file exists at `supabase/tests/database/011_verification_schema_posture.sql`
- [ ] **TT-02:** Test follows established pgTAP pattern: `begin; set search_path to extensions, public; select plan(N); ... select * from finish(); rollback;`
- [ ] **TT-03:** Asserts all 5 tables exist (`has_table` ×5)
- [ ] **TT-04:** Asserts RLS enabled on all 5 tables
- [ ] **TT-05:** Asserts `anon` has zero grants on all 5 new tables
- [ ] **TT-06:** Asserts `verification_submissions.status/reviewed_at/reviewed_by` not writable by `authenticated`
- [ ] **TT-07:** Asserts `entity_kyc_levels` not INSERT/UPDATE writable by `authenticated`
- [ ] **TT-08:** Asserts `verification_reviews` has no UPDATE/DELETE grant to any role
- [ ] **TT-09:** Asserts `verification_audit_trail` has no UPDATE/DELETE grant to any role
- [ ] **TT-10:** Asserts triggers present on 3 mutable tables
- [ ] **TT-11:** Asserts no `verification_%` SECURITY DEFINER function
- [ ] **TT-12:** Asserts Realtime excludes all 5 tables
- [ ] **TT-13:** Asserts comments present on all 5 new tables
- [ ] **TT-14:** Asserts `kyc_tiers` seeded with 4 rows
- [ ] **TT-15:** All assertions in `011` pass — zero failures

### 7.2 Automated Testing — pgTAP RPC Enforcement

- [ ] **TT-16:** Test file exists at `supabase/tests/database/012_verification_rpc_enforcement.sql`
- [ ] **TT-17:** Test follows established pgTAP pattern
- [ ] **TT-18:** Asserts authorization: `anon` cannot call any RPC (42501), `authenticated` cannot call review RPCs (42501), `authenticated` can call entity-facing RPCs, `service_role` can call all 6
- [ ] **TT-19:** Asserts validation: NULL credential_id (PLT003), non-owned credential (PLT004), duplicate active submission (PLT005), missing submission (PLT004), already-decided submission (PLT005)
- [ ] **TT-20:** Asserts functional: submit → pending, approve identity → KYC tier assigned, approve trade → Rule 2 gate flipped, reject → no propagation
- [ ] **TT-21:** Asserts audit: `verification_audit_trail` rows for all events, `verification_reviews` rows for all decisions
- [ ] **TT-22:** Asserts envelope: all RPCs return `{success, code, message, data}` with `PLT000` on success
- [ ] **TT-23:** All assertions in `012` pass — zero failures

### 7.3 Regression Testing — Existing pgTAP Suite

- [ ] **TT-24:** `008_full_schema_posture_audit.sql` passes all assertions without regression
- [ ] **TT-25:** `009_taxonomy_seed_verification.sql` passes all assertions without regression
- [ ] **TT-26:** `010_taxonomy_rpc_enforcement.sql` passes all assertions without regression
- [ ] **TT-27:** Full test suite execution via `supabase db test` reports zero failures across all test files (001–012)

### 7.4 Edge Cases

- [ ] **TT-28:** `verification_submit` with a credential that has `profession_id = NULL` (identity document) — submission created successfully
- [ ] **TT-29:** `verification_submit` with a credential that has `profession_id` set (trade proof) — submission created successfully, linked to profession binding
- [ ] **TT-30:** `verification_review_approve` on a trade proof where the entity has no bound profession — handled gracefully (PLT004 or no-op propagation)
- [ ] **TT-31:** `verification_status_get` for an entity with zero submissions — returns empty/default status
- [ ] **TT-32:** `verification_kyc_level_get` for an entity with no KYC assignment — returns `tier_0` or null with appropriate envelope
- [ ] **TT-33:** `verification_limits_get` for an entity at `tier_0` — returns all-zero limits

### 7.5 Failure Scenarios

- [ ] **TT-34:** If `verification_submit` encounters a `unique_violation` (23505) during INSERT despite pre-validation (race condition), the exception is caught and re-raised as PLT005
- [ ] **TT-35:** If `verification_submit` encounters a `foreign_key_violation` (23503) despite pre-validation, the exception is caught and re-raised as PLT004
- [ ] **TT-36:** If `verification_review_approve` propagation UPDATE on `entity_professions` affects zero rows (profession binding deleted concurrently), the RPC handles gracefully without transaction failure

### 7.6 Manual Testing

- [ ] **TT-37:** Manual invocation of `verification_submit` via `psql` or Supabase SQL editor as `authenticated` creates a pending submission
- [ ] **TT-38:** Manual invocation of `verification_review_approve` as `service_role` approves and propagates correctly
- [ ] **TT-39:** Manual invocation of `verification_review_reject` as `service_role` rejects without propagation
- [ ] **TT-40:** Manual invocation of any review RPC as `authenticated` is rejected with `42501`
- [ ] **TT-41:** Manual query of `kyc_tiers` returns 4 seeded rows with correct limits

---

## 8. User Acceptance Verification

This task has no direct user interface. User acceptance is verified indirectly through RPC correctness, envelope consistency, and downstream readiness.

- [ ] **UA-01:** All 6 RPCs return the same `{success, code, message, data}` envelope format used by existing platform RPCs — consistent API contract for future client-side consumers
- [ ] **UA-02:** Error messages from RPCs are descriptive enough for downstream UIs to display actionable feedback (e.g., "Credential not found.", "Duplicate active submission.")
- [ ] **UA-03:** Audit trail captures all verification state changes — an admin can reconstruct the full history by querying `verification_audit_trail`
- [ ] **UA-04:** `verification_status_get` returns sufficient data for onboarding/profile screens to display identity/trade/KYC state without exposing review internals
- [ ] **UA-05:** `verification_limits_get` returns sufficient data for KYC-level limit display (EP-02-12) so users understand their cashout headroom
- [ ] **UA-06:** The verification engine is sufficient to unblock EP-02-04 (Financial Integrity Schema), EP-02-10 (Identity Verification), EP-02-11 (Trade Verification), EP-02-12 (KYC Framework), and EP-02-16 (Payout & Deposit Verification)

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-03 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | Migration file exists at `supabase/migrations/<timestamp>_verification_admin_review_schema.sql` with correct naming and timestamp ordering after `20260829090002` | File inspection | ☑ |
| 2 | Migration header comment block documents purpose (EP-02-03), execution model, envelope contract, and grant strategy | Code review | ☑ |
| 3 | Exactly 5 tables created: `kyc_tiers`, `entity_kyc_levels`, `verification_submissions`, `verification_reviews`, `verification_audit_trail` | `SELECT has_table` ×5 | ☑ |
| 4 | All 5 tables have RLS enabled | `relrowsecurity` check | ☑ |
| 5 | `anon` has zero grants on the 5 new tables | `role_table_grants` query | ☑ |
| 6 | `verification_submissions.status/reviewed_at/reviewed_by` not writable by `authenticated` | column-grant assertion | ☑ |
| 7 | `entity_kyc_levels` not INSERT/UPDATE writable by `authenticated` | column-grant assertion | ☑ |
| 8 | `verification_reviews` no UPDATE/DELETE grant to any **client** role | grant query | ☑ |
| 9 | `verification_audit_trail` no UPDATE/DELETE grant to any **client** role | grant query | ☑ |
| 10 | `kyc_tiers` seeded with 4 tiers via idempotent insert | `select count(*) from kyc_tiers` = 4 | ☑ |
| 11 | Exactly 6 `verification_` functions created: `verification_submit`, `verification_review_approve`, `verification_review_reject`, `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get` | `SELECT proname FROM pg_proc WHERE proname LIKE 'verification_%'` = 6 rows | ☑ |
| 12 | All 6 RPCs are SECURITY INVOKER — zero SECURITY DEFINER | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'verification_%' AND prosecdef` = 0 | ☑ |
| 13 | Read RPCs granted to `authenticated`, `service_role`; write RPCs granted to `service_role` only | Grant inspection query | ☑ |
| 14 | `anon` cannot invoke any RPC (throws `42501`) — 6 assertions | pgTAP `throws_ok` | ☑ |
| 15 | `authenticated` cannot invoke review RPCs (throws `42501`) | pgTAP `throws_ok` | ☑ |
| 16 | `authenticated` can call entity-facing RPCs (`lives_ok`) | pgTAP `lives_ok` | ☑ |
| 17 | `verification_submit` validates NULL credential (PLT003) | pgTAP `throws_ok` | ☑ |
| 18 | `verification_submit` enforces ownership (PLT004) | pgTAP `throws_ok` | ☑ |
| 19 | `verification_submit` enforces dedup (PLT005) | pgTAP `throws_ok` | ☑ |
| 20 | Approve identity submission → `entity_kyc_levels` upserted + `verification_kyc_level_get` returns tier | pgTAP | ☑ |
| 21 | Approve trade submission → `entity_professions.trade_verification_status = 'approved'` | pgTAP (Rule 2 gate) | ☑ |
| 22 | Reject does NOT flip trade gate or KYC tier | pgTAP | ☑ |
| 23 | `verification_reviews` + `verification_audit_trail` rows written on review | pgTAP | ☑ |
| 24 | All RPCs return `{success, code, message, data}` envelope on success and PLT### codes on error | Envelope structure assertion | ☑ |
| 25 | No DDL alters `entity_credentials` / `entity_professions` / any EP-01 table structure | Migration file review | ☑ |
| 26 | Realtime excludes the 5 new tables | Publication query | ☑ |
| 27 | No SECURITY DEFINER `verification_%` function | `pg_proc` query | ☑ |
| 28 | pgTAP `011_verification_schema_posture.sql` exists and passes all assertions (20) | `supabase db test` | ☑ |
| 29 | pgTAP `012_verification_rpc_enforcement.sql` exists and passes all assertions (37) | `supabase db test` | ☑ |
| 30 | Full suite `001`–`012` passes (no regression to `008`/`009`/`010`) | `supabase db test` — 273/273 | ☑ |
| 31 | Migration header + `comment on function` for all 6 RPCs | `SELECT obj_description(oid) FROM pg_proc WHERE proname LIKE 'verification_%'` — all non-null | ☑ |
| 32 | No client-side files created — no files added under `lib/` | File inspection | ☑ |
| 33 | EP-02-04 / 10 / 11 / 12 / 16 unblocked — verification engine available for downstream consumption | Dependency check | ☑ |

---

## 10. Completion Record

**Status:** Completed — all 33 Final Approval Checklist conditions verified (marked ☑ above).

### 10.1 Verification Evidence

- Migration applied via `supabase db reset`; full pgTAP suite executed with `supabase db test`.
- Result: **12/12 test files pass, 273/273 subtests, 0 failures** (no regression on `001`–`010`).
- `011_verification_schema_posture.sql`: 20/20 assertions pass (tables, RLS, anon zero-grant, column ACLs, immutability, triggers, no SECURITY DEFINER, Realtime exclusion, comments, 4-row seed).
- `012_verification_rpc_enforcement.sql`: 37/37 assertions pass (6× anon 42501; authenticated 42501 on review RPCs; entity-facing + service_role success; PLT003/PLT004/PLT005 paths; identity→tier_1, trade→Rule-2 gate flip, reject non-propagation; audit-trail = 8 rows, reviews = 3 rows; envelope = 4 keys / PLT000; 6 functions, 0 SECURITY DEFINER).
- Manual-equivalent checks (TT-37–TT-41) are covered by the pgTAP authz/functional/envelope assertions.

### 10.2 Disclosures

1. **SV-27/SV-28 wording ("to any role"):** The table *owner* (`postgres`) inherently holds UPDATE/DELETE on every table. The immutability guarantee is enforced by granting UPDATE/DELETE to **no client role** (`anon`/`authenticated`/`service_role`). `verification_reviews`/`verification_audit_trail` receive only `SELECT`/`INSERT` grants; the 011 posture test asserts this against client roles. (SV-35/SV-39 satisfied.)
2. **TV-03 ("no DDL changes to any EP-01 table"):** No structural DDL was added to EP-01 tables. One **privilege grant** (`grant update on public.entity_professions to service_role`) was added so the service-role review RPC can flip the Rule-2 trade gate (`trade_verification_status`/`verified_at`/`verified_by`). This is DCL, not DDL, and does not alter client grants (SV-41/SV-42 hold — `authenticated`/`anon` still cannot write those columns).
3. **FV-41 / non-owned credential (PLT004):** Because RLS on `entity_credentials` hides other entities' rows from an authenticated caller, `verification_submit` reports `PLT004: Credential not found.` rather than `…does not belong to this entity.` — both are PLT004, and the explicit ownership branch (`v_cred.entity_id <> v_actor`) remains reachable for `service_role` (RLS bypassed). No existence leak.
4. **Race-condition hardening (DV-40 / TT-34 / TT-35):** Added a partial unique index `verification_submissions_one_active_credential_idx` (on `credential_id` WHERE `status in ('pending','in_review')`) plus an `exception` block in `verification_submit` mapping `unique_violation → PLT005` and `foreign_key_violation → PLT004`. This matches the `entity_profession_bind` convention and guarantees one active submission per credential even under concurrency.
5. **TV-18:** `verification_submit` now calls `public.platform_is_authenticated()` (repo convention) for the PLT001 gate. Read RPCs intentionally keep the `auth.uid() is null` check because `service_role` may query any entity by `p_entity_id`.

### 10.3 Recommendation

Task EP-02-03 is **Complete and Verified**. The verification engine (5 tables + 6 SECURITY INVOKER RPCs + seed) satisfies the approved plan and all 33 Final Approval Checklist conditions. EP-02-04, EP-02-10, EP-02-11, EP-02-12, and EP-02-16 are unblocked. Recommend marking the task Completed in the tracker.

---

> **Sign-off:** Task EP-02-03 marked **Completed** — all 33 Final Approval Checklist conditions verified (2026-08-29, full `supabase db test` = 273/273 PASS).
