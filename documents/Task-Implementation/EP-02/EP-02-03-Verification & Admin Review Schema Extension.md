# Task Implementation Plan — EP-02-03: Verification & Admin Review Schema Extension

---

## 1. Task Objective

Design and implement the extended server-side verification schema that transforms the EP-01 trust-evidence tables (`entity_credentials`, `entity_professions`) into a full verification workflow engine. Deliverables:

- **5 new tables**: `kyc_tiers`, `entity_kyc_levels`, `verification_submissions`, `verification_reviews`, `verification_audit_trail`
- **6 RPCs**: `verification_submit`, `verification_review_approve`, `verification_review_reject`, `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`
- **Full RLS** (default-deny) on all 5 tables
- **2 pgTAP test files**: `011_verification_schema_posture.sql`, `012_verification_rpc_enforcement.sql`
- **Zero modifications** to any EP-01 or EP-02-01/02 table or function

---

## 2. Business Problem Being Solved

EP-01 created trust-evidence storage (`entity_credentials` with `verification_status`/`reviewed_at`/`reviewed_by`, and `entity_professions` with `trade_verification_status`), but **no workflow exists** to move those records through review and propagate decisions:

- No unified queue for admins to triage identity documents, trade proofs, and certifications
- No server-enforced decision record — review outcomes are scattered across raw columns
- KYC tiers and financial limits are undefined — EP-02-12 (KYC framework) and EP-02-16 (cashout limits) have nothing to enforce
- The Rule 2 trade gate (`trade_verification_status == APPROVED`) has no authorized admin path to advance it — client grants exclude verification columns, so only a server-side workflow can flip them
- No immutable, queryable history of who approved/rejected what and when — required for audit, dispute resolution (EP-02-05/17), and regulatory defensibility

This task establishes the verification engine that **every downstream trust, identity, and financial-limit task depends on** (EP-02-10, EP-02-11, EP-02-12, EP-02-16).

---

## 3. Scope

| In Scope | Detail |
|---|---|
| `kyc_tiers` table | Reference/config table of KYC verification tiers and their limits (config-driven, not hardcoded) |
| `entity_kyc_levels` table | Per-entity current KYC tier assignment (one active tier per entity) |
| `verification_submissions` table | Unified, admin-reviewable submission queue (identity / trade / certification) |
| `verification_reviews` table | Immutable decision record per admin review action |
| `verification_audit_trail` table | Append-only log of all verification state changes |
| RPC: `verification_submit` | Entity queues an existing `entity_credentials` for review (self-scoped) |
| RPC: `verification_review_approve` | Service-role admin approves a submission and propagates status (KYC assignment / trade gate) |
| RPC: `verification_review_reject` | Service-role admin rejects a submission (no approval propagation) |
| RPC: `verification_status_get` | Aggregated verification status for an entity (self or service-role) |
| RPC: `verification_kyc_level_get` | Current KYC tier + limits for the calling entity |
| RPC: `verification_limits_get` | Applicable transaction/cashout limits for the calling entity |
| RLS + grants | Default-deny on all 5 tables; admin writes via service-role-only EXECUTE grants |
| pgTAP posture test | `011_verification_schema_posture.sql` |
| pgTAP enforcement test | `012_verification_rpc_enforcement.sql` |
| KYC tier seed data | 4 tiers (`tier_0` through `tier_3`) with base NGN limits, idempotent insert |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| Client-side verification UI / data layer | EP-02-10, EP-02-11, EP-02-12 |
| Storage bucket wiring for documents | EP-02-06 |
| Financial schema (accounts, balances, escrow) | EP-02-04 |
| Dispute resolution schema | EP-02-05 |
| KYC provider integration adapters | EP-02-12 (integration seam only) |
| Currency-specific limit overrides | EP-02-16 extends limits per currency; EP-02-03 stores base (NGN) limits |
| Admin review UI / dashboard | Future task (simplified admin tooling may use these RPCs directly) |
| Modification of `entity_credentials` / `entity_professions` tables | Finalized in EP-01-06; this task references them, does not alter them |
| Multi-currency KYC limit matrix | Deferred to EP-02-16 |
| Any client-side Dart/Flutter code | Server-side only task |

---

## 5. Recommended Technical Approach

### 5.1 Single SQL Migration

Create one migration file:
```
supabase/migrations/<YYYYMMDD><HHMMSS>_verification_admin_review_schema.sql
```

The migration contains, in order: (1) 5 table DDLs with constraints, indexes, triggers, comments; (2) RLS enablement, revokes, and grants per table; (3) 6 RPC function definitions; (4) EXECUTE grants; (5) `comment on function` documentation; (6) Realtime exclusion. **No changes to any EP-01 or EP-02-01/02 table or function.**

### 5.2 Execution Model: SECURITY INVOKER

All 6 RPCs are `SECURITY INVOKER` — RLS applies inside the function body. This is consistent with:
- `008_full_schema_posture_audit.sql` (asserts no `entity_%` / `verification_%` SECURITY DEFINER function)
- The EP-02-02 RPC pattern (all 7 taxonomy RPCs are SECURITY INVOKER)
- The EP-01-06 entity RPC pattern (all 5 entity RPCs are SECURITY INVOKER)

**Authorization model:**
- **Entity-facing RPCs** (`verification_submit`, `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get`): EXECUTE granted to `authenticated` + `service_role`. They call `platform_is_authenticated()` and scope all reads/writes to `auth.uid()`.
- **Admin review RPCs** (`verification_review_approve`, `verification_review_reject`): EXECUTE granted to **`service_role` only**. `anon` and `authenticated` receive `42501` (insufficient privilege) before the body runs — no explicit auth check needed inside.

### 5.3 Audit Logging Strategy (service-role auth-context caveat)

`platform_audit_log_add()` is `SECURITY DEFINER` but enforces `platform_is_authenticated()` (`auth.uid() is not null`). In a `service_role` invocation context (Edge Function / Supabase dashboard) `auth.uid()` is `NULL`, so calling `platform_audit_log_add` from the review RPCs would raise `PLT001`. Therefore:

- `verification_submit` (authenticated context) **may** call `platform_audit_log_add` for general mutation auditing.
- `verification_review_approve` / `verification_review_reject` (service-role context) write directly to the dedicated `verification_audit_trail` table instead of `platform_audit_log_add`, avoiding the auth-context dependency. `verification_audit_trail` is the authoritative verification audit log and is append-only.

### 5.4 Status Propagation (the trust gate)

`verification_review_approve` performs targeted, server-side status propagation:

- **Identity / certification submission** → upsert `entity_kyc_levels` to the assigned tier (default mapping: first approved identity document promotes entity to `tier_1`, `status = 'active'`). Logged as `kyc_level_assigned`.
- **Trade proof submission** (`credential.kind = 'trade_proof'`, `credential.profession_id` set) → set `entity_professions.trade_verification_status = 'approved'`, `verified_at = now()`, `verified_by = <reviewer>` for the linked profession binding. Logged as `trade_status_propagated`. This is the **only authorized path** that advances the Rule 2 gate (client grants on `entity_professions` exclude `trade_verification_status`, `verified_at`, `verified_by`).

`verification_review_reject` records the decision and sets submission `status = 'rejected'` but does **not** advance any approval state; trade status remains `unverified`/`pending` and KYC tier is unchanged.

### 5.5 Response Envelope Contract

All RPCs return the standard `{success, code, message, data}` envelope (PLT000 success; PLT001 auth, PLT003 validation, PLT004 not found, PLT005 conflict, PLT999 internal). Error messages are static (no data values), consistent with `enforcement_foundation.sql`.

### 5.6 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001` | Auth gate on entity-facing RPCs |
| `platform_raise_error(code, message)` | `20260819090001` | Standardized error raising |
| `platform_set_updated_at()` | `20260819090001` | `updated_at` trigger on mutable tables |
| `platform_audit_log_add(...)` | `20260819090002` | General audit from authenticated submit RPC only |
| `verification_audit_trail` direct insert | New table | Authoritative verification audit from review RPCs |

---

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Verification schema + RPC migration | `supabase/migrations/<timestamp>_verification_admin_review_schema.sql` | **Create** — new SQL migration |
| pgTAP schema posture test | `supabase/tests/database/011_verification_schema_posture.sql` | **Create** — new test file |
| pgTAP RPC enforcement test | `supabase/tests/database/012_verification_rpc_enforcement.sql` | **Create** — new test file |

**No client-side modules, Dart files, or Flutter components are created in this task.**

---

## 7. Data Requirements

### 7.1 New Tables (5)

**`kyc_tiers`** — KYC tier limit definitions (config-driven reference table):

| Column | Type | Notes |
|---|---|---|
| `tier_code` | `text` PK | `^tier_[0-9]+$`, lowercase; e.g. `tier_0`..`tier_3` |
| `name` | `text` | 1–255 chars |
| `description` | `text` | nullable |
| `daily_limit` | `numeric` | ≥ 0, base currency (NGN) |
| `weekly_limit` | `numeric` | ≥ 0 |
| `monthly_limit` | `numeric` | ≥ 0 |
| `cashout_limit` | `numeric` | ≥ 0 |
| `is_active` | `boolean` | default true |
| `sort_order` | `integer` | default 0 |
| audit cols | per convention | `created_at`, `updated_at`, `created_by` |

Seeded idempotently via `INSERT ... ON CONFLICT (tier_code) DO NOTHING`:

| tier_code | name | daily_limit | weekly_limit | monthly_limit | cashout_limit |
|---|---|---|---|---|---|
| `tier_0` | Unverified | 0 | 0 | 0 | 0 |
| `tier_1` | Identity Verified | 50,000 | 200,000 | 800,000 | 100,000 |
| `tier_2` | Trade Verified | 200,000 | 800,000 | 3,000,000 | 500,000 |
| `tier_3` | Fully Verified | 1,000,000 | 4,000,000 | 15,000,000 | 2,000,000 |

**`entity_kyc_levels`** — per-entity current KYC assignment:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | `unique (entity_id)` — one current tier |
| `tier_code` | `text` FK `kyc_tiers(tier_code)` | |
| `status` | `text` | `pending \| active \| expired`, default `pending` |
| `assigned_at` | `timestamptz` | default now() |
| `assigned_by` | `uuid` | reviewer/actor |
| `expires_at` | `timestamptz` | nullable |
| audit cols | per convention | `created_at`, `updated_at`, `created_by` |

**`verification_submissions`** — unified review queue:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | |
| `credential_id` | `uuid` FK `entity_credentials(id)` ON DELETE RESTRICT | nullable |
| `submission_type` | `text` | `identity_document \| trade_proof \| certification` |
| `status` | `text` | `pending \| in_review \| approved \| rejected \| requires_resubmission`, default `pending` |
| `priority` | `integer` | default 5 (admin triage ordering) |
| `assigned_reviewer` | `uuid` | nullable |
| `submitted_at` | `timestamptz` | default now() |
| `reviewed_at` | `timestamptz` | nullable |
| `reviewed_by` | `uuid` | nullable |
| `decision_notes` | `text` | nullable |
| audit cols | per convention | `created_at`, `updated_at`, `created_by` |

Constraint `verification_submissions_review_consistency`: pending/in_review ⇒ `reviewed_at IS NULL AND reviewed_by IS NULL`; decided ⇒ `reviewed_at IS NOT NULL`.

**`verification_reviews`** — immutable decision records:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `submission_id` | `uuid` FK `verification_submissions(id)` ON DELETE CASCADE | |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | |
| `reviewer_id` | `uuid` | nullable |
| `decision` | `text` | `approved \| rejected \| requires_resubmission` |
| `decision_notes` | `text` | nullable |
| `created_at` | `timestamptz` | default now() |
| `created_by` | `uuid` | default auth.uid() |

No `updated_at` (decisions are immutable).

**`verification_audit_trail`** — append-only state-change log:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE SET NULL | nullable |
| `event_type` | `text` | `submission_created \| submission_assigned \| review_approved \| review_rejected \| review_resubmitted \| kyc_level_assigned \| trade_status_propagated \| status_cleared` |
| `subject_type` | `text` | e.g. `submission \| kyc_level \| trade_binding` |
| `subject_id` | `uuid` | nullable |
| `from_state` | `text` | nullable |
| `to_state` | `text` | nullable |
| `actor_id` | `uuid` | nullable |
| `details` | `jsonb` | default `{}` |
| `created_at` | `timestamptz` | default now() |

No `updated_at`; append-only (no UPDATE/DELETE grants).

### 7.2 Indexes

- `kyc_tiers_is_active_sort_idx (is_active, sort_order)`
- `entity_kyc_levels_entity_id_key` (unique, explicit)
- `verification_submissions_entity_status_idx (entity_id, status)`
- `verification_submissions_credential_id_idx (credential_id)`
- `verification_submissions_submitted_at_idx (submitted_at desc)`
- `verification_reviews_submission_id_idx (submission_id)`
- `verification_reviews_entity_idx (entity_id)`
- `verification_audit_trail_entity_idx (entity_id)`
- `verification_audit_trail_created_at_idx (created_at desc)`

---

## 8. Database Considerations

### 8.1 Existing Schema (References Only, No Modification)

- `entity_credentials(id, kind, profession_id, entity_id, verification_status…)` — referenced by `verification_submissions.credential_id`. Not altered.
- `entity_professions(entity_id, profession_id, trade_verification_status, verified_at, verified_by)` — advanced by review RPCs. Client grants exclude the verification columns (D5), so only these server-side RPCs mutate them. Not altered.
- `entities(id)` — FK target. Not altered.

### 8.2 Constraint Compliance

| Constraint | Enforced By |
|---|---|
| `kyc_tiers.tier_code` format + uniqueness | CHECK regex `^tier_[0-9]+$` + PK |
| Non-negative limits | CHECK `daily_limit >= 0 AND weekly_limit >= 0 AND monthly_limit >= 0 AND cashout_limit >= 0` |
| `entity_kyc_levels` one tier per entity | UNIQUE `(entity_id)` |
| `verification_submissions` review consistency | CHECK `(status in ('pending','in_review') AND reviewed_at IS NULL AND reviewed_by IS NULL) OR (status in ('approved','rejected','requires_resubmission') AND reviewed_at IS NOT NULL)` |
| Submission type / status vocabularies | CHECK `in (...)` (text, not ENUM — forward-extensible per EP-01 D2 pattern) |
| FK integrity | all references `ON DELETE CASCADE/RESTRICT` as noted |

### 8.3 RLS & Grants (Default-Deny)

Revoke blanket privileges first. Then per table:

| Table | `anon` | `authenticated` | `service_role` |
|---|---|---|---|
| `kyc_tiers` | SELECT | SELECT | SELECT, INSERT, UPDATE |
| `entity_kyc_levels` | — | SELECT (self) | SELECT, INSERT, UPDATE, DELETE |
| `verification_submissions` | — | SELECT (self), INSERT (limited cols) | SELECT, INSERT, UPDATE |
| `verification_reviews` | — | SELECT (self) | SELECT, INSERT |
| `verification_audit_trail` | — | SELECT (self), INSERT (self) | SELECT, INSERT |

RLS policies (self-scoped via `entity_id = auth.uid()`) mirror the EP-01 pattern:
- `verification_submissions_authenticated_select` (using `entity_id = auth.uid()`)
- `verification_submissions_authenticated_insert` (with check `entity_id = auth.uid()`; columns limited to `entity_id, credential_id, submission_type, priority` — `status` is **never** client-writable)
- `entity_kyc_levels_authenticated_select`, `verification_reviews_authenticated_select`, `verification_audit_trail_authenticated_select`, `verification_audit_trail_authenticated_insert` (with check `entity_id = auth.uid()`)

No UPDATE/DELETE grant on `verification_reviews` or `verification_audit_trail` for any role (immutability).

### 8.4 Trigger Compatibility

`platform_set_updated_at()` attached to `kyc_tiers`, `entity_kyc_levels`, `verification_submissions` (the mutable tables). `verification_reviews` and `verification_audit_trail` have no `updated_at` column and no trigger.

### 8.5 Realtime Exclusion

All 5 new tables excluded from `supabase_realtime` (guarded `DO $$` block, consistent with EP-01-05/06 pattern).

### 8.6 Idempotency

- `kyc_tiers` seed uses `ON CONFLICT (tier_code) DO NOTHING`.
- DDL is non-destructive (new tables only); re-running the migration is safe in dev.

### 8.7 Posture Audit Compatibility

The existing `008_full_schema_posture_audit.sql` asserts only the original nine tables and that **no `entity_%` function is SECURITY DEFINER**. New tables and `verification_%` functions do not affect those assertions. A new `011_verification_schema_posture.sql` adds equivalent assertions for the 5 new tables.

---

## 9. API Requirements

### 9.1 RPC API Surface (PostgREST `/rpc/`)

| RPC | Access | Volatility | Purpose |
|---|---|---|---|
| `verification_submit(p_credential_id uuid, p_submission_type text default null)` | authenticated, service_role | VOLATILE | Queue a credential for review |
| `verification_review_approve(p_submission_id uuid, p_notes text default null)` | service_role only | VOLATILE | Approve + propagate |
| `verification_review_reject(p_submission_id uuid, p_notes text default null)` | service_role only | VOLATILE | Reject |
| `verification_status_get(p_entity_id uuid default null)` | authenticated (self), service_role | STABLE | Aggregated status |
| `verification_kyc_level_get()` | authenticated (self), service_role | STABLE | Current KYC tier + limits |
| `verification_limits_get()` | authenticated (self), service_role | STABLE | Applicable limits |

### 9.2 No REST Endpoints / No Edge Functions

All access via RPC. No custom REST routes or Edge Functions are created in this task.

---

## 10. User Interface Requirements

**None.** This task produces no UI. The verification UIs are EP-02-10/11/12.

---

## 11. User Experience Considerations

While server-side only, this schema directly shapes UX downstream:
- **Transparent status**: `verification_status_get` lets onboarding/profiles show identity/trade/KYC state without exposing review internals
- **Consistent envelope**: all RPCs return `{success, code, message, data}`, simplifying client error handling
- **Meaningful errors**: PLT003/PLT004/PLT005 let the client show actionable messages (missing credential, already submitted, not found)
- **Limit visibility**: `verification_limits_get` powers KYC-level limit display (EP-02-12) so users understand their cashout headroom

---

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Admin authorization | Review RPCs EXECUTE-granted to `service_role` only; `anon`/`authenticated` get `42501` before body executes |
| Self-scoping | Entity-facing RPCs enforce `entity_id = auth.uid()` in RLS + explicit check; an entity can only submit/inspect its own data |
| Trade gate integrity | `trade_verification_status` advanced only inside `verification_review_approve` (client grants exclude those columns) — no client bypass possible |
| KYC assignment integrity | `entity_kyc_levels` mutated only by review RPC (service_role); `authenticated` has SELECT only |
| Verification-column ACL | `status`, `reviewed_at`, `reviewed_by` on `verification_submissions` excluded from `authenticated` INSERT/UPDATE grants (mirrors EP-01 D5) |
| Immutability | `verification_reviews`, `verification_audit_trail` have zero UPDATE/DELETE grants to any role |
| Default-deny | All 5 tables revoked from `anon`/`authenticated` except the narrow grants above |
| No new SECURITY DEFINER | All `verification_%` RPCs are SECURITY INVOKER (posture audit compatible) |
| service-role audit caveat | Review RPCs write `verification_audit_trail` directly (not `platform_audit_log_add`) because `auth.uid()` is NULL in service_role context — see §5.3 |
| Secrets | No credentials/PII beyond existing references; `decision_notes` is admin-authored free text (length-capped, reviewed) |
| SQL injection | All DML parameterized via PL/pgSQL variable references; no string-built SQL |

---

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Read paths | `verification_status_get` / `verification_kyc_level_get` use `entity_id` indexes (`verification_submissions_entity_status_idx`, `entity_kyc_levels_entity_id_key`) |
| Review queue scan | Admin list scans `verification_submissions` filtered by `status`/`priority` — covered by `submitted_at` index; low volume at EP-02 scale |
| Propagation writes | Single-row UPDATEs on `entity_professions` / upsert on `entity_kyc_levels`; no table locks |
| Audit inserts | Append-only, indexed on `created_at`/`entity_id`; negligible overhead per review |
| Volatility | Read RPCs `STABLE`; write/review RPCs `VOLATILE` |
| No N+1 | `verification_status_get` assembles the aggregate in one function with a few indexed lookups |

---

## 14. Testing Strategy

### 14.1 `011_verification_schema_posture.sql`

| Test | Assertion |
|---|---|
| All 5 tables exist | `has_table` ×5 |
| RLS enabled on all 5 | `relrowsecurity = true` count = 5 |
| anon zero grants on new tables | `role_table_grants` grantee `anon` = 0 |
| Verification `status`/`reviewed_at`/`reviewed_by` not writable by `authenticated` on `verification_submissions` | column-grant count = 0 |
| `entity_kyc_levels` not writable by `authenticated` (INSERT/UPDATE) | column-grant count = 0 |
| `verification_reviews` no UPDATE/DELETE grant to any role | 0 |
| `verification_audit_trail` no UPDATE/DELETE grant to any role | 0 |
| Triggers present on mutable tables (3) | `_set_updated_at` count = 3 |
| No `verification_%` SECURITY DEFINER function | count = 0 |
| Realtime excludes all 5 tables | 0 |
| Comments present on new tables | `obj_description` non-null |
| `kyc_tiers` seeded (4 rows) | count = 4 |
| Posture regression | existing `008` assertions unaffected (run full suite) |

### 14.2 `012_verification_rpc_enforcement.sql`

**Authorization:**

| Test | Assertion |
|---|---|
| `anon` cannot call `verification_review_approve` | `throws_ok` 42501 |
| `anon` cannot call `verification_review_reject` | `throws_ok` 42501 |
| `authenticated` cannot call `verification_review_approve` | `throws_ok` 42501 |
| `authenticated` cannot call `verification_review_reject` | `throws_ok` 42501 |
| `authenticated` can call `verification_submit` | `lives_ok` |
| `authenticated` can call `verification_status_get` / `verification_kyc_level_get` / `verification_limits_get` | `lives_ok` |
| `service_role` can call all 6 RPCs | `lives_ok` |

**Validation (authenticated / service_role):**

| Test | Assertion |
|---|---|
| `verification_submit` with non-owned credential | PLT004 |
| `verification_submit` with null credential | PLT003 |
| `verification_submit` duplicate active submission for same credential | PLT005 |
| `verification_review_approve` with missing submission | PLT004 |
| `verification_review_approve` on already-decided submission | PLT005 / guarded no-op |
| `verification_status_get` with another entity's id (authenticated) | self-scope enforced (PLT004 or empty) |

**Functional / propagation:**

| Test | Assertion |
|---|---|
| submit identity credential → status `pending` | envelope `success`; row exists |
| `verification_review_approve` on identity submission → `entity_kyc_levels` upserted to `tier_1` active | tier present |
| `verification_kyc_level_get` returns `tier_1` limits | limits match seed |
| submit trade proof (profession bound) → approve → `entity_professions.trade_verification_status = 'approved'` | Rule 2 gate flipped |
| `verification_review_reject` → submission `rejected`, trade status remains non-approved | gate NOT flipped |
| `verification_audit_trail` has `review_approved` / `trade_status_propagated` / `kyc_level_assigned` rows | audit present |
| `verification_reviews` has immutable decision row | row present, no UPDATE path |

**Envelope contract:** all RPCs return `{success, code, message, data}`; success code `PLT000`.

### 14.3 Regression

Run full suite `001`–`012`. Confirm `008` (entity-model posture) and `009`/`010` (taxonomy) still pass — no EP-01 table altered.

---

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Create migration file `<timestamp>_verification_admin_review_schema.sql` | Scaffold |
| 2 | Header comment block (EP-02-03, execution model, envelope, grant strategy) | Docs |
| 3 | DDL: `kyc_tiers` (constraints, indexes, trigger, comment) | Table |
| 4 | DDL: `entity_kyc_levels` (FK, unique, trigger, comment) | Table |
| 5 | DDL: `verification_submissions` (FK, consistency CHECK, indexes, trigger, comment) | Table |
| 6 | DDL: `verification_reviews` (FK, indexes, comment) | Table |
| 7 | DDL: `verification_audit_trail` (FK, indexes, comment) | Table |
| 8 | Idempotent `kyc_tiers` seed (tier_0..tier_3) | Seed |
| 9 | RLS enable + revoke + per-table grants + self-scoped policies | Security |
| 10 | Implement `verification_submit` (auth, ownership, dedup, audit) | RPC |
| 11 | Implement `verification_review_approve` (service-role, propagate KYC + trade gate, audit) | RPC |
| 12 | Implement `verification_review_reject` (service-role, decision record, audit) | RPC |
| 13 | Implement `verification_status_get`, `verification_kyc_level_get`, `verification_limits_get` | RPCs |
| 14 | `revoke execute on all functions in schema public from public` + specific EXECUTE grants | Authz |
| 15 | `comment on function` for all 6 RPCs | Docs |
| 16 | Realtime exclusion `DO $$` block for 5 tables | Security |
| 17 | Create `011_verification_schema_posture.sql` | Test |
| 18 | Create `012_verification_rpc_enforcement.sql` | Test |
| 19 | `supabase db push` (or `supabase db reset`) | Migrate |
| 20 | `supabase db test` — all new + existing pass | Verify |

---

## 16. Expected Outcome

- 5 verification tables deployed with full RLS (default-deny), triggers, indexes, comments, Realtime exclusion
- `kyc_tiers` seeded with 4 tiers (config-driven limits)
- 6 RPCs deployed; entity-facing RPCs self-scoped and authenticated; review RPCs service-role-only
- Approving an identity submission assigns the entity's KYC tier; approving a trade proof flips `entity_professions.trade_verification_status = 'approved'` (Rule 2 gate) — the **only authorized path**
- Every decision and state change captured immutably in `verification_reviews` + `verification_audit_trail`
- No `verification_%` SECURITY DEFINER function; no EP-01 table altered
- pgTAP `011` + `012` pass; full suite (`001`–`012`) green
- EP-02-10, EP-02-11, EP-02-12, EP-02-16 unblocked with a real verification engine

---

## 17. Definition of Done (DoD)

| # | Criterion | Verification Method |
|---|---|---|
| 1 | Migration file exists with correct naming/ordering | File inspection |
| 2 | 5 tables created: `kyc_tiers`, `entity_kyc_levels`, `verification_submissions`, `verification_reviews`, `verification_audit_trail` | `has_table` ×5 |
| 3 | All 5 tables have RLS enabled | `relrowsecurity` check |
| 4 | `anon` has zero grants on the 5 new tables | `role_table_grants` query |
| 5 | `verification_submissions.status/reviewed_at/reviewed_by` not writable by `authenticated` | column-grant assertion |
| 6 | `entity_kyc_levels` not INSERT/UPDATE writable by `authenticated` | column-grant assertion |
| 7 | `verification_reviews` and `verification_audit_trail` have no UPDATE/DELETE grant to any role | grant query |
| 8 | `kyc_tiers` seeded with 4 tiers via idempotent insert | `select count(*) from kyc_tiers` = 4 |
| 9 | 6 RPC functions exist, all SECURITY INVOKER | `pg_proc` query (prosecdef = 0) |
| 10 | Review RPCs EXECUTE-granted to `service_role` only | grant inspection |
| 11 | `anon`/`authenticated` cannot call review RPCs (42501) | pgTAP `throws_ok` |
| 12 | `verification_submit` enforces ownership (PLT004) and dedup (PLT005) | pgTAP |
| 13 | Approve identity submission → `entity_kyc_levels` upserted + `verification_kyc_level_get` returns tier | pgTAP |
| 14 | Approve trade submission → `entity_professions.trade_verification_status = 'approved'` | pgTAP (Rule 2 gate) |
| 15 | Reject does NOT flip trade gate or KYC tier | pgTAP |
| 16 | `verification_reviews` + `verification_audit_trail` rows written on review | pgTAP |
| 17 | All RPCs return `{success, code, message, data}` envelope | envelope assertion |
| 18 | No DDL alters `entity_credentials` / `entity_professions` / any EP-01 table | migration review |
| 19 | Realtime excludes the 5 new tables | publication query |
| 20 | No SECURITY DEFINER `verification_%` function | `pg_proc` query |
| 21 | pgTAP `011` + `012` exist and pass | `supabase db test` |
| 22 | Full suite `001`–`012` passes (no regression to `008`/`009`/`010`) | `supabase db test` |
| 23 | Migration header + `comment on function` for all 6 RPCs | code review |
| 24 | No client-side files created under `lib/` | file inspection |
| 25 | EP-02-10/11/12/16 unblocked | dependency check |

---

## 18. Implementation AI Execution Profile

| Attribute | Recommendation |
|---|---|
| **Recommended Coding Reasoning Level** | **Extremely High** |
| **Reasoning Level Justification** | This task requires Extremely High reasoning, matching the EP-02 Phase Plan assignment, due to converging risk factors: **(1) Security risk** — the admin review RPCs are the sole authorized path that advances the Rule 2 trade gate and assigns KYC tiers; any EXECUTE-grant or RLS misconfiguration would let unprivileged callers mutate verification state or bypass the marketplace participation gate. **(2) Data complexity** — five interrelated tables with FKs, a status state machine (`verification_submissions_review_consistency`), an immutable decision log, and a config-driven KYC limit model requiring careful vocabulary/constraint design. **(3) Integration complexity** — status propagation must correctly touch `entity_professions` (trade gate) and `entity_kyc_levels` (KYC), and remain consistent with the EP-01 D5 column-ACL posture and the `008` posture audit; the service-role `auth.uid()` caveat (§5.3) demands a deliberate audit-logging decision. **(4) Financial impact** — KYC limits defined here drive EP-02-16 cashout limits and EP-02-12 limit enforcement; incorrect limit modeling propagates to financial risk. **(5) Test complexity** — the pgTAP suite must prove three authorization roles × six RPCs, status-machine integrity, Rule 2 gate flipping, and zero regression to the existing posture audit. The combination of security-critical server-side enforcement, multi-table state propagation, and downstream financial dependency places this squarely at Extremely High. |
