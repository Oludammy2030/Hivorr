# TASK IMPLEMENTATION PLAN: EP-01-06

## Universal Entity Data Model & Core Schema Design

## Task Identification

| Field | Value |
|---|---|
| Task ID | EP-01-06 |
| Task Name | Universal Entity Data Model & Core Schema Design |
| Related Phase | EP-01: Core Platform Foundation & Infrastructure |
| Status | Ready for Approval |
| Dependencies | EP-01-05 completed (enforcement foundation, audit-column convention, policy naming, RPC/error contract, pgTAP harness, CI workflow, runbook) |
| Repository State | Branch `master`; EP-01-01 through EP-01-05 completed. `supabase/` contains `config.toml`, 3 versioned migrations, 4-file pgTAP suite (`001`–`004`), and runbook `README.md`. `.github/workflows/database-rls-tests.yml` executes the suite on PR/push. Staging + Prod cloud projects migrated and pristine; Dev = local Supabase instance (Docker), per EP-01-05 Deviation 3 |

---

## 1. Task Objective

Design and implement the **Universal Entity data model** — the most critical data architecture decision in the platform:

- Create the nine core tables defined by the approved phase plan: `entities`, `entity_profiles`, `entity_roles`, `entity_credentials`, `industries`, `professions`, `entity_professions`, `entity_settings`, `entity_devices`.
- Model the **fluid multi-role entity**: one account operating simultaneously as professional, consumer, merchant, and/or rider with no siloed profiles or mode toggles (VISION.md Universal Entity Principle; phase objective 2).
- Implement the **two-tier taxonomy** (Industry → Profession) as schema placeholders validating the AGENT.md Rule 2 architecture, ready for EP-02's taxonomy registry.
- Apply the **EP-01-05 enforcement inheritance**: audit columns + `updated_at` triggers on every table, RLS enabled and default-deny on every table, explicit minimal grants, `<table>_<role>_<op>` policy naming, `platform_*` helper reuse, normalized `{success, code, message, data}` envelope and `PLT###` error contract.
- Deliver a **minimal server-side RPC set** proving that invariant-carrying entity operations (role activation, profession binding, credential submission, financial-anchor profile update) enforce rules **server-side only**, with privileged state transitions (verification approvals) having **no client path**.
- Extend the pgTAP suite proving **zero cross-entity data leakage** across all nine tables and correct taxonomy integrity.
- Validate the schema against **EP-02 requirements** (registration, KYC, trade verification gate, bound-payout name anchoring) before completion.

---

## 2. Business Problem Being Solved

Without this task:

- Every subsequent phase (EP-01-08 data layer, EP-01-09 auth, EP-02 trust engine onward) has no data foundation — nothing can be built, tested, or deployed.
- If the entity model is designed incorrectly, the failure is **catastrophic and propagates to all eight phases** (phase plan Risk register): retrofitting multi-role fluidity, taxonomy, or verification state onto a wrong schema forces breaking migrations across live financial data.
- Traditional per-user-type account models (separate customer/pro/rider tables) contradict the product's core differentiator — fluid role-shifting — and would force destructive redesign once marketplace phases arrive.
- Without a schema-level verification-state model (`trade_verification_status`), AGENT.md Rule 2 (bidding locked until `APPROVED`) and Rule 3 (deposit payer-name matching) cannot be enforced server-side in EP-02+, exposing the platform to unverified-trader fraud and financial-integrity failures.
- Without taxonomy tables, industries/professions cannot be onboarded, searched, or given SEO-stable URLs (`/p/:profession_slug/:entity_id` per ARCHITECTURE.md).

This task converts the platform's central architectural concept — the Universal Entity — into enforced database reality.

---

## 3. Scope

### In Scope

- Versioned, append-only SQL migrations under `supabase/migrations/` (Supabase CLI timestamp convention):
  - Taxonomy tables (`industries`, `professions`) with SEO-stable unique slugs.
  - Entity core tables (`entities`, `entity_profiles`, `entity_roles`, `entity_credentials`, `entity_professions`, `entity_settings`, `entity_devices`) with constraints, indexes, audit columns, and `updated_at` triggers.
  - RLS enablement + explicit policies + minimal grants on all nine tables (including column-level privilege restriction on verification-state fields).
  - Minimal entity-lifecycle RPC set with validation, envelope responses, typed errors, audit-log integration, and narrowed `GRANT EXECUTE`.
- Realtime exclusion of all nine tables (extending the EP-01-05 DO-block pattern).
- pgTAP suite extension (new files `005`–`008` under `supabase/tests/database/`): entity leakage matrix, taxonomy integrity, RPC enforcement, whole-schema posture audit.
- Runbook update (`supabase/README.md`) documenting the entity surface, access model, and RPC contract.
- Migration promotion Dev (local) → Staging → Prod with lead approval gates (ENV-007) and zero-data verification.
- Regression: `flutter analyze` / `flutter test` (no Dart changes expected).
- Explicit EP-02 requirements-validation exercise, recorded in the Definition-of-Done document produced at completion.

---

## 4. Out of Scope

- Any Dart client code: API layer, datasources, repositories, DTOs, mappers, providers — EP-01-07/EP-01-08.
- Authentication & authorization framework — EP-01-09 (schema links to `auth.users`; no auth flows here).
- Taxonomy **seed/business data**: no `INSERT` of industries/professions in migrations; population happens in EP-02 via its approved registry flows. Test fixtures exist only inside the pgTAP suite (local/CI).
- Credential **Storage buckets/upload flows** — EP-02 wires Storage; this task defines only the `document_path` reference column.
- Admin review-gate RPCs approving/rejecting credentials or trades — EP-02 (this task ensures **no client-writable path exists** for those transitions).
- Marketplace/discovery surfaces, public entity-directory projections, search indexing — EP-03+.
- Wallets, escrow, payouts, KYC provider integration — EP-02+ (schema only reserves stable keys and the legal-name anchor).
- Edge Functions, Realtime subscriptions, foreign-data wrappers, unapproved extensions.
- Modification of existing EP-01-04/EP-01-05 workflow files, applied migrations, the approved phase document, ARCHITECTURE.md, or AGENT.md.
- Final feature documentation (a Definition-of-Done document is produced at completion, per established practice).

---

## 5. Recommended Technical Approach

### 5.1 Design Principles (Inherited & Binding)

| Principle | Source |
|---|---|
| Client = unprivileged presentation layer; enforcement server-side | AGENT.md Rule 4, ARCHITECTURE.md |
| RLS enabled + default-deny on every table; explicit grants only | EP-01-05 §5.4 |
| Audit columns (`created_at`, `updated_at`, `created_by`) + `platform_set_updated_at()` trigger on every mutable table | EP-01-05 migration 1 convention |
| Policy naming `<table>_<role>_<op>`; `COMMENT ON` everything | EP-01-05 §5.5 |
| `SECURITY INVOKER` RPCs by default; `SECURITY DEFINER` only with pinned `search_path` | EP-01-05 §5.6 |
| Envelope `{success, code, message, data}`; codes `PLT000`–`PLT999`; static messages | EP-01-05 error contract |
| Migrations append-only, one logical change each, reproducible via `supabase db reset` | EP-01-05 §5.2 |
| No secrets, no dynamic SQL from user input, parameterized functions | EP-01-05 §12 |

### 5.2 Key Design Decisions (lead confirmation requested at approval)

| # | Decision | Recommendation | Rationale |
|---|---|---|---|
| D1 | Entity↔auth-user identity mapping | `entities.id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`, defaulting to `auth.uid()` | 1:1 identity keeps every RLS policy a cheap indexed `id = auth.uid()` predicate; eliminates join indirection in policies; registration always occurs post-auth. Stable UUIDs satisfy all future phases' foreign keys. |
| D2 | Role representation | Text + `CHECK` constraints (not PostgreSQL `ENUM`s) for role/status/kind vocabularies | CHECK sets migrate forward trivially (`ALTER TABLE DROP/ADD CONSTRAINT`); ENUM removal is impossible — protects EP-08 extensibility. Values today: roles `('consumer','professional','merchant','rider')` per phase objective 2. |
| D3 | Profile cardinality | `entity_profiles.entity_id UNIQUE` — strictly 1:1 today; table named plural to allow additive relaxation later | Matches phase table list; avoids premature multi-profile complexity; financial anchor stays singular. |
| D4 | Verification state location | Per-profession binding: `entity_professions.trade_verification_status ('unverified','pending','approved')`; credentials carry their own `verification_status` | Directly implements AGENT.md Rule 2 (bidding locked per profession until `APPROVED`); credentials evidence the trades. |
| D5 | Privileged-column protection | Column-level `GRANT`s: clients may INSERT/UPDATE only permitted column lists; verification columns (`trade_verification_status`, `verified_by/at`, `reviewed_*`) have **zero** client grant | Stronger than trigger guards alone; enforced by PostgreSQL ACLs; asserted by pgTAP. Transitions belong to future server-side workflows (EP-02). |
| D6 | Taxonomy visibility | `SELECT` granted to `anon` + `authenticated` on `industries`/`professions`; no client writes ever (service-role only) | Onboarding pickers and public SEO pages need pre-auth taxonomy reads; registry mutation is administrative (EP-02). |
| D7 | Entity data visibility | Strictly self-scoped (owner = `auth.uid()`). No public entity-profile projection in EP-01-06 | Zero-trust default; public discovery surfaces are EP-03 concerns and must be deliberate, reviewed exposures — not accidental grants. |
| D8 | Taxonomy seed data | None in migrations; empty structured tables ship to all environments; dev-only fixtures confined to the pgTAP suite | Preserves ENV-008 hygiene and the EP-01-05 "no operational INSERTs" rule; EP-02 owns registry population. |
| D9 | Deletion semantics | Soft-delete via `status` on `entities` (`active`,`suspended`,`deactivated`,`deleted`); `ON DELETE CASCADE` from `auth.users` as last-resort purge; `DELETE` grants only on `entity_settings` and `entity_devices` (ephemeral data) | Financial/audit history must survive; device tokens and preferences are safely revocable. |

### 5.3 Proposed Schema (implementation-level blueprint)

**`entities`** — root identity node (D1, D9): `id uuid PK → auth.users(id)`; `status text NOT NULL DEFAULT 'active' CHECK (...)`; audit columns; trigger. **No `entity_type` column** — capability is expressed exclusively through `entity_roles`, which is what makes the model universal and fluid.

**`entity_profiles`** — 1:1 (D3): `id uuid PK`; `entity_id uuid NOT NULL UNIQUE → entities ON DELETE CASCADE`; `legal_name text NOT NULL` (**Rule 3 deposit-matching anchor**); `display_name text NOT NULL`; `bio text`; `avatar_path text` (Storage lands in EP-02); `country_code char(2)` (cheap now, avoids painful EP-08 backfill); audit columns; trigger. Contact PII deliberately stays in Supabase Auth — minimal-PII principle.

**`entity_roles`** — fluid shift (D2): `id uuid PK`; `entity_id FK`; `role text NOT NULL CHECK IN ('consumer','professional','merchant','rider')`; `is_active boolean DEFAULT true`; `activated_at timestamptz`; `UNIQUE(entity_id, role)`; audit columns; trigger. Deactivation = `is_active = false`; no DELETE grant.

**`entity_credentials`** — trust evidence: `id uuid PK`; `entity_id FK`; `profession_id nullable FK`; `kind text CHECK ('identity_document','trade_proof','certification')`; `title text`; `document_path text` (bucket wiring = EP-02); `verification_status text CHECK ('pending','approved','rejected') DEFAULT 'pending'`; `submitted_at`, `reviewed_at`, `reviewed_by uuid`, `rejection_reason text`, `expires_at`; audit columns; trigger. Clients: SELECT/INSERT own rows only; **UPDATE denied** (submissions immutable; fixes = resubmit); review columns unreachable by clients (D5).

**`industries`** (tier 1): `id uuid PK`; `slug text UNIQUE NOT NULL` (lowercase-check); `name`; `description`; `is_active`; `sort_order`; audit columns; trigger. **`professions`** (tier 2): as above + `industry_id NOT NULL → industries` (RESTRICT); `UNIQUE(slug)`; `INDEX(industry_id)`. Publicly readable (D6).

**`entity_professions`** — junction + gate (D4): `id uuid PK`; `entity_id FK`; `profession_id FK`; `UNIQUE(entity_id, profession_id)`; `is_primary boolean`; `trade_verification_status CHECK ('unverified','pending','approved') DEFAULT 'unverified'`; `verified_at`, `verified_by`; audit columns; trigger. Column-level grants exclude verification fields (D5).

**`entity_settings`**: composite PK `(entity_id, setting_key)`; `value jsonb NOT NULL DEFAULT '{}'`; audit columns; trigger; full self CRUD incl. DELETE.

**`entity_devices`**: `id uuid PK`; `entity_id FK`; `device_token text UNIQUE NOT NULL`; `platform CHECK ('android','ios','web','macos','windows','linux')`; `device_name`; `app_version`; `is_active`; `last_seen_at`; audit columns; trigger; self CRUD incl. DELETE (push-token lifecycle).

**Indexing:** every FK indexed; partial indexes `entity_roles(entity_id) WHERE is_active`, `entity_professions(entity_id) WHERE trade_verification_status = 'approved'`, `entity_credentials(entity_id, verification_status)`; descending `created_at` mirrors EP-01-05 convention.

### 5.4 Proposed Repository Structure (additive only)

```text
supabase/
├── migrations/
│   ├── (existing EP-01-05 files untouched — append-only)
│   ├── <ts>_entity_taxonomy_tables.sql      # industries, professions
│   ├── <ts>_entity_core_tables.sql          # entities, profiles, roles,
│   │                                        # credentials, junction, settings, devices
│   ├── <ts>_entity_model_rls_policies.sql   # RLS, grants (incl. column-level),
│   │                                        # triggers, realtime exclusion
│   └── <ts>_entity_model_rpcs.sql           # enforcement RPC set + EXECUTE grants
├── tests/database/
│   ├── (existing 001–004 untouched)
│   ├── 005_entity_rls_leakage_matrix.sql
│   ├── 006_taxonomy_integrity.sql
│   ├── 007_entity_rpc_enforcement.sql
│   └── 008_full_schema_posture_audit.sql
└── README.md                                # extended: entity surface + RPC contract
```

### 5.5 Minimal Entity RPC Set (all `SECURITY INVOKER`, envelope-returning, audit-integrated)

| RPC | Purpose | Enforcement demonstrated |
|---|---|---|
| `entity_profile_update(p_legal_name, p_display_name, p_bio)` | Guarded mutation of the financial-anchor profile (trim/length validation; audit-logged) | Rule 3 anchor discipline; validated self-write |
| `entity_roles_activate(p_role)` / `entity_roles_deactivate(p_role)` | Fluid role shifting with vocabulary validation (`PLT003` on unknown role) | Server-side state rule on the fluidity model |
| `entity_profession_bind(p_profession_id)` | Binds profession after checking existence/activity (`PLT004`), duplicate (`PLT005`); lands as `unverified` | Relational validation server-side; Rule 2 gate initialization |
| `entity_credentials_submit(p_kind, p_title, p_profession_id, p_document_path)` | Creates `pending` credential; audit-logged | Privileged state creation only — no client path to `approved`/`rejected` (EP-02 owns review) |

Direct owner-scoped table grants (mirroring the proven `platform_demo_records` pattern) cover plain self-CRUD; RPCs exist where invariants live. Anon receives **nothing**. Reuses `platform_is_authenticated()`, `platform_validate_payload()`, `platform_raise_error()`, `platform_audit_log_add()` unchanged.

### 5.6 Environment Promotion

Identical to EP-01-05 §5.7: local Dev rebuild (`db reset`), then `--dry-run` + lead approval gate + session-pooler (6543) push to Staging, then Production; ledger verification (`Remote database is up to date`); zero-row verification post-push. CI requires no workflow change — `supabase test db` auto-discovers `005`–`008`.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Responsibility |
|---|---|---|
| Versioned migrations (4 new) | `supabase/migrations/` | Entity/taxonomy schema, RLS/grants, RPCs |
| Enforcement inheritance | EP-01-05 migration 1 helpers | Auth context, triggers, validation, typed errors, audit path |
| Nine core tables | Supabase PostgreSQL | Universal Entity data model |
| RLS policies + column-level grants | Migrations | Default-deny isolation; privileged-field protection |
| Entity RPC set (4–5 functions) | Migrations | Server-side invariant enforcement |
| pgTAP extensions (4 new files) | `supabase/tests/database/` | Leakage matrix, integrity, RPC, posture proofs |
| Existing CI workflow | `.github/workflows/database-rls-tests.yml` | Runs extended suite automatically (unmodified) |
| Runbook | `supabase/README.md` | Updated surface/access/RPC documentation |
| Promotion tooling | Supabase CLI (pinned 2.115.0) + pooler creds via secrets | Dev → Staging → Prod with gates |

No new Dart package, no `pubspec.yaml` change, no `lib/` code.

---

## 7. Data Requirements

- **Zero user/business data** in any environment from this task; migrations carry no operational `INSERT`s (D8).
- Test fixtures (users, entities, taxonomy rows) exist only inside pgTAP transactional contexts (local/CI); Cloud Staging runs follow the EP-01-05 hygiene protocol (`discard all`, statement-by-statement execution, post-run cleanup, **never** against Production).
- Schema must represent: one fluid entity → N simultaneous active roles; 1:1 profile with legal-name anchor; M:N entity↔profession bindings with per-binding verification state; 1:N credentials with immutable submissions; arbitrary keyed settings; N registered devices.
- All rows traceable via audit columns; security-relevant mutations additionally mirrored into `platform_audit_log`.

---

## 8. Database Considerations

Central deliverable. Requirements:

- RLS enabled + default-deny on all nine tables; policies resolve through PK/FK indexes (`auth.uid()` predicates — no function calls that defeat index usage beyond the existing `STABLE` helpers).
- Column-level grants implement D5; pgTAP-asserted.
- Referential integrity: cascades from `entities` to dependent rows; RESTRICT on `professions.industry_id` (taxonomy stability); `auth.users` cascade as purge path.
- Uniqueness: profile per entity, role per entity, profession-slug global, profession-binding per entity, device token global.
- Check-constrained vocabularies (D2); `COMMENT ON` for every table, column of note, policy, and function.
- Triggers limited to the single lightweight `updated_at` statement — no heavy chains.
- Correct volatility declarations (`STABLE` reads, `VOLATILE` writes); parameterized SQL only; no dynamic SQL.
- Realtime publication excludes all nine tables.
- No unapproved extensions; stock PostgreSQL + existing EP-01-05 surface only.

---

## 9. API Requirements

- **No client API code** (EP-01-07/08 consume this).
- Deliverable is the **server-side contract**: nine table shapes (columns/types/constraints) for EP-01-08 mappers; four-to-five RPC signatures with parameter types, auth requirements, envelope shape, and `PLT###` outcomes for EP-01-07 interceptors and EP-01-09 guards.
- Exposure governed by `GRANT EXECUTE`/table grants via PostgREST; documented in the runbook's access-model table (extended EP-01-05 §9 format).
- Contract stability rule: any post-approval column/RPC change requires a lead-approved amendment before implementation proceeds.

---

## 10. User Interface Requirements

**Not applicable.** No widgets, screens, routes, or user-facing behavior. `lib/` remains untouched; regression only.

---

## 11. User Experience Considerations

Developer and operator experience only:

- One-command reproducibility: `supabase start` → `db reset` → `test db` yields the full entity model + green suite.
- Runbook clearly maps the entity surface, access model, and RPC contract for downstream phase engineers.
- CI reports the entity leakage matrix on every PR.
- Safe static error messages throughout (`PLT###`), never revealing data values.
- Lead approval gates before any non-local promotion, with dry-run summaries for review.

---

## 12. Security Considerations

| Risk | Required Control |
|---|---|
| Cross-entity data leakage | Owner-scoped RLS on all seven private tables; leakage-matrix tests for anon/A/B actors on every table |
| Unauthenticated access | Zero anon table grants; zero anon EXECUTE on entity RPCs; taxonomy SELECT is the sole anon surface (D6) |
| Verification-state forgery (Rule 2 bypass) | No client grant whatsoever on verification columns (D5); pgTAP asserts denial; review transitions reserved to future server-side workflows |
| Legal-name manipulation (Rule 3 bypass) | Profile mutation only via validating RPC, audit-logged; EP-02 adds re-verification workflow on change |
| Privilege escalation via RPC | `SECURITY INVOKER` everywhere; no new `SECURITY DEFINER`; auth check inside every RPC in addition to narrowed grants |
| Injection | Parameterized functions; no dynamic SQL; payload validation via existing helper |
| Taxonomy tampering | No client write grants on `industries`/`professions`; service-role only |
| Secrets in repository | Static scans (existing CI step + local); no credentials in migrations/config/docs |
| Environment contamination | Isolated projects; append-only migrations; gated promotion (ENV-007/ENV-008) |
| Realtime exposure | All nine tables excluded from publication |
| Orphaned/untraceable mutations | Audit columns everywhere + `platform_audit_log_add` on security-relevant RPC paths |

---

## 13. Performance Considerations

- Policy predicates hit indexed UUID equality — O(1) index lookups; partial indexes keep hot predicates (active roles, approved professions) narrow.
- Slugs unique-indexed for constant-time SEO lookups (`/p/:profession_slug/:entity_id`).
- Composite PK on settings avoids surrogate overhead; JSONB values validated as objects where written via RPC.
- UUIDv4 PKs accepted for EP-01 (documented note: revisit index-locality characteristics at scale in EP-08 if write volume warrants).
- Trigger cost = one assignment per UPDATE; audit writes append-only and lightweight.
- No N+1 loops inside RPC bodies; small composable functions.
- Suite runtime target: full pgTAP set (8 files) comfortably within existing CI budget (~45-min ceiling, currently ~4 min).
- Zero impact on the 15–20 MB installer (no Dart/assets/packages).

---

## 14. Testing Strategy

### 14.1 Entity RLS Leakage Matrix (new pgTAP `005`)
Per table (`entities`, `entity_profiles`, `entity_roles`, `entity_credentials`, `entity_professions`, `entity_settings`, `entity_devices`): anon read/write denied; user A cannot read/update/insert-as/delete user B's rows; A enjoys full self-CRUD per grant matrix; `service_role` bypasses (server-side only); credential UPDATE denied even to owner; verification-column updates denied even to owner (column-grant assertion).

### 14.2 Taxonomy Integrity (new `006`)
Public readability of `industries`/`professions` for anon + authenticated; client/service-denied writes; slug uniqueness; `industry_id` RESTRICT behavior; profession→industry referential integrity; cascade behavior from entity deletion.

### 14.3 Entity RPC Enforcement (new `007`)
Auth required (`PLT001`); unknown role (`PLT003`); unknown/inactive profession (`PLT004`); duplicate binding (`PLT005`); credential lands `pending` with no approval path; envelope shape on success; audit-log rows written for mutating calls; legal-name trim/length validation.

### 14.4 Full-Schema Posture Audit (new `008`)
Generic assertions: **every** table in `public` has RLS enabled; zero anon table grants schema-wide; all expected triggers present; verification columns absent from client column-grants; Realtime exclusion for all nine tables; no secrets in new migrations; `COMMENT ON` presence spot-checks.

### 14.5 Execution & Regression
- Local: `supabase start` → `supabase db reset` → `supabase test db` until green (69 existing + new assertions).
- CI: existing workflow runs the expanded suite automatically — **no workflow modification**.
- Cloud: staged promotion with dry-run gates; optional Staging suite run per EP-01-05 hygiene protocol; Production never test-run.
- Regression: `flutter analyze` / `flutter test` (expect no Dart deltas); static secret scans; final-diff scope review.

---

## 15. Recommended Implementation Sequence

1. Verify EP-01-05 state intact: migrations, suite 69/69 locally, runbook; confirm branch cleanliness.
2. Record the D1–D9 design decisions and the EP-02 requirements-validation checklist in the working plan notes; obtain lead confirmation of flagged decisions at the plan-approval gate.
3. Write migration 1 — taxonomy tables (`industries`, `professions`).
4. Write migration 2 — seven entity core tables (constraints, indexes, audit columns, triggers, comments).
5. Write migration 3 — RLS enablement, policies, minimal + column-level grants, realtime exclusion.
6. Write migration 4 — entity RPC set + `GRANT EXECUTE` scoping.
7. Local rebuild from zero (`db reset`); resolve any ordering/dependency issues; confirm append-only discipline vs EP-01-05 files.
8. Author pgTAP `005`–`008`; iterate locally to green alongside existing `001`–`004`.
9. Push branch; verify CI green (expanded suite + secret scan; no workflow edits).
10. Promotion gate — apply to Development (local instance) if not already current; verify.
11. Approval gate — `--dry-run` summary, lead approval, push to Staging; verify ledger + zero rows.
12. Approval gate — same for Production; verify ledger + zero rows.
13. Execute the EP-02 validation checklist against the live schema (registration path, taxonomy binding, verification gate fields, legal-name anchor, stable-key fitness) and record results.
14. Update `supabase/README.md`: entity surface, access-model table, RPC contract, promotion notes.
15. Regression: `flutter analyze` / `flutter test`; final static scans.
16. Review final diff for strict EP-01-06 scope containment (no Dart, no workflow edits, no EP-01-05 migration edits, no phase-document changes).
17. Stop at the implementation approval boundary — no EP-01-07/08/09 work begins.

---

## 16. Expected Outcome

- Nine RLS-protected core tables implementing the Universal Entity model: fluid multi-role operation, two-tier taxonomy, verification-state gating, legal-name financial anchor, settings, and device registry — with audit columns and triggers throughout.
- Proven zero-leakage isolation (extended pgTAP matrix) and hardened privileged-field protection via column-level grants.
- A minimal, documented entity RPC contract extending the EP-01-05 envelope/error standard, ready for EP-01-07/08/09 consumption.
- Schema demonstrably validated against EP-02 requirements before completion — the catastrophic-redesign risk retired.
- Extended CI-enforced test suite, updated runbook, and clean promotion across Dev → Staging → Prod with zero business data anywhere.

---

## 17. Definition of Done (DoD)

**Structure & Migrations**
- [ ] Four new migrations exist under `supabase/migrations/`, timestamp-ordered after EP-01-05 files, append-only, one logical change each.
- [ ] `supabase db reset` reproduces the entire schema from zero; existing EP-01-05 migrations byte-identical (untouched).
- [ ] All nine tables exist with the approved columns, constraints, and comments; audit columns + `updated_at` triggers on every mutable table.
- [ ] No `INSERT` of operational/seed data in any migration.

**Enforcement**
- [ ] RLS enabled and default-deny on all nine tables; policy naming follows `<table>_<role>_<op>`; `COMMENT ON` present.
- [ ] Anon holds zero table grants except taxonomy `SELECT`; zero anon `EXECUTE` on all new RPCs.
- [ ] Verification-state columns have no client-facing grants (column-level ACLs verified).
- [ ] Credential rows are owner-immutable (no client UPDATE); settings/device DELETE paths work as specified.
- [ ] All new RPCs are `SECURITY INVOKER`, auth-gated, envelope-returning, `PLT###`-typed, and audit-integrated; no new `SECURITY DEFINER` functions.
- [ ] Realtime excludes all nine tables.

**Testing**
- [ ] pgTAP `005`–`008` authored and green locally together with `001`–`004` (full suite passes).
- [ ] Leakage matrix proves anon/cross-entity denial and self-access correctness for every table.
- [ ] RPC tests prove `PLT001`/`PLT003`/`PLT004`/`PLT005` behaviors, `pending`-only credential creation, and audit writes.
- [ ] Posture audit proves RLS-everywhere, zero anon grants, trigger presence, column-grant restrictions, Realtime exclusion.
- [ ] CI green on PR/push without any workflow-file modification.

**Promotion & Data Hygiene**
- [ ] Migrations applied Dev (local) → Staging → Prod with dry-run summaries and explicit lead approval gates (ENV-007).
- [ ] Ledger verification (`up to date`) on each environment; zero entity/taxonomy rows in Staging and Prod post-push.
- [ ] Any cloud-suite execution followed the EP-01-05 hygiene protocol; Production never test-run.

**Validation & Containment**
- [ ] EP-02 requirements-validation checklist executed and recorded (registration, taxonomy binding, Rule 2 gate fields, Rule 3 legal-name anchor, stable-key fitness for escrow/payout phases).
- [ ] No Dart code, packages, assets, Edge Functions, Storage configuration, or auth flows added; `pubspec.yaml`/`pubspec.lock` unchanged.
- [ ] `flutter analyze` and `flutter test` pass.
- [ ] Static scans confirm no secrets, keys, or real URLs committed.
- [ ] Approved phase document, ARCHITECTURE.md, AGENT.md, and all EP-01-05 artifacts unchanged.
- [ ] Final diff contains only approved EP-01-06 changes; deviations documented and lead-approved.
- [ ] Definition-of-Done document produced for lead verification (per established practice).

---

## 18. AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

- **Technical complexity:** Extremely high — a nine-table relational model with identity mapping to `auth.users`, M:N junction semantics, column-level ACL engineering, partial/composite indexing, trigger wiring, and four interdependent migrations must be authored correctly in append-only form where early mistakes become permanent, breaking migrations.
- **Business impact:** Critical — the phase plan rates a wrong Universal Entity model "catastrophic — affects all future phases." Every marketplace, financial, logistics, verification, and AI feature in EP-02→EP-08 inherits these structures; retrofitting fluid multi-role or verification semantics later is a destructive, data-migrating event on live systems.
- **Security risk:** Extremely high — the schema *is* the zero-trust boundary's data plane: cross-entity isolation, verification-state forgery prevention, financial-anchor protection, and grant precision are all enforced here; a single over-broad grant or missing policy is a direct data-breach or Rule-2/Rule-3 bypass vector.
- **Performance sensitivity:** High — RLS predicates, index strategy, and policy shapes set the query-performance ceiling for every future server-side operation; institutionalizing unindexed policy checks or heavy triggers would tax the entire platform permanently.
- **Data complexity:** Extremely high — fluid 1:N role multiplicity, 1:1 profile anchoring, M:N taxonomy bindings with per-binding state machines, immutable-submission credentials, and purge-vs-soft-delete semantics must coexist under strict auditability and ENV isolation.
- **Integration complexity:** Extremely high — must inherit EP-01-05 conventions exactly (helpers, envelope, naming, migration discipline, CI, runbook), remain cleanly consumable by EP-01-07/08/09 without coupling, and satisfy EP-02+ requirements it cannot yet see — demanding forward-validating design judgment rather than mechanical table creation.

Extremely High reasoning is required because this is an irreversible, security-critical data-architecture keystone whose correctness must be reasoned forward across eight future phases.

---

## 19. Approval Required

**This implementation plan is ready for review and approval.**

Specifically, the lead's confirmation is requested on design decisions **D1–D9** (§5.2) — most consequentially: D1 (entity id = `auth.users.id`), D5 (column-level grant protection of verification state), D6 (anon-readable taxonomy), and D8 (zero taxonomy seed data; EP-02 owns population).

Upon approval, the plan document will be saved to `documents/Task-Implementation/EP-01/EP-01-06-Universal-Entity-Data-Model-Core-Schema-Design.md` (matching the established task-plan format), and implementation will begin only after a separate implementation approval. No production code is written during planning.
