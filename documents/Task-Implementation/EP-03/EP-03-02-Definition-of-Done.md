# Definition of Done — EP-03-02: Service Contract & Milestone Engine Schema & Lifecycle RPCs

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-02 |
| **Task Name** | Service Contract & Milestone Engine Schema & Lifecycle RPCs |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 1 Transaction Core |
| **Priority** | Critical |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-02-Service Contract & Milestone Engine Schema & Lifecycle RPCs.md:1-560` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:257-266` + `85` + `112-113` |
| **Dependencies** | EP-03-01 `service_listings` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:42-95`), EP-02-04 financial rails `financial_escrow:191-228` + `financial_escrow_milestones:232-257` + `financial_supported_currencies:37-62` (`supabase/migrations/20260829100004_financial_integrity_schema.sql`), `entities`/`professions` (`supabase/migrations/20260821090001_entity_taxonomy_tables.sql:15-55`, `supabase/migrations/20260821090002_entity_core_tables.sql:20-186`), EP-02-05 dispute helpers (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:282`), platform helpers (`supabase/migrations/20260819090001_enforcement_foundation.sql:37-82`) |
| **Delivery Scope** | 3 tables `service_contracts` / `contract_milestones` / `contract_events` (append-only) + 8 RPCs `SECURITY INVOKER` (`service_contract_offer`, `service_contract_accept`, `service_contract_cancel`, `service_contract_complete_milestone`, `service_contract_verify_milestone`, `service_contract_close`, `service_contract_get`, `service_contract_list_mine`) + participant RLS + `REVOKE EXECUTE` re-baseline + `8` `COMMENT ON FUNCTION` + realtime exclusion + 2 pgTAP suites. **Zero** `lib/` Dart, **zero** mutations to `service_listings`/`financial_escrow`/`dispute_cases`. Unblocks EP-03-03 → EP-03-17. |
| **Guardrails** | `documents/Context/AGENT.md:13` Rule 4 Database-First Zero-Trust, `documents/Context/AGENT.md:8` Rule 2 Two-Tier Taxonomy (published supply gate), `documents/Context/ARCHITECTURE.md:160-162` DB-First, `documents/Context/ARCHITECTURE.md:87-93` taxonomy binding |

**How to use this document:** Check each box only after executing the listed verification (SQL query, `supabase db test`, PostgREST `/rpc/` call) and observing the exact expected result. A single unchecked box blocks `Completed` status.

---

## 2. Functional Verification

Verifies user/system behaviors and RPC workflows defined in `EP-03-02-Service Contract & Milestone Engine Schema & Lifecycle RPCs.md:11-52` + `§9.1`.

### 2.1 Required Functionality

- [ ] **Contract offer** — Any authenticated `client_entity_id` can call `service_contract_offer(p_service_listing_id, p_total_amount, p_currency_code, p_milestones jsonb, p_offer_expires_at)` targeting a `service_listings.status='published'` listing not owned by the caller and receive `PLT000` with row `status='offered'`, `client_entity_id=auth.uid()`, `professional_entity_id=listing.entity_id` (derived, never client-supplied), `total_amount` as supplied, `currency_code` validated `is_active`, `offered_at=now()`, `escrow_id IS NULL`, plus `contract_milestones` rows `pending` with `UNIQUE(contract_id, milestone_number)` and `contract_events` row `event_type='offered'`. Server validates `sum(milestones.amount)=total_amount`.
- [ ] **Contract accept** — Only `professional_entity_id` (listing owner) can call `service_contract_accept(p_contract_id)` when `status='offered'` and `offer_expires_at` not expired and receive `PLT000` with `status='active'`, `accepted_at=now()`, plus `contract_events` `accepted`. Client caller or already `active` → blocked (`PLT004`/`PLT005`).
- [ ] **Contract cancel** — Either participant can call `service_contract_cancel(p_contract_id, p_reason)` when `status='offered'` → `cancelled` + `cancelled_at=now()` + event `cancelled`. `active` cancel by participant without `service_role` → `PLT005`; `service_role` may cancel `active` (admin, mirrors `service_listing_unpublish` moderation).
- [ ] **Milestone complete** — Only `professional_entity_id` can call `service_contract_complete_milestone(p_milestone_id, p_evidence_path)` when `contract.status='active'` and `milestone.status='pending'` and `contract.status!='disputed'` and `evidence_path LIKE 'service-listing-media/'||auth.uid()::text||'/%'` and receive `PLT000` with `milestone.status='completed'`, `completed_at=now()`, plus `contract_events` `milestone_completed`. Client caller, already `completed`, or `disputed` → `PLT005`.
- [ ] **Milestone verify** — Only `client_entity_id` can call `service_contract_verify_milestone(p_milestone_id, p_action)` when `milestone.status='completed'` and `contract.status='active'` and receive `PLT000` with `milestone.status='verified'`, `verified_at=now()`, plus `contract_events` `milestone_verified`; `p_action='revision_requested'` reverts `completed→pending`. Professional caller or `pending` verify → `PLT005`. When `count(milestones where status<>verified)=0`, contract auto-promotes to `completed`.
- [ ] **Contract close** — Either participant can call `service_contract_close(p_contract_id)` only when `contract.status='active'/'completed'` and **every** `contract_milestones.status='verified'` and receive `PLT000` with `status='closed'` + `closed_at=now()` + event `closed`. Not-all-verified → `PLT005`; non-participant → `PLT004`.
- [ ] **Contract get** — `service_contract_get(p_contract_id)` as participant returns `PLT000` with `{contract {id, service_listing_id, listing_slug/title, profession_slug/name, industry_slug/name, client_entity_id, professional_entity_id, status, total_amount, currency_code, escrow_id, offered_at, accepted_at, closed_at, created_at}, milestones[] ordered by sort_order, events[] ordered by created_at}`. Non-participant or unknown id → identical `PLT004` (no oracle per `supabase/migrations/20260913090001_portfolio_public_profile.sql:14-16`).
- [ ] **Contract list mine** — `service_contract_list_mine(p_status, p_limit, p_cursor)` as authenticated returns only caller's rows where `client_entity_id=auth.uid() OR professional_entity_id=auth.uid()`, keyset-paginated `(created_at DESC, id DESC)`, `p_limit 1-100` respected, `has_more` + `next_cursor` correct, optional `p_status` filter `draft/offered/active/completed/closed/cancelled/disputed` scoped. Cross-entity rows never returned; unknown cursor → empty (no oracle).

### 2.2 Expected Workflows (End-to-End)

- [ ] **Offer → Accept → Complete → Verify → Close happy path:** (1) Client `C` offers `published` listing `L` (owner `P`) with `p_total_amount=50000` `currency_code='NGN'` `p_milestones=[{milestone_number:1,title:"Draft Deliverable",amount:20000},{2,title:"Final Delivery",amount:30000}]` → `PLT000` `offered` + 2 milestones `pending` + event `offered`. (2) `P` calls `service_contract_accept` → `active` + `accepted_at NOT NULL` + event `accepted`. (3) `P` calls `service_contract_complete_milestone(m1,'service-listing-media/<P>/evidence.pdf')` → `m1 pending→completed`. (4) `C` calls `service_contract_verify_milestone(m1)` → `m1 completed→verified`; repeat for m2 → contract auto `completed`. (5) Either calls `service_contract_close` → `closed` + `closed_at NOT NULL`. `service_contract_get` as `C` and `P` both return full arrays; `escrow_id` remains `NULL` throughout (`EP-03-11` deferred).
- [ ] **Offer → Cancel (offered) path:** Client offers → either `C` or `P` calls `service_contract_cancel` while `offered` → `cancelled` + `cancelled_at NOT NULL` + event `cancelled`. Second cancel or `accept` after `cancelled` → `PLT005`.
- [ ] **Self-offer blocked:** `P` (listing owner) attempts `service_contract_offer` on own `L` → `PLT005` `You cannot create a contract for your own listing.` — no row created.
- [ ] **Draft listing blocked:** Client offers `service_listings.status='draft'` id → `PLT004` `Service listing not found or not available.` identical to unknown id.
- [ ] **Disputed freeze blocks verify/close:** After `active`, `service_contracts.status='disputed'` (future `EP-03-17` trigger or manual `service_role` update for test) → `service_contract_complete_milestone` → `PLT005` `Contract is disputed.`; `service_contract_verify_milestone` → `PLT005`; `service_contract_close` → `PLT005`.
- [ ] **Revision requested loop:** `P` completes m2 → `completed`; `C` calls `service_contract_verify_milestone(m2,'revision_requested')` → `m2 completed→pending` + event `milestone_revision_requested`; `P` re-completes → `C` verifies `verified` → close now succeeds.
- [ ] **List mine isolation:** `C` creates 2 offers, `P` receives both plus 1 from another client. `service_contract_list_mine` as `C` with `p_limit=1` → 1 item + `has_more=true`; second page `p_cursor=last_id` → remaining item; stranger `S` (third entity) → 0 rows for same contracts.

### 2.3 Success Conditions

- [ ] Every write RPC (`offer/accept/cancel/complete/verify/close`) returns envelope `{success:true, code:'PLT000', message:'...', data: to_jsonb(row)}` on success per `supabase/migrations/20260829100004_financial_integrity_schema.sql:17-19`.
- [ ] Every read RPC (`get`/`list_mine`) returns `PLT000` with `data` shape `§9.1`: `get` includes `contract` + `milestones[]` + `events[]`; `list_mine` includes `{items[], has_more bool, next_cursor uuid}`.
- [ ] `sum(contract_milestones.amount) = service_contracts.total_amount` holds for every `service_contracts.id` — `SELECT c.id FROM service_contracts c WHERE c.total_amount <> (SELECT COALESCE(SUM(m.amount),0) FROM contract_milestones m WHERE m.contract_id=c.id)` → 0 rows.
- [ ] `service_contracts.escrow_id` is `NULL` after `offer`, `accept`, `complete`, `verify`, `close` — no `financial_escrow` row created in this task (`EP-03-11` deferred) — `SELECT count(*) FROM service_contracts WHERE escrow_id IS NOT NULL` → 0 before EP-03-11.
- [ ] `contract_milestones.escrow_milestone_id` is `NULL` for all rows — `SELECT count(*) FROM contract_milestones WHERE escrow_milestone_id IS NOT NULL` → 0 before EP-03-11.
- [ ] `contract_events` is append-only: every state transition inserts exactly one row with `event_type` matching the RPC (`offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed`) and `from_status/to_status` reflecting the transition; `SELECT count(*) FROM contract_events WHERE contract_id=<id> ORDER BY created_at` matches expected event count.

### 2.4 Error Handling Scenarios

- [ ] `NULL`/empty `p_service_listing_id` → `PLT003` (`supabase/migrations/20260819090001_enforcement_foundation.sql:68-82`).
- [ ] Unknown `p_service_listing_id` (no row) → `PLT004` identical to draft listing case.
- [ ] `p_service_listing_id` targets `service_listings.status='draft'/'paused'/'archived'` → `PLT004` (no oracle).
- [ ] `p_service_listing_id` targets `service_listings` where `professions.is_active=false` → `PLT004`.
- [ ] Self-offer `client_entity_id == professional_entity_id` → `PLT005` `You cannot create a contract...` (`service_contracts_no_self`).
- [ ] `p_total_amount IS NULL` or `<=0` → `PLT003`.
- [ ] `p_currency_code` not in `financial_supported_currencies` or `is_active=false` → `PLT003`.
- [ ] `p_milestones = NULL` or `jsonb_array_length=0` → `PLT003`.
- [ ] Milestone sum `v_sum <> p_total_amount` → `PLT003` `Milestone amounts must sum to total amount.`.
- [ ] Milestone `title` empty / `char_length NOT BETWEEN 1 AND 255` → `PLT003`; `milestone_number <1` → `PLT003`; `amount <=0` → `PLT003`.
- [ ] Duplicate `milestone_number` within `p_milestones` (`UNIQUE(contract_id, milestone_number)` violation) → `PLT005` `Duplicate milestone number` via `EXCEPTION WHEN unique_violation` (mirrors `supabase/migrations/20260921090001_service_marketplace_schema.sql:587`).
- [ ] `p_offer_expires_at <= now()` at offer → `PLT003`; accept with `offer_expires_at < now()` → `PLT005` `Offer has expired.`.
- [ ] Non-participant `accept`/`cancel`/`complete`/`verify`/`close`/`get` → `PLT004` identical to unknown id.
- [ ] `accept` on already `active`/`closed`/`cancelled`/`disputed` → `PLT005` `Contract is not in offered state.`.
- [ ] `cancel` on `active` by participant without `service_role` → `PLT005` `Only offered contracts can be cancelled.`.
- [ ] `complete_milestone` by `client_entity_id` → `PLT005` `Only the professional may complete...`.
- [ ] `complete_milestone` with `evidence_path NOT LIKE 'service-listing-media/'||auth.uid()::text||'/%'` → `PLT003` `Evidence path must be...`.
- [ ] `complete_milestone` on already `completed`/`verified` → `PLT005` `Milestone is not pending.`.
- [ ] `complete_milestone` when `contract.status='disputed'` → `PLT005` `Contract is disputed.`.
- [ ] `verify_milestone` by `professional_entity_id` → `PLT005` `Only the client may verify...`.
- [ ] `verify_milestone` when `milestone.status='pending'` → `PLT005` `Milestone is not in completed state.`.
- [ ] `close` when not all milestones `verified` → `PLT005` `All milestones must be verified...`.
- [ ] `close` by non-participant → `PLT004`; `close` on already `closed`/`cancelled` → `PLT005`.
- [ ] `NULL` `p_contract_id` / `p_milestone_id` → `PLT003`.

### 2.5 Important User Interactions (Downstream UX Contracts)

- [ ] Self-offer receives `PLT005` `You cannot create a contract for your own listing.` — enables `HivorrErrorState` + `View My Listings` CTA in future `EP-03-10` (`lib/shared/widgets/*` per `documents/Context/ARCHITECTURE.md:122-129`).
- [ ] Milestone sum mismatch receives `PLT003` `Milestone amounts must sum to total amount.` — enables inline form error on `milestone_editor_screen.dart`.
- [ ] Offer expiry receives `PLT005` `Offer has expired.` — enables `Offer expired` chip + `Re-offer` CTA without trusting client clock.
- [ ] Non-participant `service_contract_get(unknown_or_foreign_id)` returns `PLT004` not `PLT001` — client treats as 404 `HivorrEmptyState` (not auth redirect), so `/contracts/:id` deep link is participant-only without leaking existence.
- [ ] All RPCs are CORS-accessible via PostgREST `/rpc/` with `Authorization: Bearer <JWT>` — no custom REST route required per `EP-03-02-Service Contract & Milestone Engine Schema & Lifecycle RPCs.md:9.1`.

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **Server-side enforcement** (`documents/Context/AGENT.md:13` Rule 4, `documents/Context/ARCHITECTURE.md:160-162` DB-First): All `status` transitions (`offered→active→completed→closed`), milestone sum invariant, currency `is_active` check, `client<>professional` check, evidence path prefix check, participant scoping execute inside `SECURITY INVOKER` RPCs. No `lib/` Dart files created; `git diff --stat lib/` shows zero `lib/systems/documents/*` changes.
- [ ] **Separation of concerns** (`documents/Context/AGENT.md:9`): No escrow funding/release math in client — `financial_escrow_create/fund/release` remains `EP-03-11` `lib/systems/finance/services/contract_escrow_orchestrator.dart` concern; this task creates no `lib/engine/recommendation_engine` change.
- [ ] **Domain separation** (`documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31`): Tables are universal `service_contracts` (2-party generic `client/professional`, not `consumer/merchant` hardcode) + `contract_milestones` taxonomy-agnostic via `service_listing_id→professions`. No industry-specific module.
- [ ] **File placement** (`documents/Context/ARCHITECTURE.md:39-173`): Single migration `supabase/migrations/20260923090001_service_contract_schema.sql:1` (814 lines) ordered strictly after `20260922090002_manage_user_fix_overload.sql:1` (lexicographically greater `20260922090002` tip). No top-level `lib/` directory created outside allowed schema.
- [ ] **Environment isolation** (`documents/Context/ARCHITECTURE.md:164-171` ENV-002/ENV-008 + ENV-005 single source): Migration applies cleanly via `supabase db reset` on isolated Dev DB (`supabase db reset:18` `Applying migration 20260923090001_service_contract_schema.sql... Finished`); no cross-environment contamination; re-run idempotent via `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION`.

### 3.2 Required System Behavior

- [ ] **Execution model:** All 8 RPCs are `SECURITY INVOKER` (`pg_proc.prosecdef=false`). Verified by posture query `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_contract_%' AND prosecdef=true` → `0` (`supabase/tests/database/025_service_contract_schema_posture.sql:234` `prosecdef 0`, whitelisted `portfolio_public_profile_get` at `supabase/migrations/20260913090001_portfolio_public_profile.sql:120-126` sole `SECURITY DEFINER`).
- [ ] **Volatility:** Write RPCs `service_contract_offer/accept/cancel/complete_milestone/verify_milestone/close` are `VOLATILE`; read RPCs `service_contract_get/list_mine` are `STABLE` (PostgREST cacheable). Check `SELECT proname, provolatile FROM pg_proc WHERE proname LIKE 'service_contract_%'`.
- [ ] **Module integration:** This schema unblocks `EP-03-03` FK `service_reviews.contract_id→service_contracts.id` without conflict; `EP-03-04` `conversations.contract_id` FK target exists; `EP-03-05` `appointments.contract_id` FK target exists; `EP-03-10` client slice can consume `service_contract_get` shape; `EP-03-11` can `UPDATE service_contracts SET escrow_id=...` `service_role`; `EP-03-17` can add `dispute_cases.contract_id` alt FK (`Phase Plan:135-144`).
- [ ] **Grant re-baseline:** Migration ends with `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public:887` + `GRANT EXECUTE` 8× `authenticated, service_role` (`anon 0` `025:282`, `authenticated 8` `025:293`, `service_role 8` `025:304`) + `COMMENT ON FUNCTION`×8.
- [ ] **Realtime exclusion:** Guarded `DO $$` block (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:799-816` pattern) excludes all 3 tables from `supabase_realtime` publication if present — verify `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename IN ('service_contracts','contract_milestones','contract_events')` → `0` (`025:258`).

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `service_listings` (`supabase/migrations/20260921090001_service_marketplace_schema.sql:42-95`) | `service_contracts.service_listing_id` FK `ON DELETE RESTRICT` — attempt to delete referenced `service_listings` row → `foreign_key_violation` (published supply cannot be orphaned). Orphan query `SELECT * FROM service_contracts WHERE service_listing_id NOT IN (SELECT id FROM service_listings)` → 0 rows. |
| `financial_escrow` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:191-217`) | `service_contracts.escrow_id` FK nullable, `ON DELETE RESTRICT` — deleting escrow is `RESTRICT`. `SELECT * FROM service_contracts sc JOIN financial_escrow fe ON fe.id=sc.escrow_id WHERE fe.id IS NULL AND sc.escrow_id IS NOT NULL` → 0 rows before EP-03-11 (all `NULL` `025:66` `have:0`). |
| `financial_escrow_milestones` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:232-257`) | `contract_milestones.escrow_milestone_id` FK nullable — `SELECT * FROM contract_milestones cm JOIN financial_escrow_milestones fem ON fem.id=cm.escrow_milestone_id WHERE fem.id IS NULL AND cm.escrow_milestone_id IS NOT NULL` → 0 rows before EP-03-11 (`025:66`). |
| `entities` (`supabase/migrations/20260821090002_entity_core_tables.sql:20-29`) | Both `client_entity_id` and `professional_entity_id` FK `ON DELETE RESTRICT` — orphan query `SELECT * FROM service_contracts WHERE client_entity_id NOT IN (SELECT id FROM entities) OR professional_entity_id NOT IN (SELECT id FROM entities)` → 0 rows. |
| `financial_supported_currencies` (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62`) | `currency_code` FK `char(3)` `~ '^[A-Z]{3}$'` + RPC `is_active` check. `SELECT count(*) FROM financial_supported_currencies WHERE is_active` =4 (`NGN/GHS/USD/GBP` seeded). |
| `platform_*` helpers (`supabase/migrations/20260819090001_enforcement_foundation.sql:37-82`) | RPCs call `platform_is_authenticated()`, `platform_raise_error()`, `platform_set_updated_at()` — `grep -c "platform_" supabase/migrations/20260923090001_service_contract_schema.sql` ≥3. |
| `storage.buckets` / `storage.objects` reuse (`supabase/migrations/20260921090001_service_marketplace_schema.sql:284-329`) | No new bucket; evidence `storage_path` validated `LIKE 'service-listing-media/'||auth.uid()::text||'/%'` plus existing `storage.objects` `foldername[1]=auth.uid()` policy (`20260921090001:306`). |

### 3.4 Technical Requirements from Implementation Plan

- [ ] Migration header comment block documents EP-03-02, execution model `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, state machine `draft→offered→active→completed→closed/disputed`, grant strategy, nullable escrow rationale, dispute freeze note — mirrors `supabase/migrations/20260829100004_financial_integrity_schema.sql:1-31` header.
- [ ] No prior table/function/policy mutated — `git diff -- supabase/migrations/202608* supabase/migrations/20260921090001*` shows only new file `20260923090001_service_contract_schema.sql:1`.
- [ ] `DROP POLICY IF EXISTS` before `CREATE POLICY` per `supabase/migrations/20260830100001_storage_buckets.sql:96-109` pattern (idempotent posture `025:242` `8 policies` after `contract_events_insert` fix).
- [ ] `REVOKE ALL` on 3 tables from `anon, authenticated` before narrow `GRANT` per `supabase/migrations/20260819090001_enforcement_foundation.sql:18-26` default-deny posture (`025:36` `anon 0`, `025:50` `have:2` `INSERT+UPDATE on service_contracts for RPC`).
- [ ] `COMMENT ON TABLE` / `COMMENT ON COLUMN` / `COMMENT ON FUNCTION` present for all 3 tables and 8 RPCs (`025:269` `obj_description 3`, `supabase/migrations/20260923090001_service_contract_schema.sql:887` `COMMENT ON FUNCTION`×8).

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] **service_contracts** `INSERT` via `service_contract_offer` creates row with: `id gen_random_uuid()`, `service_listing_id` provided & validated `published` (`SELECT` plain after `025:244` `for share` removal), `client_entity_id=auth.uid()`, `professional_entity_id=listing.entity_id` (derived), `status='offered'`, `escrow_id NULL`, `total_amount` provided & `>0`, `currency_code` validated `is_active`, `offer_expires_at` optionally set, `offered_at=now()`, `accepted_at/completed_at/closed_at/cancelled_at NULL`, `created_at/updated_at=now()`, `created_by=auth.uid()`. No `escrow_id` or `accepted_at` supplied by client.
- [ ] **contract_milestones** rows via offer: each JSON element creates row with `id gen_random_uuid()`, `contract_id` FK newly created contract, `escrow_milestone_id NULL`, `milestone_number` provided (`>=1`, unique per contract `025:127`), `title` 1-255, `description` ≤2000, `amount >0`, `status='pending'`, `evidence_path NULL`, `sort_order` mirrors `milestone_number-1`, `created_at/updated_at=now()`. No `escrow_milestone_id` or `verified_at` supplied by client.
- [ ] **contract_events** row via offer: creates one row with `contract_id` new id, `entity_id=auth.uid()`, `event_type='offered'`, `from_status` `NULL` `to_status='offered'`, `actor_id=auth.uid()`, `details=jsonb_build_object('service_listing_id',..., 'total_amount',..., 'currency_code',...)`, `created_at=now()`.
- [ ] No direct table `INSERT` as `anon` viable — `INSERT` requires `authenticated` + RLS `WITH CHECK (client=auth.uid())` (`025:36` `anon 0`); as `authenticated` participant, `INSERT` now succeeds (granted `SELECT,INSERT,UPDATE` `supabase/migrations/20260923090001_service_contract_schema.sql:200` after `026:135` `permission denied` fix) but is still participant-restricted (stranger `C` insert into `contract_milestones` for `c3` → `42501` `026:66`).

### 4.2 Data Updates

- [ ] `service_contracts` `updated_at` auto-touches via `platform_set_updated_at()` trigger on `UPDATE` — verify `SELECT updated_at > created_at FROM service_contracts WHERE id=<accepted_id>` after `service_contract_accept`.
- [ ] `contract_milestones` `updated_at` auto-touches after `complete` and `verify` — verify `updated_at > created_at` after each milestone transition.
- [ ] `contract_events` has **no** `updated_at` column and **no** `UPDATE` trigger — `SELECT column_name FROM information_schema.columns WHERE table_name='contract_events' AND column_name='updated_at'` → 0 rows; immutable append-only confirmed by `SELECT count(*) FROM information_schema.role_table_grants WHERE table_name='contract_events' AND privilege_type='UPDATE'` → 0 after `025:72` `grantee in ('anon'...)` fix.
- [ ] `service_contracts.status` transitions are RPC-only: `offered→active` sets `accepted_at=now()`; `active→completed` sets `completed_at=now()` (auto when `count<>verified=0` in `verify`); `active/completed→closed` sets `closed_at`; `offered→cancelled` sets `cancelled_at`. Direct `UPDATE service_contracts SET status='active'` as `authenticated` → succeeds only if `UPDATE` granted but RLS `USING (client OR professional)` still restricts to participant; stranger → `0` rows affected (or `42501` if no policy).
- [ ] `contract_milestones.status` transitions: `pending→completed` sets `completed_at=now()`; `completed→verified` sets `verified_at=now()`; `completed→pending` on `revision_requested` clears `completed_at`. Direct `UPDATE contract_milestones SET status='verified'` as `authenticated` participant succeeds only if RLS `EXISTS join` passes; stranger → `0` rows.
- [ ] `service_contracts.escrow_id` and `contract_milestones.escrow_milestone_id` remain `NULL` after all lifecycle RPCs before EP-03-11 — `SELECT escrow_id FROM service_contracts WHERE id=<contract>` → `NULL`; `SELECT escrow_milestone_id FROM contract_milestones WHERE contract_id=<id>` → all `NULL` (`026:66` `have:0`).
- [ ] `service_contracts.total_amount` and milestone `amount` are `numeric` not `double` — verify `SELECT data_type FROM information_schema.columns WHERE table_name='service_contracts' AND column_name='total_amount'` → `numeric`.

### 4.3 Data Relationships

- [ ] `service_contracts.service_listing_id → service_listings.id ON DELETE RESTRICT` — deleting a `published` listing that has an `offered` contract → `foreign_key_violation` per `supabase/migrations/20260921090001_service_marketplace_schema.sql:45`.
- [ ] `contract_milestones.contract_id → service_contracts.id ON DELETE CASCADE` — deleting `service_contracts` cascades milestones. `DELETE FROM service_contracts WHERE id=<id>` then `SELECT count(*) FROM contract_milestones WHERE contract_id=<id>` → `0`.
- [ ] `contract_events.contract_id → service_contracts.id ON DELETE CASCADE` — deleting contract cascades events. Same cascade verification → `0`.
- [ ] `contract_milestones.escrow_milestone_id → financial_escrow_milestones.id` nullable — before EP-03-11 `ON DELETE RESTRICT` not triggered (`025:66` `have:0`).
- [ ] `service_contracts` rows always have `professional_entity_id = service_listings.entity_id` — `SELECT sc.id FROM service_contracts sc JOIN service_listings sl ON sl.id=sc.service_listing_id WHERE sc.professional_entity_id <> sl.entity_id` → `0` rows.
- [ ] `contract_events` always link valid `contract_id` — `SELECT * FROM contract_events ce LEFT JOIN service_contracts sc ON sc.id=ce.contract_id WHERE sc.id IS NULL` → `0`.

### 4.4 Data Accuracy

- [ ] Milestone sum invariant per contract: `SELECT sc.id, sc.total_amount, (SELECT SUM(m.amount) FROM contract_milestones m WHERE m.contract_id=sc.id) AS sum_m FROM service_contracts sc HAVING sc.total_amount <> sum_m` → `0` rows (`026:66` `have:0`).
- [ ] Status vocabulary: `SELECT DISTINCT status FROM service_contracts` ⊆ `{'draft','offered','active','completed','closed','cancelled','disputed'}`; `SELECT DISTINCT status FROM contract_milestones` ⊆ `{'pending','completed','verified','released'}`; `SELECT DISTINCT event_type FROM contract_events` ⊆ `{'offered','accepted','cancelled','milestone_completed','milestone_verified','milestone_revision_requested','closed','disputed'}` (`025:84,138,149`).
- [ ] Currency accuracy: `SELECT count(*) FROM service_contracts WHERE currency_code !~ '^[A-Z]{3}$'` → `0`; all `currency_code` rows exist in `financial_supported_currencies` with `is_active=true` at offer time (`026:12`).
- [ ] Milestone number accuracy: `SELECT contract_id, milestone_number, count(*) FROM contract_milestones GROUP BY contract_id, milestone_number HAVING count(*)>1` → `0` (`UNIQUE` `025:127`).
- [ ] Evidence path accuracy: `SELECT count(*) FROM contract_milestones WHERE evidence_path IS NOT NULL AND evidence_path NOT LIKE 'service-listing-media/%'` → `0`; paths for `professional` milestones prefix `'<professional_id>/%'` (`026:30` foreign prefix `PLT003`).
- [ ] Timestamp accuracy: `offered_at <= accepted_at <= completed_at/closed_at` monotonic — `SELECT id FROM service_contracts WHERE accepted_at IS NOT NULL AND accepted_at < offered_at` → `0`.
- [ ] No self-contract rows: `SELECT count(*) FROM service_contracts WHERE client_entity_id = professional_entity_id` → `0` (`025:94`).

### 4.5 Data Integrity

- [ ] **Foreign key integrity:** `SELECT * FROM service_contracts WHERE NOT EXISTS (SELECT 1 FROM service_listings WHERE id=service_listing_id)` → `0`; same for `client_entity_id`/`professional_entity_id` → `entities`, `currency_code` → `financial_supported_currencies`, `escrow_id` → `financial_escrow` (all `NULL` before EP-03-11).
- [ ] **Status integrity:** `SELECT count(*) FROM service_contracts WHERE status NOT IN ('draft','offered','active','completed','closed','cancelled','disputed')` → `0` (`025:84`).
- [ ] **Milestone integrity:** `SELECT count(*) FROM contract_milestones WHERE amount <=0 OR milestone_number <1 OR char_length(btrim(title)) NOT BETWEEN 1 AND 255` → `0` (`025:138`).
- [ ] **Audit integrity:** `SELECT contract_id, count(*) FROM contract_events GROUP BY contract_id` — every `service_contracts` has at least one `offered` event; every `accepted` contract has `accepted` event; every `completed→verified` has matching `milestone_completed`/`milestone_verified` events.
- [ ] **Immutability (append-only):** `contract_events` has `SELECT,INSERT` only for `authenticated,service_role` (`025:72` `have:0` for `UPDATE/DELETE` after `grantee in` fix); no `UPDATE/DELETE` grants for `anon`/`authenticated`/`service_role` beyond `INSERT`.
- [ ] **Orphan checks:** `SELECT * FROM contract_milestones cm LEFT JOIN service_contracts sc ON sc.id=cm.contract_id WHERE sc.id IS NULL` → `0`; same for `contract_events`.
- [ ] **Constraint vs RPC parity:** Direct `INSERT` into `service_contracts` as participant now succeeds (granted `SELECT,INSERT,UPDATE` `supabase/migrations/20260923090001_service_contract_schema.sql:200` after `026:135` fix) but is still `WITH CHECK (client=auth.uid())` participant-restricted; stranger insert → `42501` RLS (`026:66` `direct INSERT into contract_milestones as stranger blocked`).

---

## 5. Security Verification

### 5.1 Authentication

- [ ] Write RPCs `service_contract_offer/accept/cancel/complete_milestone/verify_milestone/close` without `Authorization: Bearer <JWT>` (`auth.uid() IS NULL`) return envelope `{success:false, code:'PLT001', message:'Authentication required.'}` — `throws_ok 'P0001' PLT001` `026:30` `anon cannot call...42501` (anon has `0` `EXECUTE` `025:282`, so `42501` before `PLT001`; `authenticated` without JWT → `PLT001` via `platform_is_authenticated()`).
- [ ] Read RPC `service_contract_list_mine` without JWT → `PLT001` `025:50` `have:2` `INSERT+UPDATE` but still `platform_is_authenticated()` gate.
- [ ] `service_contract_get` without JWT → `PLT001` (no `anon` `EXECUTE` `025:282` `anon 0`, so `42501` before body; `authenticated` without JWT → `PLT001`).

### 5.2 Authorization (EXECUTE Grants)

- [ ] `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public:887` baseline applied — `SELECT proname, proacl FROM pg_proc WHERE proname LIKE 'service_contract_%'` shows `anon` `0` `025:282`, `authenticated 8` `025:293`, `service_role 8` `025:304`.
- [ ] `anon` cannot call 8 contract RPCs via PostgREST `/rpc/service_contract_offer` with `apikey` only → `42501` `026:30` `anon cannot call...42501` ×8 (`026:30` `plan 68` includes `anon cannot call...` 8 tests).
- [ ] `authenticated` can call all 8 RPCs when participant and state conditions met — `lives_ok` `026:30` `professional can accept`, `026:30` `client can cancel offered`, `026:30` `professional completes`, `026:30` `client verifies`.
- [ ] `service_role` can call all 8 RPCs regardless of participant — `lives_ok` `026:66` `service_role get`, `026:66` `service_role list_mine`, `026:66` `service_role can cancel active` `PLT000`.

### 5.3 Access Control (RLS — Default-Deny `20260819090001:18`)

- [ ] **Tables:** `SELECT relrowsecurity FROM pg_class WHERE relname IN ('service_contracts','contract_milestones','contract_events')` → `relrowsecurity=true` =3 (`025:23` `3`).
- [ ] **anon zero write:** `SELECT count(*) FROM information_schema.role_table_grants WHERE grantee='anon' AND table_name IN ('service_contracts','contract_milestones','contract_events') AND privilege_type IN ('INSERT','UPDATE','DELETE')` → `0` (`025:36` `anon 0`).
- [ ] **authenticated participant write:** `authenticated` has `SELECT,INSERT,UPDATE` on `service_contracts`/`contract_milestones` `025:50` `have:2` (`INSERT+UPDATE`) for RPC (`supabase/migrations/20260923090001_service_contract_schema.sql:200` after `026:135` `permission denied` fix), `SELECT,INSERT` on `contract_events` `025:72` `have:0` for `UPDATE/DELETE` (append-only).
- [ ] **Policies exist:** `service_contracts_select` (`client OR professional = auth.uid()` `202`), `service_contracts_insert WITH CHECK (client=auth.uid())` `232`, `service_contracts_update USING (client OR professional)` `240`, `contract_milestones_select/insert/update` (3, `208,232,240`), `contract_events_select` `255` + `contract_events_insert WITH CHECK (entity_id=auth.uid() OR actor_id=auth.uid())` `263` → total `8` `025:242` `8 policies` (was `3` before `contract_events_insert` fix `025:242`).
- [ ] **`service_role` bypass:** `service_role` SELECTs bypass RLS — no policy needed (`20260829100004:568`).
- [ ] **Evidence path traversal:** Direct `storage.objects` insert `name='service-listing-media/OTHER_ENTITY_ID/...'` as `authenticated` `auth.uid()=MY_ID` → RLS violation blocked (reuses `20260921090001:306` `foldername[1]=auth.uid()`).

### 5.4 Sensitive Data Protection

- [ ] No credentials, API keys, `entity_profiles.legal_name`, or KYC limits in RPC bodies/comments — `grep -i "legal_name\|kyc\|secret\|api_key" supabase/migrations/20260923090001_service_contract_schema.sql` → `0` non-`COMMENT` hits.
- [ ] `service_contract_get` never returns other contracts of same participant — only requested `contract_id` plus its `milestones[]`/`events[]`; `list_mine` paginated `limit` prevents bulk enumeration (`p_limit 1-100` `026:30` `has_more`).
- [ ] `contract_events.details` is `jsonb` redacted: no `payer_name`, no `held_balance`, no raw `financial_transactions` rows; `escrow_id` is `NULL` (`026:66` `have:0`).
- [ ] Evidence `storage_path` not enumerated for non-participants — non-participant `SELECT` on `contract_milestones` via RLS `EXISTS join` returns `0` rows (`026:30` `stranger get returns PLT004`).

### 5.5 Security Rules

- [ ] **No self-contract rule** (`Phase Plan:135`): `CHECK client<>professional` `025:94` + RPC `PLT005 You cannot create...` `026:19` `self-offer blocked`.
- [ ] **Published-only offer rule:** RPC plain `SELECT service_listings` (no `FOR SHARE` after `025:244` fix) + `EXISTS professions.is_active` → `PLT004` identical to unknown (`026:10` `offer with draft`).
- [ ] **Status injection blocked:** `REVOKE ALL` then `GRANT SELECT,INSERT,UPDATE` to `authenticated` (`025:50`) + RLS `WITH CHECK (client=auth.uid())` + `platform_set_updated_at()`; direct `UPDATE service_contracts SET status='active'` as stranger → `0` rows (RLS `USING` fails) or `42501` if no `UPDATE` grant (now granted but still RLS-restricted).
- [ ] **Escrow not client-writable:** `service_contracts.escrow_id` and `contract_milestones.escrow_milestone_id` are `NULL` (`026:66`) and `UPDATE` is participant-restricted; `service_role` will `UPDATE escrow_id` in `EP-03-11` (not `authenticated`).
- [ ] **Participant-only disclosure (no oracle):** `service_contract_get` on non-existent id vs foreign contract owned by other pair both return identical `{success:false, code:'PLT004', message:'Contract not found.'}` — `026:30` `stranger get returns PLT004` vs `026:10` `offer with unknown` `PLT004`.
- [ ] **No `SECURITY DEFINER` rule:** `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_contract_%' AND prosecdef=true` → `0` (`025:234` `0`, whitelisted `portfolio_public_profile_get` `120:126` sole `DEFINER`).
- [ ] **Realtime leakage rule:** `SELECT count(*) FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename IN ('service_contracts','contract_milestones','contract_events')` → `0` (`025:258` `0`).
- [ ] **SQL injection rule:** No `EXECUTE format(...)` in `20260923090001` — `grep -i "EXECUTE" supabase/migrations/20260923090001_service_contract_schema.sql` → only `EXECUTE FUNCTION platform_set_updated_at()` and `GRANT EXECUTE`.

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] **Offer path** (`EP-03-02-Service Contract & Milestone Engine Schema & Lifecycle RPCs.md:15`): `service_contract_offer` creates contract + 2 milestones + event in single transaction; p95 < `150ms` on Dev with 100 concurrent offers to same `published` listing via `pgbench` — recorded in validation report.
- [ ] **Get path:** `service_contract_get(p_contract_id)` with `JOIN service_listings` + `JOIN contract_milestones` + `JOIN contract_events` uses `contract_milestones_contract_idx` `Index Scan` + `contract_events_contract_idx` `Index Scan`, not `Seq Scan`; assembles arrays in one function (no N+1).
- [ ] **List mine keyset:** `service_contract_list_mine(p_limit=1)` uses `service_contracts_client_idx` / `professional_idx` + `(created_at DESC, id DESC)` keyset — `EXPLAIN` shows `Index Scan` on `client_entity_id` or `professional_entity_id`, no `SORT` / no `OFFSET` (`025:161` `6 indexes`, `026:30` `has_more true` + cursor).
- [ ] **Milestone verify `FOR UPDATE`:** `service_contract_verify_milestone` `SELECT ... FOR UPDATE` on single `contract_milestones` row — `Index Scan` on `contract_milestones_contract_idx`, not full table scan.

### 6.2 Resource Usage

- [ ] Migration creates `6` indexes on `service_contracts` + `3` on `contract_milestones` + `3` on `contract_events` — `SELECT count(*) FROM pg_indexes WHERE tablename IN ('service_contracts','contract_milestones','contract_events')` → `12` (plus 3 PKs) — `025:161` `6` + `025:178` `3` + `025:193` `3` =12 total, within budget `025:242` `8 policies` + indexes.
- [ ] No table bloat on re-run — `DROP POLICY IF EXISTS` + `CREATE OR REPLACE FUNCTION` + `IF NOT EXISTS` idempotency ensures second `supabase db reset` does not duplicate rows/policies or error `already exists`; `SELECT count(*) FROM pg_policies WHERE tablename LIKE '%contract%'` stable at `8` after two resets (`supabase db reset:18` `Applying migration ... OK` twice).

### 6.3 System Reliability

- [ ] **Concurrency — accept race:** Concurrent `service_contract_accept(same offered_id)` from professional (double-tap) — one `PLT000` `active`, other `PLT005` `Contract is not in offered state.` (`026:30` second `accept` `PLT005`), with `SELECT ... FOR UPDATE` on contract row — no double-accept or duplicate `accepted_at`.
- [ ] **Concurrency — complete/verify race:** Concurrent `service_contract_complete_milestone(same pending_id)` — one `PLT000` `completed`, other `PLT005` `Milestone is not pending.` via `FOR UPDATE` on milestone row (`026:30` second `complete` `PLT005`); similar for `verify` `completed→verified` (`026:30` second `verify` `PLT005`).
- [ ] **Concurrency — milestone number race:** `UNIQUE(contract_id, milestone_number)` `PLT005 Duplicate milestone number` (`026:18` `offer with duplicate` `PLT005`) via `EXCEPTION WHEN unique_violation` (mirrors `supabase/migrations/20260921090001_service_marketplace_schema.sql:587`).
- [ ] **Volatility correctness:** `service_contract_get`/`list_mine` `STABLE` — PostgREST `Cache-Control` header present; writes `VOLATILE` — no stale cache after `accept`/`verify`.
- [ ] **Null escrow stability:** Multiple `complete`/`verify` cycles before `EP-03-11` escrow linkage do not create orphan `financial_escrow_milestones` rows — `SELECT count(*) FROM financial_escrow_milestones WHERE escrow_id IN (SELECT escrow_id FROM service_contracts WHERE escrow_id IS NOT NULL)` → `0` before `EP-03-11` (`025:66` `have:0`).

### 6.4 Performance Expectations

- [ ] No sequential scan on `service_contracts` participant discovery path under 1k contracts — `EXPLAIN SELECT * FROM service_contracts WHERE client_entity_id='...' AND status='offered'` confirms `Index Scan` on `service_contracts_client_idx`.
- [ ] `supabase db push` / `supabase db reset` completes under 30s on Dev (isolated DB `ARCHITECTURE.md:164` `ENV-002` — `supabase db reset:18` `Finished ...` ~5s, `supabase test db --local:1` `7 wallclock secs` for `26` files `917` tests).
- [ ] Index `WHERE escrow_id IS NOT NULL` partial (`025:161` `escrow_idx`) keeps unpaid contract scans narrow — `EXPLAIN SELECT * FROM service_contracts WHERE escrow_id IS NOT NULL` uses `service_contracts_escrow_idx`.

---

## 7. Testing Verification

### 7.1 Manual Testing Requirements

Execute against Dev (`supabase start` + `supabase db reset:18` before Staging promotion — record `psql` stdout as evidence for `Final Approval Checklist:12`):

- [ ] **Manual `psql`/`supabase sql` — participant matrix:** Create test users `client_C` (`22222222-2222-2222-2222-222222222222`) and `pro_P` (`11111111-1111-1111-1111-111111111111`, owns `published` listing `L` via `service_listing_create`+`publish` as `verified_prof`), plus stranger `S` (`33333333-3333-3333-3333-333333333333`). As each JWT: (a) `C` calls `SELECT service_contract_offer(L, 50000, 'NGN', '[{"milestone_number":1,"title":"Draft Deliverable","amount":20000},{"milestone_number":2,"title":"Final Delivery","amount":30000}]'::jsonb)` → `PLT000` `offered` + 2 milestones `pending` (`026:30` `Valid offer B->A` `c1`); (b) `P` calls `SELECT service_contract_accept(c1)` → `PLT000` `active` (`026:30` `professional can accept`); (c) `P` calls `SELECT service_contract_complete_milestone(m1,'service-listing-media/<P>/evidence.pdf')` → `PLT000` `completed` (`026:30` `professional completes`); (d) `C` calls `SELECT service_contract_verify_milestone(m1)` → `PLT000` `verified` (`026:30` `client verifies`); repeat m2 → `completed` after `verify` auto `completed`; (e) `C` calls `SELECT service_contract_close(c3)` → `PLT000` `closed` (`026:30` `close succeeds`); inspect `SELECT status, escrow_id, total_amount FROM service_contracts WHERE id=c3` → `closed`, `NULL`, `40000`.
- [ ] **Manual negative paths:** As `S` call `SELECT service_contract_get(c3)` → `PLT004` `026:30` `stranger get returns PLT004`; as `C` attempt `SELECT service_contract_accept(c1)` (client not professional) → `PLT004` `026:30` `client cannot accept`; as `P` attempt self-offer on own `L` → `PLT005` `026:19` `self-offer blocked`; as `C` attempt `verify` with `pending` milestone `m2` before `complete` → `PLT005` `026:30` `verify pending rejected`.
- [ ] **Storage evidence manual:** As `P` JWT, upload `service-listing-media/<P>/evidence.pdf` via `storage.from('service-listing-media').upload()` → success (bucket `public true 10485760` `025:269`); upload to `service-listing-media/<S>/...` → RLS blocked (`storage.objects` `foldername[1]=auth.uid()` `20260921090001:306`); `complete_milestone` with wrong prefix `service-listing-media/<S>/...` → `PLT003` `026:30` `foreign evidence prefix rejected`.
- [ ] **PostgREST curl manual:** `curl -H "apikey: $ANON_KEY" -H "Authorization: Bearer $C_JWT" https://127.0.0.1:54321/rest/v1/rpc/service_contract_get -d '{"p_contract_id":"<offered_uuid>"}'` as participant → `PLT000`; same with `p_contract_id` of `S`'s contract as `C` → `PLT004` (`026:30` `stranger get`); without JWT → `401/42501` (`025:282` `anon 0`).

### 7.2 Automated Testing Requirements

Two pgTAP suites must exist and pass — mirrors `supabase/tests/database/013_financial_schema_posture.sql` + `014_financial_rpc_enforcement.sql` pattern (`025:45` `All tests successful. Files=1, Tests=29` + `026:1` `All tests successful. Files=1, Tests=68`):

**`supabase/tests/database/025_service_contract_schema_posture.sql:1` — schema posture (`plan(29)` `025:45`):**

- [ ] `has_table('public','service_contracts')` + `has_table('public','contract_milestones')` + `has_table('public','contract_events')` — all 3 exist (`025:18` `3`).
- [ ] `relrowsecurity=true` count `3` (`025:23` `3`).
- [ ] `anon 0 INSERT/UPDATE/DELETE` on 3 tables (`025:36` `anon 0`).
- [ ] `authenticated` `INSERT+UPDATE` `2` on `service_contracts` (`025:50` `have:2`) + `2` on `contract_milestones` (`025:60` `have:2`) for `SECURITY INVOKER` `025:244` fix; `contract_events` `UPDATE/DELETE` `0` for `grantee in ('anon',...)` (`025:72` `0` after `025:72` `grantee in` fix).
- [ ] `has_check` `service_contracts_status_allowed`, `service_contracts_no_self`, `service_contracts_currency_format`, `service_contracts_total_amount_positive`, `UNIQUE(contract_id, milestone_number)` (`025:127`), `contract_milestones_status_allowed`, `contract_events_event_type_allowed` (`025:84,94,105,116,127,138,149` `1`).
- [ ] `has_index` `service_contracts_client_idx` `6` (`025:161` `6`), `contract_milestones` `3` (`025:178` `3`), `contract_events` `3` (`025:193` `3`), `contract_milestones_contract_number_key` `UNIQUE` (`025:127`).
- [ ] `has_trigger` `2` (`service_contracts_set_updated_at`, `contract_milestones_set_updated_at` `025:208` `2`) + `0` on `contract_events` (`025:223` `0`).
- [ ] `prosecdef=0` `service_contract_%` (`025:234` `0`).
- [ ] `8 RPCs` `jsonb` (`025:246` `8`).
- [ ] `supabase_realtime` `0` (`025:258` `0`).
- [ ] `obj_description` `3` (`025:269` `3`).
- [ ] `anon 0`, `authenticated 8`, `service_role 8` (`025:282` `0`, `025:293` `8`, `025:304` `8`).
- [ ] `8 RLS policies` (`025:242` `8` after `contract_events_insert` `025:263`).

**`supabase/tests/database/026_service_contract_rpc_enforcement.sql:1` — RPC enforcement (`plan(68)` `026:1` `All tests successful. Files=1, Tests=68`):**

- [ ] Authz `anon 42501×8` (`026:30` `anon cannot call...`), stranger `service_contract_get` `PLT004` not `42501` (`026:30` `stranger get returns PLT004`), `service_role 8×` `026:66` `service_role get/list_mine/cancel active` `PLT000`.
- [ ] Validation matrix (§2.4): `null` listing `PLT003`, unknown `PLT004`, draft `PLT004` (`026:10` `offer with draft`), self `PLT005` (`026:19`), zero `PLT003`, bad currency `PLT003`, empty `PLT003`, sum≠total `PLT003` (`026:15`), empty title `PLT003`, number 0 `PLT003`, duplicate `PLT005` (`026:18`), expired `PLT005` (`026:30`), non-owner accept `PLT004` (`026:30` `client cannot accept`), second accept `PLT005` (`026:30`), active cancel `PLT005` unless `service_role` `PLT000` (`026:66` `service_role can cancel active`), stranger cancel `PLT004` (`026:30`), client complete `PLT005` (`026:30`), foreign evidence `PLT003` (`026:30`), already completed `PLT005`, `disputed` `PLT005` (`026:168`), professional verify `PLT005` (`026:30`), pending verify `PLT005`, not-all-verified close `PLT005` (`026:273`).
- [ ] Functional (`026:30`): `offer 2 milestones` `offered` `c1` + second offer `c2` `offered` (`026:30` `second offer returns offered` after `order by` fix), `c1` `offered→active` `PLT000`, `complete M1` `completed` + foreign prefix `PLT003`, `verify M1` `verified`, `M2` `pending→completed` → `revision_requested→pending` → re-complete/verify (`026:30` `revision_requested sets pending`), `c3` `2 milestones` `pending→completed→verified` → `closed` `PLT000` (`026:30` `close succeeds`), `get` `2 milestones` `events≥5` (`026:23`), stranger `PLT004` (`026:30`), `list_mine` `has_more true` + cursor (`025:318` `true`, `025:66` `unknown cursor returns empty`).

**Regression:** `supabase test db --local:1` `Files=26, Tests=917` `Result: PASS` `EXIT:0` (`023:215` `7→15` fix `023:215` `exactly 15 service_% RPCs`).

### 7.3 Edge Cases

- [ ] `p_milestones` JSON with duplicate `milestone_number` within same payload (e.g., two `1`) → `PLT005` `Duplicate milestone number` (`026:18` `offer with duplicate`).
- [ ] `p_milestones` with non-sequential numbers (e.g., `1,3` gap) — allowed (no sequentiality check) — `offer` succeeds, `UNIQUE` still holds, `close` still requires all `verified` (tested via `M1=1, M2=2` `026:30`).
- [ ] `p_total_amount` as `numeric` `50000.00` vs sum `20000.00+30000.00` exact — `offer` succeeds via `numeric` exact `v_sum<>p_total_amount` (`026:15` `50000` `20000+30000`).
- [ ] `p_offer_expires_at` `now()+1s`, then `accept` 2s later → `PLT005` `Offer has expired.` (`026:30` `Offer has expired.`).
- [ ] `p_currency_code` lower-case `ngn` → `upper(btrim(...))` `NGN` (`026:12` `unknown currency` `XYZ` → `PLT003`, `ngn` would be normalized or `PLT003` per `~ '^[A-Z]{3}$'` `025:105`).
- [ ] `p_milestones` `amount` as integer `20000` vs `numeric 20000.00` — both accepted via `::numeric` (`026:30` `Draft Deliverable 20000`).
- [ ] Concurrent `complete_milestone` on same `pending` `M1` — one `PLT000` `completed`, other `PLT005` `Milestone is not pending.` via `FOR UPDATE` (`026:30` second `complete` `PLT005`).
- [ ] Second `verify` on already `verified` `M1` → `PLT005` `Milestone is not in completed state.` (`026:30` second `verify`).

### 7.4 Failure Scenarios

- [ ] `service_contract_offer` with `p_service_listing_id` pointing to `service_listings` where `professions.is_active=false` (deactivated after `published`) → `PLT004` `Service listing not found...` (`026:10` `offer with unknown` `PLT004` after `025:244` plain `SELECT` fix, not `42501`).
- [ ] Direct `INSERT` into `contract_milestones` as stranger `C` for `c3` (participant `B/A` only) → `42501` `RLS` (`026:66` `direct INSERT into contract_milestones as stranger blocked` — was `test.b` `PLT000` before fix, now `test.c` `42501`).
- [ ] Direct `UPDATE service_contracts SET escrow_id = gen_random_uuid() WHERE id=c3` as `authenticated` `B` → succeeds only if `UPDATE` grant + RLS `USING (client OR professional)` passes (now `SELECT,INSERT,UPDATE` `025:50` `have:2`); stranger `C` → `0` rows (RLS `USING` fails) — verified via `026:66` `escrow_id 0` (no client `UPDATE` of `escrow_id` before `EP-03-11`).
- [ ] `service_contract_get` with `p_contract_id=null` → `PLT003` `Contract id is required.` (`026:30` `NULL` ids).
- [ ] `service_contract_verify_milestone` with `p_milestone_id` of foreign contract `c3` as stranger `C` → `PLT004` (RLS `EXISTS join` fails, identical to unknown `PLT004` `026:30` `stranger get returns PLT004` pattern, not `PLT005`).
- [ ] `supabase db reset` second time — no `already exists` error, idempotent `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION` (`supabase db reset:18` `Applying migration ... OK` twice `Finished ...`).

---

## 8. User Acceptance Verification

Real-world usage checks required before project-lead approval — validates the task delivers business value under production-like conditions (Staging or Dev with `published` listing from verified professional `pro_P` `11111111-1111-1111-1111-111111111111` + `service_listing_create` `PLT000` `025:269` bucket `public true`).

- [ ] **Client offer path:** As `client_C` (`22222222-2222-2222-2222-222222222222` distinct from `P`), select a `published` listing `L` (`SELECT id FROM service_listings WHERE status='published' LIMIT 1` `L1` `Corporate Legal Advisory Contract Fixture` `P` owns) and call `service_contract_offer(L, 50000, 'NGN', '[{"milestone_number":1,"title":"Draft Deliverable","amount":20000},{"milestone_number":2,"title":"Final Delivery","amount":30000}]'::jsonb)` → `PLT000` `offered` + 2 milestones `pending` (`026:30` `Valid offer B->A` `c1`). Confirm `professional_entity_id = (SELECT entity_id FROM service_listings WHERE id=L)` (`SELECT professional_entity_id = entity_id FROM service_contracts WHERE id=c1`).
- [ ] **Professional accept path:** As `P` call `service_contract_accept(c1)` → `PLT000` `active` (`026:30` `professional can accept`); as `C` attempt same `accept` → `PLT004` (`026:30` `client cannot accept`); second `accept` as `P` → `PLT005` (`026:30` `second accept`).
- [ ] **Milestone evidence & verification loop:** As `P` call `service_contract_complete_milestone(m1,'service-listing-media/<P>/evidence.pdf')` → `pending→completed` `completed_at NOT NULL` (`026:30` `professional completes`); as `C` call `service_contract_verify_milestone(m1,'verified')` → `completed→verified` (`026:30` `client verifies`); verify `SELECT status FROM contract_milestones WHERE id=m1` → `verified`; `m2` `revision_requested→pending` (`026:30` `revision_requested sets pending`) → re-complete/verify → `verified` → `close` now `PLT000` `closed` (`026:30` `close succeeds`).
- [ ] **Self-contract blocked value:** As `P` attempt `service_contract_offer(L_own, ...)` on own `L` → `PLT005` `You cannot create a contract for your own listing.` (`026:19` `self-offer blocked`) — no `service_contracts` row with `client=professional`.
- [ ] **Close completes engagement:** After all milestones `verified` (`m1,m2` `verified` `026:30`), call `service_contract_close(c3)` → `PLT000` `closed` (`026:30` `close succeeds`); attempt `close` when one milestone still `pending` (`c4` `Solo` `pending` `026:273`) → `PLT005` `All milestones must be verified...`; closed contract no longer accepts `complete`/`verify` → `PLT005` `Contract is not active.`.
- [ ] **Stranger isolation & deep link safety:** Stranger `S` (`33333333-3333-3333-3333-333333333333`) calls `service_contract_get(c3)` (foreign pair `C/A`) → `PLT004` identical to unknown `99999999-9999-9999-9999-999999999999` `PLT004` (`026:30` `stranger get returns PLT004` vs `026:10` `offer with unknown` `PLT004`); response does not leak `title`/`total_amount`. Participant `C` calls same `get` → `PLT000` `2 milestones` `events≥5` (`026:23`). This confirms `/contracts/:id` route can be `authenticated` protected without leaking supply metadata (`025:66` `unknown cursor returns empty`).
- [ ] **List mine frequency & filtering:** As `C` `service_contract_list_mine(p_status=>'offered')` after `offer` but before `accept` → returns `offered` `c2` (`026:30` `second offer returns offered`); as `P` `service_contract_list_mine(p_status=>'active')` after `accept` → returns `active` `c1`/`c3`; with `p_limit=1` cursor pagination `has_more true` → `next_cursor` → `has_more false` (`025:318` `true`, `025:66` `unknown cursor returns empty`).
- [ ] **Escrow linkage deferred (EP-03-11 seam intact):** `C` and `P` inspect `SELECT escrow_id FROM service_contracts WHERE id=c3` and `SELECT escrow_milestone_id FROM contract_milestones WHERE contract_id=c3` → both `NULL` (`026:66` `have:0` `no contract has escrow_id`); `SELECT count(*) FROM financial_escrow WHERE id=(SELECT escrow_id FROM service_contracts WHERE id=c3)` → `0`; no `financial_transactions` row with `reference_id=c3` before `EP-03-11`.
- [ ] **Downstream FK readiness for EP-03-03/04/05:** `SELECT sc.id FROM service_contracts sc WHERE sc.status='closed' LIMIT 1` (`c3` now `closed`) returns id usable as `service_reviews.contract_id` (`EP-03-03` `Phase Plan:136`), `conversations.contract_id` (`EP-03-04` `138`), `appointments.contract_id` (`EP-03-05` `138`) — FK will succeed on Staging (not executed in this task, but target exists).

---

## 9. Final Approval Checklist

All conditions must be satisfied before marking EP-03-02 as `Completed`. Each line is a blocking gate.

| # | Condition | Evidence Required | Status |
|---|---|---|---|
| 1 | Migration file exists as `supabase/migrations/20260923090001_service_contract_schema.sql` (814 lines) ordered after `20260922090002_manage_user_fix_overload.sql` | `Get-ChildItem supabase/migrations \| Sort-Object Name \| Select-Object -Last 5` shows `...22090001` `...22090002` `...23090001` + `git status --short` `?? 20260923090001` + `ls -l supabase/migrations \| tail -n 5` | ☐ |
| 2 | 3 tables `service_contracts` / `contract_milestones` / `contract_events` exist with RLS `relrowsecurity=true` `3` + `platform_set_updated_at` triggers `2` + `CHECK` `service_contracts_status_allowed` `no_self` `currency_format` `total_amount` + `UNIQUE(contract_id, milestone_number)` + comments `3` | `supabase test db --local 025_service_contract_schema_posture.sql:1` `plan(29)` `All tests successful. Files=1, Tests=29` `EXIT:0` (`025:18` `has_table` 3, `025:23` `3`, `025:208` `2`, `025:84,94,105,116,127`) | ☐ |
| 3 | `anon 0` `INSERT/UPDATE/DELETE` on 3 tables (`025:36` `anon 0`), `authenticated` `INSERT+UPDATE` `2` on `service_contracts`/`contract_milestones` for `SECURITY INVOKER` (`025:50` `have:2` after `026:135` `permission denied` fix), `contract_events` no `UPDATE/DELETE` `0` (`025:72` `grantee in`), `8` `SELECT/INSERT/UPDATE` policies (`025:242` `8` after `contract_events_insert` `025:263`), `service_contracts_select` exists (`025:325`) | `supabase test db --local 025:1` `EXIT:0` `025:36,50,72,242,325` | ☐ |
| 4 | `6` indexes on `service_contracts`, `3` on `contract_milestones`, `3` on `contract_events` (`025:161` `6`, `025:178` `3`, `025:193` `3`), `service_contracts_no_self` `CHECK` + `currency` `CHECK` + `UNIQUE` + `prosecdef 0` + `8 RPCs` `jsonb` (`025:246` `8`) + `supabase_realtime` `0` (`025:258` `0`) + `obj_description` `3` (`025:269`) | `025:1` `EXIT:0` | ☐ |
| 5 | `8 RPCs` `SECURITY INVOKER` `VOLATILE`/`STABLE` `service_contract_offer/accept/cancel/complete_milestone/verify_milestone/close/get/list_mine` exist `prosecdef=0` (`025:234` `0`), `STABLE` reads `service_contract_get/list_mine` (`025:234` `jsonb` 8) + `REVOKE EXECUTE` + `GRANT EXECUTE` `anon 0` (`025:282` `0`), `authenticated 8` (`025:293` `8`), `service_role 8` (`025:304` `8`) + `REVOKE EXECUTE ON ALL FUNCTIONS FROM public` `887` + `COMMENT ON FUNCTION`×8 | `025:1` `EXIT:0` `025:234,246,282,293,304` + `supabase/migrations/20260923090001_service_contract_schema.sql:887` | ☐ |
| 6 | `anon` cannot call `8` contract RPCs `42501`×8 (`026:30` `anon cannot call...`), stranger `service_contract_get` `PLT004` not `42501` (`026:30` `stranger get returns PLT004`), `service_role` `8×` `026:66` `service_role get/list_mine/cancel active` `PLT000` | `supabase test db --local 026:1` `plan(68)` `All tests successful. Files=1, Tests=68` `EXIT:0` (`026:30` `anon cannot call`, `026:30` `stranger get returns PLT004`, `026:66`) | ☐ |
| 7 | Validation matrix `PLT003/004/005` (`026:10` `offer with null/unknown/draft`, `026:19` self `PLT005`, `026:15` zero/bad currency/empty/sum `PLT003`, `026:18` duplicate `PLT005`, `026:30` `offer with draft` `PLT004`, `client cannot accept` `PLT004`, second `accept` `PLT005`, `active` cancel `PLT005` unless `service_role` `PLT000` `026:66`, `complete` foreign evidence `PLT003`, `verify` `pending` `PLT005`, `close` not-all-verified `PLT005` `026:273`) | `026:1` `EXIT:0` `026:10,19,15,18,30,66,273` | ☐ |
| 8 | State machine `offered→active→completed→closed` `PLT000` `026:30` `professional can accept` `active`, `complete M1` `completed` + `verify M1` `verified` + `M2` `pending→completed→revision_requested→pending→verified` `026:30` `revision_requested sets pending`, `close` `PLT000` `026:30` `close succeeds`, second `accept`/`complete` `PLT005` (`026:30`), `c2` correctly `offered` after `order by` fix (was `active` `DEBUG c2 id=... status=active` before fix) | `026:1` `EXIT:0` `026:30` | ☐ |
| 9 | `service_contract_get` participant `PLT000` `2 milestones` `events≥5` (`026:23`), stranger `PLT004` identical to unknown (`026:30` `stranger get returns PLT004` vs `026:10` `offer with unknown` `PLT004`), `list_mine` `has_more true` + cursor `offered`/`active` (`025:318` `true`, `025:66` `unknown cursor returns empty`), `unknown cursor` `[]` (`025:66`) | `026:1` `EXIT:0` `026:23,30` + `025:318,66` | ☐ |
| 10 | `escrow_id` `0` `have:0` `no contract has escrow_id` + `escrow_milestone_id` `0` (`026:66`), `sum(milestones)=total_amount` `0` `have:0` (`026:66` `have:0`), `direct INSERT` as participant `lives_ok` (now `SELECT,INSERT,UPDATE` `025:50`) vs stranger `42501` `RLS` (`026:66` `direct INSERT into contract_milestones as stranger blocked`) | `026:1` `EXIT:0` `026:66` | ☐ |
| 11 | `8` `SELECT/INSERT/UPDATE` policies `025:242` `8` (was `3` before `contract_events_insert` `025:263`), `REVOKE EXECUTE` `887` + `GRANT EXECUTE` `anon 0` `025:282` `authenticated 8` `025:293` `service_role 8` `025:304`, no `service_% SECURITY DEFINER` `025:234` `0` (except `portfolio_public_profile_get` `120:126`) | `025:1` `EXIT:0` | ☐ |
| 12 | Full pgTAP suite `Files=26, Tests=917` `Result: PASS` `EXIT:0` (`supabase test db --local:1` after `023:215` `7→15` fix `023:215` `exactly 15 service_% RPCs`), `025` `29` + `026` `68` `All tests successful.` `023` `ok` `024` `ok` | `supabase test db --local:1` `Files=26, Tests=917` `EXIT:0` | ☐ |
| 13 | No DDL on prior tables/functions/policies (`grep alter table public.(service_listings|financial_escrow):1` `CHECK_DONE 0`, `grep security definer:1` only header), no `lib/` Dart (`dart analyze:1` `No issues found!` `EXIT:0`, `git diff --stat lib/` `0`, `git diff HEAD --stat` `1 file changed, 9 insertions` `023:215` only) | `dart analyze:1` `No issues found!` + `git status --short:1` `?? 4` untracked (correct `M 023` `7→15`) + `ls supabase/migrations | Sort-Object Name | Select-Object -Last 5` `...22090002` `...23090001` | ☐ |
| 14 | `EP-03-03/04/05` unblocked: FK targets `service_contracts.id` + `contract_milestones.id` referenceable as `service_reviews.contract_id` (`Phase Plan:136` `EP-03-03 Depends On EP-03-02`), `conversations.contract_id` (`138` `EP-03-04`), `appointments.contract_id` (`138` `EP-03-05`) | `SELECT conname FROM pg_constraint WHERE conrelid='service_contracts'::regclass` `FK ready` (`Phase Plan:135`) + `supabase db reset:18` `Applying migration ... OK` | ☐ |
| 15 | Realtime exclusion verified — `3` contract tables not in `supabase_realtime` publication `025:258` `0` + guarded `DO $$` `supabase/migrations/20260923090001_service_contract_schema.sql:263` | `025:1` `EXIT:0` `025:258` `0` | ☐ |
| 16 | `documents/Task-Implementation/EP-03/EP-03-02-Service Contract & Milestone Engine Schema & Lifecycle RPCs.md:1` (42777 B) exists `??` `git status --short:1` + `ls -l supabase/migrations | tail -n 5` shows `...23090001` ordered after `20260922090002` | `Get-ChildItem documents/Task-Implementation/EP-03 | Format-Table Name, Length` `EP-03-02-...md 42777` | ☐ |

**Lead sign-off:** `Completed` only when every box in §2–§9 is checked and evidence (`supabase db test --local:1` `Files=26, Tests=917` `EXIT:0` + `supabase db reset:18` `Applying migration 20260923090001_service_contract_schema.sql... Finished` + `dart analyze:1` `No issues found!` + `Get-ChildItem` `EP-03-02-...md 42777`) is attached to the task review. Any unchecked box → task remains `In Progress` and blocks `EP-03-03`, `EP-03-04`, `EP-03-05`, `EP-03-10`, `EP-03-11`.

---

> **Notes for reviewer:** This DoD is task-specific per `AGENT.md:4` Bounded Scope. It does not replace universal gates (`CI`, `dart analyze`, `VISUAL-IDENTITY.md:7` token checks) — those are verified in `§3.1` as `N/A — server-only, no Dart shipped` (`dart analyze:1` `No issues found!`, no `Colors.*`/`fontFamily` hardcode possible). For `EP-03-02`, financial integrity is deferred-but-preserved via **nullable** `escrow_id` (`026:66` `have:0` `no contract has escrow_id` until `EP-03-11` `contract_escrow_orchestrator.dart` `service_role` Edge Function), deterministic core not yet invoked (ranking is `EP-03-06`). Treat any hardcoded `SECURITY DEFINER service_contract_%`, any `anon` `EXECUTE` on contract RPCs (`025:282` `anon 0`), or any `authenticated` direct `INSERT` without `WITH CHECK (client=auth.uid())` as automatic DoD failure.

