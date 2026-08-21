# DEFINITION OF DONE: EP-01-06

## Universal Entity Data Model & Core Schema Design

---

> **Task Status:** PENDING IMPLEMENTATION — checklist to be completed by the Project Lead after implementation.
> **Approved Implementation Plan:** `documents/Task-Implementation/EP-01/EP-01-06-Universal Entity Data Model & Core Schema Design.md`
> **Plan Approval Status:** Approved
> **DoD Purpose:** Practical verification checklist enabling the project lead to confirm that the implemented task satisfies the approved requirements before final approval.

---

## 1. Task Identification

| Field | Value |
|---|---|
| **Task ID** | EP-01-06 |
| **Task Name** | Universal Entity Data Model & Core Schema Design |
| **Related Phase** | EP-01: Core Platform Foundation & Infrastructure |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-01/EP-01-06-Universal Entity Data Model & Core Schema Design.md` |
| **Reference Architecture** | `documents/Context/ARCHITECTURE.md` |
| **Reference Directive** | `documents/Context/AGENT.md` |
| **Reference Vision** | `documents/Context/VISION.md` (Universal Entity Principle) |
| **Task Type** | Database-first Universal Entity schema design (9 core tables, RLS/grants, minimal entity RPC set, pgTAP extensions); no client application code, no UI, no seed/business data |
| **Dependencies** | EP-01-05 completed (enforcement foundation, helpers, error contract, pgTAP harness, CI workflow, runbook) |
| **Success Criteria Summary** | Nine RLS-protected tables implementing fluid multi-role entities, two-tier taxonomy, verification-state gating, legal-name financial anchor, settings, and device registry; four append-only migrations; column-level protection of privileged fields; five security-invoker RPCs; extended pgTAP suite green locally and in CI; promotion Dev → Staging → Prod with gates and zero business data; schema validated against EP-02 requirements; zero Dart/workflow changes |

---

## 2. Functional Verification

### 2.1 Universal Entity Identity & Fluid Multi-Role Operation

**Test Procedure:** In a clean local rebuild, create test users and exercise entity lifecycle behaviors through permitted paths (direct owner-scoped writes + RPCs).

**Verify:**
- [ ] One `entities` row exists per authenticated identity, keyed 1:1 to `auth.users(id)` (D1).
- [ ] A single entity can hold multiple simultaneously active roles (consumer + professional + merchant + rider) — no siloed profiles, no mode toggles (VISION Universal Entity Principle).
- [ ] Role vocabulary is constrained to `('consumer','professional','merchant','rider')`; any other value is rejected.
- [ ] Role deactivation sets `is_active = false`; roles are never hard-deleted by clients.
- [ ] `entity_roles_activate` / `entity_roles_deactivate` enforce the vocabulary server-side (`PLT003` on unknown role).
- [ ] No `entity_type` column exists — capability is expressed exclusively through `entity_roles`.

**Pass Criteria:**
- [ ] Fluid multi-role operation is demonstrably supported at the schema level without redesign hacks.
- [ ] Invalid role values fail closed with `PLT003`.

### 2.2 Entity Profile & Legal-Name Financial Anchor

**Verify:**
- [ ] Exactly one profile row per entity (`entity_profiles.entity_id UNIQUE`) (D3).
- [ ] `legal_name` is NOT NULL and anchors AGENT.md Rule 3 (deposit payer-name matching).
- [ ] `display_name`, `bio`, `avatar_path`, `country_code` behave per blueprint §5.3.
- [ ] Profile mutation of anchor fields occurs via `entity_profile_update` only, with trim/length validation and an audit-log entry written.
- [ ] Contact PII is not duplicated into profile tables (remains in Supabase Auth).

**Pass Criteria:**
- [ ] The legal-name anchor is enforced, validated server-side, and audit-traceable.

### 2.3 Two-Tier Taxonomy Workflows

**Verify:**
- [ ] `industries` (tier 1) and `professions` (tier 2) exist with unique, lowercase-constrained slugs.
- [ ] Every profession references an existing industry (`industry_id NOT NULL`, RESTRICT delete).
- [ ] Both tables are readable by `anon` and `authenticated` (pre-auth onboarding pickers, public SEO pages) (D6).
- [ ] No client role can write either table (service-role only).
- [ ] Slugs resolve constant-time lookups supporting `/p/:profession_slug/:entity_id`.

**Pass Criteria:**
- [ ] Industry → Profession architecture is structurally validatable end-to-end.

### 2.4 Profession Binding & Trade Verification Gate (Rule 2)

**Verify:**
- [ ] `entity_profession_bind(p_profession_id)` creates a binding landing at `trade_verification_status = 'unverified'`.
- [ ] Binding a nonexistent/inactive profession yields `PLT004`; duplicate binding yields `PLT005`.
- [ ] `trade_verification_status`, `verified_at`, `verified_by` are unreachable by any client write (column-level ACLs, D5).
- [ ] No RPC or grant anywhere provides a client path to set `pending`/`approved` — transitions reserved for EP-02 server-side workflows.

**Pass Criteria:**
- [ ] AGENT.md Rule 2 gate (`APPROVED` before bidding) is enforceable from schema state alone.

### 2.5 Credential Submission Workflow

**Verify:**
- [ ] `entity_credentials_submit(...)` creates credentials locked at `verification_status = 'pending'`.
- [ ] Owners can SELECT and INSERT their own credentials; **UPDATE is denied even to the owner** (immutable submissions; corrections = resubmit).
- [ ] Review columns (`reviewed_at`, `reviewed_by`, `rejection_reason`) have zero client grants.
- [ ] `document_path` accepts Storage object references without requiring bucket wiring (EP-02 configures buckets).

**Pass Criteria:**
- [ ] Privileged credential state is client-unreachable; submission flow completes with audit trail.

### 2.6 Settings & Device Registry Workflows

**Verify:**
- [ ] `entity_settings` supports keyed JSONB values under composite PK `(entity_id, setting_key)` with full self CRUD including DELETE.
- [ ] `entity_devices` registers devices with globally unique `device_token`, platform vocabulary constraint, `is_active`, `last_seen_at`, and self CRUD including DELETE (push-token lifecycle).

**Pass Criteria:**
- [ ] Settings and device lifecycles operate correctly within self-scoped RLS.

### 2.7 Error Handling Scenarios (All Paths Fail Closed)

| Scenario | Expected Result |
|---|---|
| Unauthenticated call to any entity RPC | `PLT001`, no data exposure |
| Unknown role value to activate/deactivate | `PLT003` |
| Missing/oversized legal or display name | `PLT003`, safe message |
| Bind unknown or inactive profession | `PLT004` |
| Duplicate profession binding | `PLT005` |
| Any cross-entity access attempt | Denied / zero rows |
| Any verification-column write attempt | Denied (ACL) |
| Server fault | `PLT999`, raw Postgres error never surfaced |

**Pass Criteria:**
- [ ] All error paths return the normalized envelope contract with static messages; no data values leak.

---

## 3. Technical Verification

### 3.1 Migration Structure & Reproducibility

**Test Procedure:**

```powershell
Get-ChildItem -Path supabase\migrations | Select-Object Name
supabase start; supabase db reset; supabase test db
```

**Verify:**
- [ ] Exactly four new migrations exist, timestamp-ordered after all EP-01-05 files: taxonomy tables → entity core tables → RLS/policies/grants → RPCs (§5.4 structure).
- [ ] Existing EP-01-05 migrations are byte-identical (append-only discipline held).
- [ ] One logical change per migration; no operational `INSERT`s anywhere.
- [ ] Clean `supabase db reset` reproduces the entire schema from zero.

**Pass Criteria:**
- [ ] Full rebuild succeeds deterministically; migration ledger remains append-only.

### 3.2 Schema Conformance to Blueprint §5.3

**Verify table-by-table:**
- [ ] `entities`: `id uuid PK → auth.users(id) ON DELETE CASCADE` defaulting `auth.uid()`; `status CHECK ('active','suspended','deactivated','deleted')`.
- [ ] `entity_profiles`: 1:1 UNIQUE `entity_id`; `legal_name NOT NULL`; approved field set.
- [ ] `entity_roles`: role CHECK vocabulary; `UNIQUE(entity_id, role)`; `activated_at`.
- [ ] `entity_credentials`: kind CHECK; nullable `profession_id`; status CHECK defaulting `pending`; review/expiry fields.
- [ ] `industries` / `professions`: slugs unique + lowercase-check; profession→industry RESTRICT FK; activity/sort fields.
- [ ] `entity_professions`: `UNIQUE(entity_id, profession_id)`; `is_primary`; verification-state trio.
- [ ] `entity_settings`: composite PK; JSONB value.
- [ ] `entity_devices`: unique token; platform CHECK; lifecycle fields.
- [ ] Audit columns (`created_at`, `updated_at`, `created_by`) + `platform_set_updated_at()` trigger on every mutable table.
- [ ] Indexes: every FK indexed; partial indexes on active roles, approved bindings, credential status; descending `created_at` convention.
- [ ] `COMMENT ON` present for tables, notable columns, policies, and functions.

**Pass Criteria:**
- [ ] Implemented schema matches the approved blueprint; any deviation is documented and lead-approved.

### 3.3 Enforcement Inheritance & RPC Execution Model

**Verify:**
- [ ] Reuses `platform_is_authenticated()`, `platform_validate_payload()`, `platform_raise_error()`, `platform_audit_log_add()` unchanged — no helper duplication.
- [ ] All new RPCs are `SECURITY INVOKER`; **no new `SECURITY DEFINER` functions** exist.
- [ ] Every RPC performs explicit auth check plus narrowed `GRANT EXECUTE`; anon receives nothing.
- [ ] Envelope `{success, code, message, data}` returned on success paths; `PLT###` typed failures.
- [ ] Parameterized SQL only; no dynamic SQL from user input.

**Pass Criteria:**
- [ ] Zero-trust execution model extends EP-01-05 patterns exactly.

### 3.4 RLS, Grants & Realtime Configuration

**Verify:**
- [ ] RLS enabled + default-deny on all nine tables; policies named `<table>_<role>_<op>`.
- [ ] Anon table grants: taxonomy `SELECT` only; zero elsewhere.
- [ ] Owner-scoped policies use indexed `auth.uid()` equality predicates.
- [ ] Column-level grants exclude all verification/review fields from client INSERT/UPDATE lists (D5).
- [ ] DELETE granted only on `entity_settings` and `entity_devices`.
- [ ] `supabase_realtime` publication excludes all nine tables.

**Pass Criteria:**
- [ ] Access model matches plan §5.3/§5.5 exactly and is machine-asserted by the posture audit.

### 3.5 CI Execution (Unmodified Workflow)

**Verify:**
- [ ] `.github/workflows/database-rls-tests.yml` runs the expanded suite automatically (auto-discovery of `005`–`008`) with **zero workflow edits**.
- [ ] Secret-scan step passes against all new migrations.

**Pass Criteria:**
- [ ] CI green on PR/push; no workflow-file diffs.

### 3.6 Architecture Compliance

**Verify:**
- [ ] AGENT.md Rule 2/3/4 supportable purely from schema state (gate fields, legal-name anchor, server-side enforcement).
- [ ] Client remains unprivileged presentation layer; no logic in any client artifact.
- [ ] ENV-001–ENV-010 respected: isolated projects, gated promotion, single source repo.
- [ ] No Edge Functions, Storage configuration, foreign-data wrappers, or unapproved extensions introduced.

**Pass Criteria:**
- [ ] Full compliance with ARCHITECTURE.md and AGENT.md boundaries.

---

## 4. Data Verification

### 4.1 Zero Business/Seed Data

**Verify:**
- [ ] Migrations contain no operational `INSERT`s; all nine tables ship empty to every environment.
- [ ] Staging contains zero entity/taxonomy rows post-push; Production contains zero rows.
- [ ] Test fixtures exist only inside pgTAP transactional contexts (local/CI); any cloud-suite run followed the EP-01-05 hygiene protocol (`discard all`, statement-by-statement, post-run cleanup) and was **never** executed against Production.

**Pass Criteria:**
- [ ] ENV-008 hygiene intact; no demo/test residue above local development.

### 4.2 Relationships & Integrity

**Verify:**
- [ ] Cascade chain: `auth.users` deletion cascades `entities` → dependent rows (purge path); soft-delete `status` is the normal operational path (D9).
- [ ] `professions.industry_id` RESTRICT prevents taxonomy orphaning.
- [ ] Uniqueness enforced: profile/entity, role/entity, slug global, binding/entity-pair, device token global.
- [ ] Check constraints hold on every vocabulary column; invalid states impossible via any granted path.

**Pass Criteria:**
- [ ] Referential and domain integrity proven under adversarial inserts.

### 4.3 Traceability & Accuracy

**Verify:**
- [ ] Every row carries audit columns; `updated_at` advances via trigger on mutation.
- [ ] Mutating RPC calls mirror entries into `platform_audit_log` with correct actor attribution.
- [ ] Verification-state defaults land exactly as specified (`unverified` bindings, `pending` credentials).

**Pass Criteria:**
- [ ] Data state transitions are accurate, defaulted correctly, and fully auditable.

---

## 5. Security Verification

### 5.1 Authentication & Authorization

**Verify:**
- [ ] `auth.uid()`/JWT context is the sole identity source in policies/RPCs.
- [ ] Anon: taxonomy reads only; no EXECUTE on any entity RPC.
- [ ] Authenticated users access exclusively their own rows across all seven private tables.
- [ ] Service-role bypass remains server-tooling-only.

**Pass Criteria:**
- [ ] Authentication and authorization enforced server-side with zero client bypass.

### 5.2 Access Control & Privileged-State Protection

**Verify:**
- [ ] Default-deny posture with explicit policies on all nine tables.
- [ ] Verification columns (`trade_verification_status`, `verified_by/at`, `reviewed_*`, `rejection_reason`) absent from every client-facing grant — attempted writes fail (pgTAP-asserted).
- [ ] Credential UPDATE denied to owners; role DELETE denied; taxonomy writes denied to all clients.
- [ ] No client path exists to transition any verification state.

**Pass Criteria:**
- [ ] Rules 2 and 3 cannot be bypassed through any exposed surface.

### 5.3 Sensitive Data Protection & Secrets

**Test Procedure:**

```powershell
Select-String -Path supabase\migrations\*.sql, supabase\config.toml, supabase\README.md -Pattern "service_role|private_key|password|secret|token=|eyJhbGciOiJIUzI1NiIs"
```

**Verify:**
- [ ] No service-role keys, DB passwords, access tokens, JWT material, or live URLs committed.
- [ ] Credentials used during promotion existed only in session environment/secrets.
- [ ] Error messages and audit output contain static text only.

**Pass Criteria:**
- [ ] Zero sensitive values in the repository; matches flagged variable names reviewed as safe.

### 5.4 Security Rules & Posture

**Verify:**
- [ ] No new `SECURITY DEFINER`; injection-resistant parameterized functions; payload validation applied.
- [ ] Realtime excludes all nine tables; PostgREST exposure governed solely by grants.
- [ ] Full-schema posture audit (`008`) passes: RLS-everywhere, zero anon grants, trigger presence, column-grant restrictions, comment coverage.

**Pass Criteria:**
- [ ] All automated security assertions green.

---

## 6. Performance Verification

**Verify:**
- [ ] Every RLS predicate resolves through PK/FK/partial indexes (`EXPLAIN` spot-check on representative queries in local instance).
- [ ] Slug lookups hit unique indexes (constant-time).
- [ ] Trigger cost limited to single assignment per UPDATE; no chained triggers.
- [ ] RPC bodies small/composable; no N+1 loops; volatility declared correctly.
- [ ] Full pgTAP suite (8 files) completes comfortably within CI budget (current baseline ~4 min vs 45-min ceiling).
- [ ] Installer size untouched (no Dart/assets/packages) — 15–20 MB target unaffected.
- [ ] UUIDv4 locality caveat documented for future EP-08 revisit.

**Pass Criteria:**
- [ ] No institutionalized performance debt; CI runtime acceptable.

---

## 7. Testing Verification

### 7.1 Required pgTAP Files

- [ ] `005_entity_rls_leakage_matrix.sql`
- [ ] `006_taxonomy_integrity.sql`
- [ ] `007_entity_rpc_enforcement.sql`
- [ ] `008_full_schema_posture_audit.sql`
- [ ] Existing `001`–`004` remain byte-identical and green.

### 7.2 Entity Leakage Matrix (`005`)

Per private table: anon read/write denied; cross-entity read/update/insert-as/delete denied; full self-CRUD per grant matrix; service-role bypass; credential-owner UPDATE denied; verification-column write denied.

### 7.3 Taxonomy Integrity (`006`)

Anon + authenticated readability; client/service-denied writes; slug uniqueness violations rejected; industry RESTRICT enforced; referential integrity holds; cascade behavior correct.

### 7.4 RPC Enforcement (`007`)

Auth gates (`PLT001`); validation (`PLT003`); not-found (`PLT004`); conflict (`PLT005`); credentials land `pending` only; envelope shape verified; audit rows written for mutating calls.

### 7.5 Posture Audit (`008`)

RLS enabled on every public-schema table; zero anon grants schema-wide; expected triggers present; column-grant exclusions verified; Realtime exclusion; comment spot-checks; no secrets in migrations.

### 7.6 Execution

**Local:**

```powershell
supabase start
supabase db reset
supabase test db
```

- [ ] Build-from-zero succeeds; full suite green locally.

**CI:**
- [ ] Expanded suite green on PR and push; workflow file unmodified.

**Regression:**
- [ ] `flutter analyze` clean; `flutter test` passes (no Dart deltas expected).

**Edge Cases & Failure Scenarios:**
- [ ] Empty/null payloads fail closed (`PLT003`).
- [ ] Concurrent duplicate binding attempts yield single row + `PLT005` for loser.
- [ ] Deactivated-profession rebinding blocked (`PLT004`).
- [ ] Cross-user device/settings manipulation denied.
- [ ] Oversized names/bio/titles rejected with safe messages.
- [ ] Purge cascade removes dependents without orphaning audit log.

**Scope Validation:**

```powershell
git status --short
git diff --stat
git diff "documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 Core-Platform-Foundation-Infrastructure.md"
git diff "documents/Task-Implementation/EP-01/EP-01-06-Universal Entity Data Model & Core Schema Design.md"
```

**Expected Output:** No diff output for protected documents — phase document and approved implementation plan were not modified.

- [ ] Final diff contains only approved EP-01-06 changes.
- [ ] No Dart code, no workflow edits, no EP-01-05 migration edits, no phase-document changes.

---

## 8. User Acceptance Verification

### 8.1 Project Lead Manual Review

**Project Lead Manual Check:**

- [ ] Four new migrations follow the approved §5.4 structure and ordering.
- [ ] All nine tables match blueprint §5.3 (spot-check against the plan during review).
- [ ] Promotion to Staging then Production was witnessed with dry-run summaries and explicit approval gates (ENV-007).
- [ ] Migration ledgers verified (`Remote database is up to date`) on each environment.
- [ ] Zero entity/taxonomy rows confirmed on Staging and Prod post-push.
- [ ] The runbook clearly documents the entity surface, access model, RPC contract, and promotion notes.
- [ ] CI reports the entity leakage matrix result on every PR.
- [ ] EP-02 requirements-validation checklist results reviewed and accepted.
- [ ] Any deviation from the approved plan is documented and explicitly approved.

### 8.2 Downstream Readiness

**Pass Criteria:**

- [ ] EP-01-07 (Core API Layer) is unblocked — table shapes and RPC signatures documented for consumption.
- [ ] EP-01-08 (Unified Data Access Layer) is unblocked — reference vertical-slice schema available for mappers/repositories.
- [ ] EP-01-09 (Authentication & Authorization) is unblocked — entity↔`auth.users` identity mapping in place.
- [ ] EP-02 (Trust & Identity Engine) prerequisites validated — taxonomy, verification gate fields, legal-name anchor, stable keys all proven.
- [ ] No downstream implementation was prematurely included.

### 8.3 Document Integrity

**Test Procedure:**

```powershell
git diff "documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 Core-Platform-Foundation-Infrastructure.md"
git diff "documents/Task-Implementation/EP-01/EP-01-06-Universal Entity Data Model & Core Schema Design.md"
git diff "documents/Context/ARCHITECTURE.md"
git diff "documents/Context/AGENT.md"
git diff --stat -- supabase/migrations/20260819090001_enforcement_foundation.sql supabase/migrations/20260819090002_reference_tables_rls.sql supabase/migrations/20260819090003_foundational_rpcs.sql .github/workflows/
```

**Expected Output:** No diff output — the phase document, approved implementation plan, architecture/directive documents, EP-01-05 migrations, and CI workflows are all unchanged.

**Pass Criteria:**
- [ ] The approved implementation plan remains unchanged.
- [ ] The EP-01 phase document remains unchanged.
- [ ] `ARCHITECTURE.md` remains unchanged.
- [ ] `AGENT.md` remains unchanged.
- [ ] All EP-01-05 artifacts remain unchanged.
- [ ] Existing CI workflows remain unchanged.

---

## 9. Final Approval Checklist

Task EP-01-06 can be marked as **COMPLETED** only when ALL of the following conditions are satisfied:

| # | Condition | Verification Method | Pass/Fail |
|---|---|---|---|
| 1 | Four new migrations exist, append-only, ordered after EP-01-05 files | Section 3.1 — migration listing | ☐ |
| 2 | Existing EP-01-05 migrations byte-identical | Section 8.3 — `git diff` | ☐ |
| 3 | Clean rebuild from zero succeeds (`db reset`) | Section 3.1 — local rebuild | ☐ |
| 4 | All nine tables exist per blueprint §5.3 | Section 3.2 — schema review | ☐ |
| 5 | Audit columns + `updated_at` triggers on every mutable table | Section 3.2 / 4.3 — schema review + tests | ☐ |
| 6 | RLS enabled + default-deny on all nine tables | Section 3.4 / 7.5 — posture audit | ☐ |
| 7 | Policy naming `<table>_<role>_<op>` with comments | Section 3.4 — policy review | ☐ |
| 8 | Anon surface limited to taxonomy SELECT; zero anon EXECUTE on new RPCs | Section 5.1 — leakage matrix | ☐ |
| 9 | Authenticated users restricted to own rows on all private tables | Section 7.2 — leakage matrix | ☐ |
| 10 | Column-level ACLs block all verification/review-field writes | Section 5.2 — pgTAP assertion | ☐ |
| 11 | Credentials owner-immutable (no client UPDATE) | Section 2.5 / 7.2 — tests | ☐ |
| 12 | Fluid multi-role operation verified (multiple simultaneous active roles) | Section 2.1 — functional test | ☐ |
| 13 | Role vocabulary CHECK enforced server-side (`PLT003`) | Section 2.1 / 7.4 — tests | ☐ |
| 14 | Legal-name anchor validated via RPC with audit trail | Section 2.2 / 7.4 — tests | ☐ |
| 15 | Profession binding lands `unverified`; duplicates conflict (`PLT005`) | Section 2.4 / 7.4 — tests | ☐ |
| 16 | Credentials land `pending` with no approval path | Section 2.5 / 7.4 — tests | ☐ |
| 17 | Taxonomy publicly readable; writes service-role only | Section 2.3 / 7.3 — tests | ☐ |
| 18 | Settings/device self-CRUD incl. DELETE works within RLS | Section 2.6 — functional test | ☐ |
| 19 | Error contract upheld across all failure scenarios | Section 2.7 — error tests | ☐ |
| 20 | All new RPCs SECURITY INVOKER; no new SECURITY DEFINER | Section 3.3 — code/posture review | ☐ |
| 21 | Envelope + `PLT###` contract consistent with EP-01-05 | Section 3.3 — envelope checks | ☐ |
| 22 | Realtime excludes all nine tables | Section 3.4 / 7.5 — posture audit | ☐ |
| 23 | pgTAP `005`–`008` authored and green locally with `001`–`004` | Section 7.6 — local run | ☐ |
| 24 | Expanded suite green in CI; workflow files unmodified | Section 3.5 / 7.6 — CI verification | ☐ |
| 25 | Migrations promoted Dev → Staging → Prod with lead gates | Section 8.1 — promotion witness | ☐ |
| 26 | Ledger verification passed per environment | Section 8.1 — dry-run output | ☐ |
| 27 | Zero business/seed rows in Staging and Prod | Section 4.1 — data review | ☐ |
| 28 | EP-02 requirements-validation checklist executed and recorded | Section 8.1 / 8.2 — checklist review | ☐ |
| 29 | No Dart/packages/assets/Edge Functions/Storage/auth flows added | Section 7.6 — scope validation | ☐ |
| 30 | `flutter analyze` and `flutter test` pass | Section 7.6 — regression | ☐ |
| 31 | Static scans confirm no secrets committed | Section 5.3 — secret scan | ☐ |
| 32 | Runbook updated (entity surface, access model, RPC contract) | Section 8.1 — documentation review | ☐ |
| 33 | Phase document, plan, ARCHITECTURE.md, AGENT.md unchanged | Section 8.3 — `git diff` | ☐ |
| 34 | Final diff contains only approved EP-01-06 changes | Section 7.6 — diff review | ☐ |
| 35 | Any deviation documented and lead-approved | Section 8.1 — sign-off | ☐ |

---

## Approval Signature

| Role | Name | Date | Approved |
|---|---|---|---|
| Project Lead | Abidemi Oluwadamilare | | ☐ |

---

> **Document Reference:** This DoD is derived exclusively from `EP-01-06-Universal Entity Data Model & Core Schema Design.md`, `ARCHITECTURE.md`, and `AGENT.md`. It must not be applied to any other task.
