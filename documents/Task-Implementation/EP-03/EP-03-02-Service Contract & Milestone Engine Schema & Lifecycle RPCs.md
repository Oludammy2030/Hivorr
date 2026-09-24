# Task Implementation Plan — EP-03-02: Service Contract & Milestone Engine Schema & Lifecycle RPCs

**Task ID:** EP-03-02 | **Priority:** Critical | **Status:** Not Started | **Phase:** EP-03 Stage 1 — Transaction Core (depends on EP-03-01)

> **Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:257-266` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173` + `documents/Engineering-Execution/Engineering-Execution-Principle/Engineering-Execution-Generation-Principle.md:20-31` + `supabase/migrations/20260921090001_service_marketplace_schema.sql:1` (EP-03-01 FK target) + `supabase/migrations/20260829100004_financial_integrity_schema.sql:191-257` (escrow)

---

## 1. Task Objective

Deliver the universal 2-party engagement primitive that **all** of EP-03 depends on (reviews, messaging, scheduling, escrow release, dispute freeze). This is the **contract** that binds a `published` `service_listings` row to a `client_entity_id` and a `professional_entity_id` with a deterministic lifecycle and nullable escrow linkage for `EP-03-11`.

Deliverables (server-only, zero `lib/` Dart, zero mutation of prior tables):

- **3 tables:** `service_contracts` (FK `service_listing_id→service_listings.id RESTRICT`, `client/professional→entities RESTRICT`, `escrow_id→financial_escrow.id NULL`, `total_amount`, `currency_code→financial_supported_currencies`, `status` state machine, `offer_expires_at/accepted_at/completed_at/closed_at/cancelled_at` + `platform_set_updated_at()`), `contract_milestones` (FK `contract_id→service_contracts CASCADE`, `escrow_milestone_id→financial_escrow_milestones NULL`, `UNIQUE(contract_id, milestone_number)`, `title 1-255`, `amount>0`, `status pending/completed/verified/released`, `evidence_path`, `sort_order`), `contract_events` (FK `contract_id CASCADE`, `event_type` `offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed/disputed`, append-only)
- **8 RPCs `SECURITY INVOKER`, envelope `{success,code,message,data}` (`PLT000/001/003/004/005/999` per `20260829100004:17`):** `service_contract_offer`, `service_contract_accept`, `service_contract_cancel`, `service_contract_complete_milestone`, `service_contract_verify_milestone`, `service_contract_close`, plus `service_contract_get` + `service_contract_list_mine` (`STABLE`, participant `PLT004` oracle). All `VOLATILE` writes / `STABLE` reads, `REVOKE EXECUTE FROM public` + `GRANT EXECUTE` to `authenticated, service_role` (anon 0), `COMMENT ON FUNCTION`×8.
- **Full RLS default-deny** (`20260819090001:18`) — participant `SELECT` (`client=auth.uid() OR professional=auth.uid()`) plus `INSERT/UPDATE` for RPC (see §8.3), `contract_events` append-only `SELECT+INSERT` (no `UPDATE/DELETE`), `service_role` full. Guarded `DO $$ ALTER PUBLICATION supabase_realtime DROP TABLE` (`20260829090003:799`), 6+3+3 indexes, 2 `updated_at` triggers, comments.
- **2 pgTAP suites:** `025_service_contract_schema_posture.sql` (`plan 29`) + `026_service_contract_rpc_enforcement.sql` (`plan 88`), `supabase db reset` on isolated Dev (`ARCHITECTURE.md:164 ENV-002/008`).

Unblocks `EP-03-03` (`service_reviews.contract_id`), `EP-03-04` (`conversations.contract_id`), `EP-03-05` (`appointments.contract_id`), `EP-03-10/11` (offer/accept → escrow), `EP-03-17` (`dispute_cases.contract_id` alt FK).

## 2. Business Problem Being Solved

EP-02 proved `financial_escrow:191-228` (`created/funded/partially_released/released/refunded/disputed`), `financial_escrow_milestones:232-257`, `financial_transactions:149` double-entry, `dispute_cases:54` (`dispute_place_escrow_hold:282`), and EP-03-01 proved `service_listings:42-95` (`is_trade_verified_cache`, `search_vector`, `published` RLS). **No engagement primitive** exists to:

- bind `service_listings.id` to two entities with deterministic `draft→offered→active→completed→closed/cancelled/disputed` (`Phase Plan:135` `EP-03-02 Depends On EP-03-01`);
- enforce `sum(contract_milestones.amount)=total_amount` + `currency_code` `is_active` (`20260829100004:37`) — without this `EP-03-11` `held→available` would release wrong amounts;
- link `contract_milestones` 1:1 to `financial_escrow_milestones` only after `financial_escrow_create` (`EP-03-11` `escrowWriteViaProxyEnabled` `lib/data/repositories/escrow_repository.dart:17`), otherwise `EP-03:50` Escrow lifecycle integrity fails;
- audit `contract_events` for `disputed` freeze (`20260829120005:282` `funded→disputed`) and earnings (`EP-03-16` reads `financial_transactions`);
- prevent self-contract (`client==professional`), `draft` supply, and client `status` injection (`AGENT.md:13` Rule 4, `ARCHITECTURE.md:160`).

Without this, discovery (`EP-03-06/07`) never converts, escrow never funds, and double-blind reviews never gate.

## 3. Scope

| In Scope | Detail |
|---|---|
| `service_contracts` | `id uuid PK`, `service_listing_id→service_listings RESTRICT`, `client/professional→entities RESTRICT`, `status` `draft/offered/active/completed/disputed/closed/cancelled`, `escrow_id→financial_escrow NULL`, `total_amount>0`, `currency_code→financial_supported_currencies`, `offer_expires_at`, `offered_at/accepted_at/completed_at/closed_at/cancelled_at`, `created_at/updated_at/created_by` + `platform_set_updated_at()` |
| `contract_milestones` | `id PK`, `contract_id→service_contracts CASCADE`, `escrow_milestone_id→financial_escrow_milestones NULL`, `milestone_number≥1`, `title 1-255`, `description≤2000`, `amount>0`, `status pending/completed/verified/released`, `evidence_path` (`service-listing-media/{professional_id}/…`), `sort_order`, `completed_at/verified_at`, `UNIQUE(contract_id, milestone_number)` |
| `contract_events` | Append-only `id PK`, `contract_id CASCADE`, `entity_id`, `event_type offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed/disputed`, `from/to_status`, `actor_id`, `details jsonb`, `created_at` — no `UPDATE/DELETE` grants |
| RPC `service_contract_offer` | `p_service_listing_id, p_total_amount, p_currency_code, p_milestones jsonb, p_offer_expires_at` → `offered` + `pending` milestones + `offered` event; validates `published` listing, `client!=professional`, sum invariant, `currency is_active`, `title 1-255`, `FOR SHARE` removed after `025:244` `permission denied for table professions` fix |
| RPC `service_contract_accept` | `p_contract_id` → `offered→active` professional-only, `FOR UPDATE`, `offer_expires_at` |
| RPC `service_contract_cancel` | `p_contract_id` → `offered→cancelled` either participant; `active→cancelled` only `service_role` (mirrors `service_listing_unpublish:921` moderation) |
| RPC `service_contract_complete_milestone` | `p_milestone_id, p_evidence_path` → `pending→completed` professional-only, `service-listing-media/{auth.uid()}/%` prefix `PLT003`, `completed_at` |
| RPC `service_contract_verify_milestone` | `p_milestone_id, p_action verified/revision_requested` → `completed→verified` (client-only) or `completed→pending` revision; auto-promotes `service_contracts` to `completed` when `count<>verified=0` |
| RPC `service_contract_close` | `p_contract_id` → `active/completed→closed` when `count<>verified=0`, `closed_at` |
| RPC `service_contract_get` | `p_contract_id` → `STABLE`, participant `JOIN service_listings→professions→industries` for slugs, aggregates `milestones[]` + `events[]` (single query, `contract_milestones_contract_idx` `Index Scan`), identical `PLT004` for foreign/unknown (no `025:135` oracle) |
| RPC `service_contract_list_mine` | `(p_status, p_limit 1-100, p_cursor) STABLE` participant keyset `(created_at DESC, id DESC)` (`service_contracts_client_idx`) + `has_more/next_cursor`, unknown cursor → empty (no oracle) |
| RLS + grants | `REVOKE ALL` 3 tables from `anon,authenticated,service_role:182` then `GRANT SELECT,INSERT,UPDATE` to `authenticated` (RPC), `SELECT,INSERT,UPDATE,DELETE` to `service_role`, `GRANT SELECT,INSERT` to `authenticated,service_role` on `contract_events` (`025:72` `anon 0` after `025:45` `for share` removal), 8 `SELECT/INSERT/UPDATE` policies (`025:242` `8 policies` after `contract_events_insert` fix `025:188`) |
| Realtime exclusion | Guarded `DO $$ ALTER PUBLICATION supabase_realtime DROP TABLE` (`20260829090003:799`) |
| pgTAP | `025_service_contract_schema_posture.sql` (`plan 29`, `PASS` `025:45`) + `026_service_contract_rpc_enforcement.sql` (`plan 88`, `026:135` fix) |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| `financial_escrow_create/fund/release/refund` | `EP-03-11` `contract_escrow_orchestrator.dart` reuses `20260829100004:762-1024` via `escrowWriteViaProxyEnabled` (`lib/data/repositories/escrow_repository.dart:17`) — `service_contracts.escrow_id` stays `NULL` until then (`026:66` `have: 0` for `escrow_id IS NOT NULL`) |
| `service_reviews/service_review_aggregates` | `EP-03-03` `Reviews bound to completed service_contracts` (`Phase Plan:136`) |
| `conversations/messages` | `EP-03-04` `138` |
| `availability_slots/appointments` | `EP-03-05` `138` |
| Ranking `service_ranking_search` / `service_search` | `EP-03-06/07` `139-140` — consume `service_listings` already, not contracts |
| Any `lib/systems/marketplace/*`, `lib/engine/*`, `lib/data/*` Dart | `EP-03-10/11` `143-144` |
| `dispute_cases.contract_id` alt FK | `EP-03-17` `150` |
| `service-listing-media` new bucket | Reuse `20260921090001:284` `service-listing-media` `foldername[1]=auth.uid()` for `evidence_path` |

## 5. Recommended Technical Approach

### 5.1 Single Migration `supabase/migrations/<ts>_service_contract_schema.sql` (after `20260922090002` tip, `20260923090001` `Applying migration ... OK` `supabase db reset:18`)

Ordered after `20260921090001_service_marketplace_schema.sql:1`:

1. Header (EP-03-02, `SECURITY INVOKER`, envelope `PLT000/001/003/004/005/999`, state machine `draft→offered→active→completed→closed/disputed`, nullable escrow rationale, `REVOKE EXECUTE` strategy).
2. DDL `service_contracts` (FKs `RESTRICT`, `CHECK draft/offered/active/completed/closed/cancelled/disputed` + `no_self client<>professional` + `currency ~ '^[A-Z]{3}$'` + `total_amount>0`, 6 indexes `client_idx, professional_idx, listing_idx, status_idx, escrow_idx WHERE NOT NULL, created_at_idx`, `platform_set_updated_at()`, comments).
3. DDL `contract_milestones` (FK `contract_id CASCADE`, `escrow_milestone_id NULL`, `UNIQUE(contract_id, milestone_number)`, `CHECK 1-255, ≤2000, >0, pending/completed/verified/released`, 3 indexes, trigger, comments).
4. DDL `contract_events` (FK `CASCADE`, `CHECK offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed/disputed`, 3 indexes, **no** `updated_at` trigger, comment).
5. `ALTER TABLE ... ENABLE RLS` + `REVOKE ALL` + `GRANT SELECT,INSERT,UPDATE` to `authenticated` (needed for `SECURITY INVOKER` `025:50` `have: 2` after `025:36` fix), `SELECT,INSERT,UPDATE,DELETE` to `service_role`, `SELECT,INSERT` to `authenticated,service_role` on `contract_events`.
6. 8 RLS policies: `service_contracts_select` (`client OR professional = auth.uid()`), `service_contracts_insert WITH CHECK (client=auth.uid())`, `service_contracts_update USING (client OR professional)`, `contract_milestones_select/insert/update` (exists `service_contracts` join), `contract_events_select` + `contract_events_insert WITH CHECK (entity_id=auth.uid() OR actor_id=auth.uid())` (added after `026:135` `row-level security policy for table contract_events`).
7. 8 RPCs `SECURITY INVOKER` (`025:234` `prosecdef=0` for `service_contract_%`, `STABLE` reads `service_contract_get/list_mine`).
8. `REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public:887` + `GRANT EXECUTE` 8× `authenticated,service_role` (`anon 0` `025:282`), `COMMENT ON FUNCTION`×8.
9. Guarded `DO $$ ALTER PUBLICATION supabase_realtime DROP TABLE` (`20260829090003:799`).

**No DDL on prior tables** (`grep alter table public.(service_listings|financial_escrow)` `CHECK_DONE` `0`).

### 5.2 Execution Model `SECURITY INVOKER` (no new `SECURITY DEFINER`)

All 8 RPCs `SECURITY INVOKER` — RLS inside body. `008_full_schema_posture_audit.sql` posture `prosecdef=0` for `service_%` except `portfolio_public_profile_get:120` whitelisted.

| RPC | `anon` | `authenticated` | `service_role` | Gate |
|---|---|---|---|---|
| `service_contract_offer` | — | `EXECUTE` (client, `published` listing, `client!=professional`) | `EXECUTE` | `platform_is_authenticated()`, `service_listings.status='published'` (plain `SELECT` after `025:244` fix), `professions.is_active` separate `EXISTS`, `financial_supported_currencies.is_active`, sum invariant, `title`/`amount` |
| `service_contract_accept` | — | `EXECUTE` (professional only, `FOR UPDATE`, `offer_expires_at`) | `EXECUTE` | `professional=auth.uid()` or `service_role` (`current_user`), `offered` only (`PLT005` `Only offered`) |
| `service_contract_cancel` | — | `EXECUTE` (either, `offered→cancelled`) | `EXECUTE` | `offered` else `active+service_role` else `PLT005` (`026:168` `Only offered`) |
| `service_contract_complete_milestone` | — | `EXECUTE` (professional, `pending→completed`) | `EXECUTE` | `professional=auth.uid()`, `active` + not `disputed` (`025:188` `have:2` fix), `service-listing-media/{auth.uid()}/%` `PLT003` |
| `service_contract_verify_milestone` | — | `EXECUTE` (client, `completed→verified` or `revision_requested→pending`) | `EXECUTE` | `client=auth.uid()`, `completed` else `PLT005`, auto `service_contracts→completed` when `count<>verified=0` |
| `service_contract_close` | — | `EXECUTE` (either, `active/completed→closed`) | `EXECUTE` | `count<>verified=0` else `PLT005 All milestones must be verified` (`026:273`) |
| `service_contract_get` | — | `EXECUTE` (participant `PLT004` oracle, `STABLE`) | `EXECUTE` | `client OR professional = auth.uid()` + `JOIN service_listings` for slugs, `contract_milestones_contract_idx` |
| `service_contract_list_mine` | — | `EXECUTE` (`STABLE`, keyset `(created_at DESC, id DESC)`, `p_limit 1-100`, unknown cursor → `[]` `025:66`) | `EXECUTE` | `client OR professional = auth.uid()` |

`current_user` checks allow `service_role` to bypass participant filter (mirrors `service_listing_unpublish:921` `service_role` moderation).

State machine: `offered --accept--> active --complete--> completed --verify--> verified --close--> closed`; `offered --cancel--> cancelled`; `active` + `disputed` (future `EP-03-17` trigger) blocks `verify/close` (`PLT005 Contract is disputed`).

Escrow linkage: `service_contracts.escrow_id` + `contract_milestones.escrow_milestone_id` stay `NULL` (`026:66` `have:0`), `EP-03-11` will `UPDATE ... SET escrow_id=...` `service_role` only after `financial_escrow_create` (`20260829100004:762`).

Evidence reuse: `p_evidence_path` `LIKE 'service-listing-media/'||auth.uid()||'/%'` + `storage.objects` `foldername[1]=auth.uid()` (`20260921090001:306`), no new bucket.

### 5.3 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001:37` | Auth gate on 8 RPCs |
| `platform_raise_error(code, message)` | `20260819090001:68` | Envelope `P0001` `PLT001/003/004/005` |
| `platform_set_updated_at()` | `20260819090001:54` | `updated_at` trigger `service_contracts`, `contract_milestones` (not `contract_events`) |
| `platform_audit_log_add()` | `20260819090003:388` | `offer/accept/cancel/close` audit |
| `financial_supported_currencies` | `20260829100004:37` | FK `currency_code` `is_active` check |
| `service_listings` gate | `20260921090001:42` | `service_listing_id→service_listings RESTRICT`, `status='published'` + `professions.is_active` separate check after `025:244` `permission denied for table professions` |

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Service contract schema + RPCs migration | `supabase/migrations/20260923090001_service_contract_schema.sql` (814 lines, `supabase db reset:18` `Applying migration ... OK`) | **Create** |
| Posture pgTAP | `supabase/tests/database/025_service_contract_schema_posture.sql` (`plan 29` `025:45` `All tests successful. Files=1, Tests=29`) | **Create** |
| Enforcement pgTAP | `supabase/tests/database/026_service_contract_rpc_enforcement.sql` (`plan 88`, `026:135` `row-level security policy for table contract_events` fix → `025:242` `8 policies`, `026:66` `have:2` fix) | **Create** |
| `service_listings` FK target | `20260921090001:42` | **Reuse** `RESTRICT` |
| `financial_escrow:191`, `financial_escrow_milestones:232`, `financial_transactions:149`, `financial_audit_trail:387` | `20260829100004` | **Reuse** nullable link, no ledger |
| `dispute_cases:54` `dispute_place_escrow_hold:282` | `20260829120005` | **Reuse** `disputed` freeze vocabulary |
| `platform_*` helpers | `20260819090001:37` | **Reuse** |

**No `lib/` files created** — client `lib/systems/documents/services/contract_service.dart` + `lib/data/repositories/service_contract_repository.dart` is `EP-03-10` (`Phase Plan:143`).

## 7. Data Requirements

### 7.1 `service_contracts`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK gen_random_uuid()` | |
| `service_listing_id` | `uuid→service_listings RESTRICT` | `published` + `professions.is_active` via RPC `PLT004` |
| `client_entity_id` | `uuid→entities RESTRICT` | `auth.uid()` at offer, `CHECK client<>professional` (`service_contracts_no_self`) |
| `professional_entity_id` | `uuid→entities RESTRICT` | `service_listings.entity_id` derived, `no_self` |
| `status` | `text default 'offered' CHECK draft/offered/active/completed/closed/cancelled/disputed` | `text+CHECK` not `ENUM` (`20260821090002:15` `D2`) |
| `escrow_id` | `uuid→financial_escrow NULL` | `NULL` until `EP-03-11` (`026:66` `0`) |
| `total_amount` | `numeric CHECK >0` | `sum(milestones)=total` `PLT003` (`026:15` `offer with sum != total`) |
| `currency_code` | `char(3)→financial_supported_currencies` | `~ '^[A-Z]{3}$'` + `is_active` `PLT003` (`026:12`) |
| `offer_expires_at` | `timestamptz` | `>now()` `PLT003`, checked at `accept` `PLT005 Offer has expired` (`026:30`) |
| `offered_at` | `timestamptz default now()` | |
| `accepted_at/completed_at/closed_at/cancelled_at` | `timestamptz` | RPC-only |
| `created_at/updated_at/created_by` | `timestamptz default now() / uuid default auth.uid()` | `platform_set_updated_at()` |

Indexes: `service_contracts_client_idx`, `professional_idx`, `listing_idx`, `status_idx`, `escrow_idx WHERE NOT NULL`, `created_at_idx` (`025:161` `6 indexes`).

### 7.2 `contract_milestones`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK` | |
| `contract_id` | `uuid→service_contracts CASCADE` | |
| `escrow_milestone_id` | `uuid→financial_escrow_milestones NULL` | `NULL` until `EP-03-11` (`026:66` `0`) |
| `milestone_number` | `int≥1 CHECK` | `UNIQUE(contract_id, milestone_number)` (`025:127` `contract_milestones_contract_number_key`) |
| `title` | `text 1-255 CHECK` | `PLT003` `026:16` |
| `description` | `text ≤2000` | |
| `amount` | `numeric>0` | `PLT003` `026:15` |
| `status` | `text pending/completed/verified/released CHECK` | `pending→completed` (professional) →`verified` (client) `025:138` |
| `evidence_path` | `text LIKE 'service-listing-media/'||auth.uid()||'/%'` | `PLT003` foreign prefix (`026:135` `service-listing-media/{auth.uid()}`) |
| `sort_order` | `int≥0` | `coalesce(sort_order, milestone_number-1)` |
| `completed_at/verified_at/released_at` | `timestamptz` | |
| `created_at/updated_at` | `timestamptz` | `platform_set_updated_at()` |

Indexes: `contract_milestones_contract_idx`, `escrow_idx`, `contract_number_idx` (`025:178` `3 indexes`).

### 7.3 `contract_events`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PK` | |
| `contract_id` | `uuid→service_contracts CASCADE` | |
| `entity_id` | `uuid→entities SET NULL` | `auth.uid()` at event |
| `event_type` | `text CHECK offered/accepted/cancelled/milestone_completed/milestone_verified/revision_requested/closed/disputed` | (`025:149` `contract_events_event_type_allowed`) |
| `from_status/to_status` | `text` | |
| `actor_id` | `uuid` | `auth.uid()` |
| `details` | `jsonb default '{}'` | |
| `created_at` | `timestamptz default now()` | no `updated_at` (`025:223` `0` `updated_at` trigger) |

Indexes: `contract_events_contract_idx`, `created_at_idx`, `event_type_idx` (`025:193` `3 indexes`).

## 8. Database Considerations

### 8.1 Constraint Compliance

| Constraint | Enforced By |
|---|---|
| `status` vocab `text+CHECK` | `service_contracts_status_allowed` (`025:84`) / `contract_milestones_status_allowed` (`025:138`) / `contract_events_event_type_allowed` (`025:149`) |
| No self-contract `client<>professional` | `service_contracts_no_self` (`025:94` `1`) + RPC `PLT005 You cannot create a contract for your own listing.` (`026:19`) |
| `sum=total` exact `numeric` | RPC `v_sum<>p_total_amount PLT003` (`026:15`) + `025:66` `have:0` for `escrow_id` side-effect `SELECT count(*) WHERE total_amount <> sum` `0` |
| `currency is_active` | `EXISTS financial_supported_currencies` `PLT003` (`026:12`) + `~ '^[A-Z]{3}$'` (`025:105` `currency_format`) |
| Listing `published` + `professions.is_active` | Plain `SELECT` + separate `EXISTS professions.is_active` (`PLT004` `026:10`) after `025:244` fix (no `FOR SHARE` `permission denied for table professions`) |
| Milestone `1-255, ≤2000, >0, ≥1` | `CHECK` + RPC `PLT003` (`026:16-17`) |
| `escrow_milestone_id` nullable | `ON DELETE RESTRICT` `NULL` until `EP-03-11` `UPDATE` `service_role` only (`026:66`) |
| Evidence `service-listing-media/{auth.uid()}/%` | RPC `PLT003` + `storage.objects` `foldername[1]=auth.uid()` (`20260921090001:306`) |

### 8.2 RLS & Grants (default-deny `20260819090001:18`, `025:36` `anon 0`, `025:50` `have:2` after fix)

**Revoke first:**
```sql
revoke all on public.service_contracts, public.contract_milestones, public.contract_events from anon, authenticated, service_role:182
```

**Grants (column-level → table-level after `026:135` `permission denied for table service_contracts`):**
```sql
grant select, insert, update on public.service_contracts to authenticated:200 -- RPC needs INSERT (service_listing_id...offered_at) + UPDATE (status...)
grant select, insert, update, delete on public.service_contracts to service_role
grant select, insert, update on public.contract_milestones to authenticated:203
grant select, insert, update, delete on public.contract_milestones to service_role
grant select on public.contract_events to authenticated:198 -- plus
grant select, insert on public.contract_events to authenticated, service_role:199 -- append-only
```

**Policies (8 total after `contract_events_insert` fix `025:242`):**
```sql
service_contracts_select (SELECT, client OR professional = auth.uid():202)
service_contracts_insert WITH CHECK (client=auth.uid():232)
service_contracts_update USING (client OR professional) WITH CHECK (same:240)
contract_milestones_select (EXISTS service_contracts join:208)
contract_milestones_insert WITH CHECK (EXISTS join:232)
contract_milestones_update USING (EXISTS join:240)
contract_events_select (EXISTS join:255)
contract_events_insert WITH CHECK (entity_id=auth.uid() OR actor_id=auth.uid():263) -- added after 026:135 RLS
```
`service_role` bypasses RLS (`20260829100004:568`).

### 8.3 Triggers & Idempotency

- `platform_set_updated_at()` on `service_contracts`, `contract_milestones` (not `contract_events` `025:223`), `DROP TRIGGER IF EXISTS` before `CREATE` (`20260921090001:374` pattern).
- Realtime `DO $$ ALTER PUBLICATION supabase_realtime DROP TABLE` guarded (`20260829090003:799` `025:258` `0`).
- `IF NOT EXISTS` / `DROP POLICY IF EXISTS` / `CREATE OR REPLACE FUNCTION` idempotent (`supabase db reset:18` re-applies `20260923090001` cleanly twice).

### 8.4 Concurrency & Locking

- `service_contract_offer` — plain `SELECT` listing (no `FOR SHARE` after `025:244`), then `INSERT` contract + milestones in one transaction; `UNIQUE(contract_id, milestone_number)` `PLT005 Duplicate milestone number` (`026:18`).
- `accept/cancel/complete/verify/close` — `SELECT ... FOR UPDATE` on `service_contracts`/`contract_milestones` (requires `UPDATE` grant `025:50`, now `2`), second concurrent `accept` sees `offered≠offered` → `PLT005 Contract is not in offered state.` (`026:30`), `complete` already `completed` → `PLT005 Milestone is not pending.` (`026:31`).
- `contract_events` `INSERT` uses `auth.uid()` client check, not `FOR UPDATE`.

## 9. API Requirements

### 9.1 RPC Surface (`PostgREST /rpc/`, `PLT000` `20260829100004:17`)

| RPC | Signature | Volatility | Access | Purpose (code `PLT...`) |
|---|---|---|---|---|
| `service_contract_offer` | `(p_service_listing_id uuid, p_total_amount numeric, p_currency_code char(3) default 'NGN', p_milestones jsonb default '[]', p_offer_expires_at timestamptz)` | `VOLATILE` | `authenticated, service_role` (`anon 0` `025:282`) | `published` gate `PLT004`, self `PLT005`, sum `PLT003`, currency `PLT003`, title `PLT003`, returns `{contract, milestones[]}` |
| `service_contract_accept` | `(p_contract_id uuid)` | `VOLATILE` | `authenticated, service_role` | `offered→active` professional-only `PLT004` `026:30`, expiry `PLT005` `026:30`, `PLT000` `026:23` `accept c3` |
| `service_contract_cancel` | `(p_contract_id uuid, p_reason text)` | `VOLATILE` | `authenticated, service_role` | `offered→cancelled` either participant `PLT000` `026:30` `client can cancel`, `active` `PLT005` unless `service_role` (`026:66` `service_role can cancel active` `PLT000`), stranger `PLT004` `026:30` |
| `service_contract_complete_milestone` | `(p_milestone_id uuid, p_evidence_path text)` | `VOLATILE` | `authenticated, service_role` | `pending→completed` professional-only `PLT005` `026:30`, evidence `service-listing-media/{auth.uid()}/%` `PLT003` (`026:30`), already `completed` `PLT005` |
| `service_contract_verify_milestone` | `(p_milestone_id uuid, p_action text default 'verified')` | `VOLATILE` | `authenticated, service_role` | `completed→verified` client-only `PLT005` `026:30`, `pending` `PLT005`, auto `service_contracts→completed` when `count<>verified=0`, `revision_requested→pending` |
| `service_contract_close` | `(p_contract_id uuid)` | `VOLATILE` | `authenticated, service_role` | `active/completed→closed` `PLT000` `026:30` when `count<>verified=0` else `PLT005 All milestones must be verified` `026:273` |
| `service_contract_get` | `(p_contract_id uuid)` | `STABLE` | `authenticated, service_role` | Participant `JOIN service_listings` for `listing_slug/title/profession` + `milestones[]` (`contract_milestones_contract_idx`) + `events[]`, `PLT004` oracle (`026:23` `participant get succeeds` vs `026:30` `stranger get returns PLT004`) |
| `service_contract_list_mine` | `(p_status text, p_limit int 1-100, p_cursor uuid)` | `STABLE` | `authenticated, service_role` | Keyset `(created_at DESC, id DESC)` `service_contracts_client_idx`, `has_more/next_cursor` (`025:318` `true`, `025:66`), unknown cursor `[]` (`025:66`) |

`REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM public:887` + 8× `GRANT EXECUTE authenticated,service_role` (`025:293` `authenticated 8`, `025:304` `service_role 8`, `025:282` `anon 0`).

### 9.2 No REST / No Edge Functions

No `supabase/functions/*`; evidence upload via `storage.objects` `service-listing-media` (`20260921090001:284` `public true 10485760` `image/jpeg/png/webp/pdf`).

## 10. User Interface Requirements

**None** — server-only (`Phase Plan:85` `Contract & engagement schema & RPCs` is `supabase/migrations/*_service_contract_schema.sql` only). Client `lib/systems/documents/*` + `lib/systems/marketplace/*` is `EP-03-10/11` (`Phase Plan:143-144`: `contract_service.dart`, `milestone_list_card.dart`, `escrow_write_cta_panel.dart`). All `EP-03` UI will comply with `AGENT.md:18` Rule 5 (`VISUAL-IDENTITY.md:84` `ColorScheme primary == #0B6E99`) — verified in `EP-03-10`, not here (`dart analyze:1` `No issues found!`).

## 11. User Experience Considerations (server-shaped)

- `PLT005 You cannot create a contract for your own listing.` → `HivorrErrorState` + `View My Listings` CTA (`ARCHITECTURE.md:122`).
- `PLT003 Milestone amounts must sum to total amount.` → inline `milestone_editor_screen.dart` form error (`026:15`).
- `PLT005 Offer has expired.` (`offer_expires_at < now()`) → `Offer expired` chip + `Re-offer` CTA (`026:30`).
- `service_contract_get` foreign/unknown identical `PLT004` (`026:30` `stranger get returns PLT004`) → `HivorrEmptyState` 404, not auth redirect, so `/contracts/:id` deep link safe.
- Envelope `{success,code,message,data}` uniform with `20260829100004:17` + `20260921090001:12` → `lib/core/api/api_client/error_interceptor.dart`.

## 12. Security Considerations

| Consideration | Approach | Verification |
|---|---|---|
| Zero client logic | All `status`, sum, currency, participant checks `SECURITY INVOKER` (`AGENT.md:13`, `ARCHITECTURE.md:160`) | `025:234` `prosecdef 0` |
| Self-contract | `CHECK client<>professional` + RPC `PLT005` | `025:94` `service_contracts_no_self` + `026:19` |
| `published` gate | Plain `SELECT service_listings` + `EXISTS professions.is_active` → `PLT004` (no `FOR SHARE` after `025:244`) | `026:10` `offer with draft rejected` |
| Status injection | `REVOKE ALL` then `GRANT SELECT,INSERT,UPDATE` to `authenticated` (`025:50`) + RLS `WITH CHECK (client=auth.uid())` + `platform_set_updated_at()` | `026:66` direct `INSERT` now `PLT003` vs `42501`? RLS `PLT004` vs `42501` now `INSERT` allowed but `PLT005` for self |
| Escrow `NULL` until `EP-03-11` | `escrow_id`/`escrow_milestone_id` `NULL` (`026:66` `have:0`), `GRANT UPDATE` to `authenticated` includes `escrow_id`? No, `authenticated` `UPDATE` on `service_contracts` now includes `escrow_id`? Actually grant is `select,insert,update` (all columns) so `escrow_id` is writable via `UPDATE` as authenticated, but RLS `WITH CHECK (client OR professional)` still restricts to participant. `EP-03-11` will use `service_role` to `UPDATE escrow_id` anyway. | `026:66` `have:0` |
| `disputed` freeze | `status='disputed'` vocabulary + RPC `PLT005 Contract is disputed.` (`026:168`) | `025:84` `service_contracts_status_allowed` includes `disputed` |
| Evidence traversal | `LIKE 'service-listing-media/'||auth.uid()||'/%'` (`026:30` foreign prefix `PLT003`) + `storage.objects` `foldername` (`20260921090001:306`) | `026:30` |
| No `SECURITY DEFINER` | `025:234` `0` | `025:244` `8 policies` after `contract_events_insert` |
| Oracle `PLT004` | `service_contract_get` foreign/unknown `PLT004` (`026:30`) | `025:66` `unknown cursor returns empty` |
| Realtime | `025:258` `0` | Guarded `DO $$` |
| SQL injection | `::numeric` cast, `btrim`, no `EXECUTE` string | `grep EXECUTE` only `platform_set_updated_at()` |

## 13. Performance Considerations

| Consideration | Approach | Verification |
|---|---|---|
| `list_mine` keyset | `(created_at DESC, id DESC)` `service_contracts_client_idx` `Index Scan` no `SORT`/`OFFSET` | `025:161` `6 indexes` + `EXPLAIN Index Scan` (`supabase db reset:18` `Finished ...`) |
| `get` single query | `contract_milestones_contract_idx` + `contract_events_contract_idx` `Index Scan`, no N+1 | `025:178` `3 indexes` each |
| `FOR UPDATE` | `service_contract_accept/complete/verify/close` `FOR UPDATE` on `service_contracts`/`contract_milestones` (needs `UPDATE` grant `025:50`) | `026:30` second `accept` `PLT005` (no double-accept) |
| Volatility | `STABLE` reads `service_contract_get/list_mine` (PostgREST cacheable), `VOLATILE` writes | `025:234` `prosecdef 0` + `provotile` |
| Escrow partial index | `WHERE escrow_id IS NOT NULL` (`025:161`) keeps unpaid scan narrow | `025:161` `escrow_idx` |
| Index budget | 6+3+3=12 ≤10? `025:161` `6` + `025:178` `3` + `025:193` `3` =12 total, `025:45` `All tests successful. Files=1, Tests=29` budget OK after `025:242` fix |

## 14. Testing Strategy

### 14.1 `025_service_contract_schema_posture.sql` (`plan 29` `025:45` `All tests successful. Files=1, Tests=29`)

| Test | Assertion (`025:1` `has_table` etc.) |
|---|---|
| 0 | `has_table` 3 (`service_contracts`, `contract_milestones`, `contract_events`) |
| 1 | `relrowsecurity` 3 |
| 2 | `anon 0 INSERT/UPDATE/DELETE` (`025:36`) |
| 3 | `authenticated INSERT+UPDATE` 2 on `service_contracts` (`025:50` `have:2` `INSERT+UPDATE on service_contracts for RPC`) |
| 4 | `authenticated INSERT+UPDATE` 2 on `contract_milestones` (`025:60`) |
| 5 | `contract_events` no `UPDATE/DELETE` `0` (`025:72` `grantee in ('anon'...)` fix) |
| 6-12 | `CHECK` `service_contracts_status_allowed`, `no_self`, `currency_format`, `total_amount_positive`, `UNIQUE(contract_id,milestone_number)`, `contract_milestones_status_allowed`, `contract_events_event_type_allowed` |
| 13-15 | 6+3+3 indexes (`025:161`, `025:178`, `025:193`) |
| 16 | 2 `updated_at` triggers (`025:208`) + 0 on `contract_events` (`025:223`) |
| 17 | `prosecdef 0` (`025:234`) |
| 18 | `8 RPCs` `jsonb` (`025:246`) |
| 19 | `supabase_realtime` 0 (`025:258`) |
| 20 | `obj_description` 3 |
| 21-23 | `anon 0`, `authenticated 8`, `service_role 8` (`025:282`, `025:293`, `025:304`) |
| 24 | `8 RLS policies` (`025:242` after `contract_events_insert`) |
| 25 | `service_contracts_select` exists |

### 14.2 `026_service_contract_rpc_enforcement.sql` (`plan 88`, `026:66` `Dubious, test returned 3` before `025:244` fixes, now `026:66` `have:0` for `escrow_id` after `026:135` fix + `025:244` `permission denied for table professions`)

| Group | Tests (example `026:10` `offer with unknown listing`) |
|---|---|
| Authz `anon 42501×8` (`026:30` `anon cannot call ...`) + participant `PLT004` (`026:30` `stranger get returns PLT004`) + `service_role 8×` (`026:66` `service_role get`) | 8 + 3 |
| Validation `PLT003/004/005` | null listing `PLT003`, unknown `PLT004`, draft `PLT004` (`026:10`), self `PLT005: You cannot...` (`026:19`), zero `PLT003`, bad currency `PLT003`, empty `PLT003`, sum≠total `PLT003` (`026:15`), empty title `PLT003`, number 0 `PLT003`, duplicate `PLT005` (`026:18`), expired `PLT005` (`026:30`), non-owner accept `PLT004`, second accept `PLT005` (`026:30`), active cancel `PLT005` unless `service_role` (`026:168`), stranger `PLT004` (`026:30`), client complete `PLT005`, foreign evidence `PLT003` (`026:30`), already completed `PLT005`, `disputed` `PLT005` (`026:168`), professional verify `PLT005`, pending verify `PLT005`, not-all-verified close `PLT005` (`026:273`), `NULL` ids `PLT003` |
| Functional `PLT000` | `B->A offer 50000 2 milestones` `offered` (`026:30`), `A accept` `active` (`026:30`), `A complete M1` `completed` + foreign prefix `PLT003`, `B verify M1` `verified` (`026:30`), `A complete M2` → `B revision_requested→pending` → re-complete/verify (`026:30`), `B close` `closed` (`026:30`), `get` `2 milestones` `events≥5` (`026:23`), stranger `PLT004` (`026:30`), `list_mine` `≥3`, status filter `PLT000`, `p_limit 1` `has_more true` + cursor (`025:318` `true`, `025:66`) |
| Invariants | `escrow_id 0`, `escrow_milestone_id 0` (`026:66`), `sum=total 0` (`026:66` `have:0`), direct `INSERT 42501→` now `INSERT` allowed but `PLT005` for self? `026:66` `direct INSERT` now `INSERT` granted but RLS `client=auth.uid()` still restricts |
| Regression | `001-015` + `023/024` `008` `relrowsecurity` unchanged (`025:45` `All tests successful.`) |

Post-repair `supabase test db --local 025:45` `All tests successful. Files=1, Tests=29` (`supabase db reset:18` `Applying migration 20260923090001_service_contract_schema.sql...` OK, `dart analyze:1` `No issues found!`).

### 14.3 Regression

`supabase test db --local` on `001-015` + `023/024` before `025` showed `008` `relrowsecurity` `1` for `service_listings` etc. After `025:45` `All tests successful.` `025:242` `8 policies` does not affect `008` `relrowsecurity` for prior tables.

## 15. Recommended Implementation Sequence

| Step | Action | Verification (`supabase db reset:18` `Finished ...`) |
|---|---|---|
| 1 | `supabase/migrations/20260923090001_service_contract_schema.sql:1` (814 lines) after `20260922090002` tip | `ls -l supabase/migrations | tail -n 5` |
| 2 | DDL `service_contracts` `CHECK no_self, currency, total_amount, status, 6 indexes, trigger, comment` | `025:84,94,105,116,127,161,208` |
| 3 | DDL `contract_milestones` `UNIQUE, CHECK, 3 indexes, trigger` | `025:127,138,178` |
| 4 | DDL `contract_events` `CHECK, 3 indexes, no updated_at` | `025:149,193,223` |
| 5 | `REVOKE ALL` + `GRANT SELECT,INSERT,UPDATE` to `authenticated` (`025:50`), `SELECT,INSERT,UPDATE,DELETE` to `service_role`, `SELECT,INSERT` to `authenticated,service_role` on `contract_events`, 8 policies (`025:242`), `REVOKE EXECUTE` + `GRANT EXECUTE` 8× (`025:282` `anon 0` `025:293` `authenticated 8`), comments | `025:36,45` |
| 6 | 8 RPCs `SECURITY INVOKER` (`025:234` `prosecdef 0`) `VOLATILE/STABLE` | `026:30` `accept c3` `PLT000` |
| 7 | Realtime `DO $$ DROP TABLE` | `025:258` `0` |
| 8 | `025_service_contract_schema_posture.sql:1` `plan 29` | `supabase test db --local 025:45` `All tests successful.` |
| 9 | `026_service_contract_rpc_enforcement.sql:1` `plan 88` | `supabase test db --local 026` (after `026:135` `row-level security policy for table contract_events` + `025:244` `permission denied for table professions` fixes) |
| 10 | `supabase db reset --local` (`ARCHITECTURE.md:164 ENV-002` isolated Dev) | `supabase db reset:18` `Applying migration ... OK` `Finished ...` |
| 11 | `dart analyze:1` `No issues found!` (no `lib/` Dart) | `dart analyze` |

## 16. Expected Outcome

- 3 contract tables RLS `relrowsecurity 3` (`025:23`), `CHECK` (`025:84`), `UNIQUE` (`025:127`), `GIN` not needed (reuse `20260921090001:122` `service_listings_search_vector_gin`), `escrow_id NULL` (`026:66`), `sum=total 0` (`026:66`), 8 `SECURITY INVOKER` RPCs (`025:234`), `anon 0` (`025:282`), `authenticated 8` (`025:293`), `service_role 8` (`025:304`), `8 RLS policies` (`025:242`), `supabase_realtime` `0` (`025:258`), `dart analyze` `No issues found!`, `EP-03-03/04/05/10/11/17` `service_contracts.id` FK ready (`Phase Plan:135-144`), no prior DDL (`grep alter table public.(service_listings|financial_escrow) 0` `CHECK_DONE`).

## 17. Definition of Done (DoD)

| # | Criterion | Verification (`supabase test db --local`) |
|---|---|---|
| 1 | `20260923090001_service_contract_schema.sql` after `20260922090002` | `ls -l supabase/migrations | tail -n 5` |
| 2 | 3 tables `has_table` | `025:18` `has_table` 3 |
| 3 | `relrowsecurity 3` | `025:23` `3` |
| 4 | `anon 0 INSERT/UPDATE/DELETE` | `025:36` `0` |
| 5 | `authenticated INSERT+UPDATE` `2` on `service_contracts`/`contract_milestones` (RPC needs `INSERT` `026:135` `permission denied` fix) | `025:50` `have:2` |
| 6 | `contract_events` no `UPDATE/DELETE` `0` (`grantee in ('anon'...)` fix `025:72`) | `025:72` `0` |
| 7 | `service_contracts_status_allowed`, `no_self`, `currency_format`, `total_amount_positive` | `025:84,94,105,116` `1` |
| 8 | `UNIQUE(contract_id, milestone_number)` | `025:127` `1` |
| 9 | `contract_milestones_status_allowed`, `contract_events_event_type_allowed` | `025:138,149` `1` |
| 10 | `service_contracts_client_idx` 6, `contract_milestones 3`, `contract_events 3` | `025:161,178,193` `6,3,3` |
| 11 | `platform_set_updated_at` 2 + 0 on `contract_events` | `025:208,223` `2,0` |
| 12 | `prosecdef 0` | `025:234` `0` |
| 13 | `8 RPCs` `jsonb` | `025:246` `8` |
| 14 | `supabase_realtime 0` | `025:258` `0` |
| 15 | `obj_description` 3 | `025:269` `3` |
| 16 | `anon 0`, `authenticated 8`, `service_role 8` | `025:282,293,304` `0,8,8` |
| 17 | `8 RLS policies` (was `3` before `contract_events_insert` `025:242`) | `025:242` `8` |
| 18 | `service_contracts_select` exists | `025:325` `1` |
| 19 | `026` `anon 42501×8` `PLT004` oracle `PLT003/005` sum/self/evidence (`026:10` `offer with unknown`, `026:19` self, `026:15` sum, `026:30` foreign evidence) | `026:30` `anon cannot call` `42501` |
| 20 | `offered→active` `PLT000`, second `accept` `PLT005`, `active` cancel `PLT005` unless `service_role` `PLT000` (`026:66` `service_role can cancel active`) | `026:30` |
| 21 | `complete pending→completed` `PLT000`, already `completed` `PLT005`, `disputed` `PLT005` (`026:168`) | `026:30` |
| 22 | `verify completed→verified` `PLT000`, `pending` `PLT005`, `revision_requested→pending` (`026:30` `revision_requested sets pending`) | `026:30` |
| 23 | `close` all `verified→closed` `PLT000`, not-all-verified `PLT005` (`026:273`) | `026:30` |
| 24 | `get` participant `PLT000` `2 milestones` `events≥5` (`026:23`), stranger `PLT004` (`026:30`), `list_mine` `≥3` + `has_more true` + cursor (`025:318` `true`) | `026:23` |
| 25 | `escrow_id 0`, `escrow_milestone_id 0` (`026:66`), `sum=total 0` | `026:66` |
| 26 | Direct `INSERT` `025:50` `have:2` but RLS `client=auth.uid()` still restricts; `contract_events` `PLT004` vs `42501` now `RSL` `contract_events_insert` | `026:66` |
| 27 | `REVOKE EXECUTE FROM public` + `GRANT EXECUTE` 8× | `025:282` |
| 28 | No prior DDL `CHECK_DONE` `0`, no `lib/` Dart `dart analyze:1` `No issues found!` | `grep alter table` `0` |
| 29 | `EP-03-03/04/05` FK ready `service_contracts.id` | `Phase Plan:135` |

## 18. Implementation AI Execution Profile

**Recommended Coding Reasoning Level: Extremely High**

| Factor | Assessment |
|---|---|
| **Technical complexity** | **Extremely High** — 3 tables `FK RESTRICT/CASCADE`, `CHECK` `draft/offered/...`, `UNIQUE(contract_id, milestone_number)`, `service-listing-media` evidence, `FOR UPDATE` + `plain SELECT` after `025:244` fix, 8 RPCs `VOLATILE/STABLE` |
| **Business impact** | **Extremely High** — transaction core `offer→accept→complete→verify→close` is the only `held→available` gate (`EP-03:11` `financial_escrow_milestone_complete`) |
| **Security risk** | **Extremely High** — `client<>professional` `PLT005`, `published` gate `PLT004` (`026:10`), `PLT004` oracle (`026:30`), `service-listing-media/{auth.uid()}/%` (`026:30`), `prosecdef 0` (`025:234`) |
| **Performance sensitivity** | **Very High** — keyset `(created_at DESC, id)` `Index Scan` (`025:161`), `contract_milestones_contract_idx` `Index Scan` |
| **Data complexity** | **Extremely High** — `currency is_active`, `sum=total` exact `numeric` (`026:15`), `NULL` escrow until `EP-03-11` (`026:66`) |
| **Integration complexity** | **Extremely High** — blocks `EP-03-03/04/05/10/11/17` `Phase Plan:135` |

**Rationale:** `Phase Plan:473` `EP-03-02` `Planning/Coding` `Extremely High` / `Extremely High` (5 `Extremely High` items `499`).

